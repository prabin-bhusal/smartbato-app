import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

class RealtimeSocketService {
  io.Socket? _socket;
  String? _token;
  final Set<int> _joinedSupportThreads = <int>{};
  final Set<int> _joinedDiscussionCourses = <int>{};
  final Set<int> _joinedBattles = <int>{};

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    final existingSocket = _socket;
    if (existingSocket != null && _token == token) {
      if (!existingSocket.connected) {
        existingSocket.connect();
      }
      return;
    }

    disconnect();
    _token = token;

    final socket = io.io(ApiConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': false,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 500,
      'reconnectionDelayMax': 3000,
      'auth': <String, dynamic>{'token': token},
    });

    socket.on('connect', (_) {
      for (final threadId in _joinedSupportThreads) {
        socket.emit('support:join_thread', {'thread_id': threadId});
      }
      for (final courseId in _joinedDiscussionCourses) {
        socket.emit('discussion:join_course', {'course_id': courseId});
      }
      for (final battleId in _joinedBattles) {
        socket.emit('battle:join', {'battle_id': battleId});
      }
    });

    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _token = null;
    _joinedSupportThreads.clear();
    _joinedDiscussionCourses.clear();
    _joinedBattles.clear();
  }

  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic)? handler]) {
    _socket?.off(event, handler);
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void joinSupportThread(int threadId) {
    if (threadId <= 0) return;
    _joinedSupportThreads.add(threadId);
    emit('support:join_thread', {'thread_id': threadId});
  }

  void joinDiscussionCourse(int courseId) {
    if (courseId <= 0) return;
    _joinedDiscussionCourses.add(courseId);
    emit('discussion:join_course', {'course_id': courseId});
  }

  void joinBattle(int battleId) {
    if (battleId <= 0) return;
    _joinedBattles.add(battleId);
    emit('battle:join', {'battle_id': battleId});
  }
}
