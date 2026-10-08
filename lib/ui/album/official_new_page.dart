import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/nav_bar_hidden.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';

/// 新增官方圖（OfficialNew）：一次可加多張，選分組；官方圖沒有 tag。沒有底部導覽列。
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

class _OfficialNewPageState extends ConsumerState<OfficialNewPage>
    with HidesNavBar<OfficialNewPage> {
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
      showSnack(context, context.l10n.albumPickImageFirst);
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
    return AlbumFormScaffold(
      title: context.l10n.albumOfficialNewTitle,
      children: [
        AlbumFieldLabel(context.l10n.albumFieldImage),
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
        AlbumSubmitButton(
          label: context.l10n.albumOfficialAdd,
          busy: _saving,
          onTap: groupId == null ? null : () => _save(groupId),
        ),
      ],
    );
  }
}
