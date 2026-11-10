import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/inspo_queries.dart';
import '../../data/material_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_form.dart';
import '../album/move_sheet.dart' show GroupChoiceChips;
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../../theme/tokens.dart';

/// 編輯一張靈感圖（InspoPreview 的「編輯」，D-141／D-143）：分類、說明。
/// 設計稿沒畫這頁，版型沿用 RefNew（圖片、單選 chips、說明、儲存）。沒有底部導覽列。
class InspoEditPage extends ConsumerStatefulWidget {
  const InspoEditPage({super.key, required this.image});
  final MaterialImage image;

  @override
  ConsumerState<InspoEditPage> createState() => _InspoEditPageState();
}

class _InspoEditPageState extends ConsumerState<InspoEditPage>
    with HidesNavBar<InspoEditPage> {
  late String _category = widget.image.categoryKey;
  late final _note = TextEditingController(text: widget.image.note ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    if (_category != widget.image.categoryKey) {
      await db.moveMaterials([widget.image.id], _category);
    }
    await db.setMaterialNote(widget.image.id, _note.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cats = ref.watch(inspoCategoriesProvider).value ?? const [];
    final r = widget.image;
    final aspect = (r.width > 0 && r.height > 0) ? r.width / r.height : 1.0;
    return AlbumFormScaffold(
      title: l.inspoEditTitle,
      children: [
        AlbumFieldLabel(l.albumFieldImage),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 120,
            child: AspectRatio(
              aspectRatio: aspect.clamp(0.5, 2.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.image),
                child: MediaThumb(
                  MediaSource.row(
                    file: r.imageFile,
                    kind: r.kind,
                    durationMs: r.durationMs,
                    posterFile: r.posterFile,
                    width: r.width,
                    height: r.height,
                  ),
                  cacheWidth: 300,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AlbumFieldLabel(l.materialFieldCategory),
        GroupChoiceChips(
          options: [for (final c in cats) (c.id, c.name)],
          selected: _category,
          onSelected: (id) => setState(() => _category = id),
        ),
        const SizedBox(height: 18),
        NoteField(controller: _note),
        const SizedBox(height: 26),
        AlbumSubmitButton(label: l.commonSave, busy: _saving, onTap: _save),
      ],
    );
  }
}
