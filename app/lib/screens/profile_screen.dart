import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/device.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/premium.dart';
import '../widgets/ui.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Profile profile;
  const ProfileScreen({super.key, required this.profile});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _bf = false, _water = false, _w = false, _steps = false;
  String _bfTime = '08:30', _wTime = '07:30';
  late final _stepGoal = TextEditingController(text: '${stepGoalOf(widget.profile)}');

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _stepGoal.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final bf = await Prefs.getBool('rem_bf'), water = await Prefs.getBool('rem_water');
    final w = await Prefs.getBool('rem_w'), steps = await StepsService.instance.isConnected;
    final bt = await Prefs.getString('rem_bf_time', '08:30'), wt = await Prefs.getString('rem_w_time', '07:30');
    if (mounted) {
      setState(() {
        _bf = bf;
        _water = water;
        _w = w;
        _steps = steps;
        _bfTime = bt;
        _wTime = wt;
      });
    }
  }

  Future<void> _toggle(String key, bool v) async {
    if (v) await Reminders.instance.askPermission();
    await Prefs.setBool(key, v);
    await Reminders.instance.apply();
    await _loadPrefs();
    if (mounted) toast(context, v ? 'Reminder on' : 'Reminder off');
  }

  Future<void> _pickTime(String key, String current) async {
    final parts = current.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0),
    );
    if (t == null) return;
    await Prefs.setString(key, '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    await Reminders.instance.apply();
    await _loadPrefs();
  }

  String _nice(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0, m = p.length > 1 ? p[1] : '00';
    return '${h % 12 == 0 ? 12 : h % 12}:$m ${h < 12 ? 'am' : 'pm'}';
  }

  Future<void> _connectSteps() async {
    final ok = await StepsService.instance.connect();
    await _loadPrefs();
    var days = 0;
    if (ok) days = await StepsService.instance.syncRecent((d, n) => Db.instance.setSteps(dayKey(d), n), force: true);
    if (mounted) {
      toast(context, ok ? 'Steps connected · $days day${days == 1 ? '' : 's'} of steps added' : 'Permission not given. You can still type steps.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final prof = widget.profile, g = prof.goals;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    const goalText = {'lose': 'Losing weight', 'maintain': 'Staying steady', 'gain': 'Building muscle'};

    Widget kv(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [Expanded(child: Muted(a, size: 14)), Text(b, style: const TextStyle(fontWeight: FontWeight.w800))]),
        );

    Widget remRow(String emoji, String title, String sub, bool on, ValueChanged<bool> onChanged, {String? time, VoidCallback? onTime}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Muted(sub, size: 12),
              ]),
            ),
            if (time != null)
              TextButton(onPressed: onTime, child: Text(_nice(time), style: const TextStyle(fontWeight: FontWeight.w800))),
            Switch(value: on, onChanged: onChanged, activeTrackColor: p.leaf),
          ]),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 130), children: [
      Panel(
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.forest, borderRadius: BorderRadius.circular(20)),
            child: Text(prof.name.isEmpty ? 'Y' : prof.name.trim()[0].toUpperCase(),
                style: display(context, 24, color: p.forestInk)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prof.name.isEmpty ? 'You' : prof.name, style: display(context, 20, weight: FontWeight.w700)),
              Muted('${goalText[prof.goal] ?? ''}${prof.goal != 'maintain' ? ', target ${prof.targetWeightKg.toStringAsFixed(1)} kg' : ''}'),
              if (email.isNotEmpty) Muted(email, size: 12),
            ]),
          ),
          const _AccountButton(),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Your body'),
          const SizedBox(height: 8),
          BmiCard(weightKg: prof.weightKg, heightCm: prof.heightCm),
          const SizedBox(height: 8),
          kv('Age', '${prof.age} yrs'),
          kv('Height', '${prof.heightCm.round()} cm'),
          kv('Weight', '${prof.weightKg.toStringAsFixed(1)} kg'),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Daily targets'),
          kv('Calories', '${g.kcal} kcal'),
          kv('Protein', '${g.protein} g'),
          kv('Carbs', '${g.carbs} g'),
          kv('Fat', '${g.fat} g'),
          kv('Water', '${(g.waterMl / 1000).toStringAsFixed(1)} L'),
        ]),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingScreen(initial: prof))),
        child: const Text('Edit profile and targets'),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Activity'),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Daily step goal', style: TextStyle(fontWeight: FontWeight.w800)),
                Muted('8,000 is a good start', size: 12),
              ]),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _stepGoal,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
                onSubmitted: (v) async {
                  final n = (int.tryParse(v) ?? 8000).clamp(1000, 50000);
                  _stepGoal.text = '$n';
                  await Db.instance.setStepGoal(n);
                  if (context.mounted) toast(context, 'Step goal saved');
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('👟', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Steps from your phone', style: TextStyle(fontWeight: FontWeight.w800)),
                Muted(_steps ? 'Connected to Health Connect / Apple Health' : 'Read steps automatically', size: 12),
              ]),
            ),
            if (!_steps) PillButton('Connect', onTap: _connectSteps) else Icon(Icons.check_circle, color: p.leaf),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Reminders'),
          remRow('☕', 'Breakfast', 'Daily', _bf, (v) => _toggle('rem_bf', v),
              time: _bfTime, onTime: () => _pickTime('rem_bf_time', _bfTime)),
          remRow('💧', 'Water', 'Every 2 hours, 9 am to 9 pm', _water, (v) => _toggle('rem_water', v)),
          remRow('⚖️', 'Weigh-in', 'Daily, before breakfast', _w, (v) => _toggle('rem_w', v),
              time: _wTime, onTime: () => _pickTime('rem_w_time', _wTime)),
        ]),
      ),
      const SizedBox(height: 12),
      const _DeleteDataButton(),
      const SizedBox(height: 16),
      const Muted('Nutrition numbers are estimates, not medical advice. Talk to a doctor or dietitian before big diet changes.',
          size: 12, align: TextAlign.center),
    ]);
  }
}


/// Small login / sign up (or log out) button for the top card.
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  void _open(BuildContext context, bool saveGuest) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => AuthScreen(popOnDone: true, saveGuest: saveGuest)));

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, _) {
          final u = FirebaseAuth.instance.currentUser;
          final guest = u == null || u.isAnonymous;
          if (!guest) {
            return OutlinedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log out'),
            );
          }
          return FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Log in'),
            onPressed: () => showAppSheet<void>(
              context,
              (ctx) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const H2('Your account'),
                  const SizedBox(height: 4),
                  const Muted("You're using the app as a guest. Save your data with an email so you don't lose it if you change phone."),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _open(context, true);
                    },
                    icon: const Icon(Icons.cloud_done_outlined),
                    label: const Text('Sign up · keep my data'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _open(context, false);
                    },
                    child: const Text('I already have an account · Log in'),
                  ),
                  const SizedBox(height: 4),
                  Muted('Logging in to another account shows that account\'s data instead.', size: 12, align: TextAlign.center),
                ]),
              ),
            ),
          );
        },
      );
}

/// "Delete all my data" (Play Store requirement).
class _DeleteDataButton extends StatelessWidget {
  const _DeleteDataButton();
  Future<void> _delete(BuildContext context) async {
    final p = Palette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
            'This removes your profile, meals, water, steps, workouts and weight history from this app for good. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await Db.instance.deleteAllMyData();
      final u = FirebaseAuth.instance.currentUser;
      try {
        await u?.delete(); // removes the login too
      } on FirebaseAuthException catch (_) {
        // needs a recent login: the data is already gone, just sign out
      }
      await FirebaseAuth.instance.signOut();
      if (context.mounted) toast(context, 'All your data was deleted');
    } catch (e) {
      if (context.mounted) toast(context, 'Could not delete right now. Check your internet and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TextButton.icon(
      onPressed: () => _delete(context),
      style: TextButton.styleFrom(foregroundColor: p.danger),
      icon: const Icon(Icons.delete_outline),
      label: const Text('Delete all my data'),
    );
  }
}
