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
}) {
  // 選淺坑時 form sheet 變兩欄、加寬到 880（NewPitShallow）；切回坑縮回 600。
  final width = ValueNotifier<double>(
    initialStatus == PitStatus.shallow
        ? PitNewPage.shallowWidth
        : PitNewPage.pitWidth,
  );
  return showAdaptiveModal<String>(
    context,
    width: PitNewPage.pitWidth,
    widthListenable: width,
    builder: (_, asModal) => PitNewPage(
      asModal: asModal,
      initialStatus: initialStatus,
      widthNotifier: width,
    ),
  ).whenComplete(width.dispose);
}

/// 開新坑：類型（坑｜淺坑）、坑名、描述；選淺坑時多出封面（可選）與「開啟的格子」。
/// [asModal]＝畫成 modal 內容（取消／開新坑／建立 標題列，不藏導覽列）；否則整頁。
///
/// iPad form sheet（NewPit／NewPitShallow）：選淺坑時變兩欄（880 寬）：左＝類型、封面（可選）、坑名、描述；
/// 右＝開啟的格子（7 個開關，預設只開官方圖冊、好看同人圖）。坑名沒有 placeholder（D-075）。
/// 手機整頁的格子預設全關（D-088）。
class PitNewPage extends ConsumerStatefulWidget {
  const PitNewPage({
    super.key,
    this.asModal = false,
    this.initialStatus = PitStatus.active,
    this.widthNotifier,
  });
  final bool asModal;
  final PitStatus initialStatus;

  /// form sheet 的寬度（選淺坑時 880，其餘 600）；由 [openNewPit] 傳入，讓對話框跟著加寬。
  final ValueNotifier<double>? widthNotifier;

  static const pitWidth = 600.0;
  static const shallowWidth = 880.0;

  /// 對話框寬度夠放兩欄的門檻（被視窗縮窄時退回單欄）。
  static const twoColumnMin = 760.0;

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
  // iPad modal 預設只開官方圖冊、好看同人圖（NewPitShallow）；手機整頁維持全關（D-088）。
  late final Set<PitSectionKey> _sections = widget.asModal
      ? {PitSectionKey.official, PitSectionKey.fan}
      : {};

  bool get _shallow => _status == PitStatus.shallow;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || !_canSave) return;
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

  void _setStatus(PitStatus s) {
    setState(() => _status = s);
    widget.widthNotifier?.value = s == PitStatus.shallow
        ? PitNewPage.shallowWidth
        : PitNewPage.pitWidth;
  }

  /// 坑名填了才能建立／儲存；沒填按鈕變灰，不另加提示（D-121 ①）。
  bool get _canSave => _name.text.trim().isNotEmpty;

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  Widget _typeSegment() => PitTypeSegment(
    value: _status,
    allowArchive: false,
    onChanged: _setStatus,
  );

  Widget _nameField() => TextFormField(
    key: const ValueKey('pit-name'),
    controller: _name,
    autofocus: !_shallow,
    textInputAction: TextInputAction.next,
    style: const TextStyle(fontSize: 15),
    decoration: pitInputDecoration(context),
  );

  Widget _descField(int minLines) => TextFormField(
    key: const ValueKey('pit-desc'),
    controller: _desc,
    minLines: minLines,
    maxLines: 6,
    style: const TextStyle(fontSize: 15, height: 1.55),
    decoration: pitInputDecoration(context),
  );

  Widget _sectionList() => PitSectionSwitchList(
    enabled: _sections,
    onChanged: (k, v) => setState(() {
      v ? _sections.add(k) : _sections.remove(k);
    }),
  );

  /// 單欄表單欄位（手機整頁、page sheet、窄的 form sheet）。
  List<Widget> _fields({required bool modal, required bool sheet}) {
    final t = context.tokens;
    return [
      _typeSegment(),
      // 開新坑／開新淺坑都沒有封面欄（Molly 10/23：淺坑不要封面）。
      PitFieldLabel(context.l10n.pitsFieldName),
      _nameField(),
      SizedBox(height: modal ? 18 : 16),
      PitFieldLabel(context.l10n.pitsFieldDesc),
      _descField(_shallow ? 2 : (sheet ? 5 : (modal ? 4 : 3))),
      if (_shallow) ...[
        const SizedBox(height: 18),
        _sectionList(),
      ] else if (sheet) ...[
        // 只有 page sheet（NewPit400）有這行說明；600 的 form sheet 稿（NewPit）沒有。
        const SizedBox(height: 14),
        Text(
          context.l10n.ipadpitCoverLater,
          style: TextStyle(fontSize: 12.5, color: t.text4),
        ),
      ] else
        const SizedBox(height: 8),
    ];
  }

  /// 兩欄（NewPitShallow，對話框 ≥760）：左 400＝類型、坑名、描述；右＝開啟的格子。
  Widget _twoColumns() {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _typeSegment(),
                PitFieldLabel(context.l10n.pitsFieldName),
                _nameField(),
                const SizedBox(height: 18),
                PitFieldLabel(context.l10n.pitsFieldDesc),
                _descField(4),
              ],
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
              child: _sectionList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modal(BuildContext context) {
    // page sheet（NewPit400，＜600）：內距 20×18、底部留 40。
    final sheet = AdaptiveModalScope.sheetOf(context);
    return ModalFormFrame(
      title: context.l10n.pitsNewTitle,
      actionLabel: context.l10n.pitsCreate,
      onAction: _canSave ? _save : null,
      child: Form(
        key: _form,
        child: LayoutBuilder(
          builder: (context, c) {
            final twoCols =
                !sheet && _shallow && c.maxWidth >= PitNewPage.twoColumnMin;
            return SingleChildScrollView(
              padding: twoCols
                  ? EdgeInsets.zero
                  : sheet
                  ? EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      40 + MediaQuery.paddingOf(context).bottom,
                    )
                  : const EdgeInsets.fromLTRB(28, 24, 28, 30),
              child: twoCols
                  ? _twoColumns()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _fields(modal: true, sheet: sheet),
                    ),
            );
          },
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
                    ..._fields(modal: false, sheet: false),
                    SizedBox(height: _shallow ? 0 : 16),
                    PitPrimaryButton(
                      label: context.l10n.pitsCreate,
                      onPressed: _canSave ? _save : null,
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
