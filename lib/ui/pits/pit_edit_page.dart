import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'pit_form.dart';

/// 編輯坑：封存、坑名、描述、刪除。坑內有圖才顯示「更換封面」。
class PitEditPage extends ConsumerStatefulWidget {
  const PitEditPage({super.key, required this.pit});
  final Pit pit;

  @override
  ConsumerState<PitEditPage> createState() => _PitEditPageState();
}

class _PitEditPageState extends ConsumerState<PitEditPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pit.name);
  late final _desc = TextEditingController(text: widget.pit.description ?? '');
  late bool _archived = widget.pit.archived;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final desc = _desc.text.trim();
    await ref
        .read(databaseProvider)
        .updatePit(
          widget.pit.id,
          name: _name.text.trim(),
          description: desc.isEmpty ? null : desc,
          archived: _archived,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除這個坑？'),
        content: const Text('坑內的內容也會一併刪除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('刪除', style: TextStyle(color: ctx.tokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(databaseProvider).deletePit(widget.pit.id);
    if (!mounted) return;
    // 回到主頁（越過坑內頁）。
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasImages =
        (ref.watch(pitStatsProvider(widget.pit.id)).value?.imageCount ?? 0) > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯坑'),
        actions: [TextButton(onPressed: _save, child: const Text('儲存'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (hasImages) ...[
              OutlinedButton(
                // TODO: 進入選擇封面（CoverPick）。
                onPressed: () {},
                child: const Text('更換封面'),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              decoration: pitFieldDecoration(context, '坑名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入坑名' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              minLines: 3,
              maxLines: 6,
              decoration: pitFieldDecoration(context, '描述'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: t.accent,
              title: const Text('封存'),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _delete,
              child: Text('刪除這個坑', style: TextStyle(color: t.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
