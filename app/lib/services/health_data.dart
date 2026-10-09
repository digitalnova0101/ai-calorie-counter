// Allergies and health concerns (same lists as the website).
class Choice {
  final String id, emoji, label;
  const Choice(this.id, this.emoji, this.label);
}

const allergyChoices = <Choice>[
  Choice('none', '🙂', 'None'),
  Choice('milk', '🥛', 'Milk and dairy'),
  Choice('eggs', '🥚', 'Eggs'),
  Choice('peanuts', '🥜', 'Peanuts'),
  Choice('nuts', '🌰', 'Tree nuts'),
  Choice('gluten', '🌾', 'Gluten (wheat)'),
  Choice('soy', '🫘', 'Soy'),
  Choice('fish', '🐟', 'Fish'),
  Choice('shellfish', '🦐', 'Shellfish'),
  Choice('sesame', '🌱', 'Sesame'),
];

const concernChoices = <Choice>[
  Choice('none', '🙂', 'None of these'),
  Choice('sugar', '🩸', 'Blood sugar control'),
  Choice('bp', '💓', 'Blood pressure control'),
  Choice('chol', '🫀', 'Cholesterol control'),
  Choice('gut', '🌿', 'Gut health'),
  Choice('pcos', '🌸', 'PCOS / hormones'),
  Choice('thyroid', '🦋', 'Thyroid'),
  Choice('heart', '❤️', 'Heart health'),
];

List<String> labelsOf(List<Choice> list, List<String> ids) => ids
    .where((x) => x != 'none')
    .map((x) => list.firstWhere((c) => c.id == x, orElse: () => Choice(x, '', x)).label)
    .toList();

/// Words that suggest an allergen in a food name.
const _allergenWords = <String, List<String>>{
  'milk': ['milk', 'paneer', 'curd', 'dahi', 'lassi', 'raita', 'kheer', 'cheese', 'butter', 'ghee', 'cream', 'chaas', 'buttermilk', 'tea with milk', 'coffee with milk', 'khoa', 'malai', 'rasgulla', 'gulab jamun', 'whey'],
  'eggs': ['egg', 'omelette', 'anda', 'mayonnaise'],
  'peanuts': ['peanut', 'groundnut', 'mungfali', 'moongfali'],
  'nuts': ['almond', 'badam', 'cashew', 'kaju', 'walnut', 'pista', 'pistachio'],
  'gluten': ['roti', 'chapati', 'phulka', 'paratha', 'naan', 'puri', 'bread', 'maggi', 'noodles', 'samosa', 'pav', 'upma', 'oats', 'biscuit', 'cake', 'pasta', 'pizza', 'wheat', 'atta', 'maida', 'suji'],
  'soy': ['soya', 'soy', 'tofu'],
  'fish': ['fish', 'machli'],
  'shellfish': ['prawn', 'shrimp', 'crab', 'lobster', 'jhinga'],
  'sesame': ['sesame', 'til'],
};

/// Allergens from the user's list that this food may contain.
List<String> allergensIn(String foodName, List<String> userAllergies) {
  final n = foodName.toLowerCase();
  return userAllergies
      .where((a) => (_allergenWords[a] ?? const []).any((w) => n.contains(w)))
      .map((a) => allergyChoices.firstWhere((c) => c.id == a, orElse: () => Choice(a, '', a)).label)
      .toList();
}
