import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/image_picker_field.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../tags/tag_picker.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';

/// 新增腦洞（亦作編輯頁）：標題、內文、配圖、tag、關聯草稿、關聯成圖。
/// 沒有導覽列。選擇草稿／成圖的面板只從這裡打開（D-037）。
class IdeaFormPage extends ConsumerStatefulWidget {
  const IdeaFormPage({
    super.key,
    required this.pitId,
    this.ideaId,
    this.initialTime,
  });
  final String pitId;
  final String? ideaId;

  /// 新增時使用的建立時間（時間軸上以「此時此刻」新增、可改時間）。
  final DateTime? initialTime;

  @override
  ConsumerState<IdeaFormPage> createState() => _IdeaFormPageState();
}

class _IdeaFormPageState extends ConsumerState<IdeaFormPage>
    with HidesNavBar<IdeaFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final List<ImageItem> _images = [];
  List<String> _tagIds = [];
  List<String> _draftIds = [];
  List<String> _pieceIds = [];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.ideaId;
    if (id != null) {
      final v = await ref.read(databaseProvider).watchIdeaView(id).first;
      if (v != null) {
        _title.text = v.idea.title;
        _body.text = v.idea.body;
        _images.addAll(
          v.images.map(
            (e) => ImageItem.stored(
              NewImage(file: e.file, width: e.width, height: e.height),
            ),
          ),
        );
        _tagIds = v.tags.map((e) => e.id).toList();
        _draftIds = v.draftIds;
        _pieceIds = v.pieceIds;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    await ref
        .read(databaseProvider)
        .saveIdea(
          id: widget.ideaId,
          pitId: widget.pitId,
          title: _title.text.trim(),
          body: _body.text.trim(),
          images: imgs,
          tagIds: _tagIds,
          draftIds: _draftIds,
          pieceIds: _pieceIds,
          createdAt: widget.initialTime,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addImages() async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked.map(ImageItem.picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts =
        ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    final pieces =
        ref.watch(pieceViewsProvider((widget.pitId, null))).value ?? const [];
    final isNew = widget.ideaId == null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: isNew
                  ? context.l10n.ideaFormTitleNew
                  : context.l10n.ideaFormTitleEdit,
              titleSize: 20,
              gap: 6,
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _form,
                      child: ContentWidth(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          children: [
                            FormLabel(context.l10n.entityFieldTitle),
                            TextFormField(
                              controller: _title,
                              style: const TextStyle(fontSize: 15),
                              decoration: entityFieldDecoration(
                                context,
                                context.l10n.ideaFormTitleHint,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? context.l10n.entityTitleRequired
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            FormLabel(context.l10n.entityFieldBody),
                            TextFormField(
                              controller: _body,
                              minLines: 4,
                              maxLines: 12,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.55,
                              ),
                              decoration: entityFieldDecoration(
                                context,
                                context.l10n.ideaFormBodyHint,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FormLabel(context.l10n.ideaFormImages),
                            FormImageGrid(
                              items: _images,
                              size: 72,
                              onAdd: _addImages,
                              onRemove: (i) =>
                                  setState(() => _images.removeAt(i)),
                            ),
                            const SizedBox(height: 16),
                            TagPicker(
                              pitId: widget.pitId,
                              selected: _tagIds,
                              onChanged: (v) => setState(() => _tagIds = v),
                            ),
                            const SizedBox(height: 16),
                            ConnectField(
                              label: context.l10n.entityConnectDraft,
                              kind: ConnectKind.draft,
                              options: [
                                for (final d in drafts)
                                  ConnectOption(
                                    id: d.draft.id,
                                    title: d.draft.title ?? '',
                                    file: d.images.isEmpty
                                        ? null
                                        : d.images.first.file,
                                    imageCount: d.images.length,
                                    date: d.draft.createdAt,
                                  ),
                              ],
                              selected: _draftIds,
                              onChanged: (v) => setState(() => _draftIds = v),
                            ),
                            const SizedBox(height: 16),
                            ConnectField(
                              label: context.l10n.entityConnectPiece,
                              kind: ConnectKind.piece,
                              options: [
                                for (final p in pieces)
                                  ConnectOption(
                                    id: p.piece.id,
                                    title: p.piece.title,
                                    file: p.images.isEmpty
                                        ? null
                                        : p.images.first.file,
                                    imageCount: p.images.length,
                                    date: p.piece.finishedAt,
                                  ),
                              ],
                              selected: _pieceIds,
                              onChanged: (v) => setState(() => _pieceIds = v),
                            ),
                            const SizedBox(height: 22),
                            FormSubmitButton(
                              label: isNew
                                  ? context.l10n.ideaFormCreate
                                  : context.l10n.commonSave,
                              onPressed: _saving ? null : _save,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
