import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../album/image_picker_field.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';

/// 新增腦洞（亦作編輯頁）：標題、內文、配圖、tag、連接草稿、連接成圖。
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

class _IdeaFormPageState extends ConsumerState<IdeaFormPage> {
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
      final v = await ref.read(ideaViewProvider(id).future);
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

  @override
  Widget build(BuildContext context) {
    final drafts =
        ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    final pieces =
        ref.watch(pieceViewsProvider((widget.pitId, null))).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ideaId == null ? '新增腦洞' : '編輯腦洞'),
        actions: [
          TextButton(
            onPressed: (_loaded && !_saving) ? _save : null,
            child: const Text('儲存'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: pitFieldDecoration(context, '標題'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _body,
                    minLines: 5,
                    maxLines: 12,
                    decoration: pitFieldDecoration(context, '內文'),
                  ),
                  const SizedBox(height: 20),
                  const FormLabel('配圖'),
                  ImagePickerField(
                    items: _images,
                    onAdd: () async {
                      final picked = await ref.read(imagePickerProvider)();
                      if (picked.isNotEmpty) {
                        setState(
                          () => _images.addAll(picked.map(ImageItem.picked)),
                        );
                      }
                    },
                    onRemove: (i) => setState(() => _images.removeAt(i)),
                  ),
                  const SizedBox(height: 20),
                  TagPicker(
                    pitId: widget.pitId,
                    selected: _tagIds,
                    onChanged: (v) => setState(() => _tagIds = v),
                  ),
                  const SizedBox(height: 12),
                  ConnectField(
                    label: '連接草稿',
                    options: [
                      for (final d in drafts)
                        ConnectOption(
                          id: d.draft.id,
                          title: d.draft.title ?? '',
                          file: d.images.isEmpty ? null : d.images.first.file,
                        ),
                    ],
                    selected: _draftIds,
                    onChanged: (v) => setState(() => _draftIds = v),
                  ),
                  const SizedBox(height: 12),
                  ConnectField(
                    label: '連接成圖',
                    options: [
                      for (final p in pieces)
                        ConnectOption(
                          id: p.piece.id,
                          title: p.piece.title,
                          file: p.images.isEmpty ? null : p.images.first.file,
                        ),
                    ],
                    selected: _pieceIds,
                    onChanged: (v) => setState(() => _pieceIds = v),
                  ),
                ],
              ),
            ),
    );
  }
}
