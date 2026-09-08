import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../../models/focus_session.dart';

enum TimerState { idle, running, paused }

class TimerProvider extends ChangeNotifier {
  final ApiClient _api;

  FocusSession? _activeSession;
  TimerState _timerState = TimerState.idle;
  Timer? _ticker;
  int _displaySeconds = 0;
  bool _isLoading = false;
  String? _errorMessage;
  List<FocusSession> _history = [];

  TimerProvider(this._api) {
    _restoreActiveSession();
  }

  FocusSession? get activeSession => _activeSession;
  TimerState get timerState => _timerState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<FocusSession> get history => _history;

  String get displayTime {
    final secs = _displaySeconds;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Restore any in-progress session from the server on app start
  Future<void> _restoreActiveSession() async {
    try {
      final json = await _api.get('/focus-sessions/active');
      if (json != null) {
        _activeSession = FocusSession.fromJson(json as Map<String, dynamic>);
        _displaySeconds = _activeSession!.currentElapsedSeconds;
        if (_activeSession!.isRunning) {
          _timerState = TimerState.running;
          _startTicker();
        } else if (_activeSession!.isPaused) {
          _timerState = TimerState.paused;
        }
        notifyListeners();
      }
    } catch (_) {
      // No active session or network error — start fresh
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeSession != null && _timerState == TimerState.running) {
        _displaySeconds = _activeSession!.currentElapsedSeconds;
        notifyListeners();
      }
    });
  }

  Future<void> startSession({String? taskId}) async {
    _setLoading(true);
    try {
      final body = <String, dynamic>{};
      if (taskId != null) body['taskId'] = taskId;
      final json = await _api.post('/focus-sessions', body: body);
      _activeSession = FocusSession.fromJson(json as Map<String, dynamic>);
      _displaySeconds = 0;
      _timerState = TimerState.running;
      _startTicker();
    } catch (e) {
      _errorMessage = 'Could not start timer. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> pauseSession() async {
    if (_activeSession == null || _timerState != TimerState.running) return;
    _ticker?.cancel();
    _setLoading(true);
    try {
      final json = await _api.patch('/focus-sessions/${_activeSession!.id}/pause', body: {});
      _activeSession = FocusSession.fromJson(json as Map<String, dynamic>);
      _displaySeconds = _activeSession!.elapsedSeconds;
      _timerState = TimerState.paused;
    } catch (e) {
      _errorMessage = 'Could not pause timer. Please try again.';
      // Restart ticker so display keeps going
      _startTicker();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resumeSession() async {
    if (_activeSession == null || _timerState != TimerState.paused) return;
    _setLoading(true);
    try {
      final json = await _api.patch('/focus-sessions/${_activeSession!.id}/resume', body: {});
      _activeSession = FocusSession.fromJson(json as Map<String, dynamic>);
      _timerState = TimerState.running;
      _startTicker();
    } catch (e) {
      _errorMessage = 'Could not resume timer. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<FocusSession?> completeSession({String? notes}) async {
    if (_activeSession == null) return null;
    _ticker?.cancel();
    _setLoading(true);
    try {
      final body = <String, dynamic>{};
      if (notes != null) body['notes'] = notes;
      final json = await _api.patch('/focus-sessions/${_activeSession!.id}/complete', body: body);
      final completed = FocusSession.fromJson(json as Map<String, dynamic>);
      _activeSession = null;
      _timerState = TimerState.idle;
      _displaySeconds = 0;
      _history.insert(0, completed);
      notifyListeners();
      return completed;
    } catch (e) {
      _errorMessage = 'Could not complete session. Please try again.';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> discardSession() async {
    if (_activeSession == null) return;
    _ticker?.cancel();
    _setLoading(true);
    try {
      await _api.patch('/focus-sessions/${_activeSession!.id}/discard', body: {});
    } catch (_) {
      // Best effort
    } finally {
      _activeSession = null;
      _timerState = TimerState.idle;
      _displaySeconds = 0;
      _setLoading(false);
    }
  }

  Future<void> fetchHistory() async {
    try {
      final json = await _api.get('/focus-sessions') as List<dynamic>;
      _history = json.map((e) => FocusSession.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
