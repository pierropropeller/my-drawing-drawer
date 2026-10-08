import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
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
            PitHeader(title: context.l10n.pitsNewTitle),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    PitFieldLabel(context.l10n.pitsFieldName),
                    TextFormField(
                      controller: _name,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 15),
                      decoration: pitInputDecoration(context),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.l10n.pitsNameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    PitFieldLabel(context.l10n.pitsFieldDesc),
                    TextFormField(
                      controller: _desc,
                      minLines: 3,
                      maxLines: 6,
                      style: const TextStyle(fontSize: 15, height: 1.55),
                      decoration: pitInputDecoration(context),
                    ),
                    const SizedBox(height: 24),
                    PitPrimaryButton(
                      label: context.l10n.pitsCreate,
                      onPressed: _save,
                    ),
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
