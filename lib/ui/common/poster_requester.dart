import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// 影片截圖（poster）的即時來源（D-080）。
///
/// - [poster] 有值：直接交給 [builder]。
/// - [poster] 是 null（還沒產生）：請 `PosterFixer` 背景補（限流，同一支影片失敗有冷卻與次數上限），
///   補好之後（`healedPosterProvider`）自動換成新的 poster，列表／詳情頁不必重開。
class LivePoster extends ConsumerStatefulWidget {
  const LivePoster({
    super.key,
    required this.file,
    required this.poster,
    required this.builder,
  });

  /// 影片檔名。
  final String file;
  final String? poster;
  final Widget Function(BuildContext context, String? poster) builder;

  @override
  ConsumerState<LivePoster> createState() => _LivePosterState();
}

class _LivePosterState extends ConsumerState<LivePoster> {
  @override
  void initState() {
    super.initState();
    _requestIfMissing();
  }

  @override
  void didUpdateWidget(LivePoster old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file || old.poster != widget.poster) {
      _requestIfMissing();
    }
  }

  bool get _missing => widget.poster == null || widget.poster!.isEmpty;

  void _requestIfMissing() {
    if (!_missing) return;
    final file = widget.file;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_missing) return;
      ref.read(posterRequestProvider)(file);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_missing) return widget.builder(context, widget.poster);
    final healed = ref.watch(healedPosterProvider(widget.file)).value;
    return widget.builder(context, healed);
  }
}
