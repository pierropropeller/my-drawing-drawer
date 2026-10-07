import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'album_view.dart';
import 'fan_art_sources.dart';

/// 編輯同人圖：作者、出處、tag。
class FanArtEditPage extends ConsumerStatefulWidget {
  const FanArtEditPage({super.key, required this.pitId, required this.imageId});
  final String pitId;
  final String imageId;

  @override
  ConsumerState<FanArtEditPage> createState() => _FanArtEditPageState();
}

class _FanArtEditPageState extends ConsumerState<FanArtEditPage> {
  final _author = TextEditingController();
  String? _source;
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
      _source = row.source.isEmpty ? null : row.source;
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
          source: _source ?? '',
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
                  selected: _tagIds!,
                  onChanged: (v) => setState(() => _tagIds = v),
                ),
              ],
            ),
    );
  }
}
