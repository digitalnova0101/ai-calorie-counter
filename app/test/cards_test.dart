// Draws the new cards on a phone-sized screen and saves pictures (goldens)
// so layout problems can be checked without a phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:aicaloriecounter/models.dart';
import 'package:aicaloriecounter/services/db.dart';
import 'package:aicaloriecounter/theme.dart';
import 'package:aicaloriecounter/widgets/premium.dart';

final problems = <String>[];

Profile prof({String goal = 'lose', double target = 57, String date = ''}) => Profile(
      name: 'Ayesha',
      sex: 'female',
      age: 28,
      heightCm: 162,
      weightKg: 63.6,
      activity: 'light',
      goal: goal,
      targetWeightKg: target,
      targetDate: date,
      goals: const Goals(kcal: 1530, protein: 102, carbs: 166, fat: 51, waterMl: 2250),
    );

List<WeightEntry> weights(List<double> kgs) {
  final now = DateTime.now();
  return [
    for (var i = 0; i < kgs.length; i++)
      WeightEntry(dayKey(now.subtract(Duration(days: (kgs.length - 1 - i) * 7))), kgs[i])
  ];
}

List<DayLog> days() {
  final now = DateTime.now();
  return List.generate(30, (i) {
    final k = dayKey(now.subtract(Duration(days: i)));
    if (i == 3 || i > 9) return DayLog.empty(k);
    final kcal = 1250.0 + (i * 97) % 500;
    return DayLog(
      date: k,
      waterMl: 1500,
      steps: 3000 + (i * 1300) % 8000,
      meals: [
        MealEntry.fromMap({
          'id': 'm$i',
          'type': 'Lunch',
          'time': 1,
          'source': 'search',
          'items': [
            {'name': 'Dal roti', 'portion': '1', 'grams': 200, 'kcal': kcal, 'protein': 60 + i * 4, 'carbs': kcal * .5 / 4, 'fat': kcal * .3 / 9, 'mult': 1}
          ]
        })
      ],
    );
  });
}

Future<void> shot(WidgetTester t, String name, Widget child, {bool dark = false}) async {
  t.view.physicalSize = const Size(390 * 2, 2400 * 2);
  t.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(dark ? Brightness.dark : Brightness.light),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  ));
  await t.pump(const Duration(seconds: 3));
  await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5))
      .catchError((_) => 0);
  await expectLater(find.byKey(key), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() {
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      if (s.contains('GoogleFonts') || s.contains('allowRuntimeFetching') || s.contains('font')) return;
      problems.add(s.split('\n').first);
    };
  });
  tearDownAll(() {
    // ignore: avoid_print
    print('LAYOUT PROBLEMS: ${problems.length}');
    // ignore: avoid_print
    for (final p in problems.toSet()) print('PROBLEM: $p');
  });

  final ws = weights([63.6, 63.1, 62.8, 62.4, 61.9]);
  testWidgets('goal lose', (t) async => shot(t, 'goal_lose', GoalProgressCard(profile: prof(), weights: ws, onFixGoal: () {})));
  testWidgets('goal gain', (t) async => shot(t, 'goal_gain',
      GoalProgressCard(profile: prof(goal: 'gain', target: 68), weights: weights([60.2, 61.0, 61.9]), onFixGoal: () {})));
  testWidgets('goal wrong', (t) async => shot(t, 'goal_wrong',
      GoalProgressCard(profile: prof(target: 68), weights: weights([64.3]), onFixGoal: () {})));
  testWidgets('plan', (t) async => shot(t, 'plan',
      WeightPlanCard(profile: prof(date: dayKey(DateTime.now().add(const Duration(days: 131)))), weights: ws, today: days().first)));
  testWidgets('week', (t) async => shot(t, 'week', WeekHero(days: days(), profile: prof(), weights: ws, onTap: () {})));
  testWidgets('bmi', (t) async => shot(t, 'bmi', const BmiCard(weightKg: 61.9, heightCm: 162)));
  testWidgets('bmi dark', (t) async => shot(t, 'bmi_dark', const BmiCard(weightKg: 75, heightCm: 172), dark: true));
  testWidgets('history', (t) async => shot(t, 'history',
      Column(children: [for (final d in days().where((d) => d.meals.isNotEmpty)) HistoryRow(day: d, goals: prof().goals)])));
}
