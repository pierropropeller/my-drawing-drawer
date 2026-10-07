import 'package:google_sign_in/google_sign_in.dart';

import 'remote.dart';

/// Drive 的「App 專用資料夾」scope（使用者在 Drive 裡看不到這些檔案）。
const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

/// Web 類型的 OAuth Client ID，Android 用 Credential Manager 登入時需要。
/// 透過 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` 帶入（CI 由 GitHub secret 提供）。
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 帳號服務介面：方便測試時替換。
abstract class AccountService {
  /// 開啟 Google 登入並授權 Drive 專用資料夾，回傳帳號 email。
  Future<String> signIn();

  /// 靜默還原先前登入的帳號；沒有則回傳 null。
  Future<String?> restore();
  Future<void> signOut();
  Future<Map<String, String>> headers();
}

class GoogleAccountService implements AccountService {
  bool _initialized = false;
  GoogleSignInAccount? _account;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId.isEmpty
          ? null
          : googleServerClientId,
    );
    _initialized = true;
  }

  @override
  Future<String> signIn() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: [driveAppDataScope],
      );
      await account.authorizationClient.authorizeScopes([driveAppDataScope]);
      _account = account;
      return account.email;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('已取消');
      }
      throw AuthFailure('連結失敗：${e.description ?? e.code.name}');
    } catch (e) {
      throw AuthFailure('連結失敗：$e');
    }
  }

  @override
  Future<String?> restore() async {
    try {
      await _init();
      final a = await GoogleSignIn.instance.attemptLightweightAuthentication();
      _account = a;
      return a?.email;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _account = null;
  }

  @override
  Future<Map<String, String>> headers() async {
    final a =
        _account ??
        await (() async {
          await _init();
          return GoogleSignIn.instance.attemptLightweightAuthentication();
        })();
    _account = a;
    if (a == null) throw const SyncAuthException();
    final h = await a.authorizationClient.authorizationHeaders([
      driveAppDataScope,
    ], promptIfNecessary: false);
    if (h == null) throw const SyncAuthException();
    return h;
  }
}
