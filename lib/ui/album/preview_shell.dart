import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/app_icons.dart';
import '../common/dismissible_preview.dart';
import '../common/svg_icon.dart';
import '../common/media_widgets.dart';
import '../common/sensitive_gate.dart';
import '../common/sensitive_safe_button.dart';

/// 預覽頁固定深色（ImagePreview／FanArtPreview 設計稿），不隨主題變化。
abstract final class PreviewPalette {
  static const bg = Color(0xFF1E1B18);
  static const text = Color(0xFFF5F0E8);
  static const muted = Color(0xFFA49A8C);
  static const action = Color(0xFFE9E2D8);
  static const danger = Color(0xFFF08A76);

  /// 官方分組小標底色。
  static const pill = Color(0xFFC9D6E3);

  /// 同人圖出處小標底色。
  static const pillFan = Color(0xFFE8C6CF);

  /// 同人圖 tag 底色（白 12%）。
  static const tagBg = Color(0x1FFFFFFF);
  static const tagText = Color(0xFFF2ECE4);
}

/// 「2026 / 09 / 21 加入」。
String previewDate(DateTime d, [AppLocalizations? l10n]) =>
    (l10n ?? l10nStatic).albumPreviewDateAdded(
      d.year,
      d.month.toString().padLeft(2, '0'),
      d.day.toString().padLeft(2, '0'),
    );

class PreviewAction {
  const PreviewAction(this.svg, this.label, this.onTap, {this.color});
  final String svg;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

/// 預覽頁骨架：返回＋標題＋頁碼、可左右滑動的圖、資訊區、底部動作列。
class PreviewShell extends StatelessWidget {
  const PreviewShell({
    super.key,
    required this.title,
    required this.counter,
    required this.controller,
    required this.media,
    required this.currentIndex,
    required this.onPageChanged,
    required this.info,
    required this.actions,
    this.headerTrailing,
  });

  final String title;
  final String counter;
  final PageController controller;

  /// 每一頁的媒體（圖片／GIF／影片，D-080）。
  final List<MediaSource> media;

  /// 目前顯示的頁；其他頁的影片會自動暫停、GIF 停止。
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final Widget info;
  final List<PreviewAction> actions;

  /// 頂欄頁碼前面的額外按鈕（例如「參考檢視」入口）；null＝和原來一樣。
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    // 套用共用的預覽手勢（見 dismissible_preview.dart）：點一下圖片收起／叫出 UI、
    // 垂直拖曳（或第一張往右／最後一張往左的水平拖曳）退出。
    return DismissiblePreview(
      background: PreviewPalette.bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PreviewChrome(child: _header(context)),
              Expanded(
                child: PreviewMediaArea(
                  pageController: controller,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: PreviewPageView(
                      controller: controller,
                      itemCount: media.length,
                      onPageChanged: onPageChanged,
                      // 圖片與 GIF 可縮放；影片用自己的控制列（同詳情頁），不縮放。
                      // 安全模式開時已標記的圖也模糊＋52px 圓（D-110）；關閉就是正常的圖（不加小標）。
                      itemBuilder: (_, i) {
                        final viewer = MediaViewer(
                          media[i],
                          active: i == currentIndex,
                          zoomable: true,
                        );
                        if (media[i].isVideo) return viewer;
                        return SensitiveGate(
                          file: media[i].file,
                          circleSize: 52,
                          showBadge: false,
                          child: viewer,
                        );
                      },
                    ),
                  ),
                ),
              ),
              PreviewChrome(child: info),
              PreviewChrome(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
                  ),
                  child: Row(
                    children: [for (final a in actions) _ActionButton(a)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.commonBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const SvgIcon(
              AppIcons.back,
              color: PreviewPalette.text,
              strokeWidth: 1.9,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PreviewPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (headerTrailing != null) ...[
            headerTrailing!,
            const SizedBox(width: 8),
          ],
          SensitiveSafeButton(
            files: [
              for (final m in media)
                if (!m.isVideo) m.file,
            ],
            color: PreviewPalette.text,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              counter,
              style: const TextStyle(color: PreviewPalette.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action);
  final PreviewAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.color ?? PreviewPalette.action;
    return Expanded(
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(action.svg, size: 22, color: color, strokeWidth: 1.7),
              const SizedBox(height: 5),
              Text(action.label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
