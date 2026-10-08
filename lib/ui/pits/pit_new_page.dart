import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../common/nav_bar_hidden.dart';
import 'pit_form.dart';

/// 開新坑：只有坑名與描述，沒有封面欄位。
class PitNewPage extends ConsumerStatefulWidget {
  const PitNewPage({super.key});

  @override
  ConsumerState<PitNewPage> createState() => _PitNewPageState();
}

class _PitNewPageState extends ConsumerState<PitNewPage>
    with HidesNavBar<PitNewPage> {
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
      body: SafeArea(
        child: Column(
          children: [
            const PitHeader(title: '開新坑'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const PitFieldLabel('坑名'),
                    TextFormField(
                      controller: _name,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 15),
                      decoration: pitInputDecoration(context),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '請輸入坑名' : null,
                    ),
                    const SizedBox(height: 16),
                    const PitFieldLabel('描述'),
                    TextFormField(
                      controller: _desc,
                      minLines: 3,
                      maxLines: 6,
                      style: const TextStyle(fontSize: 15, height: 1.55),
                      decoration: pitInputDecoration(context),
                    ),
                    const SizedBox(height: 24),
                    PitPrimaryButton(label: '建立', onPressed: _save),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
