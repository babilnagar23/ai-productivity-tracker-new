import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_engine.dart';

class OnlineStatus {
  final bool isOnline;
  final DateTime? lastSyncTime;
  final bool syncInProgress;
  final int failedSyncCount;

  OnlineStatus({
    this.isOnline = true,
    this.lastSyncTime,
    this.syncInProgress = false,
    this.failedSyncCount = 0,
  });

  bool get isOffline => !isOnline;

  OnlineStatus copyWith({
    bool? isOnline,
    DateTime? lastSyncTime,
    bool? syncInProgress,
    int? failedSyncCount,
  }) {
    return OnlineStatus(
      isOnline: isOnline ?? this.isOnline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncInProgress: syncInProgress ?? this.syncInProgress,
      failedSyncCount: failedSyncCount ?? this.failedSyncCount,
    );
  }
}

class OnlineStatusNotifier extends StateNotifier<OnlineStatus> {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final Connectivity _connectivity = Connectivity();

  OnlineStatusNotifier() : super(OnlineStatus()) {
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    _connectivity.checkConnectivity().then(_handleConnectivityChange);

    final syncEngine = SyncEngine();
    syncEngine.onSyncStatusChanged = (isSyncing) {
      setSyncInProgress(isSyncing);
    };
    syncEngine.onSyncSuccess = () {
      setLastSyncTime(DateTime.now());
    };
    syncEngine.onSyncFailed = (err) {
      incrementFailedSyncCount();
    };
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
    state = state.copyWith(isOnline: hasConnection);
  }

  void setSyncInProgress(bool inProgress) {
    state = state.copyWith(syncInProgress: inProgress);
  }

  void setLastSyncTime(DateTime time) {
    state = state.copyWith(lastSyncTime: time, failedSyncCount: 0);
  }

  void incrementFailedSyncCount() {
    state = state.copyWith(failedSyncCount: state.failedSyncCount + 1);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final onlineStatusProvider = StateNotifierProvider<OnlineStatusNotifier, OnlineStatus>((ref) {
  return OnlineStatusNotifier();
});
