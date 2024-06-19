import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:logger/logger.dart';
import 'package:openid_client/openid_client.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uni/controller/local_storage/preferences_controller.dart';
import 'package:uni/model/entities/session.dart';
import 'package:uni/view/navigation_service.dart';

extension UriString on String {
  /// Converts a [String] to an [Uri].
  Uri toUri() => Uri.parse(this);
}

/// Manages the networking of the app.
class NetworkRouter {
  /// The HTTP client used for all requests.
  /// Can be set to null to use the default client.
  /// This is useful for testing.
  static http.Client? httpClient;

  /// The timeout for Sigarra login requests.
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// The mutual exclusion primitive for login requests.
  static final Lock _loginLock = Lock();

  /// The last time the user was logged in.
  /// Used to avoid repeated concurrent login requests.
  static DateTime? _lastLoginTime;

  /// Cached session for the current user.
  /// Returned on repeated concurrent login requests.
  static Session? _cachedSession;

  /// Performs a login using the Sigarra API,
  /// returning an authenticated [Session] with the
  /// given username [username] and password [password] if successful.
  static Future<Session?> login(
    String username,
    String password,
    List<String> faculties, {
    required bool persistentSession,
    bool ignoreCached = false,
  }) async {
    return _loginLock.synchronized(
      () async {
        if (_lastLoginTime != null &&
            DateTime.now().difference(_lastLoginTime!) <
                const Duration(minutes: 1) &&
            _cachedSession != null &&
            !ignoreCached) {
          Logger().d('Login request ignored due to recent login');
          return _cachedSession;
        }

        final url =
            '${NetworkRouter.getBaseUrls(faculties)[0]}mob_val_geral.autentica';
        final response = await http.post(
          url.toUri(),
          body: {'pv_login': username, 'pv_password': password},
        ).timeout(_requestTimeout);

        if (response.statusCode != 200) {
          Logger().e('Login failed with status code ${response.statusCode}');
          return null;
        }

        final session = Session.fromLogin(
          response,
          faculties,
          persistentSession: persistentSession,
        );

        if (session == null) {
          Logger().e('Login failed: user not authenticated');
          return null;
        }

        Logger().i('Login successful');
        _lastLoginTime = DateTime.now();
        _cachedSession = session;

        return session;
      },
      timeout: _requestTimeout,
    );
  }

  static Future<Session?> loginWithToken(
    String token,
    String studentNumber,
    List<String> faculties, {
    required bool persistentSession,
  }) async {
    //Get the cookie from SIGARRA
    const sigarraTokenEndpoint = 'https://sigarra.up.pt/auth/oidc/token';
    final response = await http.get(
      Uri.parse(sigarraTokenEndpoint),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      Logger().e('Failed to get token from SIGARRA');
      throw Exception('Failed to get token from SIGARRA');
    }

    // TODO(thePeras): implement this
    //if(response.body.result != 'success') {
    //  Logger().e('Failed to get token from SIGARRA');
    //  throw Exception('Failed to get token from SIGARRA');
    //}

    final setCookies = response.headers['set-cookie'];
    if (setCookies == null) {
      Logger().e('Failed to get token from SIGARRA');
      throw Exception('Failed to get token from SIGARRA');
    }

    final splitedCookies = setCookies.split(',').join('; ').split(';');
    final cookiesMap = <String, String>{};
    for (final cookie in splitedCookies) {
      final parts = cookie.split('=');
      if (parts.length < 2) continue;

      final key = parts[0].replaceAll(' ', '');
      final value = parts[1].replaceAll(' ', '');
      cookiesMap[key] = value;
    }

    if (!cookiesMap.containsKey('SI_SESSION') ||
        !cookiesMap.containsKey('SI_SECURITY')) {
      Logger().e('Failed to get token from SIGARRA');
      throw Exception('Failed to get token from SIGARRA');
    }

    final cookies =
        'SI_SESSION=${cookiesMap['SI_SESSION']}; SI_SECURITY=${cookiesMap['SI_SECURITY']}';

    return Session(
      username: studentNumber,
      cookies: cookies,
      faculties: faculties,
      persistentSession: persistentSession,
      federatedSession: true,
    );
  }

  /// Re-authenticates the user via the Sigarra API
  /// using data stored in [session],
  /// returning an updated Session if successful.
  static Future<Session?> reLoginFromSession(Session session) async {
    if (!session.federatedSession) {
      final password = await PreferencesController.getUserPassword();

      if (password == null) {
        Logger().e('Re-login failed: password not found');
        return null;
      }
      return login(
        session.username,
        password,
        session.faculties,
        persistentSession: session.persistentSession,
      );
    }

    final refreshToken = PreferencesController.getSessionRefreshToken();
    final faculties = PreferencesController.getUserFaculties();
    final studentNumber = PreferencesController.getUserNumber();
    if (refreshToken == null || studentNumber == null || faculties.isEmpty) {
      Logger().e('Re-login failed: refresh token not found');
      return null;
    }

    final realm = dotenv.env['REALM'] ?? '';
    final issuer = await Issuer.discover(Uri.parse(realm));
    if (issuer.metadata.tokenEndpoint == null) {
      Logger().e('Re-login failed: token endpoint not found');
      return null;
    }

    final response = await http.post(
      issuer.metadata.tokenEndpoint!,
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': dotenv.env['CLIENT_ID'],
        'client_secret': dotenv.env['CLIENT_SECRET'],
      },
    );

    final body = json.decode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String;

    if (response.statusCode != 200) {
      Logger().e('Re-login failed: status code ${response.statusCode}');
      return null;
    }

    return loginWithToken(
      accessToken,
      studentNumber,
      faculties,
      persistentSession: session.persistentSession,
    );
  }

  /// Returns the response body of the login in Sigarra
  /// given username [user] and password [pass].
  static Future<String> loginInSigarra(
    String user,
    String pass,
    List<String> faculties,
  ) async {
    final url =
        '${NetworkRouter.getBaseUrls(faculties)[0]}vld_validacao.validacao';
    final response = await http.post(
      url.toUri(),
      body: {'p_user': user, 'p_pass': pass},
    ).timeout(_requestTimeout);
    return response.body;
  }

  /// Extracts the cookies present in [headers].
  static String extractCookies(Map<String, String> headers) {
    final cookieList = <String>[];
    final cookies = headers['set-cookie'];

    if (cookies != null && cookies != '') {
      final rawCookies = cookies.split(',');
      for (final c in rawCookies) {
        cookieList.add(Cookie.fromSetCookieValue(c).toString());
      }
    }

    return cookieList.join(';');
  }

  /// Makes an authenticated GET request with the given [session] to the
  /// resource located at [baseUrl] with the given [query] parameters.
  /// If the request fails with a 403 status code, the user is re-authenticated
  /// and the session is updated.
  static Future<http.Response> getWithCookies(
    String baseUrl,
    Map<String, String> query,
    Session session, {
    Duration timeout = _requestTimeout,
  }) async {
    var url = baseUrl;
    if (!url.contains('?')) {
      url += '?';
    }
    query.forEach((key, value) {
      url += '$key=$value&';
    });
    if (query.isNotEmpty) {
      url = url.substring(0, url.length - 1);
    }

    final headers = <String, String>{};
    headers['cookie'] = session.cookies;

    final response = await (httpClient != null
            ? httpClient!.get(url.toUri(), headers: headers).timeout(timeout)
            : http.get(url.toUri(), headers: headers))
        .timeout(timeout);

    if (response.statusCode == 200) {
      return response;
    }

    final forbidden = response.statusCode == 403;
    if (forbidden) {
      final userIsLoggedIn =
          _cachedSession != null && await userLoggedIn(session);
      if (!userIsLoggedIn) {
        Logger()
            .d('User is not logged in; performing re-login from saved data');

        final newSession = await reLoginFromSession(session);

        if (newSession == null) {
          NavigationService.logoutAndPopHistory();
          return Future.error(
            'Re-login failed; user might have changed password',
          );
        }

        session
          ..username = newSession.username //(thePeras): Why is this necessary?
          ..cookies = newSession.cookies;
        headers['cookie'] = session.cookies;
        return http.get(url.toUri(), headers: headers).timeout(timeout);
      } else {
        // If the user is logged in but still got a 403, they are
        // forbidden to access the resource or the login was invalid
        // at the time of the request,
        // but other thread re-authenticated.
        // Since we do not know which one is the case, we try again.
        headers['cookie'] = session.cookies;
        final response =
            await http.get(url.toUri(), headers: headers).timeout(timeout);
        return response.statusCode == 200
            ? Future.value(response)
            : Future.error('HTTP Error: ${response.statusCode}');
      }
    }

    return Future.error('HTTP Error: ${response.statusCode}');
  }

  /// Check if the user is still logged in,
  /// performing a health check on the user's personal page.
  static Future<bool> userLoggedIn(Session session) async {
    Logger().d('Checking if user is still logged in');

    final url = '${getBaseUrl(session.faculties[0])}'
        'fest_geral.cursos_list?pv_num_unico=${session.username}';
    final headers = <String, String>{};
    headers['cookie'] = session.cookies;

    final response = await (httpClient != null
        ? httpClient!.get(url.toUri(), headers: headers)
        : http.get(url.toUri(), headers: headers));

    return response.statusCode == 200;
  }

  /// Returns the base url of the user's faculties.
  static List<String> getBaseUrls(List<String> faculties) {
    return faculties.map(getBaseUrl).toList();
  }

  /// Returns the base url of the user's faculty.
  static String getBaseUrl(String faculty) {
    return 'https://sigarra.up.pt/$faculty/pt/';
  }

  /// Returns the base url from the user's previous session.
  static List<String> getBaseUrlsFromSession(Session session) {
    return NetworkRouter.getBaseUrls(session.faculties);
  }

  /// Makes an HTTP request to terminate the session in Sigarra.
  static Future<Response> killSigarraAuthentication(
    List<String> faculties,
  ) async {
    final url = '${NetworkRouter.getBaseUrl(faculties[0])}vld_validacao.sair';
    final response = await http.get(url.toUri()).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      Logger().i('Logout Successful');
    } else {
      Logger().i('Logout Failed');
    }

    return response;
  }
}
