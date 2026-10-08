import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'album_actions.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';

/// 新增官方圖：一次可加多張，選分組；官方圖沒有 tag。
class OfficialNewPage extends ConsumerStatefulWidget {
  const OfficialNewPage({
    super.key,
    required this.pitId,
    this.initialGroupId,
    this.initialImages = const [],
  });
  final String pitId;
  final String? initialGroupId;

  /// 從相簿先選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

  @override
  ConsumerState<OfficialNewPage> createState() => _OfficialNewPageState();
}

class _OfficialNewPageState extends ConsumerState<OfficialNewPage> {
  late final List<ImageItem> _files = widget.initialImages
      .map(ImageItem.picked)
      .toList();
  String? _groupId;
  bool _saving = false;

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isNotEmpty) {
      setState(() => _files.addAll(picked.map(ImageItem.picked)));
    }
  }

  Future<void> _save(String groupId) async {
    if (_files.isEmpty) {
      showSnack(context, '請先選擇圖片');
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imported = <NewImage>[];
    for (final f in _files) {
      imported.add(await f.resolve(store));
    }
    await ref
        .read(databaseProvider)
        .addOfficial(widget.pitId, groupId, imported);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'official'))).value ?? const [];
    final groupId = groups.any((g) => g.id == _groupId)
        ? _groupId
        : (groups.any((g) => g.id == widget.initialGroupId)
              ? widget.initialGroupId
              : (groups.isEmpty ? null : groups.first.id));
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 58,
        titleSpacing: 6,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: IconButton(
            tooltip: '返回',
            padding: EdgeInsets.zero,
            icon: SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          '新增官方圖',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
            child: Text(
              '圖片',
              style: TextStyle(
                color: t.text2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ImagePickerField(
            items: _files,
            onAdd: _pick,
            onRemove: (i) => setState(() => _files.removeAt(i)),
          ),
          const SizedBox(height: 18),
          GroupPicker(
            pitId: widget.pitId,
            kind: 'official',
            selected: groupId,
            onSelected: (v) => setState(() => _groupId = v),
          ),
          const SizedBox(height: 26),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            GestureDetector(
              onTap: groupId == null ? null : () => _save(groupId),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: groupId == null
                      ? t.accent.withValues(alpha: 0.4)
                      : t.accent,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: const Text(
                  '加入官方圖冊',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
