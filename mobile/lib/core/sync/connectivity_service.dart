import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'sync_engine.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    // Initial check
    _connectivity.checkConnectivity().then(_handleConnectivityChange);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    bool hasConnection = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet
    );
    
    if (hasConnection && !_isOnline) {
      debugPrint('[ConnectivityService] Network restored. Triggering sync.');
      _isOnline = true;
      SyncEngine().syncNow();
    } else if (!hasConnection && _isOnline) {
      debugPrint('[ConnectivityService] Network lost.');
      _isOnline = false;
    } else {
      _isOnline = hasConnection;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
