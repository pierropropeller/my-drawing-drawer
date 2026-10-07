import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'pit_form.dart';

/// 開新坑：只有坑名與描述，沒有封面欄位。
class PitNewPage extends ConsumerStatefulWidget {
  const PitNewPage({super.key});

  @override
  ConsumerState<PitNewPage> createState() => _PitNewPageState();
}

class _PitNewPageState extends ConsumerState<PitNewPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();

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
        .createPit(
          name: _name.text.trim(),
          description: desc.isEmpty ? null : desc,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('開新坑'),
        actions: [TextButton(onPressed: _save, child: const Text('建立'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
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
          ],
        ),
      ),
    );
  }
}
