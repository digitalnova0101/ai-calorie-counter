import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'add_food.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  final Profile profile;
  const HomeShell({super.key, required this.profile});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  DateTime _date = DateTime.now();
  int _progressVisits = 0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pages = [
      TodayScreen(
          profile: widget.profile,
          date: _date,
          onDateChanged: (d) => setState(() => _date = d)),
      ProgressScreen(key: ValueKey(_progressVisits), profile: widget.profile),
      ProfileScreen(profile: widget.profile),
    ];

    Widget tab(int i, IconData icon, IconData on, String label) {
      final sel = _tab == i;
      return Expanded(
        child: Pressable(
          onTap: () => setState(() {
            if (i == 1 && _tab != 1) _progressVisits++;
            _tab = i;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sel ? p.leaf.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(sel ? on : icon, color: sel ? p.ink : p.muted, size: 23),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: sel ? p.ink : p.muted)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, slot = (w - 84) / 3;
            return SizedBox(
              height: 96,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 66,
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: p.line),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Row(children: [
                      tab(0, Icons.radio_button_unchecked, Icons.adjust, 'Today'),
                      tab(1, Icons.show_chart, Icons.insights, 'Progress'),
                      const SizedBox(width: 84),
                      tab(2, Icons.person_outline, Icons.person, 'Profile'),
                    ]),
                  ),
                ),
                Positioned(
                  left: slot * 2 + 9,
                  bottom: 30,
                  child: Semantics(
                    button: true,
                    label: 'Add food',
                    child: Pressable(
                      onTap: () => showAddFoodSheet(context, _date),
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: p.saffron,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                                color: p.saffron.withValues(alpha: 0.55),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: const Icon(Icons.center_focus_strong_outlined,
                            color: Color(0xFF2B1400), size: 32),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),
      ),
    );
  }
}
