import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/providers/prefs_provider.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final DateTime lastReadAt;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    DateTime? lastReadAt,
  }) : lastReadAt = lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  int get unreadCount =>
      notifications.where((n) => n.createdAt.isAfter(lastReadAt)).length;

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    DateTime? lastReadAt,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        lastReadAt: lastReadAt ?? this.lastReadAt,
      );
}

class NotificationViewModel extends StateNotifier<NotificationState> {
  final NotificationRepository _repo;
  final SharedPreferences _prefs;
  final String _userId;

  StreamSubscription<List<NotificationModel>>? _broadcastSub;
  StreamSubscription<List<NotificationModel>>? _userSub;
  List<NotificationModel> _broadcastNotifs = [];
  List<NotificationModel> _userNotifs = [];

  static const _prefKey = 'notifications_last_read_at';

  NotificationViewModel(this._repo, this._prefs, this._userId)
      : super(NotificationState()) {
    _init();
  }

  void _init() {
    final ms = _prefs.getInt(_prefKey) ?? 0;
    state = state.copyWith(
      isLoading: true,
      lastReadAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );

    // Stream broadcast (notifications globales admin → tous).
    _broadcastSub = _repo.stream().listen(
      (notifs) {
        _broadcastNotifs = notifs;
        _merge();
      },
      onError: (e) => state = state.copyWith(isLoading: false, error: e.toString()),
    );

    // Stream personnel (notifications contrat pour cet utilisateur).
    if (_userId.isNotEmpty) {
      _userSub = _repo.streamUserNotifs(_userId).listen(
        (notifs) {
          _userNotifs = notifs;
          _merge();
        },
        onError: (_) {},
      );
    }
  }

  void _merge() {
    final all = [..._broadcastNotifs, ..._userNotifs];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(
      notifications: all.take(50).toList(),
      isLoading: false,
    );
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    await _prefs.setInt(_prefKey, now.millisecondsSinceEpoch);
    state = state.copyWith(lastReadAt: now);
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _broadcastSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

final notificationViewModelProvider = StateNotifierProvider.family<
    NotificationViewModel, NotificationState, String>(
  (ref, userId) {
    final prefs = ref.watch(sharedPrefsProvider);
    return NotificationViewModel(NotificationRepository(), prefs, userId);
  },
);
