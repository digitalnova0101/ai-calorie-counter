// Data models used across the app.

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => _d(v).round();

class Goals {
  final int kcal, protein, carbs, fat, waterMl;
  const Goals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.waterMl,
  });
  static const fallback =
      Goals(kcal: 2000, protein: 110, carbs: 240, fat: 60, waterMl: 2500);

  factory Goals.fromMap(Map<String, dynamic>? m) {
    if (m == null) return fallback;
    return Goals(
      kcal: _i(m['kcal']),
      protein: _i(m['protein']),
      carbs: _i(m['carbs']),
      fat: _i(m['fat']),
      waterMl: _i(m['waterMl']),
    );
  }

  Map<String, dynamic> toMap() => {
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'waterMl': waterMl,
      };
}

class FastRecord {
  final int start, end, plan;
  FastRecord(this.start, this.end, this.plan);
  factory FastRecord.fromMap(Map<String, dynamic> m) =>
      FastRecord(_i(m['start']), _i(m['end']), _i(m['plan']));
  Map<String, dynamic> toMap() => {'start': start, 'end': end, 'plan': plan};
}

class FastState {
  final int plan; // fasting hours, e.g. 16 for 16:8
  final int? start; // millis, null when not fasting
  final List<FastRecord> history;
  const FastState({this.plan = 16, this.start, this.history = const []});

  factory FastState.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const FastState();
    return FastState(
      plan: m['plan'] == null ? 16 : _i(m['plan']),
      start: m['start'] == null ? null : _i(m['start']),
      history: ((m['history'] as List?) ?? [])
          .map((e) => FastRecord.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'plan': plan,
        'start': start,
        'history': history.take(20).map((e) => e.toMap()).toList(),
      };
}

class Profile {
  final String name, sex, activity, goal;
  final int age, stepGoal;
  final double heightCm, weightKg, targetWeightKg;
  final Goals goals;
  final FastState fast;
  final String targetDate; // yyyy-MM-dd, '' when not set
  final List<String> allergies, concerns;
  final bool stepGoalCustom; // true when the user typed their own step goal
  final String units; // 'metric', 'imperial', or '' to follow the phone

  const Profile({
    required this.name,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
    required this.targetWeightKg,
    required this.goals,
    this.stepGoal = 8000,
    this.fast = const FastState(),
    this.targetDate = '',
    this.allergies = const [],
    this.concerns = const [],
    this.stepGoalCustom = false,
    this.units = '',
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        name: '${m['name'] ?? ''}',
        sex: '${m['sex'] ?? 'male'}',
        age: _i(m['age']),
        heightCm: _d(m['heightCm']),
        weightKg: _d(m['weightKg']),
        activity: '${m['activity'] ?? 'light'}',
        goal: '${m['goal'] ?? 'maintain'}',
        targetWeightKg: _d(m['targetWeightKg']),
        goals: Goals.fromMap((m['goals'] as Map?)?.cast<String, dynamic>()),
        stepGoal: m['stepGoal'] == null ? 8000 : _i(m['stepGoal']),
        fast: FastState.fromMap((m['fast'] as Map?)?.cast<String, dynamic>()),
        targetDate: '${m['targetDate'] ?? ''}',
        allergies: ((m['allergies'] as List?) ?? []).map((e) => '$e').toList(),
        concerns: ((m['concerns'] as List?) ?? []).map((e) => '$e').toList(),
        stepGoalCustom: m['stepGoalCustom'] == true,
        units: '${m['units'] ?? ''}',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'sex': sex,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity,
        'goal': goal,
        'targetWeightKg': targetWeightKg,
        'goals': goals.toMap(),
        'stepGoal': stepGoal,
        'targetDate': targetDate,
        'allergies': allergies,
        'concerns': concerns,
        'stepGoalCustom': stepGoalCustom,
        'units': units,
      };
}

/// One food line. Nutrition values are for [portion]; [mult] scales them.
class FoodItem {
  final String name, portion;
  final double grams, kcal, protein, carbs, fat;
  double mult;
  String? portionLabel; // set by the portion picker, e.g. "2 katoris, 300 g"
  String? src; // "db" when numbers came from the built-in food list

  FoodItem({
    required this.name,
    required this.portion,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.mult = 1,
    this.portionLabel,
    this.src,
  });

  double get tKcal => kcal * mult;
  double get tProtein => protein * mult;
  double get tCarbs => carbs * mult;
  double get tFat => fat * mult;

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
        name: '${m['name'] ?? 'Food'}',
        portion: '${m['portion'] ?? ''}',
        grams: _d(m['grams']),
        kcal: _d(m['kcal']),
        protein: _d(m['protein']),
        carbs: _d(m['carbs']),
        fat: _d(m['fat']),
        mult: m['mult'] == null ? 1 : _d(m['mult']),
        portionLabel: m['portionLabel'] as String?,
        src: m['src'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'portion': portion,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'mult': mult,
        if (portionLabel != null) 'portionLabel': portionLabel,
        if (src != null) 'src': src,
      };

  FoodItem copy() => FoodItem.fromMap(toMap());
}

const mealTypes = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];
const mealEmoji = {
  'Breakfast': '☕',
  'Lunch': '🍛',
  'Snacks': '🥪',
  'Dinner': '🌙',
};

String guessMealType([DateTime? t]) {
  final h = (t ?? DateTime.now()).hour;
  if (h < 11) return 'Breakfast';
  if (h < 16) return 'Lunch';
  if (h < 19) return 'Snacks';
  return 'Dinner';
}

class MealEntry {
  final String id, type, source, dish;
  final int time;
  final String? thumb; // small JPEG, base64
  final List<FoodItem> items;

  MealEntry({
    required this.id,
    required this.type,
    required this.time,
    required this.source,
    required this.items,
    this.dish = '',
    this.thumb,
  });

  String get title =>
      dish.isNotEmpty ? dish : items.map((i) => i.name).join(', ');

  factory MealEntry.fromMap(Map<String, dynamic> m) => MealEntry(
        id: '${m['id']}',
        type: '${m['type'] ?? 'Snacks'}',
        time: _i(m['time']),
        source: '${m['source'] ?? 'text'}',
        dish: '${m['dish'] ?? ''}',
        thumb: m['thumb'] as String?,
        items: ((m['items'] as List?) ?? [])
            .map((e) => FoodItem.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'time': time,
        'source': source,
        'dish': dish,
        if (thumb != null) 'thumb': thumb,
        'items': items.map((e) => e.toMap()).toList(),
      };
}

class Workout {
  final String id, type;
  final int min, time;
  final double kcal;
  Workout(
      {required this.id,
      required this.type,
      required this.min,
      required this.kcal,
      required this.time});
  factory Workout.fromMap(Map<String, dynamic> m) => Workout(
        id: '${m['id']}',
        type: '${m['type'] ?? 'other'}',
        min: _i(m['min']),
        kcal: _d(m['kcal']),
        time: _i(m['time']),
      );
  Map<String, dynamic> toMap() =>
      {'id': id, 'type': type, 'min': min, 'kcal': kcal, 'time': time};
}

class Totals {
  double kcal = 0, protein = 0, carbs = 0, fat = 0;
  void addItems(Iterable<FoodItem> items) {
    for (final i in items) {
      kcal += i.tKcal;
      protein += i.tProtein;
      carbs += i.tCarbs;
      fat += i.tFat;
    }
  }

  static Totals of(Iterable<FoodItem> items) => Totals()..addItems(items);
}

class DayLog {
  final String date; // yyyy-MM-dd
  final List<MealEntry> meals;
  final List<Workout> workouts;
  final int waterMl, steps;

  DayLog({
    required this.date,
    required this.meals,
    required this.waterMl,
    this.steps = 0,
    this.workouts = const [],
  });

  factory DayLog.empty(String date) => DayLog(date: date, meals: [], waterMl: 0);

  factory DayLog.fromMap(String date, Map<String, dynamic>? m) {
    if (m == null) return DayLog.empty(date);
    return DayLog(
      date: date,
      meals: ((m['meals'] as List?) ?? [])
          .map((e) => MealEntry.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      workouts: ((m['workouts'] as List?) ?? [])
          .map((e) => Workout.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      waterMl: _i(m['waterMl']),
      steps: _i(m['steps']),
    );
  }

  Totals get totals {
    final t = Totals();
    for (final m in meals) {
      t.addItems(m.items);
    }
    return t;
  }
}

class WeightEntry {
  final String date;
  final double kg;
  WeightEntry(this.date, this.kg);
}
