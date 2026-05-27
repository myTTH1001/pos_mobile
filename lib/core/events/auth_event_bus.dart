// lib/core/events/auth_event_bus.dart
import 'dart:async';

class AuthEventBus {
  AuthEventBus._();
  static final AuthEventBus instance = AuthEventBus._();

  final _controller = StreamController<AuthBusEvent>.broadcast();

  Stream<AuthBusEvent> get stream => _controller.stream;

  void emitLogout() {
    if (!_controller.isClosed) {
      _controller.add(AuthBusEvent.sessionExpired);
    }
  }

  void dispose() {
    _controller.close();
  }
}

enum AuthBusEvent { sessionExpired }
