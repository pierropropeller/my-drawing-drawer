import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../album/image_picker_field.dart';
import '../tags/tag_picker.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';

/// 新增草稿（亦作編輯頁）：圖片置頂（至少一張），標題、內文、tag 可空，可連接多個腦洞。
/// 時間＝建立時間，表單不讓使用者改。
class DraftFormPage extends ConsumerStatefulWidget {
  const DraftFormPage({
    super.key,
    required this.pitId,
    this.draftId,
    this.initialTime,
    this.initialImages = const [],
  });
  final String pitId;
  final String? draftId;

  /// 新增時使用的建立時間（時間軸上以「此時此刻」新增、可改時間）。
  final DateTime? initialTime;

  /// 先從相簿選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

  @override
  ConsumerState<DraftFormPage> createState() => _DraftFormPageState();
}

class _DraftFormPageState extends ConsumerState<DraftFormPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final List<ImageItem> _images = [];
  List<String> _tagIds = [];
  List<String> _ideaIds = [];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.initialImages.map(ImageItem.picked));
    _load();
  }

  Future<void> _load() async {
    final id = widget.draftId;
    if (id != null) {
      final v = await ref.read(databaseProvider).watchDraftView(id).first;
      if (v != null) {
        _title.text = v.draft.title ?? '';
        _body.text = v.draft.body ?? '';
        _images.addAll(
          v.images.map(
            (e) => ImageItem.stored(
              NewImage(file: e.file, width: e.width, height: e.height),
            ),
          ),
        );
        _tagIds = v.tags.map((e) => e.id).toList();
        _ideaIds = v.ideaIds;
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
    if (_images.isEmpty) {
      showSnack(context, '請至少選擇一張圖片');
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    await ref
        .read(databaseProvider)
        .saveDraft(
          id: widget.draftId,
          pitId: widget.pitId,
          title: _title.text,
          body: _body.text,
          images: imgs,
          tagIds: _tagIds,
          ideaIds: _ideaIds,
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
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final isNew = widget.draftId == null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: isNew ? '新增草稿' : '編輯草稿',
              titleSize: 20,
              gap: 6,
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        const FormLabel('草稿圖'),
                        FormImageGrid(
                          items: _images,
                          size: 84,
                          onAdd: _addImages,
                          onRemove: (i) => setState(() => _images.removeAt(i)),
                        ),
                        const SizedBox(height: 16),
                        const FormLabel('標題'),
                        TextField(
                          controller: _title,
                          style: const TextStyle(fontSize: 15),
                          decoration: entityFieldDecoration(context, '為這張草稿命名'),
                        ),
                        const SizedBox(height: 16),
                        const FormLabel('內文'),
                        TextField(
                          controller: _body,
                          minLines: 3,
                          maxLines: 10,
                          style: const TextStyle(fontSize: 15, height: 1.55),
                          decoration: entityFieldDecoration(
                            context,
                            '正在畫什麼、嘗試什麼構圖…',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TagPicker(
                          pitId: widget.pitId,
                          selected: _tagIds,
                          onChanged: (v) => setState(() => _tagIds = v),
                        ),
                        const SizedBox(height: 16),
                        ConnectField(
                          label: '連接腦洞',
                          options: [
                            for (final i in ideas)
                              ConnectOption(
                                id: i.idea.id,
                                title: i.idea.title,
                                file: i.images.isEmpty
                                    ? null
                                    : i.images.first.file,
                              ),
                          ],
                          selected: _ideaIds,
                          onChanged: (v) => setState(() => _ideaIds = v),
                        ),
                        const SizedBox(height: 22),
                        FormSubmitButton(
                          label: isNew ? '建立草稿' : '儲存',
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
