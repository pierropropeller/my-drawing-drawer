import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/adaptive_modal.dart';
import '../common/modal_form_layout.dart';
import '../common/nav_bar_hidden.dart';
import '../media_source/drop_zone.dart';
import '../../theme/tokens.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';
import '../common/reorder_tile.dart';

/// 新增官方圖的單一入口：視窗 ≥840 開置中 modal（NewOfficial，880×640），較窄開整頁。
Future<void> openOfficialNew(
  BuildContext context, {
  required String pitId,
  String? initialGroupId,
  List<XFile> initialImages = const [],
}) => showAdaptiveModal<void>(
  context,
  width: 880,
  height: 640,
  builder: (_, asModal) => OfficialNewPage(
    pitId: pitId,
    initialGroupId: initialGroupId,
    initialImages: initialImages,
    asModal: asModal,
  ),
);

/// 新增官方圖（OfficialNew）：一次可加多張，選分組；官方圖沒有 tag。沒有底部導覽列。
class OfficialNewPage extends ConsumerStatefulWidget {
  const OfficialNewPage({
    super.key,
    required this.pitId,
    this.initialGroupId,
    this.initialImages = const [],
    this.asModal = false,
  });
  final String pitId;
  final String? initialGroupId;

  /// 從相簿先選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

  /// 畫成置中 modal 的內容（取消／標題／主動作 標題列，不藏導覽列）。
  final bool asModal;

  @override
  ConsumerState<OfficialNewPage> createState() => _OfficialNewPageState();
}

class _OfficialNewPageState extends ConsumerState<OfficialNewPage>
    with HidesNavBar<OfficialNewPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

  late final List<ImageItem> _files = widget.initialImages
      .map(ImageItem.picked)
      .toList();
  String? _groupId;
  bool _saving = false;

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)(context);
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
    final imageField = [
      AlbumFieldLabel(context.l10n.albumFieldImage),
      ImagePickerField(
        items: _files,
        onAdd: _pick,
        onRemove: (i) => setState(() => _files.removeAt(i)),
        onReorder: (a, b) => setState(() => moveListItem(_files, a, b)),
      ),
      const DropHintRow(),
    ];
    final groupField = GroupPicker(
      pitId: widget.pitId,
      kind: 'official',
      selected: groupId,
      onSelected: (v) => setState(() => _groupId = v),
    );
    final Widget form;
    if (widget.asModal) {
      final name = groups.where((g) => g.id == groupId).firstOrNull?.name;
      form = ModalFormShell(
        title: context.l10n.albumOfficialNewTitle,
        actionLabel: context.l10n.albumOfficialAdd,
        onAction: () {
          if (!_saving && groupId != null) _save(groupId);
        },
        panes: [
          ModalPane(width: 420, children: imageField),
          ModalPane(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            children: [
              groupField,
              if (name != null && _files.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.ipadformsOfficialGroupNote(_files.length, name),
                  style: TextStyle(fontSize: 12.5, color: context.tokens.text3),
                ),
              ],
            ],
          ),
        ],
      );
    } else {
      form = AlbumFormScaffold(
        title: context.l10n.albumOfficialNewTitle,
        children: [
          ...imageField,
          const SizedBox(height: 18),
          groupField,
          const SizedBox(height: 26),
          AlbumSubmitButton(
            label: context.l10n.albumOfficialAdd,
            busy: _saving,
            onTap: groupId == null ? null : () => _save(groupId),
          ),
        ],
      );
    }
    return DropZone(
      title: context.l10n.ipadmediaDropTitle(context.l10n.pitsOfficial),
      subtitleFor: context.l10n.ipadmediaDropCount,
      // 拖進來的圖直接加到圖片格（分組用分組欄選）。
      onFiles: (files) =>
          setState(() => _files.addAll(files.map(ImageItem.picked))),
      enabled: !_saving,
      child: form,
    );
  }
}
