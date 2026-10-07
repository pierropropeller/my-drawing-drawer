import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';

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
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: t.piece.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.collections_bookmark,
                    size: 44,
                    color: t.piece.fg,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '畫坑',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ConnectPage()),
                ),
                child: const Text('用 Google 帳號開始'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(settingsProvider.notifier).setOnboarded(true),
                child: const Text('離線繼續，暫不同步'),
              ),
            ],
          ),
        ),
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
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('連結 Google 帳號')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: t.borderCard),
              ),
              child: Row(
                children: [
                  Icon(
                    _email == null
                        ? Icons.account_circle_outlined
                        : Icons.check_circle,
                    color: _email == null ? t.text3 : t.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _email ?? '尚未選擇帳號',
                      style: TextStyle(color: _email == null ? t.text3 : t.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _pick,
              child: Text(_email == null ? '選擇 Google 帳號' : '使用另一個帳號'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _email == null ? null : _start,
              child: const Text('連結並開始'),
            ),
            TextButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setOnboarded(true);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('離線繼續，暫不同步'),
            ),
          ],
        ),
      ),
    );
  }
}
