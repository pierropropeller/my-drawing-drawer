import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../common/nav_bar_hidden.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';

/// 編輯同人圖：圖片、作者、出處、tag（設計稿沒畫，版型沿用 OfficialNew）。沒有底部導覽列。
class FanArtEditPage extends ConsumerStatefulWidget {
  const FanArtEditPage({super.key, required this.pitId, required this.imageId});
  final String pitId;
  final String imageId;

  @override
  ConsumerState<FanArtEditPage> createState() => _FanArtEditPageState();
}

/// 離開時回傳 true＝這張圖在編輯頁被刪除。
class _FanArtEditPageState extends ConsumerState<FanArtEditPage>
    with HidesNavBar<FanArtEditPage> {
  final _author = TextEditingController();
  String? _groupId;
  List<String>? _tagIds;
  NewImage? _image;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.fanArts,
    )..where((f) => f.id.equals(widget.imageId))).getSingle();
    final ids = await db.watchTagIds(TagTarget.fanArt, widget.imageId).first;
    if (!mounted) return;
    setState(() {
      _author.text = row.author;
      _groupId = row.groupId;
      _tagIds = ids;
      _image = NewImage(
        file: row.imageFile,
        width: row.width,
        height: row.height,
      );
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _author.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(databaseProvider)
        .updateFanArt(
          widget.imageId,
          author: _author.text.trim(),
          groupId: _groupId,
          tagIds: _tagIds ?? const [],
        );
    if (mounted) Navigator.of(context).pop();
  }

  /// 圖片上的「×」＝刪除這張同人圖（編輯單張沒有別的圖可以換），要確認。
  Future<void> _removeImage() async {
    final ok = await confirmDelete(context, title: '刪除這張圖？');
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteFanArts([widget.imageId]);
    if (!mounted) return;
    // 回傳 true 讓預覽頁知道這張圖已經刪除。
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const AlbumFormScaffold(
        title: '編輯同人圖',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    return AlbumFormScaffold(
      title: '編輯同人圖',
      children: [
        const AlbumFieldLabel('圖片'),
        ImagePickerField(
          items: [ImageItem.stored(_image!)],
          onAdd: null,
          onRemove: (_) => _removeImage(),
        ),
        const SizedBox(height: 18),
        const AlbumFieldLabel('作者'),
        TextField(controller: _author, decoration: pitInputDecoration(context)),
        const SizedBox(height: 18),
        GroupPicker(
          pitId: widget.pitId,
          kind: 'fan',
          label: '出處',
          selected: _groupId,
          allowClear: true,
          onSelected: (v) => setState(() => _groupId = v),
        ),
        const SizedBox(height: 18),
        TagPicker(
          pitId: widget.pitId,
          selected: _tagIds!,
          onChanged: (v) => setState(() => _tagIds = v),
        ),
        const SizedBox(height: 26),
        AlbumSubmitButton(label: '儲存', onTap: _save),
      ],
    );
  }
}
