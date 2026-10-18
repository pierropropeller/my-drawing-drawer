import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 列表／卡片裡的多行內文（描述、內文、備註）：最多顯示 [maxLines] 行，被截斷時最後一個
/// 看得見的字後面一定接「…」。
///
/// 為什麼不用 `Text(maxLines, overflow: ellipsis)`：文字是在**硬換行**（`\n`）處被截掉時
/// （例如三行文字只顯示兩行），Flutter 不會畫省略號。這裡用 [TextPainter] 量出可見的前綴再接上「…」，
/// 軟換行（太長自動折行）、CJK、emoji 都能處理；放得下就是原文。
///
/// 自己是 RenderBox（不是 LayoutBuilder），所以可以放進 `IntrinsicHeight`（時間軸的列就是）。
class ClampedText extends StatelessWidget {
  const ClampedText(
    this.text, {
    super.key,
    required this.maxLines,
    this.style,
    this.textAlign,
  }) : assert(maxLines > 0);

  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: ClampedParagraph(
        text: text,
        maxLines: maxLines,
        style: DefaultTextStyle.of(context).style.merge(style),
        textAlign: textAlign ?? TextAlign.start,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }
}

class ClampedParagraph extends LeafRenderObjectWidget {
  const ClampedParagraph({
    super.key,
    required this.text,
    required this.maxLines,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.textScaler,
  });

  final String text;
  final int maxLines;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderClampedText()..configure(
        text: text,
        maxLines: maxLines,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        textScaler: textScaler,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderClampedText renderObject,
  ) {
    renderObject.configure(
      text: text,
      maxLines: maxLines,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
    );
  }
}

class RenderClampedText extends RenderBox {
  String _text = '';
  int _maxLines = 1;
  TextStyle _style = const TextStyle();
  TextAlign _textAlign = TextAlign.start;
  TextDirection _textDirection = TextDirection.ltr;
  TextScaler _textScaler = TextScaler.noScaling;

  TextPainter? _painter;

  /// 實際畫出來的字串（含「…」）；給測試與除錯用。
  String get shownText => _painter?.text?.toPlainText() ?? '';
  double? _paintedWidth;

  void configure({
    required String text,
    required int maxLines,
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (_text == text &&
        _maxLines == maxLines &&
        _style == style &&
        _textAlign == textAlign &&
        _textDirection == textDirection &&
        _textScaler == textScaler) {
      return;
    }
    _text = text;
    _maxLines = maxLines;
    _style = style;
    _textAlign = textAlign;
    _textDirection = textDirection;
    _textScaler = textScaler;
    _painter?.dispose();
    _painter = null;
    markNeedsLayout();
  }

  TextPainter _layoutFor(double width) {
    final shown = width.isFinite
        ? (clampTextToLines(
                _text,
                style: _style,
                maxWidth: width,
                maxLines: _maxLines,
                textDirection: _textDirection,
                textScaler: _textScaler,
                textAlign: _textAlign,
              ) ??
              _text)
        : _text.trimRight();
    return TextPainter(
      text: TextSpan(text: shown, style: _style),
      textDirection: _textDirection,
      textScaler: _textScaler,
      textAlign: _textAlign,
      maxLines: _maxLines,
    )..layout(maxWidth: width);
  }

  double _heightFor(double width) {
    final p = _layoutFor(width);
    final h = p.height;
    p.dispose();
    return h;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final p = TextPainter(
      text: TextSpan(text: _text.trimRight(), style: _style),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: _maxLines,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    final p = _painter;
    if (p == null) return 0;
    return p.computeDistanceToActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final p = _layoutFor(constraints.maxWidth);
    final size = constraints.constrain(Size(p.width, p.height));
    p.dispose();
    return size;
  }

  @override
  void performLayout() {
    _painter?.dispose();
    final p = _layoutFor(constraints.maxWidth);
    _painter = p;
    _paintedWidth = constraints.maxWidth;
    // Text 在 Column 等有限寬度下是撐滿寬度（textWidthBasis: parent），這裡一致。
    final w = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : math.max(p.width, constraints.minWidth);
    size = constraints.constrain(Size(w, p.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final p = _painter;
    if (p == null) return;
    // 佈局時的寬度與目前一致才畫（避免 dry layout 之後殘留舊的）。
    if (_paintedWidth != constraints.maxWidth) return;
    p.paint(context.canvas, offset);
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }
}

const _ellipsis = '…';

bool _isBlank(String s) => s.trim().isEmpty;

/// 在 [maxWidth] 寬、最多 [maxLines] 行下，回傳「要顯示的字串」。
///
/// - 放得下：回傳去掉結尾空白後的 [text]（沒有省略號）。
/// - 放不下：回傳可見的前綴（去掉結尾的換行／空白）＋「…」，保證前綴＋「…」本身也塞得進 [maxLines] 行。
///   例：`a\nb\n\nc`、maxLines 2 → `a\nb…`。
/// - [text] 去掉結尾空白後為空：回傳空字串。
///
/// 傳回 null 代表量不出來（呼叫端直接用原字串）。
String? clampTextToLines(
  String text, {
  required TextStyle style,
  required double maxWidth,
  required int maxLines,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  TextAlign textAlign = TextAlign.start,
}) {
  final full = text.trimRight();
  if (full.isEmpty) return '';
  if (!maxWidth.isFinite || maxWidth <= 0) return null;

  TextPainter layout(String s, {required int lines}) {
    return TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      textAlign: textAlign,
      maxLines: lines,
    )..layout(maxWidth: maxWidth);
  }

  final painter = layout(full, lines: maxLines);
  try {
    if (!painter.didExceedMaxLines) return full;

    // 最後一個可見行的行尾位置。
    final metrics = painter.computeLineMetrics();
    var end = 0;
    if (metrics.isNotEmpty) {
      final last = metrics.last;
      final midY = last.baseline - last.ascent + last.height / 2;
      final pos = painter.getPositionForOffset(Offset(0, midY));
      end = painter.getLineBoundary(pos).end.clamp(0, full.length);
    }
    var prefix = full.substring(0, end).trimRight();
    if (prefix.isEmpty) return _ellipsis;

    // 加上「…」後可能多折一行或超寬，逐個字（grapheme）往回縮到塞得進為止。
    var chars = prefix.characters;
    for (var i = 0; i < 400; i++) {
      final candidate = '$prefix$_ellipsis';
      final p = layout(candidate, lines: maxLines);
      final exceeded = p.didExceedMaxLines;
      p.dispose();
      if (!exceeded) return candidate;
      if (chars.isEmpty) break;
      chars = chars.skipLast(1);
      prefix = chars.toString().trimRight();
      if (_isBlank(prefix)) return _ellipsis;
    }
    return '$prefix$_ellipsis';
  } finally {
    painter.dispose();
  }
}
