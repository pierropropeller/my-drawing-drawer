import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/nav_bar_hidden.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';

/// 新增同人圖：圖片、作者、出處、tag。設計稿沒畫，版型沿用 OfficialNew。沒有底部導覽列。
class FanArtNewPage extends ConsumerStatefulWidget {
  const FanArtNewPage({
    super.key,
    required this.pitId,
    this.initialImages = const [],
    this.initialGroupId,
  });
  final String pitId;
  final List<XFile> initialImages;
  final String? initialGroupId;

  @override
  ConsumerState<FanArtNewPage> createState() => _FanArtNewPageState();
}

class _FanArtNewPageState extends ConsumerState<FanArtNewPage>
    with HidesNavBar<FanArtNewPage> {
  late final List<ImageItem> _files = widget.initialImages
      .map(ImageItem.picked)
      .toList();
  final _author = TextEditingController();
  late String? _groupId = widget.initialGroupId;
  List<String> _tagIds = [];
  bool _saving = false;

  @override
  void dispose() {
    _author.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isNotEmpty) {
      setState(() => _files.addAll(picked.map(ImageItem.picked)));
    }
  }

  Future<void> _save() async {
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
        .addFanArts(
          widget.pitId,
          imported,
          author: _author.text.trim(),
          groupId: _groupId,
          tagIds: _tagIds,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlbumFormScaffold(
      title: context.l10n.albumFanNewTitle,
      children: [
        AlbumFieldLabel(context.l10n.albumFieldImage),
        ImagePickerField(
          items: _files,
          onAdd: _pick,
          onRemove: (i) => setState(() => _files.removeAt(i)),
        ),
        const SizedBox(height: 18),
        AlbumFieldLabel(context.l10n.albumFieldAuthor),
        TextField(controller: _author, decoration: pitInputDecoration(context)),
        const SizedBox(height: 18),
        GroupPicker(
          pitId: widget.pitId,
          kind: 'fan',
          label: context.l10n.albumFieldSource,
          selected: _groupId,
          allowClear: true,
          onSelected: (v) => setState(() => _groupId = v),
        ),
        const SizedBox(height: 18),
        TagPicker(
          pitId: widget.pitId,
          selected: _tagIds,
          onChanged: (v) => setState(() => _tagIds = v),
        ),
        const SizedBox(height: 26),
        AlbumSubmitButton(
          label: context.l10n.albumFanAdd,
          busy: _saving,
          onTap: _save,
        ),
      ],
    );
  }
}
