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
    try {
      await _init();
      // 沒有帳號物件時（例如 App 重啟後）先靜默還原；還原不到再退回「不指定帳號」的授權請求。
      _account ??= await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      final client =
          _account?.authorizationClient ??
          GoogleSignIn.instance.authorizationClient;
      // 先靜默取；取不到（尚未授權或授權過期）就在前景補一次授權，不再直接判定失效。
      final authz =
          await client.authorizationForScopes([driveAppDataScope]) ??
          await client.authorizeScopes([driveAppDataScope]);
      return {
        'Authorization': 'Bearer ${authz.accessToken}',
        'X-Goog-AuthUser': '0',
      };
    } on GoogleSignInException catch (e) {
      throw SyncAuthException(
        '登入已失效，請重新連結 Google 帳號（${e.code.name}：${e.description ?? ''}）',
      );
    } catch (e) {
      throw SyncAuthException('登入已失效，請重新連結 Google 帳號（$e）');
    }
  }
}
