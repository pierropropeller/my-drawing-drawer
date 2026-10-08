import '../../app_name.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import '../pits/pit_form.dart';
import 'sync_first_page.dart';

/// 開頭畫面：用 Google 帳號開始（Drive 同步），或離線繼續。
/// 沒有自家帳號系統；Google 帳號只用於 Drive 同步。
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: t.piece.bg,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: t.accent.withValues(alpha: .22),
                            offset: const Offset(0, 10),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgIcon(
                          AppIcons.pencilDot,
                          size: 48,
                          strokeWidth: 1.6,
                          color: t.piece.fg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      appName,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 34, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '（暫定名稱，可更改）',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .5,
                        color: t.text4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '一個坑一個坑，\n收藏你的同人宇宙',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: t.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DarkButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ConnectPage(),
                        ),
                      ),
                      leading: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.ground,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'G',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                        ),
                      ),
                      label: '用 Google 帳號開始',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => ref
                          .read(settingsProvider.notifier)
                          .setOnboarded(true),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: fieldBorderColor(context),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(Radii.button),
                        ),
                        child: Text(
                          '離線使用，暫不同步',
                          style: TextStyle(
                            color: t.text2,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 深色（ink 底）滿版按鈕；[onTap] 為 null 時變成灰色停用。
class _DarkButton extends StatelessWidget {
  const _DarkButton({required this.label, this.onTap, this.leading});
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.ground,
        // 停用色為設計稿的 #E7DFD4／#B3A898（沒有對應 token）。
        disabledBackgroundColor: dark ? t.chipBg : const Color(0xFFE7DFD4),
        disabledForegroundColor: dark ? t.text4 : const Color(0xFFB3A898),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Text(label),
        ],
      ),
    );
  }
}

/// 連結 Google 帳號：未連結時「連結並開始」不可按；連結後可開始。
class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  String? _email;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final email = await ref.read(accountServiceProvider).signIn();
      if (mounted) setState(() => _email = email);
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _start() {
    final n = ref.read(settingsProvider.notifier);
    n.setAccount(_email);
    n.setOnboarded(true);
    // 首次連結：進「首次同步中」頁（可按「先開始使用」離開，同步在背景繼續）。
    SyncFirstPage.open(context, ref, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final email = _email;
    final nickname = ref.watch(settingsProvider.select((s) => s.nickname));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: '返回',
                  child: InkResponse(
                    onTap: () => Navigator.of(context).maybePop(),
                    radius: 24,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SvgIcon(
                          AppIcons.back,
                          strokeWidth: 1.9,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const _Illustration(),
                    const SizedBox(height: 26),
                    Text(
                      '連結 Google 帳號',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '連結後，跨設備自動同步',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: t.text2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (email == null)
                      _AddAccountRow(busy: _busy, onTap: _pick)
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: t.surface,
                          border: Border.all(color: t.borderCard),
                          borderRadius: BorderRadius.circular(Radii.card),
                        ),
                        child: Column(
                          children: [
                            _AccountRow(
                              email: email,
                              name: nickname.isEmpty
                                  ? email.split('@').first
                                  : nickname,
                              dividerColor: dark
                                  ? t.border
                                  : const Color(0xFFF1EADF),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _busy ? null : _pick,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: DashedBox(
                                        color: t.dashed,
                                        radius: 20,
                                        child: Center(
                                          child: SvgIcon(
                                            AppIcons.plus,
                                            size: 18,
                                            strokeWidth: 1.9,
                                            color: t.dashedText,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '用另一個帳號',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          color: t.text2,
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DarkButton(
                    label: '連結並開始',
                    onTap: email == null ? null : _start,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ref.read(settingsProvider.notifier).setOnboarded(true);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        '離線繼續，暫不同步',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: t.text3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手機 ⇄ 雲 ⇄ 電腦 的插圖。
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget box(double w, double h, String icon, double size, Color color) =>
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.dashed, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: SvgIcon(icon, size: size, strokeWidth: 1.5, color: color),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        box(66, 104, AppIcons.deviceSmall, 26, t.fanArt.fg),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              AppIcons.cloudSync,
              size: 40,
              strokeWidth: 1.5,
              color: t.piece.fg,
            ),
            const SizedBox(height: 4),
            SvgIcon(
              AppIcons.codeArrows,
              size: 18,
              strokeWidth: 2,
              color: t.piece.fg,
            ),
          ],
        ),
        const SizedBox(width: 14),
        box(84, 110, AppIcons.deviceLarge, 30, t.official.fg),
      ],
    );
  }
}

/// 未連結（ConnectEmpty）：虛線「加 Google 帳號」列。
class _AddAccountRow extends StatelessWidget {
  const _AddAccountRow({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: DashedBox(
        color: t.dashed,
        radius: Radii.card,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dark ? t.chipBg : const Color(0xFFF1E8DC),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgIcon(
                  AppIcons.plus,
                  size: 20,
                  strokeWidth: 1.9,
                  color: t.dashedText,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加 Google 帳號',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '未連結任何帳號',
                    style: TextStyle(fontSize: 12, color: t.text3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已選帳號列：頭像字、名稱、email、主色勾。
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.email,
    required this.name,
    required this.dividerColor,
  });
  final String email;
  final String name;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.piece.bg,
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isEmpty ? '畫' : name.characters.first.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.piece.fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.text3),
                ),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: const Center(
              child: SvgIcon(
                AppIcons.check,
                size: 14,
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
