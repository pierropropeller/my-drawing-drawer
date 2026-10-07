import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'album_actions.dart';
import 'album_view.dart';
import 'fan_art_sources.dart';
import 'image_picker_field.dart';

/// 新增同人圖：圖片、作者、出處、tag（沿用官方圖新增頁的版型）。
class FanArtNewPage extends ConsumerStatefulWidget {
  const FanArtNewPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<FanArtNewPage> createState() => _FanArtNewPageState();
}

class _FanArtNewPageState extends ConsumerState<FanArtNewPage> {
  final List<ImageItem> _files = [];
  final _author = TextEditingController();
  String? _source;
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
        .addFanArts(
          widget.pitId,
          imported,
          author: _author.text.trim(),
          source: _source ?? '',
          tagIds: _tagIds,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增同人圖'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('儲存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ImagePickerField(
            items: _files,
            onAdd: _pick,
            onRemove: (i) => setState(() => _files.removeAt(i)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _author,
            decoration: pitFieldDecoration(context, '作者'),
          ),
          const SizedBox(height: 20),
          const Text('出處', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ChipRow(
            padding: EdgeInsets.zero,
            allLabel: null,
            options: [for (final s in fanArtSources) (s, s)],
            selected: _source,
            onSelected: (v) =>
                setState(() => _source = v == _source ? null : v),
          ),
          const SizedBox(height: 20),
          TagPicker(
            pitId: widget.pitId,
            selected: _tagIds,
            onChanged: (v) => setState(() => _tagIds = v),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
