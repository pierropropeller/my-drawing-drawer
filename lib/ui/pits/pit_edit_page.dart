import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../data/sensitive_queries.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../common/adaptive_modal.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../common/sensitive_dialogs.dart';
import '../common/svg_icon.dart';
import 'pit_form.dart';
import 'pit_type_widgets.dart';

/// 編輯坑的單一入口：視窗 ≥600 開置中 modal（PitEdit，860×690，縮到不超出視窗），
/// 較窄開整頁（手機版）。刪除坑後會回到主頁（越過坑內頁）。
Future<void> openPitEdit(BuildContext context, Pit pit) async {
  final deleted = await showAdaptiveModal<bool>(
    context,
    width: 860,
    height: 690,
    // 編輯坑沒有 400 稿：窄視窗照手機版開整頁。
    sheetBelowMedium: false,
    builder: (_, asModal) => PitEditPage(pit: pit, asModal: asModal),
  );
  // modal 在最上層 Navigator，刪除後要由呼叫端把坑分頁退回主頁；整頁模式由頁面自己退。
  if (deleted == true && context.mounted) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// 編輯坑：封面、坑名、描述、雜物開關、封存、刪除。
/// 封面區三種狀態：坑內沒有圖＝不顯示（PitEdit-ntnf）；有圖沒封面＝虛線＋號（PitEditNoCover）；
/// 有封面＝縮圖＋「更換封面」（PitEdit）。
///
/// [asModal]＝畫成 modal 內容（PitEdit 稿：左封面選擇、右表單；取消／編輯坑／儲存 標題列，
/// 不藏導覽列），刪除時以 `pop(true)` 通知呼叫端（見 [openPitEdit]）。
class PitEditPage extends ConsumerStatefulWidget {
  const PitEditPage({super.key, required this.pit, this.asModal = false});
  final Pit pit;
  final bool asModal;

  @override
  ConsumerState<PitEditPage> createState() => _PitEditPageState();
}

class _PitEditPageState extends ConsumerState<PitEditPage>
    with HidesNavBar<PitEditPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pit.name);
  late final _desc = TextEditingController(text: widget.pit.description ?? '');
  late PitStatus _status = widget.pit.status;

  /// 淺坑開啟的格子（編輯中的版本）。非淺坑時是「轉成淺坑時的預設」，見 [_setStatus]。
  late Set<PitSectionKey> _sections = {
    if (widget.pit.isShallow || widget.pit.enabledSections.isNotEmpty)
      ...widget.pit.enabledSections
    else if (widget.pit.junkEnabled)
      PitSectionKey.junk,
  };

  /// 現坑的雜物開關（淺坑時雜物併入 [_sections]）。
  late bool _junk = widget.pit.isShallow
      ? widget.pit.enabledSections.contains(PitSectionKey.junk)
      : widget.pit.junkEnabled;

  /// 這個坑的敏感內容開關（D-104）；總開關開著才顯示。
  late bool _sensitive = widget.pit.sensitiveEnabled;

  /// 各格子目前的內容數量（關閉格子時決定要不要彈確認框）。
  Map<PitSectionKey, int> _counts = const {};
  late final Future<void> _countsLoaded = _loadCounts();

  /// 使用者已在確認框同意「關閉並刪除」的格子（存檔時才真的刪除）。
  final Set<PitSectionKey> _confirmedClose = {};

  // modal 的封面選擇：選了先暫存，按「儲存」才寫入（取消不動）。
  late String? _coverId = widget.pit.coverImageId;
  String? _coverKind; // 候選篩選：null＝全部，official／fan／piece
  bool _coverDirty = false;

  /// 淺坑從相簿選的封面（iPad 稿「從相簿選擇」；先暫存，按「儲存」才寫入）。
  String? _galleryCover;

  bool get _shallow => _status == PitStatus.shallow;

  Future<void> _loadCounts() async {
    final c = await ref
        .read(databaseProvider)
        .sectionContentCounts(widget.pit.id);
    if (mounted) setState(() => _counts = c);
  }

  /// 切換類型。轉成淺坑時，格子預設為有資料的格子（封存的淺坑則還原當時的設定）；
  /// 離開淺坑時，雜物開關沿用淺坑的雜物格。
  Future<void> _setStatus(PitStatus s) async {
    if (s == _status) return;
    if (s == PitStatus.shallow && !widget.pit.isShallow) {
      await _countsLoaded;
      if (!mounted) return;
      final restore =
          widget.pit.isArchived && widget.pit.enabledSections.isNotEmpty;
      setState(() {
        _status = s;
        _sections = restore
            ? {...widget.pit.enabledSections}
            : {..._counts.keys, if (_junk) PitSectionKey.junk};
        _confirmedClose.clear();
      });
      return;
    }
    setState(() {
      if (_shallow) _junk = _sections.contains(PitSectionKey.junk);
      _status = s;
    });
  }

  /// 撥動淺坑的某個格子開關。關掉「原本開著而且有內容」的格子要先彈確認框，同意才關（存檔時才刪）。
  Future<void> _toggleSection(PitSectionKey key, bool on) async {
    if (on) {
      setState(() {
        _sections.add(key);
        _confirmedClose.remove(key);
      });
      return;
    }
    await _countsLoaded;
    if (!mounted) return;
    final n = _counts[key] ?? 0;
    final deletes = n > 0 && widget.pit.openSections.contains(key);
    if (deletes && !await confirmCloseSection(context, key, n)) return;
    if (!mounted) return;
    setState(() {
      _sections.remove(key);
      if (deletes) _confirmedClose.add(key);
    });
  }

  /// 敏感內容開關（D-104）：開→關要確認（說明坑內已標記的張數、標記會保留）。
  Future<void> _toggleSensitive(bool on) async {
    if (on) {
      setState(() => _sensitive = true);
      return;
    }
    final n = await ref
        .read(databaseProvider)
        .sensitiveCountInPit(widget.pit.id);
    if (!mounted || !await confirmSensitivePitOff(context, n)) return;
    if (mounted) setState(() => _sensitive = false);
  }

  /// 總開關開著才顯示坑的敏感內容開關。
  bool get _showSensitive =>
      ref.watch(settingsProvider.select((s) => s.sensitiveEnabled));

  @override
  void initState() {
    super.initState();
    _countsLoaded; // 一進來就開始數各格內容
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final desc = _desc.text.trim();
    final db = ref.read(databaseProvider);
    final pit = widget.pit;
    if (_shallow) {
      // 原本開著、現在關掉而且有內容的格子：都要有使用者同意（切換開關時已問過；
      // 其間內容有變動、或經由同步多出內容的，這裡補問）。
      final fresh = await db.sectionContentCounts(pit.id);
      for (final k in pit.openSections.difference(_sections)) {
        final n = fresh[k] ?? 0;
        if (n > 0 && !_confirmedClose.contains(k)) {
          if (!mounted || !await confirmCloseSection(context, k, n)) return;
        }
      }
    }
    await db.savePit(
      pit.id,
      name: _name.text.trim(),
      description: desc.isEmpty ? null : desc,
      status: _status,
      enabledSections: _shallow ? _sections : null,
      junkEnabled: _shallow ? null : _junk,
      sensitiveEnabled: _sensitive == pit.sensitiveEnabled ? null : _sensitive,
      deleteClosedContent: _shallow,
    );
    // P-041：封面「最後選的贏」——從相簿選的（任何類型）換掉原本的封面；從坑內選圖則清掉相簿封面。
    if (_galleryCover != null) {
      await db.setPitCoverFile(pit.id, _galleryCover);
    } else if (_coverDirty || _coverId != pit.coverImageId) {
      await db.setCover(pit.id, _coverId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.pitsDeleteTitle),
        content: Text(ctx.l10n.pitsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.l10n.commonDelete,
              style: TextStyle(color: ctx.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(databaseProvider).deletePit(widget.pit.id);
    if (!mounted) return;
    // 回到主頁（越過坑內頁）。modal 在最上層 Navigator，交給 openPitEdit 處理。
    if (widget.asModal) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _pickGalleryCover() async {
    final file = await pickShallowCoverFile(context, ref);
    if (file != null && mounted) setState(() => _galleryCover = file);
  }

  void _pickCover() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CoverPickPage(pitId: widget.pit.id),
    ),
  );

  String? _validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.pitsNameRequired : null;

  Widget _coverSection(String? ownedCover) {
    final t = context.tokens;
    // 淺坑和現坑一樣：封面從坑內的圖挑（圖都留在坑裡，之後找得到、下載得了）。
    final coverFile = ownedCover;
    final pick = _pickCover;
    final Widget tile;
    if (coverFile == null) {
      // 有圖但還沒設封面：虛線正方框＋號，點了進選擇封面。
      tile = Semantics(
        button: true,
        label: context.l10n.pitsSelectCover,
        child: GestureDetector(
          onTap: pick,
          child: SizedBox(
            width: 110,
            height: 110,
            child: DashedBox(
              color: t.dashed,
              radius: Radii.card,
              child: Center(
                child: SvgIcon(
                  AppIcons.plus,
                  size: 26,
                  strokeWidth: 2,
                  color: t.dashedText,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      tile = Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: StoredImage(coverFile, cacheWidth: 330),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: pick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                context.l10n.pitsChangeCover,
                style: TextStyle(
                  color: t.text2,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PitFieldLabel(context.l10n.pitsFieldCover),
        Padding(padding: const EdgeInsets.only(bottom: 18), child: tile),
      ],
    );
  }

  /// 「刪除這個坑」外框按鈕（整頁與 modal 共用）。
  Widget _deleteButton() {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _delete,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border.all(
            color: dark
                ? t.danger.withValues(alpha: .5)
                : const Color(0xFFE7B9AE),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgIcon(AppIcons.trash, size: 20, color: t.danger),
            const SizedBox(width: 6),
            Text(
              context.l10n.pitsDeleteThis,
              style: TextStyle(
                color: t.danger,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- modal（≥840）----

  Widget _filterChip(String label, String? kind) {
    final t = context.tokens;
    final on = _coverKind == kind;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _coverKind = kind),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? t.ink : t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? t.surface : t.text2,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// modal 左欄：封面預覽、從坑內選圖（篩選＋4 欄候選）。
  Widget _coverPane() {
    final t = context.tokens;
    final l = context.l10n;
    final all =
        ref.watch(coverCandidatesProvider((widget.pit.id, null))).value ??
        const <CoverCandidate>[];
    final shown =
        ref.watch(coverCandidatesProvider((widget.pit.id, _coverKind))).value ??
        const <CoverCandidate>[];
    final currentFile = ref.watch(coverFileProvider(widget.pit.id)).value;
    CoverCandidate? picked;
    for (final c in all) {
      if (c.id == _coverId) picked = c;
    }
    final Widget preview;
    if (_galleryCover != null) {
      preview = StoredImage(_galleryCover!, cacheWidth: 600);
    } else if (picked != null) {
      preview = StaticMediaImage(
        MediaSource(
          file: picked.file,
          kind: picked.kind,
          durationMs: picked.durationMs,
          poster: picked.poster,
        ),
        cacheWidth: 600,
      );
    } else if (_coverId == widget.pit.coverImageId && currentFile != null) {
      preview = StoredImage(currentFile, cacheWidth: 600);
    } else {
      preview = ColoredBox(
        color: t.official.bg,
        child: Center(
          child: SvgIcon(
            AppIcons.image,
            size: 34,
            strokeWidth: 1.5,
            color: t.ink.withValues(alpha: .26),
          ),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PitFieldLabel(l.pitsFieldCover),
                SizedBox(
                  height: 190,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox.expand(child: preview),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          l.ipadpitPickFromPit,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // P-041：三種類型（坑、淺坑、封存）都可以從相簿選圖（PitEdit／PitEditShallow）。
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          key: const ValueKey('pitCoverFromAlbum'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _pickGalleryCover,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Center(
                              widthFactor: 1,
                              child: DashedBox(
                                color: t.dashed,
                                radius: 18,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    l.ipadpitPickFromAlbum,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: t.dashedText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(l.commonAll, null),
                      _filterChip(l.pitsOfficial, 'official'),
                      _filterChip(l.searchCategoryFan, 'fan'),
                      _filterChip(l.searchCategoryPiece, 'piece'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  l.albumCoverNone,
                  style: TextStyle(color: t.text3, fontSize: 14),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final c = shown[i];
                final on = _galleryCover == null && c.id == _coverId;
                return Semantics(
                  button: true,
                  selected: on,
                  label: l.albumSetCover,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _coverId = c.id;
                      _coverDirty = true;
                      _galleryCover = null;
                    }),
                    child: Container(
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.image),
                        border: on
                            ? Border.all(color: t.accent, width: 2.5)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.image),
                        child: StaticMediaImage(
                          MediaSource(
                            file: c.file,
                            kind: c.kind,
                            durationMs: c.durationMs,
                            poster: c.poster,
                          ),
                          cacheWidth: 300,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// modal 右欄：類型、坑名、描述、雜物開關（淺坑＝開啟的格子清單）、刪除。
  Widget _formPane() {
    final t = context.tokens;
    final l = context.l10n;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PitTypeSegment(value: _status, onChanged: _setStatus),
                PitFieldLabel(l.pitsFieldName),
                TextFormField(
                  key: const ValueKey('pit-name'),
                  controller: _name,
                  style: const TextStyle(fontSize: 15),
                  decoration: pitInputDecoration(context),
                  validator: _validateName,
                ),
                const SizedBox(height: 18),
                PitFieldLabel(l.pitsFieldDesc),
                TextFormField(
                  key: const ValueKey('pit-desc'),
                  controller: _desc,
                  minLines: 2,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 15, height: 1.55),
                  decoration: pitInputDecoration(context),
                ),
                const SizedBox(height: 18),
                if (_shallow)
                  PitSectionSwitchList(
                    enabled: _sections,
                    onChanged: _toggleSection,
                    sensitive: _showSensitive ? _sensitive : null,
                    onSensitiveChanged: _toggleSensitive,
                  )
                else
                  // 坑、封存＝「雜物」＋（總開關開了才有）「敏感內容」兩個開關（PitEdit）。
                  PitJunkSwitchCard(
                    value: _junk,
                    radius: 16,
                    onChanged: (v) => setState(() => _junk = v),
                    sensitive: _showSensitive ? _sensitive : null,
                    onSensitiveChanged: _toggleSensitive,
                  ),
                const SizedBox(height: 24),
                const Spacer(),
                _deleteButton(),
                const SizedBox(height: 8),
                Text(
                  l.pitsDeleteHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: t.text4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modal() {
    final t = context.tokens;
    return Form(
      key: _form,
      child: ModalFormFrame(
        title: context.l10n.pitsEditTitle,
        actionLabel: context.l10n.commonSave,
        onAction: _save,
        expandBody: true,
        child: LayoutBuilder(
          builder: (context, c) {
            // 稿：左 440、右吃剩餘；視窗被縮小時左欄跟著縮（不小於 320）。
            final left = (c.maxWidth * 440 / 860).clamp(320.0, 440.0);
            return Row(
              children: [
                Container(
                  width: left,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: t.border)),
                  ),
                  child: _coverPane(),
                ),
                Expanded(child: _formPane()),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asModal) return _modal();
    final t = context.tokens;
    final hasImages =
        (ref.watch(pitStatsProvider(widget.pit.id)).value?.imageCount ?? 0) > 0;
    final coverFile = ref.watch(coverFileProvider(widget.pit.id)).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PitHeader(title: context.l10n.pitsEditTitle),
            Expanded(
              child: Form(
                key: _form,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PitTypeSegment(
                              value: _status,
                              onChanged: _setStatus,
                            ),
                            if (hasImages) _coverSection(coverFile),
                            PitFieldLabel(context.l10n.pitsFieldName),
                            TextFormField(
                              key: const ValueKey('pit-name'),
                              controller: _name,
                              style: const TextStyle(fontSize: 15),
                              decoration: pitInputDecoration(context),
                              validator: _validateName,
                            ),
                            const SizedBox(height: 16),
                            PitFieldLabel(context.l10n.pitsFieldDesc),
                            TextFormField(
                              key: const ValueKey('pit-desc'),
                              controller: _desc,
                              minLines: 3,
                              maxLines: 6,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.55,
                              ),
                              decoration: pitInputDecoration(context),
                            ),
                            const SizedBox(height: 16),
                            if (_shallow)
                              PitSectionSwitchList(
                                enabled: _sections,
                                onChanged: _toggleSection,
                                sensitive: _showSensitive ? _sensitive : null,
                                onSensitiveChanged: _toggleSensitive,
                              )
                            else if (_status == PitStatus.active)
                              PitJunkSwitchCard(
                                value: _junk,
                                onChanged: (v) => setState(() => _junk = v),
                                sensitive: _showSensitive ? _sensitive : null,
                                onSensitiveChanged: _toggleSensitive,
                              )
                            else if (_showSensitive)
                              PitSensitiveCard(
                                value: _sensitive,
                                onChanged: _toggleSensitive,
                              ),
                            SizedBox(height: _shallow ? 0 : 22),
                            PitPrimaryButton(
                              label: context.l10n.commonSave,
                              onPressed: _save,
                            ),
                            const SizedBox(height: 28),
                            const Spacer(),
                            _deleteButton(),
                            const SizedBox(height: 10),
                            Text(
                              context.l10n.pitsDeleteHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: t.text4),
                            ),
                          ],
                        ),
                      ),
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
