import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/food_db.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

/// Search the built-in Indian food list and build a plate.
class SearchScreen extends StatefulWidget {
  final DateTime date;
  const SearchScreen({super.key, required this.date});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  List<FoodItem> _results = [];
  final List<FoodItem> _plate = [];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final r = await FoodDb.instance.search(q);
    if (mounted) setState(() => _results = r);
  }

  List<FoodItem> _merged() {
    final map = <String, FoodItem>{};
    for (final f in _plate) {
      final cur = map[f.name];
      if (cur == null) {
        map[f.name] = f.copy()..src = 'db';
      } else {
        cur.mult += 1;
      }
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final q = _q.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Search food')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: _search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search roti, dal, paneer'),
          ),
        ),
        if (q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Panel(
              color: p.forest,
              radius: 18,
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      date: widget.date,
                      source: 'text',
                      loader: () => AiService.instance.analyzeText(q),
                    ),
                  )),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: p.saffron, borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF2B1400)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ask AI about "$q"',
                        style: TextStyle(color: p.forestInk, fontWeight: FontWeight.w800)),
                    Text('For anything not in the list',
                        style: TextStyle(color: p.forestInk.withValues(alpha: .75), fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? const Center(child: Muted('Not in the list. Use "Ask AI" above.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final f = _results[i];
                    final n = _plate.where((x) => x.name == f.name).length;
                    return InkWell(
                      onTap: () => setState(() => _plate.add(f.copy())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Muted('${f.portion}, ${f.protein.round()} g protein', size: 12.5),
                            ]),
                          ),
                          Text('${f.kcal.round()}',
                              style: display(context, 15, weight: FontWeight.w700, color: p.saffron)),
                          const SizedBox(width: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: n > 0 ? p.saffron : p.bg, borderRadius: BorderRadius.circular(10)),
                            child: Text(n > 0 ? '$n' : '+',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: n > 0 ? const Color(0xFF2B1400) : p.ink)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
      bottomNavigationBar: _plate.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => ResultScreen(date: widget.date, source: 'search', items: _merged()),
                    )),
                    child: Text(
                        'Review ${_plate.length} item${_plate.length == 1 ? '' : 's'}, ${Totals.of(_plate).kcal.round()} kcal'),
                  ),
                ),
              ),
            ),
    );
  }
}
