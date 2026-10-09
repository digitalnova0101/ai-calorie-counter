import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Daily targets from body stats (Mifflin-St Jeor BMR x activity factor).
Goals calculateGoals({
  required String sex,
  required int age,
  required double heightCm,
  required double weightKg,
  required String activity,
  required String goal,
}) {
  final bmr =
      10 * weightKg + 6.25 * heightCm - 5 * age + (sex == 'female' ? -161 : 5);
  const factors = {'low': 1.2, 'light': 1.375, 'moderate': 1.55, 'high': 1.725};
  final tdee = bmr * (factors[activity] ?? 1.375);
  double kcal = tdee;
  if (goal == 'lose') kcal = tdee - 500;
  if (goal == 'gain') kcal = tdee + 300;
  kcal = math.max(kcal, sex == 'female' ? 1200.0 : 1500.0);
  final protein = weightKg * (goal == 'maintain' ? 1.2 : (goal == 'gain' ? 1.8 : 1.6));
  final fat = kcal * 0.25 / 9;
  final carbs = math.max(50.0, (kcal - protein * 4 - fat * 9) / 4);
  return Goals(
    kcal: (kcal / 10).round() * 10,
    protein: protein.round(),
    carbs: carbs.round(),
    fat: fat.round(),
    waterMl: ((weightKg * 35) / 250).round() * 250,
  );
}

double bmi(double weightKg, double heightCm) {
  final m = heightCm / 100;
  return m <= 0 ? 0.0 : weightKg / (m * m);
}

/// Asian-Indian BMI cut-offs.
class BmiBand {
  final double max;
  final String name;
  final Color Function(Palette) color;
  const BmiBand(this.max, this.name, this.color);
}

final bmiBands = <BmiBand>[
  BmiBand(18.5, 'Underweight', (p) => p.water),
  BmiBand(23, 'Healthy', (p) => p.leaf),
  BmiBand(25, 'Overweight', (p) => p.wheat),
  BmiBand(99, 'Obese', (p) => p.chili),
];
BmiBand bmiBandOf(double b) => bmiBands.firstWhere((x) => b < x.max);

// ---------------- calories burned ----------------
class WorkoutType {
  final String id, name, emoji;
  final double met;
  const WorkoutType(this.id, this.name, this.emoji, this.met);
}

const workoutTypes = <WorkoutType>[
  WorkoutType('walk', 'Walking', '🚶', 3.5),
  WorkoutType('run', 'Running', '🏃', 9.8),
  WorkoutType('cycle', 'Cycling', '🚴', 7.5),
  WorkoutType('gym', 'Gym', '🏋️', 6.0),
  WorkoutType('yoga', 'Yoga', '🧘', 2.5),
  WorkoutType('cricket', 'Cricket', '🏏', 4.8),
  WorkoutType('badminton', 'Badminton', '🏸', 5.5),
  WorkoutType('football', 'Football', '⚽', 7.0),
  WorkoutType('dance', 'Dance', '💃', 5.0),
  WorkoutType('swim', 'Swimming', '🏊', 6.0),
  WorkoutType('skip', 'Skipping', '🪢', 11.0),
  WorkoutType('other', 'Other', '⭐', 4.0),
];
WorkoutType workoutType(String id) =>
    workoutTypes.firstWhere((w) => w.id == id, orElse: () => workoutTypes.last);

/// kcal = MET x weight (kg) x hours
double workoutKcal(String type, int minutes, double weightKg) =>
    workoutType(type).met * weightKg * minutes / 60;

/// About 0.04 kcal per step at 70 kg, scaled by body weight.
double stepKcal(int steps, double weightKg) => steps * 0.04 * weightKg / 70;

/// Stride is about 41.5% of height.
double stepKm(int steps, double heightCm) => steps * heightCm * 0.415 / 100000;

class Burned {
  final int steps;
  final double stepKcal, workoutKcal;
  Burned(this.steps, this.stepKcal, this.workoutKcal);
  double get total => stepKcal + workoutKcal;
}

Burned burnedOf(DayLog d, Profile p) => Burned(
      d.steps,
      stepKcal(d.steps, p.weightKg),
      d.workouts.fold(0.0, (a, w) => a + w.kcal),
    );

// ---------------- report card ----------------
class ScorePart {
  final String name, note;
  final double pts, max;
  final Color Function(Palette) color;
  ScorePart(this.name, this.pts, this.max, this.color, this.note);
}

class Score {
  final int score;
  final List<ScorePart> parts;
  final List<(Color Function(Palette), String)> tips;
  final bool hasData;
  final int loggedDays;
  Score(this.score, this.parts, this.tips, this.hasData, [this.loggedDays = 0]);
}

String fmtInt(num n) {
  final s = n.round().toString();
  // Indian-style grouping is fine for small numbers; keep simple commas
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

Score dayScore(DayLog d, Profile p) {
  final g = p.goals, t = d.totals;
  final meals = d.meals.map((m) => m.type).toSet().length;
  final budget = g.kcal.toDouble();
  final calPts =
      t.kcal > 0 ? 35 * math.max(0, 1 - (t.kcal - budget).abs() / budget) : 0.0;
  final proPts = 25 * math.min(1, t.protein / math.max(1, g.protein));
  final watPts = 15 * math.min(1, d.waterMl / math.max(1, g.waterMl));
  final stepPts = 10 * math.min(1, d.steps / math.max(1, p.stepGoal));
  final logPts = 15 * math.min(1, meals / 3);
  final parts = [
    ScorePart('Calories on target', calPts.toDouble(), 35, (c) => c.saffron,
        t.kcal > 0 ? '${t.kcal.round()} of ${g.kcal} kcal' : 'Nothing logged'),
    ScorePart('Protein', proPts.toDouble(), 25, (c) => c.leaf,
        '${t.protein.round()} of ${g.protein} g'),
    ScorePart('Steps', stepPts.toDouble(), 10, (c) => c.water,
        '${fmtInt(d.steps)} of ${fmtInt(p.stepGoal)}'),
    ScorePart('Water', watPts.toDouble(), 15, (c) => c.water,
        '${(d.waterMl / 1000).toStringAsFixed(1)} of ${(g.waterMl / 1000).toStringAsFixed(1)} L'),
    ScorePart('Meals logged', logPts.toDouble(), 15, (c) => c.wheat,
        '$meals of 3 main meals'),
  ];
  final tips = <(Color Function(Palette), String)>[];
  if (t.kcal > 0 && t.kcal > budget * 1.1) {
    tips.add(((c) => c.chili,
        'You went ${(t.kcal - budget).round()} kcal over. A lighter dinner or a 30-minute walk balances it out.'));
  } else if (t.kcal > 0 && t.kcal < budget * 0.75) {
    tips.add(((c) => c.wheat,
        "You're ${(budget - t.kcal).round()} kcal under. Eating too little can slow you down; add a snack."));
  }
  if (t.protein < g.protein * 0.8) {
    tips.add(((c) => c.leaf,
        '${(g.protein - t.protein).round()} g protein to go. Paneer, eggs, dal, curd or chicken help.'));
  }
  if (d.steps < p.stepGoal) {
    final left = p.stepGoal - d.steps;
    tips.add(((c) => c.water,
        '${fmtInt(left)} more steps to your goal, about a ${math.max(5, (left / 100).round())}-minute walk.'));
  }
  if (d.waterMl < g.waterMl) {
    tips.add(((c) => c.water,
        '${((g.waterMl - d.waterMl) / 250).ceil()} more glasses of water to hit your goal.'));
  }
  if (tips.isEmpty) tips.add(((c) => c.leaf, "Everything's on track. Keep the streak going!"));
  final score = (calPts + proPts + watPts + stepPts + logPts).round();
  return Score(score, parts, tips, d.meals.isNotEmpty);
}

Score weekScore(List<DayLog> newestFirst, Profile p) {
  final week = newestFirst.take(7).toList();
  final logged = week.where((d) => d.meals.isNotEmpty).toList();
  if (logged.isEmpty) return Score(0, [], [], false, 0);
  final avg = logged.map((d) => dayScore(d, p).score).reduce((a, b) => a + b) /
      logged.length;
  final cons = 20 * logged.length / 7;
  final g = p.goals;
  double avgOf(double Function(DayLog) f) =>
      logged.map(f).reduce((a, b) => a + b) / logged.length;
  final aK = avgOf((d) => d.totals.kcal), aP = avgOf((d) => d.totals.protein);
  final aW = avgOf((d) => d.waterMl.toDouble());
  final onTarget =
      logged.where((d) => (d.totals.kcal - g.kcal).abs() <= g.kcal * 0.1).length;
  return Score(
    (avg * 0.8 + cons).round(),
    [
      ScorePart('Average daily score', avg * 0.8, 80, (c) => c.saffron,
          '${avg.round()} / 100'),
      ScorePart('Days logged', cons, 20, (c) => c.wheat,
          '${logged.length} of 7 days'),
    ],
    [
      ((c) => c.saffron,
          'Average ${aK.round()} kcal a day against your ${g.kcal} goal. $onTarget day${onTarget == 1 ? '' : 's'} within 10%.'),
      ((c) => c.leaf, 'Average protein ${aP.round()} g a day (goal ${g.protein} g).'),
      ((c) => c.water, 'Average water ${(aW / 1000).toStringAsFixed(1)} L a day.'),
    ],
    true,
    logged.length,
  );
}

(String, Color Function(Palette)) gradeOf(int s) {
  if (s >= 90) return ('Excellent', (p) => p.leaf);
  if (s >= 75) return ('Great', (p) => p.leaf);
  if (s >= 60) return ('Good', (p) => p.wheat);
  if (s >= 40) return ('Fair', (p) => p.saffron);
  return ('Needs work', (p) => p.chili);
}

// ---------------- weight plan maths (same as the website) ----------------
const double kcalPerKg = 7700; // about 7,700 kcal in 1 kg of body fat
const _actF = {'low': 1.2, 'light': 1.375, 'moderate': 1.55, 'high': 1.725};

double bmrOf(Profile p, double weightKg) =>
    10 * weightKg + 6.25 * p.heightCm - 5 * p.age + (p.sex == 'female' ? -161 : 5);

double tdeeOf(Profile p, double weightKg) => bmrOf(p, weightKg) * (_actF[p.activity] ?? 1.375);

/// Everything the Goal progress and weight plan cards need.
class GoalMath {
  final bool lose, wrongSide;
  final double start, cur, target, totalKg, leftKg, doneKg, pct;
  final int daysLeft;
  final double needed, perWeek, tdee, fromFood, fromMove;
  final double? realPace;
  GoalMath._(this.lose, this.wrongSide, this.start, this.cur, this.target, this.totalKg, this.leftKg,
      this.doneKg, this.pct, this.daysLeft, this.needed, this.perWeek, this.tdee, this.fromFood,
      this.fromMove, this.realPace);

  static GoalMath? of(Profile p, List<WeightEntry> ws) {
    if (p.goal == 'maintain' || p.targetWeightKg <= 0) return null;
    final lose = p.goal == 'lose';
    final start = ws.isNotEmpty ? ws.first.kg : p.weightKg;
    final cur = ws.isNotEmpty ? ws.last.kg : p.weightKg;
    final target = p.targetWeightKg;
    final wrong = lose ? start <= target : start >= target;
    final total = (start - target).abs();
    final left = math.max(0.0, lose ? cur - target : target - cur);
    final done = (total - left).clamp(0.0, total).toDouble();
    final pct = wrong ? 0.0 : (total > 0 ? (done / total * 100).clamp(0.0, 100.0).toDouble() : 100.0);
    int days;
    final td = p.targetDate.isNotEmpty ? DateTime.tryParse(p.targetDate) : null;
    if (td != null) {
      final now = DateTime.now();
      days = math.max(1, DateTime(td.year, td.month, td.day).difference(DateTime(now.year, now.month, now.day)).inDays);
    } else {
      days = math.max(1, (left / (lose ? 0.5 : 0.25) * 7).ceil());
    }
    final needed = left * kcalPerKg / days;
    final tdee = tdeeOf(p, cur);
    final foodPart = math.max(0.0, lose ? tdee - p.goals.kcal : p.goals.kcal - tdee);
    final fromFood = math.min(needed, foodPart), fromMove = math.max(0.0, needed - fromFood);
    double? real;
    if (ws.length > 1) {
      final span = DateTime.parse(ws.last.date).difference(DateTime.parse(ws.first.date)).inDays;
      if (span >= 7) real = (lose ? start - cur : cur - start) / (span / 7);
    }
    return GoalMath._(lose, wrong, start, cur, target, total, left, done, pct, days, needed,
        needed * 7 / kcalPerKg, tdee, fromFood, fromMove, real);
  }
}

/// Daily targets when the user picked a pace (kg per week) for their goal.
Goals goalsWithPace({
  required String sex,
  required int age,
  required double heightCm,
  required double weightKg,
  required String activity,
  required String goal,
  required double paceKgWeek,
}) {
  final base = calculateGoals(
      sex: sex, age: age, heightCm: heightCm, weightKg: weightKg, activity: activity, goal: goal);
  if (goal == 'maintain') return base;
  final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + (sex == 'female' ? -161 : 5);
  final tdee = bmr * (_actF[activity] ?? 1.375);
  final perDay = paceKgWeek * kcalPerKg / 7;
  double kcal = goal == 'lose' ? tdee - math.min(perDay, 1000) : tdee + math.min(perDay, 550);
  kcal = math.max(kcal, sex == 'female' ? 1200.0 : 1500.0);
  final fat = kcal * 0.28 / 9;
  final carbs = math.max(50.0, (kcal - base.protein * 4 - fat * 9) / 4);
  return Goals(
    kcal: (kcal / 10).round() * 10,
    protein: base.protein,
    carbs: carbs.round(),
    fat: fat.round(),
    waterMl: base.waterMl,
  );
}
