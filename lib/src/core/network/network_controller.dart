import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkController extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;
  bool _isOnline = true;

  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    final current = await _connectivity.checkConnectivity();
    _isOnline = _hasInternet(current);
    _isInitialized = true;
    notifyListeners();

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final nextOnline = _hasInternet(results);
      if (nextOnline != _isOnline) {
        _isOnline = nextOnline;
        notifyListeners();
      }
    });
  }

  Future<void> refreshStatus() async {
    final current = await _connectivity.checkConnectivity();
    final nextOnline = _hasInternet(current);

    if (nextOnline != _isOnline) {
      _isOnline = nextOnline;
      notifyListeners();
    }
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
