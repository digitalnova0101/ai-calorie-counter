import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../services/device.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'barcode_screen.dart';
import 'result_screen.dart';
import 'search_screen.dart';

/// Opens the camera (or gallery) and sends the photo to the AI.
Future<void> startPhotoScan(BuildContext context, DateTime date, ImageSource src) async {
  XFile? file;
  try {
    // 768 px is plenty to recognise food and uploads fast on 4G
    file = await ImagePicker().pickImage(source: src, maxWidth: 768, maxHeight: 768, imageQuality: 78);
  } catch (_) {
    if (context.mounted) {
      toast(context, src == ImageSource.camera
          ? 'Could not open the camera. Allow camera access in phone settings.'
          : 'Could not open your gallery.');
    }
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  final thumb = makeThumb(bytes);
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ResultScreen(
      date: date,
      source: 'photo',
      image: bytes,
      thumbFuture: thumb,
      loader: () => AiService.instance.analyzePhoto(bytes),
    ),
  ));
}

Future<void> startTextScan(BuildContext context, DateTime date, String text) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
        date: date,
        source: 'text',
        loader: () => AiService.instance.analyzeText(text),
      ),
    ));

Future<void> openBarcode(BuildContext context, DateTime date) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => BarcodeScreen(date: date)));

/// Bottom sheet with recent meals and every way to add food.
Future<void> showAddFoodSheet(BuildContext context, DateTime date) {
  return showAppSheet(context, (sheetCtx) {
    void go(Future<void> Function() action) {
      Navigator.of(sheetCtx).pop();
      action();
    }

    return _AddSheet(
      onRecent: (m) => go(() => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResultScreen(
              date: date,
              source: 'recent',
              items: m.items.map((i) => i.copy()).toList(),
              dish: m.dish.isNotEmpty ? m.dish : (m.items.length > 1 ? m.title : ''),
              thumb: m.thumb,
            ),
          ))),
      onScan: () => go(() => startPhotoScan(context, date, ImageSource.camera)),
      onUpload: () => go(() => startPhotoScan(context, date, ImageSource.gallery)),
      onBarcode: () => go(() => openBarcode(context, date)),
      onSearch: () => go(() => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SearchScreen(date: date)))),
      onDescribe: () => go(() => _describe(context, date)),
    );
  });
}

Future<void> _describe(BuildContext context, DateTime date) async {
  final ctrl = TextEditingController();
  final text = await showAppSheet<String>(context, (ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const H2('What did you eat?'),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '2 roti, 1 bowl dal, half plate rice and salad'),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Count it')),
      ]),
    );
  });
  ctrl.dispose();
  if (text == null || text.isEmpty || !context.mounted) return;
  await startTextScan(context, date, text);
}

class _AddSheet extends StatelessWidget {
  final ValueChanged<MealEntry> onRecent;
  final VoidCallback onScan, onUpload, onBarcode, onSearch, onDescribe;
  const _AddSheet({
    required this.onRecent,
    required this.onScan,
    required this.onUpload,
    required this.onBarcode,
    required this.onSearch,
    required this.onDescribe,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget act(String title, String sub, IconData icon, Color c, VoidCallback f, int i) =>
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 350 + i * 60),
          curve: Curves.easeOutBack,
          builder: (_, v, ch) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: ch)),
          child: Panel(
            onTap: f,
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              Muted(sub, size: 12.5),
            ]),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const H2('Add food'),
        const SizedBox(height: 12),
        FutureBuilder<List<MealEntry>>(
          future: Db.instance.recentMeals(),
          builder: (_, snap) {
            final rec = snap.data ?? [];
            if (rec.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Expanded(child: Text('Recent meals', style: TextStyle(fontWeight: FontWeight.w800))),
                  Muted('One tap, no waiting', size: 12),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rec.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final m = rec[i];
                      return Pressable(
                        onTap: () => onRecent(m),
                        child: Container(
                          width: 118,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.line),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            MealThumb(m, size: 100, height: 64),
                            const SizedBox(height: 6),
                            Text(m.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.2)),
                            const Spacer(),
                            Text('${Totals.of(m.items).kcal.round()} kcal',
                                style: TextStyle(color: p.saffron, fontWeight: FontWeight.w800, fontSize: 12)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        ),
        Panel(
          onTap: onScan,
          color: p.forest,
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: p.saffron, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.photo_camera_outlined, color: Color(0xFF2B1400)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scan your plate',
                    style: TextStyle(color: p.forestInk, fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Take a photo and AI counts it',
                    style: TextStyle(color: p.forestInk.withValues(alpha: .75), fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            act('Upload photo', 'From your gallery', Icons.photo_library_outlined, p.leaf, onUpload, 0),
            act('Barcode', 'Packaged food', Icons.qr_code_scanner, p.water, onBarcode, 1),
            act('Search', 'Roti, dal, paneer…', Icons.search, p.wheat, onSearch, 2),
            act('Describe', 'Type what you ate', Icons.edit_note, p.chili, onDescribe, 3),
          ],
        ),
      ]),
    );
  }
}

/// Meal photo thumbnail, or an icon for meals without a photo.
class MealThumb extends StatelessWidget {
  final MealEntry? meal;
  final String? thumb, source;
  final double size;
  final double? height;
  const MealThumb(this.meal, {super.key, this.size = 56, this.height, this.thumb, this.source});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = thumb ?? meal?.thumb;
    final h = height ?? size;
    const icons = {'photo': '📷', 'barcode': '🏷️', 'search': '🔍', 'text': '✍️', 'recent': '🕘'};
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: h,
        color: p.bg,
        alignment: Alignment.center,
        child: t != null
            ? Image.memory(base64Decode(t), width: size, height: h, fit: BoxFit.cover, gaplessPlayback: true)
            : Text(icons[source ?? meal?.source] ?? '🍽️', style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
