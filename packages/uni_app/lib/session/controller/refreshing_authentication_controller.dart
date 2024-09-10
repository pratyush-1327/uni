import 'dart:async';

import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uni/session/controller/authentication_controller.dart';
import 'package:uni/session/exception.dart';
import 'package:uni/session/flows/base/session.dart';
import 'package:uni/session/logout/logout_handler.dart';

class RefreshingAuthenticationController extends AuthenticationController {
  RefreshingAuthenticationController(
    Session initialSession, {
    this.logoutHandler,
  }) : _currentSession = initialSession;

  final LogoutHandler? logoutHandler;
  final Lock _authenticationLock = Lock();

  Future<void>? _nextAuthentication;
  Session _currentSession;

  final _snapshotsController =
      StreamController<AuthenticationSnapshot>.broadcast();
  Stream<AuthenticationSnapshot> get snapshots => _snapshotsController.stream;

  @override
  Future<AuthenticationSnapshot> get snapshot async {
    final nextAuthentication = _nextAuthentication;
    if (nextAuthentication != null) {
      await nextAuthentication;
    }

    return _createSnapshot(_currentSession);
  }

  Future<void> invalidate() async {
    final currentSnapshot = await snapshot;
    await currentSnapshot.invalidate();
  }

  AuthenticationSnapshot _createSnapshot(Session session) {
    return AuthenticationSnapshot(
      session,
      invalidate: () => _invalidate(session),
    );
  }

  bool _shouldInvalidate(Session session) {
    // We invalidate if the is not an invalidation in progress already
    // and the session is the same as the current one.
    return _nextAuthentication == null && _currentSession == session;
  }

  Future<void> _invalidate(Session session) async {
    // This check is intentionally used twice to avoid unnecessary lock
    // acquisitions.
    if (!_shouldInvalidate(session)) {
      return;
    }

    await _authenticationLock.synchronized(() {
      // After the lock is acquired, the condition could have changed if
      // another thread has already invalidated the session.
      if (!_shouldInvalidate(session)) {
        return;
      }

      _nextAuthentication = _reauthenticate();
    });
  }

  Future<void> _reauthenticate() async {
    final currentSession = _currentSession;

    Future<void> releaseLock() =>
        _authenticationLock.synchronized(() => _nextAuthentication = null);

    try {
      final request = currentSession.createRefreshRequest();
      _currentSession = await request.perform();

      _snapshotsController.add(_createSnapshot(_currentSession));

      // If the reauthentication is successful, we indicate that the
      // invalidation is no longer in progress and another one can be
      // performed.
      await releaseLock();
    } catch (err, st) {
      if (err is! AuthenticationException) {
        // If the error thrown is not an authentication exception,
        // for instance, a network error, we need to release the lock to
        // ensure that future accesses to a snapshot will not block
        // indefinitely.
        await releaseLock();

        // Report the exception as it will not be thrown when
        // awaiting a snapshot.
        Logger().e('Failed to reauthenticate', error: err, stackTrace: st);
        unawaited(Sentry.captureException(err, stackTrace: st));
        return;
      }

      // After the authentication attempt fails due to invalid credentials,
      // we don't allow this authentication controller to create any other
      // snapshots.
      // Futhermore, we use the logout handler to signal to the app that the
      // user must be logged out.
      await logoutHandler?.close(currentSession);

      _snapshotsController.addError(err, st);
      unawaited(_snapshotsController.close());

      rethrow;
    }
  }
}
