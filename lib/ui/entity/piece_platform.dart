import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import 'piece_icons.dart';

/// 社交平台（D-035）。儲存在資料庫的 `platform` 字串就是 [PieceSocialPlatform.label]。
enum PieceSocialPlatform {
  twitter('推特', 'X', Color(0xFFE7ECF2), Color(0xFF2B2622)),
  xiaohongshu('小紅書', '紅', Color(0xFFF6E7EA), Color(0xFFB23A4C)),
  lofter('Lofter', 'Lo', Color(0xFFEAF0F5), Color(0xFF4A7A9A)),
  pixiv('Pixiv', 'Px', Color(0xFFE3EEF9), Color(0xFF2F6DAA)),
  weibo('微博', '微', Color(0xFFFBE7E0), Color(0xFFC25436)),
  instagram('Instagram', 'IG', Color(0xFFF1E6F0), Color(0xFF9A4F8E)),

  /// 網址判斷不出來：顯示鎖鏈 icon（PieceNewLink 版）。
  other('其他', '', Color(0xFFE7ECF2), Color(0xFF5B7A99));

  const PieceSocialPlatform(this.label, this.mark, this.bg, this.fg);
  final String label;
  final String mark;
  final Color bg;
  final Color fg;

  /// 詳情頁的顯示名稱（設計稿 PieceDetail：推特（Twitter/X））。
  String get displayName =>
      this == twitter ? '推特（Twitter/X）' : (this == other ? '連結' : label);

  /// 由儲存的平台字串還原；認不得的字串＝[other]。
  static PieceSocialPlatform fromLabel(String s) {
    final p = s.toLowerCase();
    if (p.contains('推特') || p.contains('twitter') || p == 'x') return twitter;
    if (p.contains('小紅書') || p.contains('xiaohongshu')) return xiaohongshu;
    if (p.contains('lofter')) return lofter;
    if (p.contains('pixiv')) return pixiv;
    if (p.contains('微博') || p.contains('weibo')) return weibo;
    if (p.contains('instagram') || p == 'ig') return instagram;
    return other;
  }
}

/// 由貼上的網址自動判斷平台；判斷不出來回傳 [PieceSocialPlatform.other]。
PieceSocialPlatform detectSocialPlatform(String url) {
  final host = socialHostOf(url).toLowerCase();
  bool on(String d) => host == d || host.endsWith('.$d');
  if (on('x.com') || on('twitter.com') || on('t.co')) {
    return PieceSocialPlatform.twitter;
  }
  if (on('xiaohongshu.com') || on('xhslink.com')) {
    return PieceSocialPlatform.xiaohongshu;
  }
  if (on('lofter.com')) return PieceSocialPlatform.lofter;
  if (on('pixiv.net') || on('pixiv.me')) return PieceSocialPlatform.pixiv;
  if (on('weibo.com') || on('weibo.cn')) return PieceSocialPlatform.weibo;
  if (on('instagram.com') || on('instagr.am')) {
    return PieceSocialPlatform.instagram;
  }
  return PieceSocialPlatform.other;
}

/// 網址的主機名稱（去掉 www.）；解析不了回傳空字串。
String socialHostOf(String url) {
  var s = url.trim();
  if (s.isEmpty) return '';
  if (!s.contains('://')) s = 'https://$s';
  final h = Uri.tryParse(s)?.host ?? '';
  return h.startsWith('www.') ? h.substring(4) : h;
}

/// 平台徽章：圓角方塊，平台簡寫（或鎖鏈 icon）。表單 26／詳情 30。
class SocialPlatformBadge extends StatelessWidget {
  const SocialPlatformBadge(
    this.platform, {
    super.key,
    this.size = 26,
    this.radius = 7,
    this.fontSize = 12,
  });
  final PieceSocialPlatform platform;
  final double size;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? t.text2 : platform.fg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? t.chipBg : platform.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: platform == PieceSocialPlatform.other
          ? SvgIcon(PieceIcons.link, size: 15, strokeWidth: 2, color: fg)
          : Text(
              platform.mark,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
    );
  }
}
