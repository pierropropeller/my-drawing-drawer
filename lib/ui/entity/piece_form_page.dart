import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/image_picker_field.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../tags/tag_picker.dart';
import 'connect_field.dart';
import 'entity_widgets.dart';

const socialPlatforms = ['推特', '小紅書', 'lofter', 'Instagram', 'Pixiv', '其他'];

/// 社交平台徽章：文字、底色、字色、顯示名稱（設計稿 PieceDetail／PieceNew）。
({String mark, Color bg, Color fg, String name}) socialPlatformStyle(
  String platform,
) {
  final p = platform.toLowerCase();
  if (p.contains('推特') || p.contains('twitter') || p == 'x') {
    return (
      mark: 'X',
      bg: const Color(0xFFE7ECF2),
      fg: const Color(0xFF2B2622),
      name: '推特（Twitter/X）',
    );
  }
  if (p.contains('小紅書')) {
    return (
      mark: '紅',
      bg: const Color(0xFFF6E7EA),
      fg: const Color(0xFFB23A4C),
      name: platform,
    );
  }
  if (p.contains('lofter')) {
    return (
      mark: 'Lo',
      bg: const Color(0xFFEAF0F5),
      fg: const Color(0xFF4A7A9A),
      name: 'Lofter',
    );
  }
  if (p.contains('instagram')) {
    return (
      mark: 'IG',
      bg: const Color(0xFFF1E6F0),
      fg: const Color(0xFF9A4F8E),
      name: platform,
    );
  }
  if (p.contains('pixiv')) {
    return (
      mark: 'Px',
      bg: const Color(0xFFE3EEF9),
      fg: const Color(0xFF2F6DAA),
      name: platform,
    );
  }
  return (
    mark: '鏈',
    bg: const Color(0xFFEFE7DC),
    fg: const Color(0xFF6E655B),
    name: platform,
  );
}

/// 新增成圖（亦作編輯頁）：圖片置頂（只限圖片）、標題、內文、tag、社交媒體連結（多條）、
/// 目標互動量、完成時間、連接腦洞與草稿。
class PieceFormPage extends ConsumerStatefulWidget {
  const PieceFormPage({
    super.key,
    required this.pitId,
    this.pieceId,
    this.initialTime,
    this.initialImages = const [],
  });
  final String pitId;
  final String? pieceId;

  /// 新增時預設的完成時間。
  final DateTime? initialTime;

  /// 先從相簿選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

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
    if (widget.initialTime != null) _finishedAt = widget.initialTime!;
    _images.addAll(widget.initialImages.map(ImageItem.picked));
    _load();
  }

  Future<void> _load() async {
    final id = widget.pieceId;
    if (id != null) {
      final v = await ref.read(databaseProvider).watchPieceView(id).first;
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

  Widget _linkRow(BuildContext context, int i) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final st = socialPlatformStyle(_links[i].platform);
    final line = dark ? t.border : const Color(0xFFE3D8C9);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: '選擇平台',
            padding: EdgeInsets.zero,
            initialValue: _links[i].platform,
            onSelected: (v) => setState(() => _links[i].platform = v),
            itemBuilder: (_) => [
              for (final p in socialPlatforms)
                PopupMenuItem(value: p, child: Text(p)),
            ],
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: dark ? t.chipBg : st.bg,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                st.mark,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dark ? t.text2 : st.fg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _links[i].url,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '貼上連結網址',
                hintStyle: TextStyle(color: t.text4, fontSize: 13),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          InkResponse(
            radius: 18,
            onTap: () => setState(() => _links.removeAt(i).url.dispose()),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SvgIcon(
                AppIcons.closeX,
                size: 16,
                strokeWidth: 2,
                color: t.text4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? t.border : const Color(0xFFE3D8C9);
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final drafts =
        ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    final accentHex =
        '#${(t.accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: widget.pieceId == null ? '新增成圖' : '編輯成圖',
              titleSize: 20,
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          const FormLabel('成品圖'),
                          FormImageGrid(
                            size: 84,
                            items: _images,
                            onAdd: () async {
                              final picked = await ref.read(
                                imagePickerProvider,
                              )();
                              if (picked.isNotEmpty) {
                                setState(
                                  () => _images.addAll(
                                    picked.map(ImageItem.picked),
                                  ),
                                );
                              }
                            },
                            onRemove: (i) =>
                                setState(() => _images.removeAt(i)),
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('標題'),
                          TextFormField(
                            controller: _title,
                            style: const TextStyle(fontSize: 15),
                            decoration: entityFieldDecoration(
                              context,
                              '為這張成圖命名',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '請輸入標題'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('內文'),
                          TextFormField(
                            controller: _body,
                            minLines: 3,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 15, height: 1.55),
                            decoration: entityFieldDecoration(
                              context,
                              '想說的話、創作筆記…',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TagPicker(
                            pitId: widget.pitId,
                            selected: _tagIds,
                            onChanged: (v) => setState(() => _tagIds = v),
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('社交媒體連結'),
                          for (var i = 0; i < _links.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _linkRow(context, i),
                            ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DashedAddChip(
                              label: '加社交連結',
                              semanticLabel: '加社交連結',
                              onTap: () => setState(
                                () => _links.add(
                                  _LinkRow(socialPlatforms.first, ''),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const FormLabel('目標互動量'),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.surface,
                                    border: Border.all(color: line),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      SvgIcon(
                                        AppIcons.heart,
                                        size: 18,
                                        strokeWidth: 0,
                                        color: t.accent,
                                        fill: accentHex,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: TextField(
                                          controller: _target,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 15),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            filled: false,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '紅心',
                                style: TextStyle(fontSize: 13, color: t.text3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('完成時間'),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _finishedAt,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (d != null) setState(() => _finishedAt = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: t.surface,
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                fmtSlash(_finishedAt),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
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
                          const SizedBox(height: 16),
                          ConnectField(
                            label: '連接草稿',
                            options: [
                              for (final d in drafts)
                                ConnectOption(
                                  id: d.draft.id,
                                  title: d.draft.title ?? '',
                                  file: d.images.isEmpty
                                      ? null
                                      : d.images.first.file,
                                ),
                            ],
                            selected: _draftIds,
                            onChanged: (v) => setState(() => _draftIds = v),
                          ),
                          const SizedBox(height: 22),
                          FormSubmitButton(
                            label: widget.pieceId == null ? '建立成圖' : '儲存',
                            onPressed: _saving ? null : _save,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
