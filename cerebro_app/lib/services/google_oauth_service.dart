/// Uses browser-based OAuth flow with a local redirect server.
/// This approach works reliably for Desktop-type OAuth clients.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:cerebro_app/config/constants.dart';

class GoogleOAuthService {
  static const String _clientId = AppConstants.googleClientId;
  static const String _clientSecret = AppConstants.googleClientSecret;
  static const String _authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenEndpoint =
      'https://oauth2.googleapis.com/token';

  /// Runs the full OAuth flow:
  /// 1. Starts a local HTTP server to catch the redirect
  /// 2. Opens Google's consent screen in the browser
  /// 3. Catches the auth code from the redirect
  /// 4. Exchanges the auth code for an ID token
  /// Returns the ID token string, or null if cancelled/failed.
  static Future<String?> signIn() async {
    HttpServer? server;
    try {
      // 1. Start a local server on a random available port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      // 2. Build the Google OAuth URL
      final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      // 3. Open the browser
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser for Google Sign-In');
      }

      // 4. Wait for the redirect (timeout after 2 minutes)
      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('Google Sign-In timed out'),
      );

      // 5. Extract the auth code from the redirect URL
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];

      // Send a nice response to the browser
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
          <html><body style="font-family: -apple-system, sans-serif; display: flex;
            justify-content: center; align-items: center; height: 100vh; margin: 0;
            background: linear-gradient(135deg, #e8f5e9, #fff8e1);">
            <div style="text-align: center;">
              <h1 style="color: #2e7d32;">✓ Signed in to Cerebro</h1>
              <p style="color: #666;">You can close this tab and return to the app.</p>
            </div>
          </body></html>
        ''');
      await request.response.close();
      await server.close();
      server = null;

      if (error != null || code == null) {
        return null; // User cancelled or error occurred
      }

      // 6. Exchange the auth code for tokens
      final httpClient = HttpClient();
      try {
        final tokenRequest =
            await httpClient.postUrl(Uri.parse(_tokenEndpoint));
        tokenRequest.headers
            .set('Content-Type', 'application/x-www-form-urlencoded');
        tokenRequest.write(Uri(queryParameters: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        }).query);

        final tokenResponse = await tokenRequest.close();
        final body = await tokenResponse.transform(utf8.decoder).join();
        final tokenData = json.decode(body) as Map<String, dynamic>;

        if (tokenData.containsKey('id_token')) {
          return tokenData['id_token'] as String;
        } else {
          throw Exception(
              tokenData['error_description'] ?? 'Failed to get ID token');
        }
      } finally {
        httpClient.close();
      }
    } catch (e) {
      if (server != null) {
        await server.close();
      }
      rethrow;
    }
  }
}
