import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../common/adaptive_modal.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/dashed_box.dart';
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'pit_form.dart';

/// 編輯坑的單一入口：視窗 ≥840 開置中 modal（PitEdit，860×690，縮到不超出視窗），
/// 較窄開整頁（手機版）。刪除坑後會回到主頁（越過坑內頁）。
Future<void> openPitEdit(BuildContext context, Pit pit) async {
  final deleted = await showAdaptiveModal<bool>(
    context,
    width: 860,
    height: 690,
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
  late bool _archived = widget.pit.archived;
  late bool _junk = widget.pit.junkEnabled;

  // modal 的封面選擇：選了先暫存，按「儲存」才寫入（取消不動）。
  late String? _coverId = widget.pit.coverImageId;
  String? _coverKind; // 候選篩選：null＝全部，official／fan／piece

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
    await db.updatePit(
      widget.pit.id,
      name: _name.text.trim(),
      description: desc.isEmpty ? null : desc,
      archived: _archived,
      junkEnabled: _junk,
    );
    if (_coverId != widget.pit.coverImageId) {
      await db.setCover(widget.pit.id, _coverId);
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

  void _pickCover() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CoverPickPage(pitId: widget.pit.id),
    ),
  );

  String? _validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.pitsNameRequired : null;

  Widget _coverSection(String? coverFile) {
    final t = context.tokens;
    final Widget tile;
    if (coverFile == null) {
      // 有圖但還沒設封面：虛線正方框＋號，點了進選擇封面。
      tile = Semantics(
        button: true,
        label: context.l10n.pitsSelectCover,
        child: GestureDetector(
          onTap: _pickCover,
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
            onTap: _pickCover,
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
    if (picked != null) {
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
                  child: Text(
                    l.ipadpitPickFromPit,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
                final on = c.id == _coverId;
                return Semantics(
                  button: true,
                  selected: on,
                  label: l.albumSetCover,
                  child: GestureDetector(
                    onTap: () => setState(() => _coverId = c.id),
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

  /// modal 右欄：坑名、描述、雜物開關（＋封存：稿沒畫，功能保留）、刪除。
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
                PitFieldLabel(l.pitsFieldName),
                TextFormField(
                  controller: _name,
                  style: const TextStyle(fontSize: 15),
                  decoration: pitInputDecoration(context),
                  validator: _validateName,
                ),
                const SizedBox(height: 18),
                PitFieldLabel(l.pitsFieldDesc),
                TextFormField(
                  controller: _desc,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 15, height: 1.55),
                  decoration: pitInputDecoration(context),
                ),
                const SizedBox(height: 18),
                _SwitchCard(
                  label: l.junkTitle,
                  subtitle: l.ipadpitJunkHint,
                  value: _junk,
                  onChanged: (v) => setState(() => _junk = v),
                ),
                const SizedBox(height: 10),
                _SwitchCard(
                  label: l.pitsArchive,
                  value: _archived,
                  onChanged: (v) => setState(() => _archived = v),
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
                            if (hasImages) _coverSection(coverFile),
                            PitFieldLabel(context.l10n.pitsFieldName),
                            TextFormField(
                              controller: _name,
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
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.55,
                              ),
                              decoration: pitInputDecoration(context),
                            ),
                            const SizedBox(height: 16),
                            _SwitchCard(
                              label: context.l10n.junkTitle,
                              value: _junk,
                              onChanged: (v) => setState(() => _junk = v),
                            ),
                            // 設計稿沒有封存欄位；封存功能保留，樣式比照雜物開關。
                            const SizedBox(height: 10),
                            _SwitchCard(
                              label: context.l10n.pitsArchive,
                              value: _archived,
                              onChanged: (v) => setState(() => _archived = v),
                            ),
                            const SizedBox(height: 22),
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

/// 白底圓角卡片＋右側開關（PitEdit 的「雜物」）。
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: t.text4),
                    ),
                  ),
              ],
            ),
          ),
          AppSwitch(semanticLabel: label, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
