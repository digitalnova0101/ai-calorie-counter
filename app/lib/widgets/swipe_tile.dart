import 'package:flutter/material.dart';

import '../theme.dart';

/// Row that slides left to reveal Edit and Delete. Tap opens edit.
class SwipeTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit, onDelete;
  final Color? background;
  const SwipeTile({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.background,
  });

  @override
  State<SwipeTile> createState() => _SwipeTileState();
}

class _SwipeTileState extends State<SwipeTile> {
  static const _open = -152.0;
  double _x = 0;
  bool _dragging = false;

  void _close() => setState(() => _x = 0);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget action(IconData icon, String label, Color color, VoidCallback f) =>
        Expanded(
          child: Material(
            color: color,
            child: InkWell(
              onTap: () {
                _close();
                f();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(height: 4),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5)),
                ],
              ),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          if (_x != 0)
            Positioned.fill(
              child: Row(children: [
                const Spacer(),
                SizedBox(
                  width: -_open,
                  child: Row(children: [
                    action(Icons.edit_outlined, 'Edit', p.water, widget.onEdit),
                    action(Icons.delete_outline, 'Delete', p.danger, widget.onDelete),
                  ]),
                ),
              ]),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) =>
                setState(() => _x = (_x + d.delta.dx).clamp(_open - 18, 0.0)),
            onHorizontalDragEnd: (d) => setState(() {
              _dragging = false;
              final fling = d.primaryVelocity ?? 0;
              _x = (fling < -300 || (_x < -60 && fling < 300)) ? _open : 0.0;
            }),
            onTap: () => _x != 0 ? _close() : widget.onEdit(),
            child: AnimatedContainer(
              duration: _dragging ? Duration.zero : const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              transform: Matrix4.translationValues(_x, 0, 0),
              decoration: BoxDecoration(
                color: widget.background ?? p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
