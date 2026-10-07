import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'group_picker.dart';

/// 編輯同人圖：作者、分組、tag。
class FanArtEditPage extends ConsumerStatefulWidget {
  const FanArtEditPage({super.key, required this.pitId, required this.imageId});
  final String pitId;
  final String imageId;

  @override
  ConsumerState<FanArtEditPage> createState() => _FanArtEditPageState();
}

class _FanArtEditPageState extends ConsumerState<FanArtEditPage> {
  final _author = TextEditingController();
  String? _groupId;
  List<String>? _tagIds;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯同人圖'),
        actions: [
          TextButton(
            onPressed: _loaded ? _save : null,
            child: const Text('儲存'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _author,
                  decoration: pitFieldDecoration(context, '作者'),
                ),
                const SizedBox(height: 20),
                GroupPicker(
                  pitId: widget.pitId,
                  kind: 'fan',
                  selected: _groupId,
                  allowClear: true,
                  onSelected: (v) => setState(() => _groupId = v),
                ),
                const SizedBox(height: 20),
                TagPicker(
                  pitId: widget.pitId,
                  selected: _tagIds!,
                  onChanged: (v) => setState(() => _tagIds = v),
                ),
              ],
            ),
    );
  }
}
