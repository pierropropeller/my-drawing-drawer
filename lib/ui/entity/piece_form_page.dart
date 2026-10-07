import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/image_picker_field.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';

const socialPlatforms = ['推特', '小紅書', 'lofter', 'Instagram', 'Pixiv', '其他'];

/// 新增成圖（亦作編輯頁）：圖片置頂（只限圖片）、標題、內文、tag、社交媒體連結（多條）、
/// 目標互動量、完成時間、連接腦洞與草稿。
class PieceFormPage extends ConsumerStatefulWidget {
  const PieceFormPage({super.key, required this.pitId, this.pieceId});
  final String pitId;
  final String? pieceId;

  @override
  ConsumerState<PieceFormPage> createState() => _PieceFormPageState();
}

class _LinkRow {
  _LinkRow(this.platform, String url) : url = TextEditingController(text: url);
  String platform;
  final TextEditingController url;
}

class _PieceFormPageState extends ConsumerState<PieceFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _target = TextEditingController();
  final List<ImageItem> _images = [];
  final List<_LinkRow> _links = [];
  List<String> _tagIds = [];
  List<String> _ideaIds = [];
  List<String> _draftIds = [];
  DateTime _finishedAt = DateTime.now();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.pieceId;
    if (id != null) {
      final v = await ref.read(pieceViewProvider(id).future);
      if (v != null) {
        _title.text = v.piece.title;
        _body.text = v.piece.body;
        _target.text = v.piece.targetLikes > 0 ? '${v.piece.targetLikes}' : '';
        _finishedAt = v.piece.finishedAt;
        _images.addAll(
          v.images.map(
            (e) => ImageItem.stored(
              NewImage(file: e.file, width: e.width, height: e.height),
            ),
          ),
        );
        _links.addAll(v.links.map((l) => _LinkRow(l.platform, l.url)));
        _tagIds = v.tags.map((e) => e.id).toList();
        _ideaIds = v.ideaIds;
        _draftIds = v.draftIds;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _target.dispose();
    for (final l in _links) {
      l.url.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_images.isEmpty) {
      showSnack(context, '請至少選擇一張圖片');
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imgs = await resolveImages(store, _images);
    await ref
        .read(databaseProvider)
        .savePiece(
          id: widget.pieceId,
          pitId: widget.pitId,
          title: _title.text.trim(),
          body: _body.text.trim(),
          images: imgs,
          tagIds: _tagIds,
          links: [
            for (final l in _links)
              if (l.url.text.trim().isNotEmpty)
                SocialLink(l.platform, l.url.text.trim()),
          ],
          targetLikes: int.tryParse(_target.text.trim()) ?? 0,
          finishedAt: _finishedAt,
          ideaIds: _ideaIds,
          draftIds: _draftIds,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final drafts =
        ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pieceId == null ? '新增成圖' : '編輯成圖'),
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
                  TextFormField(
                    controller: _title,
                    decoration: pitFieldDecoration(context, '標題'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _body,
                    minLines: 4,
                    maxLines: 10,
                    decoration: pitFieldDecoration(context, '內文'),
                  ),
                  const SizedBox(height: 20),
                  TagPicker(
                    pitId: widget.pitId,
                    selected: _tagIds,
                    onChanged: (v) => setState(() => _tagIds = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '社交媒體連結',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _links.add(_LinkRow(socialPlatforms.first, '')),
                        ),
                        child: const Text('新增'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < _links.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          DropdownButton<String>(
                            value: _links[i].platform,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final p in socialPlatforms)
                                DropdownMenuItem(value: p, child: Text(p)),
                            ],
                            onChanged: (v) =>
                                setState(() => _links[i].platform = v!),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _links[i].url,
                              keyboardType: TextInputType.url,
                              decoration: pitFieldDecoration(context, '網址'),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: t.text3),
                            onPressed: () => setState(
                              () => _links.removeAt(i).url.dispose(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    decoration: pitFieldDecoration(context, '目標互動量'),
                  ),
                  const SizedBox(height: 16),
                  const FormLabel('完成時間'),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(fmtDate(_finishedAt)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _finishedAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _finishedAt = d);
                    },
                  ),
                  const SizedBox(height: 20),
                  ConnectField(
                    label: '連接腦洞',
                    options: [
                      for (final i in ideas)
                        ConnectOption(
                          id: i.idea.id,
                          title: i.idea.title,
                          file: i.images.isEmpty ? null : i.images.first.file,
                        ),
                    ],
                    selected: _ideaIds,
                    onChanged: (v) => setState(() => _ideaIds = v),
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
                ],
              ),
            ),
    );
  }
}
