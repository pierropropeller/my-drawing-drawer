import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/adaptive_modal.dart';
import '../common/nav_bar_hidden.dart';
import 'pit_form.dart';

/// 開新坑的單一入口：視窗 ≥840 開置中 modal（NewPit，600 闊），較窄開整頁（手機版）。
/// 回傳新坑的 id（取消為 null）。
Future<String?> openNewPit(BuildContext context) => showAdaptiveModal<String>(
  context,
  width: 600,
  builder: (_, asModal) => PitNewPage(asModal: asModal),
);

/// 開新坑：只有坑名與描述，沒有封面欄位。
/// [asModal]＝畫成 modal 內容（取消／開新坑／建立 標題列，不藏導覽列）；否則整頁。
class PitNewPage extends ConsumerStatefulWidget {
  const PitNewPage({super.key, this.asModal = false});
  final bool asModal;

  @override
  ConsumerState<PitNewPage> createState() => _PitNewPageState();
}

class _PitNewPageState extends ConsumerState<PitNewPage>
    with HidesNavBar<PitNewPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

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
    final id = await ref
        .read(databaseProvider)
        .createPit(
          name: _name.text.trim(),
          description: desc.isEmpty ? null : desc,
        );
    // 回傳新坑的 id（分享進來的「開新坑」要接著選它，D-053）。
    if (mounted) Navigator.of(context).pop(id);
  }

  Widget _modal(BuildContext context) {
    final t = context.tokens;
    return ModalFormFrame(
      title: context.l10n.pitsNewTitle,
      actionLabel: context.l10n.pitsCreate,
      onAction: _save,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PitFieldLabel(context.l10n.pitsFieldName),
              TextFormField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 15),
                decoration: pitInputDecoration(context)
                    .copyWith(hintText: context.l10n.ipadpitNameHint),
                validator: _validateName,
              ),
              const SizedBox(height: 18),
              PitFieldLabel(context.l10n.pitsFieldDesc),
              TextFormField(
                controller: _desc,
                minLines: 4,
                maxLines: 6,
                style: const TextStyle(fontSize: 15, height: 1.55),
                decoration: pitInputDecoration(context),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.ipadpitCoverLater,
                style: TextStyle(fontSize: 12.5, color: t.text4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.pitsNameRequired : null;

  @override
  Widget build(BuildContext context) {
    if (widget.asModal) return _modal(context);
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
                      validator: _validateName,
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
