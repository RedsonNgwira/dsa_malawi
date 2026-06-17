import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Monitors network connectivity and notifies listeners of changes.
/// Used for offline queue — alerts users when they go offline while sending.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _initialized = false;
  bool get initialized => _initialized;

  List<ConnectivityResult> _results = [];
  List<ConnectivityResult> get results => _results;

  /// Start listening for connectivity changes.
  Future<void> initialize() async {
    if (_initialized) return;

    _results = await _connectivity.checkConnectivity();
    _isOnline = !_results.contains(ConnectivityResult.none);
    _initialized = true;

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _results = results;
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      if (wasOnline != _isOnline) {
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Check current connectivity status.
  bool get hasInternet => _isOnline;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
