// 把 lib/l10n/fragments/*.arb 合併成 lib/l10n/app_zh.arb（gen_l10n 的範本檔）。
//
// 用法：dart run tool/merge_arb.dart && flutter gen-l10n
// 各區塊的字串寫在自己的 fragment（鍵名加區塊前綴），避免多人同時改同一個檔案。
// 鍵重複會直接報錯；`@key` 的 metadata 跟著對應的鍵走。
import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('lib/l10n/fragments');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final out = <String, Object?>{'@@locale': 'zh'};
  final owner = <String, String>{};
  for (final f in files) {
    final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    for (final e in map.entries) {
      if (e.key == '@@locale') continue;
      final base = e.key.startsWith('@') ? e.key.substring(1) : e.key;
      if (!e.key.startsWith('@')) {
        final prev = owner[base];
        if (prev != null) {
          stderr.writeln('重複的鍵 "$base"：$prev 與 ${f.path}');
          exit(1);
        }
        owner[base] = f.path;
      }
      out[e.key] = e.value;
    }
  }
  const enc = JsonEncoder.withIndent('  ');
  File('lib/l10n/app_zh.arb').writeAsStringSync('${enc.convert(out)}\n');
  stdout.writeln('合併 ${files.length} 個 fragment，${owner.length} 個字串。');
}
