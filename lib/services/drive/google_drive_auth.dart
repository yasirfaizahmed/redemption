import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:logging/logging.dart';

import 'drive_client.dart';

final _log = Logger('GoogleDriveAuth');

/// Thrown when connecting to Google fails for a reason worth showing.
class DriveConnectException implements Exception {
  DriveConnectException(this.message, {this.canceled = false});
  final String message;
  final bool canceled;
  @override
  String toString() => message;
}

/// Google could not be asked for a token right now (offline, Play services
/// busy). Unlike a missing grant, this needs no reconnect — just a retry.
class DriveAuthUnavailableException implements Exception {
  DriveAuthUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Grants and refreshes access to the `drive.appdata` scope.
abstract interface class DriveAuth implements AccessTokenProvider {
  /// Whether Google Drive backup can work on this platform/build.
  bool get isSupported;

  /// The Google account backups belong to, used to fetch tokens silently
  /// for the right account on phones with several accounts.
  set accountHint(String? email);

  /// Interactive consent (account picker + permission). Must be called from a
  /// user action. Returns normally once access is granted.
  Future<void> connect();

  Future<void> disconnect();
}

/// [DriveAuth] backed by `google_sign_in`'s authorization API.
///
/// Only *authorization* is used (no Google identity sign-in), so on Android
/// no client id is compiled into the app: Google recognises the app by its
/// package name + signing certificate registered in the Cloud project
/// (see docs/google-drive-setup.md).
class GoogleDriveAuth implements DriveAuth {
  GoogleDriveAuth({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  /// iOS needs an explicit OAuth client id (`--dart-define=GOOGLE_IOS_CLIENT_ID=…`).
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const _scopes = [DriveClient.scope];

  final GoogleSignIn _signIn;
  Future<void>? _initialized;

  /// Token from the interactive grant, reused until Google rejects it.
  String? _token;
  String? _accountHint;

  @override
  set accountHint(String? email) =>
      _accountHint = (email?.isEmpty ?? true) ? null : email;

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    return Platform.isIOS && iosClientId.isNotEmpty;
  }

  Future<void> _init() => _initialized ??= _signIn
      .initialize(
        clientId: Platform.isIOS && iosClientId.isNotEmpty ? iosClientId : null,
      )
      .catchError((Object e) {
        _initialized = null; // allow a retry
        throw e;
      });

  Future<String?> _silentToken(String? email) async {
    final tokens = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: _scopes,
              userId: null,
              email: email,
              promptIfUnauthorized: false,
            ),
          ),
        );
    return tokens?.accessToken;
  }

  /// Null means there is no grant (the user must reconnect); a platform
  /// failure throws [DriveAuthUnavailableException] instead.
  @override
  Future<String?> accessToken() async {
    if (!isSupported) return null;
    if (_token != null) return _token;
    await _init();
    final hint = _accountHint;
    if (hint != null) {
      try {
        final token = await _silentToken(hint);
        if (token != null) return _token = token;
      } on GoogleSignInException catch (e) {
        // e.g. the account was removed from the phone: try without the hint.
        _log.info('Hinted authorization failed: ${e.code} ${e.description}');
      }
    }
    try {
      return _token = await _silentToken(null);
    } on GoogleSignInException catch (e) {
      _log.warning('Silent authorization failed: ${e.code} ${e.description}');
      throw DriveAuthUnavailableException(
        'Couldn’t reach Google (${e.description ?? e.code.name})',
      );
    }
  }

  @override
  Future<void> invalidate(String token) async {
    if (_token == token) _token = null;
    try {
      await _signIn.authorizationClient.clearAuthorizationToken(
        accessToken: token,
      );
    } catch (e) {
      _log.fine('clearAuthorizationToken failed: $e');
    }
  }

  @override
  Future<void> connect() async {
    if (!isSupported) {
      throw DriveConnectException(
        'Google Drive backup is not available on this device yet.',
      );
    }
    try {
      await _init();
      final authz = await _signIn.authorizationClient.authorizeScopes(_scopes);
      _token = authz.accessToken;
      _log.info('Drive access granted');
    } on GoogleSignInException catch (e) {
      _log.warning('Drive authorization failed: ${e.code} ${e.description}');
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          throw DriveConnectException('Connection canceled.', canceled: true);
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw DriveConnectException(
            'Google sign-in isn’t configured for this build of the app. '
            'See docs/google-drive-setup.md in the project.',
          );
        default:
          // Android reports backing out of the account/consent screen as an
          // SDK exception with status 16 (CANCELED) or 12501.
          if (_isCancel(e)) {
            throw DriveConnectException('Connection canceled.', canceled: true);
          }
          throw DriveConnectException(_describe(e));
      }
    }
  }

  static bool _isCancel(GoogleSignInException e) =>
      e.code == GoogleSignInExceptionCode.unknownError &&
      RegExp(r'exception: (16|12501)\b').hasMatch(e.description ?? '');

  /// Android reports a missing/mismatched Cloud project registration as an
  /// SDK error with code 10 (DEVELOPER_ERROR).
  static String _describe(GoogleSignInException e) {
    final text = '${e.description ?? ''} ${e.details ?? ''}';
    if (RegExp(r'\b10\b|DEVELOPER_ERROR').hasMatch(text)) {
      return 'Google rejected this app (developer error 10). Register the app’s '
          'package name and SHA-1 in Google Cloud — see '
          'docs/google-drive-setup.md.';
    }
    return 'Couldn’t connect to Google: ${e.description ?? e.code.name}';
  }

  @override
  Future<void> disconnect() async {
    try {
      await _init();
      final token = _token;
      // Asking for a token with the account's email registers that account
      // with the plugin, which is what lets disconnect() revoke its grant.
      if (_accountHint != null) {
        try {
          await _silentToken(_accountHint);
        } catch (_) {}
      }
      if (token != null) await invalidate(token);
      await _signIn.disconnect();
    } catch (e) {
      _log.warning('Disconnect failed: $e');
    } finally {
      _token = null;
      _accountHint = null;
    }
  }
}
