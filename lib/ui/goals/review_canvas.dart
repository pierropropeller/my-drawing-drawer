import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../album/album_image.dart';
import '../../theme/tokens.dart';

/// 年度回顧可選的版面設定（HANDOFF 3.9）。
// (欄數, 標籤)：標籤是「列 × 欄」，與設計稿 ReviewEdit 一致（預設 4 欄＝3 × 4）。
const reviewColumnOptions = [
  (12, '1 × 12'),
  (6, '2 × 6'),
  (4, '3 × 4'),
  (3, '4 × 3'),
  (2, '6 × 2'),
];
const reviewRatioOptions = ['1:1', '4:3', '3:4', '9:16', '16:9', '2:1', '1:2'];
// 月份格式的識別值（會存進資料庫，不可翻譯）；畫面上的選項文字見 [monthFormatOptionLabel]。
const reviewMonthFormats = ['Jan', 'January', '一月', '1月', '01'];

double ratioValue(String r) {
  final p = r.split(':');
  return double.parse(p[0]) / double.parse(p[1]);
}

/// 月份格式選項在畫面上的文字（識別值不變，中文選項走 ARB）。
String monthFormatOptionLabel(AppLocalizations l, String format) =>
    switch (format) {
      '一月' => l.goalsMonthFormatCn,
      '1月' => l.goalsMonthFormatNum,
      _ => format,
    };

String monthLabel(int m, String format, AppLocalizations l) {
  const short = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  // 設計稿：「January」選項顯示英文縮寫加句點（5 月不加）。
  const long = [
    'Jan.',
    'Feb.',
    'Mar.',
    'Apr.',
    'May',
    'Jun.',
    'Jul.',
    'Aug.',
    'Sep.',
    'Oct.',
    'Nov.',
    'Dec.',
  ];
  return switch (format) {
    'January' => long[m - 1],
    '一月' => l.goalsMonthCn(m.toString()),
    '1月' => l.goalsMonthNum(m),
    '01' => m.toString().padLeft(2, '0'),
    _ => short[m - 1],
  };
}

/// 月份對齊（`start`／`center`／`end`）對應的水平對齊與文字對齊。
Alignment monthAlignment(String align) => switch (align) {
  'center' => Alignment.center,
  'end' => Alignment.centerRight,
  _ => Alignment.centerLeft,
};

/// 年度回顧畫布。預覽與匯出圖片共用同一個 widget。
/// 最外層是白色邊框（[margin]，代表匯出圖片的留白，無圓角）。
/// [monthOnImage] 為 true：圖上排版，12 格直角貼合，月份白字加陰影；
/// 否則為空白位置排版：格之間有 6px 間距，白底黑字。月份文字依 [monthAlign] 對齊（D-039）。
class ReviewCanvas extends StatelessWidget {
  const ReviewCanvas({
    super.key,
    required this.files,
    required this.columns,
    required this.ratio,
    required this.monthFormat,
    required this.monthOnImage,
    this.monthAlign = 'start',
    this.onTapMonth,
    this.margin = 12,
  });

  final Map<int, String?> files; // 月 → 檔名
  final int columns;
  final String ratio;
  final String monthFormat;
  final bool monthOnImage;
  final String monthAlign;
  final void Function(int month)? onTapMonth;

  /// 外圍白色留白（匯出圖片的邊）。
  final double margin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final aspect = ratioValue(ratio);
    final gap = monthOnImage ? 0.0 : 6.0;
    final rows = 12 ~/ columns;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(margin),
      child: LayoutBuilder(
        builder: (context, c) {
          final cellW = (c.maxWidth - gap * (columns - 1)) / columns;
          final cellH = cellW / aspect;
          return Column(
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
                  child: Row(
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col > 0) SizedBox(width: gap),
                        _Cell(
                          width: cellW,
                          height: cellH,
                          month: r * columns + col + 1,
                          file: files[r * columns + col + 1],
                          label: monthLabel(
                            r * columns + col + 1,
                            monthFormat,
                            context.l10n,
                          ),
                          align: monthAlign,
                          onImage: monthOnImage,
                          placeholder: t.chipBg,
                          onTap: onTapMonth,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.width,
    required this.height,
    required this.month,
    required this.file,
    required this.label,
    required this.align,
    required this.onImage,
    required this.placeholder,
    required this.onTap,
  });

  final double width;
  final double height;
  final int month;
  final String? file;
  final String label;
  final String align;
  final bool onImage;
  final Color placeholder;
  final void Function(int month)? onTap;

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: width,
      height: height,
      child: file == null
          ? ColoredBox(color: placeholder)
          : StoredImage(file!, cacheWidth: 600),
    );
    // 太窄放不下的月份名（例如 12 欄的 September）縮小而不是截掉。
    Widget text(TextStyle style) => SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: monthAlignment(align),
        child: Text(label, maxLines: 1, style: style),
      ),
    );
    Widget cell;
    if (onImage) {
      cell = Stack(
        children: [
          image,
          Positioned(
            left: 3,
            right: 3,
            bottom: 2,
            child: text(
              const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    color: Color(0x8C000000),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      cell = Column(
        children: [
          image,
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(2),
            child: text(
              const TextStyle(
                color: Color(0xFF2B2622),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap!(month),
        child: cell,
      ),
    );
  }
}
