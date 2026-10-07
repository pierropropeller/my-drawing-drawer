import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import 'album_actions.dart';
import 'album_view.dart';
import 'image_picker_field.dart';

/// 新增官方圖：一次可加多張，選分組；官方圖沒有 tag。
class OfficialNewPage extends ConsumerStatefulWidget {
  const OfficialNewPage({super.key, required this.pitId, this.initialGroupId});
  final String pitId;
  final String? initialGroupId;

  @override
  ConsumerState<OfficialNewPage> createState() => _OfficialNewPageState();
}

class _OfficialNewPageState extends ConsumerState<OfficialNewPage> {
  final List<XFile> _files = [];
  String? _groupId;
  bool _saving = false;

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isNotEmpty) setState(() => _files.addAll(picked));
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
      imported.add(await store.import(f));
    }
    await ref
        .read(databaseProvider)
        .addOfficial(widget.pitId, groupId, imported);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider(widget.pitId)).value ?? const [];
    final groupId = groups.any((g) => g.id == _groupId)
        ? _groupId
        : (groups.any((g) => g.id == widget.initialGroupId)
              ? widget.initialGroupId
              : (groups.isEmpty ? null : groups.first.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增官方圖'),
        actions: [
          TextButton(
            onPressed: (_saving || groupId == null)
                ? null
                : () => _save(groupId),
            child: const Text('儲存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ImagePickerField(
            files: _files,
            onAdd: _pick,
            onRemove: (i) => setState(() => _files.removeAt(i)),
          ),
          const SizedBox(height: 24),
          const Text('分組', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ChipRow(
            padding: EdgeInsets.zero,
            allLabel: null,
            options: [for (final g in groups) (g.id, g.name)],
            selected: groupId,
            onSelected: (v) => setState(() => _groupId = v),
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
