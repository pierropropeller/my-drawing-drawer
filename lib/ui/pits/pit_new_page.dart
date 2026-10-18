import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/adaptive_modal.dart';
import '../common/nav_bar_hidden.dart';
import 'pit_form.dart';
import 'pit_type_widgets.dart';

/// 開新坑的單一入口：視窗 ≥600 開置中 modal（NewPit，600 闊）；＜600 的 iPad 開 page sheet（NewPit400）；手機開整頁。
/// 回傳新坑的 id（取消為 null）。[initialStatus]：預設的類型（主頁「淺坑」分頁的「開新淺坑」帶淺坑）。
Future<String?> openNewPit(
  BuildContext context, {
  PitStatus initialStatus = PitStatus.active,
}) => showAdaptiveModal<String>(
  context,
  width: 600,
  builder: (_, asModal) =>
      PitNewPage(asModal: asModal, initialStatus: initialStatus),
);

/// 開新坑：類型（坑｜淺坑）、坑名、描述；選淺坑時多出封面（可選）與「開啟的格子」（預設全關，可以一個都不開）。
/// [asModal]＝畫成 modal 內容（取消／開新坑／建立 標題列，不藏導覽列）；否則整頁。
class PitNewPage extends ConsumerStatefulWidget {
  const PitNewPage({
    super.key,
    this.asModal = false,
    this.initialStatus = PitStatus.active,
  });
  final bool asModal;
  final PitStatus initialStatus;

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
  late PitStatus _status = widget.initialStatus == PitStatus.shallow
      ? PitStatus.shallow
      : PitStatus.active;
  final Set<PitSectionKey> _sections = {};

  bool get _shallow => _status == PitStatus.shallow;

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
          status: _status,
          enabledSections: _shallow ? _sections : const {},
        );
    // 回傳新坑的 id（分享進來的「開新坑」要接著選它，D-053）。
    if (mounted) Navigator.of(context).pop(id);
  }

  String? _validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.pitsNameRequired : null;

  /// 表單欄位（整頁與 modal 共用；[modal] 只差在內距與間距）。
  List<Widget> _fields({required bool modal}) {
    final t = context.tokens;
    return [
      PitTypeSegment(
        value: _status,
        allowArchive: false,
        onChanged: (s) => setState(() => _status = s),
      ),
      PitFieldLabel(context.l10n.pitsFieldName),
      TextFormField(
        key: const ValueKey('pit-name'),
        controller: _name,
        autofocus: !_shallow,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 15),
        decoration: modal
            ? pitInputDecoration(context)
                  .copyWith(hintText: context.l10n.ipadpitNameHint)
            : pitInputDecoration(context),
        validator: _validateName,
      ),
      SizedBox(height: modal ? 18 : 16),
      PitFieldLabel(context.l10n.pitsFieldDesc),
      TextFormField(
        key: const ValueKey('pit-desc'),
        controller: _desc,
        minLines: _shallow ? 2 : (modal ? 4 : 3),
        maxLines: 6,
        style: const TextStyle(fontSize: 15, height: 1.55),
        decoration: pitInputDecoration(context),
      ),
      if (_shallow) ...[
        const SizedBox(height: 18),
        PitSectionSwitchList(
          enabled: _sections,
          onChanged: (k, v) => setState(() {
            v ? _sections.add(k) : _sections.remove(k);
          }),
        ),
      ] else if (modal) ...[
        const SizedBox(height: 14),
        Text(
          context.l10n.ipadpitCoverLater,
          style: TextStyle(fontSize: 12.5, color: t.text4),
        ),
      ] else
        const SizedBox(height: 8),
    ];
  }

  Widget _modal(BuildContext context) {
    // page sheet（NewPit400，＜600）：內距 20×18、底部留 40。
    final sheet = AdaptiveModalScope.sheetOf(context);
    return ModalFormFrame(
      title: context.l10n.pitsNewTitle,
      actionLabel: context.l10n.pitsCreate,
      onAction: _save,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: sheet
              ? EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  40 + MediaQuery.paddingOf(context).bottom,
                )
              : const EdgeInsets.fromLTRB(28, 24, 28, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _fields(modal: true),
          ),
        ),
      ),
    );
  }

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
                    ..._fields(modal: false),
                    SizedBox(height: _shallow ? 0 : 16),
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
