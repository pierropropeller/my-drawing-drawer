import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/window_class.dart';

void main() {
  test('斷點 0／600／840／1200', () {
    expect(WindowClass.forWidth(390), WindowClass.compact);
    expect(WindowClass.forWidth(599.9), WindowClass.compact);
    expect(WindowClass.forWidth(600), WindowClass.medium);
    expect(WindowClass.forWidth(834), WindowClass.medium);
    expect(WindowClass.forWidth(840), WindowClass.expanded);
    expect(WindowClass.forWidth(1199), WindowClass.expanded);
    expect(WindowClass.forWidth(1200), WindowClass.large);
    expect(WindowClass.compact.hasSideNav, isFalse);
    expect(WindowClass.medium.hasSideNav, isTrue);
    expect(WindowClass.medium.isWide, isFalse);
    expect(WindowClass.expanded.isWide, isTrue);
  });

  test('欄數 max(2, floor(闊÷180))，RespSpec 例：700→3、1000 扣預覽面板→3', () {
    expect(gridColumnsFor(400), 2);
    expect(gridColumnsFor(700), 3);
    expect(gridColumnsFor(1000 - 84 - 300), 3);
    expect(gridColumnsFor(100), 2);
  });

  test('面板闊度夾在範圍內', () {
    expect(panelWidthFor(1000), inInclusiveRange(300, 340));
    expect(panelWidthFor(1366, min: 340, max: 380), inInclusiveRange(340, 380));
  });
}
