import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models.dart';

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime parseDay(String key) => DateFormat('yyyy-MM-dd').parse(key);
String newId(String prefix) =>
    prefix + DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// All reads and writes to Firestore for the signed-in user.
///
///   users/{uid}                 profile, goals, stepGoal, fast
///   users/{uid}/days/{date}     meals[], workouts[], waterMl, steps
///   users/{uid}/weights/{date}  kg
class Db {
  Db._();
  static final instance = Db._();

  final _fs = FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _fs.collection('users').doc(_uid);
  DocumentReference<Map<String, dynamic>> _dayDoc(String date) =>
      _userDoc.collection('days').doc(date);

  // ---------- profile ----------
  /// Latest profile seen (used by screens that need allergies etc.).
  Profile? current;

  Stream<Profile?> profileStream() => _userDoc.snapshots().map((s) {
        final d = s.data();
        if (d == null || d['goals'] == null) return null;
        return current = Profile.fromMap(d);
      });

  Future<void> saveProfile(Profile p) => _userDoc.set(
      {...p.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true));

  Future<void> setStepGoal(int steps) =>
      _userDoc.set({'stepGoal': steps, 'stepGoalCustom': true}, SetOptions(merge: true));

  Future<void> setFast(FastState f) =>
      _userDoc.set({'fast': f.toMap()}, SetOptions(merge: true));

  // ---------- days ----------
  Stream<DayLog> dayStream(String date) =>
      _dayDoc(date).snapshots().map((s) => DayLog.fromMap(date, s.data()));

  /// Read-modify-write of one day document inside a transaction.
  Future<void> _editDay(
      String date, void Function(Map<String, dynamic> data) edit) async {
    final ref = _dayDoc(date);
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      data['date'] = date;
      edit(data);
      tx.set(ref, data);
    });
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> d, String k) =>
      ((d[k] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> addMeal(String date, MealEntry meal) => _editDay(date, (d) {
        d['meals'] = [..._list(d, 'meals'), meal.toMap()];
      });

  Future<void> updateMeal(String date, MealEntry meal) => _editDay(date, (d) {
        d['meals'] = _list(d, 'meals')
            .map((m) => m['id'] == meal.id ? meal.toMap() : m)
            .toList();
      });

  Future<void> removeMeal(String date, String id) => _editDay(date, (d) {
        d['meals'] = _list(d, 'meals').where((m) => m['id'] != id).toList();
      });

  /// Instant (works offline too): the screen updates at once, the server syncs later.
  Future<void> addWater(String date, int ml) => _dayDoc(date)
      .set({'date': date, 'waterMl': FieldValue.increment(ml)}, SetOptions(merge: true));

  Future<void> setSteps(String date, int steps) => _dayDoc(date)
      .set({'date': date, 'steps': steps.clamp(0, 100000)}, SetOptions(merge: true));

  Future<void> saveWorkout(String date, Workout w) => _editDay(date, (d) {
        final list = _list(d, 'workouts');
        final i = list.indexWhere((x) => x['id'] == w.id);
        if (i >= 0) {
          list[i] = w.toMap();
        } else {
          list.add(w.toMap());
        }
        d['workouts'] = list;
      });

  Future<void> removeWorkout(String date, String id) => _editDay(date, (d) {
        d['workouts'] =
            _list(d, 'workouts').where((w) => w['id'] != id).toList();
      });

  /// Last [days] day logs, newest first (missing days are empty).
  Future<List<DayLog>> recentDays(int days) async {
    final today = DateTime.now();
    final from = dayKey(today.subtract(Duration(days: days - 1)));
    final q = await _userDoc
        .collection('days')
        .where('date', isGreaterThanOrEqualTo: from)
        .get();
    final byDate = {
      for (final d in q.docs) d.id: DayLog.fromMap(d.id, d.data()),
    };
    return List.generate(days, (i) {
      final k = dayKey(today.subtract(Duration(days: i)));
      return byDate[k] ?? DayLog.empty(k);
    });
  }

  /// Up to 8 different meals from the last 30 days, newest first.
  Future<List<MealEntry>> recentMeals() async {
    final days = await recentDays(30);
    final seen = <String>{};
    final out = <MealEntry>[];
    for (final d in days) {
      final ms = [...d.meals]..sort((a, b) => b.time.compareTo(a.time));
      for (final m in ms) {
        final sig = m.title.toLowerCase();
        if (m.items.isEmpty || seen.contains(sig)) continue;
        seen.add(sig);
        out.add(m);
        if (out.length >= 8) return out;
      }
    }
    return out;
  }

  /// Deletes every document of this user (days, weights, profile).
  Future<void> deleteAllMyData() async {
    for (final col in ['days', 'weights']) {
      while (true) {
        final q = await _userDoc.collection(col).limit(300).get();
        if (q.docs.isEmpty) break;
        final b = _fs.batch();
        for (final d in q.docs) {
          b.delete(d.reference);
        }
        await b.commit();
      }
    }
    await _userDoc.delete();
    current = null;
  }

  // ---------- weight ----------
  Future<void> logWeight(String date, double kg) async {
    await _userDoc.collection('weights').doc(date).set({'date': date, 'kg': kg});
    await _userDoc.set({'weightKg': kg}, SetOptions(merge: true));
  }

  Stream<List<WeightEntry>> weightsStream() => _userDoc
      .collection('weights')
      .orderBy('date')
      .limitToLast(90)
      .snapshots()
      .map((q) => q.docs
          .map((d) =>
              WeightEntry(d.id, (d.data()['kg'] as num?)?.toDouble() ?? 0))
          .toList());
}

/// Consecutive days (ending today or yesterday) that have at least one meal.
int streakFrom(List<DayLog> newestFirst) {
  var i = 0;
  if (newestFirst.isNotEmpty && newestFirst.first.meals.isEmpty) i = 1;
  var streak = 0;
  for (; i < newestFirst.length; i++) {
    if (newestFirst[i].meals.isEmpty) break;
    streak++;
  }
  return streak;
}
