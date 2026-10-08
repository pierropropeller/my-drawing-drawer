import 'package:flutter/material.dart';

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
const reviewMonthFormats = ['Jan', 'January', '一月', '1月', '01'];

double ratioValue(String r) {
  final p = r.split(':');
  return double.parse(p[0]) / double.parse(p[1]);
}

String monthLabel(int m, String format) {
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
  const long = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const zh = [
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ];
  return switch (format) {
    'January' => long[m - 1],
    '一月' => zh[m - 1],
    '1月' => '$m月',
    '01' => m.toString().padLeft(2, '0'),
    _ => short[m - 1],
  };
}

/// 年度回顧畫布。預覽與匯出圖片共用同一個 widget。
/// [onImage] 為 true：圖上排版，12 格直角貼合，月份白字加陰影；
/// 否則為空白位置排版：格之間有 padding，白底黑字。
class ReviewCanvas extends StatelessWidget {
  const ReviewCanvas({
    super.key,
    required this.files,
    required this.columns,
    required this.ratio,
    required this.monthFormat,
    required this.monthOnImage,
    this.onTapMonth,
    this.compact = false,
  });

  final Map<int, String?> files; // 月 → 檔名
  final int columns;
  final String ratio;
  final String monthFormat;
  final bool monthOnImage;
  final void Function(int month)? onTapMonth;

  /// 縮小預覽（年度頁的 4×3 預覽不顯示月份文字）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final aspect = ratioValue(ratio);
    final pad = monthOnImage ? 0.0 : 8.0;
    final rows = 12 ~/ columns;
    return Container(
      color: monthOnImage ? Colors.black12 : Colors.white,
      padding: EdgeInsets.all(pad),
      child: LayoutBuilder(
        builder: (context, c) {
          final cellW = (c.maxWidth - pad * (columns - 1)) / columns;
          final cellH = cellW / aspect;
          return Column(
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : pad),
                  child: Row(
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col > 0) SizedBox(width: pad),
                        _Cell(
                          width: cellW,
                          height: cellH,
                          month: r * columns + col + 1,
                          file: files[r * columns + col + 1],
                          label: compact
                              ? null
                              : monthLabel(r * columns + col + 1, monthFormat),
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
    required this.onImage,
    required this.placeholder,
    required this.onTap,
  });

  final double width;
  final double height;
  final int month;
  final String? file;
  final String? label;
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
    Widget cell;
    if (onImage) {
      cell = Stack(
        children: [
          image,
          if (label != null)
            Positioned(
              left: 6,
              bottom: 4,
              child: Text(
                label!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (width / 6).clamp(9, 22),
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
            ),
        ],
      );
    } else {
      cell = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                label!,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: (width / 6).clamp(9, 22),
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
