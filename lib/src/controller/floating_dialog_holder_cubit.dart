import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/floating_dialog_config.dart';
import '../host/floating_dialog_host_delegate.dart';
import '../models/floating_dialog_action.dart';
import '../models/floating_dialog_entry.dart';
import '../models/floating_dialog_status.dart';

part 'floating_dialog_holder_state.dart';

/// The holder's controller: open, minimize, restore, pin, resize, close and
/// evict floating windows. `FloatingDialogHolder` creates one for you; get
/// it with `FloatingDialogHolder.of(context)`.
///
/// Rules:
/// - One window per action id; opening a held id restores its window.
/// - At most one active window; opening another while one is active is
///   refused with [FloatingDialogStatus.busy].
/// - Tapping outside (or Back / Esc) closes a window, or sends it back to
///   the holder if it came from there.
/// - A minimized, unpinned window is evicted (turns dormant) when its
///   lifetime ends or when more than `maxMountedWindows` are minimized.
///   `FloatingDialogStateKeeper` content is saved first and handed back
///   when the window is rebuilt.
/// - Availability is re-checked when `availabilityChanges` notifies and
///   before every restore; windows that lost access are closed.
/// - Restorable items are saved per user (display list only) and come back
///   dormant after a restart.
class FloatingDialogHolderCubit extends Cubit<FloatingDialogHolderState> {
  /// Creates a controller. [availabilityChanges] notifies when permissions
  /// change. [watchAppLifecycle] saves the list when the app is hidden; turn
  /// it off in pure Dart tests without a widgets binding.
  FloatingDialogHolderCubit({
    FloatingDialogHostDelegate? host,
    FloatingDialogConfig config = const FloatingDialogConfig(),
    Listenable? availabilityChanges,
    bool watchAppLifecycle = true,
  }) : this._(
         host ?? FloatingDialogHostDelegate(),
         config,
         availabilityChanges,
         watchAppLifecycle,
       );

  FloatingDialogHolderCubit._(
    this.host,
    this.config,
    this._availabilityChanges,
    bool watchAppLifecycle,
  ) : _userId = host.userId(),
      super(_initialState(host, config, host.userId())) {
    if (watchAppLifecycle) {
      _lifecycle = AppLifecycleListener(onHide: _persist, onDetach: _persist);
    }
    _availabilityChanges?.addListener(revalidate);
    for (final entry in state.entries) {
      _scheduleExpiry(entry.id);
    }
  }

  /// App-specific hooks (storage, user, messages, texts).
  final FloatingDialogHostDelegate host;

  /// Tunable values.
  final FloatingDialogConfig config;

  /// Owner of the saved list, captured up front: logout usually clears the
  /// current user before the holder is disposed.
  final Object? _userId;
  final Listenable? _availabilityChanges;
  AppLifecycleListener? _lifecycle;
  String? _lastPersisted;

  final Map<String, FloatingDialogAction> _actions = {};
  final Map<String, Completer<Object?>> _results = {};
  final Map<String, Timer> _expiryTimers = {};
  final Map<String, bool Function()> _pauseGuards = {};
  final Map<String, Object? Function()> _stateSavers = {};
  final Map<String, Object?> _savedStates = {};

  static FloatingDialogHolderState _initialState(
    FloatingDialogHostDelegate host,
    FloatingDialogConfig config,
    Object? userId,
  ) {
    final minutes = host.storage.readLifetimeMinutes();
    final lifetime =
        minutes == null || minutes <= 0
            ? config.defaultLifetime
            : Duration(minutes: minutes);
    return FloatingDialogHolderState(
      lifetime: lifetime,
      entries: _savedEntries(host, userId, lifetime),
    );
  }

  static List<FloatingDialogEntry> _savedEntries(
    FloatingDialogHostDelegate host,
    Object? userId,
    Duration lifetime,
  ) {
    final saved = host.storage.readEntries();
    if (userId == null || saved == null || saved['userId'] != userId) {
      return const [];
    }
    final now = clock.now();
    final entries = <FloatingDialogEntry>[];
    for (final raw in saved['entries'] as List? ?? const []) {
      try {
        final entry = FloatingDialogEntry.fromJson(raw as Map<String, dynamic>);
        final expiresAt = entry.minimizedAt?.add(lifetime);
        final expired = expiresAt == null || !expiresAt.isAfter(now);
        if (entry.isPinned || !expired) entries.add(entry);
      } catch (_) {
        // Ignore malformed items; the list is display-only.
      }
    }
    return entries;
  }

  /// The latest action registered for [id].
  FloatingDialogAction? actionOf(String id) => _actions[id];

  /// Makes saved items of these actions visible again after a restart (and
  /// keeps their titles and icons up to date). Items whose action is not
  /// registered stay saved but hidden. Call it whenever the set of actions
  /// the app offers may change, e.g. after login or a permission refresh.
  void registerActions(Iterable<FloatingDialogAction> actions) {
    final next = {
      for (final id in state.mountedIds)
        if (_actions[id] case final action?) id: action,
      for (final a in actions)
        if (a.isAvailableNow) a.id: a,
    };
    _setActions(next);
    revalidate();
  }

  /// Closes windows (and hides items) whose action is no longer available,
  /// e.g. after the user's permissions changed. Called automatically when
  /// `availabilityChanges` notifies.
  void revalidate() {
    if (isClosed) return;
    final revoked = {
      for (final action in _actions.values)
        if (!action.isAvailableNow) action.id,
    };
    if (revoked.isEmpty) return;
    for (final id in revoked) {
      _cancelExpiry(id);
      _forget(id);
    }
    // Restorable items stay (dormant, hidden) so they reappear if access
    // comes back; the rest are dropped.
    final entries = [
      for (final e in state.entries)
        if (!revoked.contains(e.id))
          e
        else if (_actions[e.id]!.isRestorable)
          e.copyWith(isActive: false, isDormant: true),
    ];
    for (final id in revoked) {
      _results.remove(id)?.complete(null);
    }
    _actions.removeWhere((id, _) => revoked.contains(id));
    _setEntries(entries, actions: Map.of(_actions));
  }

  /// Opens [action]'s window, or restores it if it is already held.
  ///
  /// The returned handle says whether the window is shown and completes its
  /// `result` when the window is closed. Calling `open` again for a held id
  /// returns the same result.
  FloatingDialogHandle<T> open<T>(FloatingDialogAction action) {
    if (!action.isAvailableNow) {
      return FloatingDialogHandle(
        FloatingDialogStatus.unavailable,
        Future.value(),
      );
    }
    _setActions({..._actions, action.id: action});
    final FloatingDialogStatus status;
    if (state.entryOf(action.id) != null) {
      status = restore(action.id);
    } else if (state.activeEntry != null) {
      status = FloatingDialogStatus.busy;
    } else {
      _setEntries([...state.entries, FloatingDialogEntry(id: action.id)]);
      status = FloatingDialogStatus.opened;
    }
    if (!status.isShown) return FloatingDialogHandle(status, Future.value());
    final completer = _results.putIfAbsent(action.id, Completer.new);
    return FloatingDialogHandle(
      status,
      completer.future.then((value) => value is T ? value : null),
    );
  }

  /// Brings a held window back. Dormant windows are rebuilt.
  FloatingDialogStatus restore(String id) {
    final entry = state.entryOf(id);
    final action = _actions[id];
    if (entry == null || action == null) return FloatingDialogStatus.notFound;
    if (!action.isAvailableNow) {
      revalidate();
      return FloatingDialogStatus.unavailable;
    }
    if (entry.isActive) return FloatingDialogStatus.restored;
    if (state.activeEntry != null) return FloatingDialogStatus.busy;
    _cancelExpiry(id);
    _replace(
      entry.copyWith(isActive: true, isDormant: false, minimizedAt: () => null),
    );
    return FloatingDialogStatus.restored;
  }

  /// Sends a window to the holder. Returns false (the window stays open)
  /// when its action or a `FloatingDialogPauseGuard` refuses.
  bool minimize(String id) {
    final entry = state.entryOf(id);
    if (entry == null || entry.isMinimized) return true;
    if (!(_actions[id]?.canPauseNow ?? true)) return false;
    if (!(_pauseGuards[id]?.call() ?? true)) return false;
    _replace(
      entry.copyWith(isActive: false, minimizedAt: clock.now, wasHeld: true),
    );
    _scheduleExpiry(id);
    _enforceMountLimit();
    return true;
  }

  /// Tap outside / Back / Esc on the active window: back to the holder if it
  /// came from there or is pinned (into the pinned dock), otherwise closed.
  /// Returns false when it had to be minimized but refused.
  bool dismissActive() {
    final active = state.activeEntry;
    if (active == null) return true;
    if (active.wasHeld || active.isPinned) return minimize(active.id);
    closeDialog(active.id);
    return true;
  }

  /// Pins or unpins a window. Unpinning a minimized window restarts its
  /// lifetime.
  void togglePin(String id) {
    final entry = state.entryOf(id);
    if (entry == null) return;
    final pinned = !entry.isPinned;
    _replace(
      entry.copyWith(
        isPinned: pinned,
        minimizedAt:
            !pinned && entry.isMinimized ? clock.now : () => entry.minimizedAt,
      ),
    );
    _scheduleExpiry(id);
    if (!pinned) _enforceMountLimit();
  }

  /// Maximizes or restores a window's size.
  void toggleSize(String id) {
    final entry = state.entryOf(id);
    if (entry == null) return;
    _replace(entry.copyWith(isLarge: !entry.isLarge));
  }

  /// Closes a window and completes its result with [result]. A mounted
  /// dialog (and everything it owns) is disposed.
  void closeDialog(String id, [Object? result]) {
    _cancelExpiry(id);
    _results.remove(id)?.complete(result);
    _forget(id);
    if (state.entryOf(id) == null) return;
    _setEntries(state.entries.where((e) => e.id != id).toList());
  }

  /// Collapses or expands the holder bar.
  void toggleExpanded() => emit(state.copyWith(isExpanded: !state.isExpanded));

  /// Changes and saves the lifetime of minimized windows.
  Future<void> setLifetime(Duration lifetime) async {
    if (lifetime <= Duration.zero || lifetime == state.lifetime) return;
    emit(state.copyWith(lifetime: lifetime));
    for (final entry in state.entries) {
      _scheduleExpiry(entry.id);
    }
    await host.storage.writeLifetimeMinutes(lifetime.inMinutes);
  }

  /// Used by `FloatingDialogPauseGuard`.
  @internal
  void registerPauseGuard(String id, bool Function() canPause) =>
      _pauseGuards[id] = canPause;

  /// Used by `FloatingDialogPauseGuard`.
  @internal
  void unregisterPauseGuard(String id, bool Function() canPause) {
    if (_pauseGuards[id] == canPause) _pauseGuards.remove(id);
  }

  /// Used by `FloatingDialogStateKeeper`.
  @internal
  void registerStateSaver(String id, Object? Function() save) =>
      _stateSavers[id] = save;

  /// Used by `FloatingDialogStateKeeper`.
  @internal
  void unregisterStateSaver(String id, Object? Function() save) {
    if (_stateSavers[id] == save) _stateSavers.remove(id);
  }

  /// Used by `FloatingDialogStateKeeper`: the state saved when window [id]
  /// was evicted, removed on read.
  @internal
  Object? takeSavedState(String id) => _savedStates.remove(id);

  void _setActions(Map<String, FloatingDialogAction> next) {
    _actions
      ..clear()
      ..addAll(next);
    // Equal titles/icons skip the emit; the latest instances (and their
    // callbacks) are used either way since logic reads [_actions].
    emit(state.copyWith(actions: Map.of(next)));
  }

  /// Drops per-window callbacks and saved state.
  void _forget(String id) {
    _pauseGuards.remove(id);
    _stateSavers.remove(id);
    _savedStates.remove(id);
  }

  void _replace(FloatingDialogEntry entry) => _setEntries([
    for (final e in state.entries) e.id == entry.id ? entry : e,
  ]);

  void _setEntries(
    List<FloatingDialogEntry> entries, {
    Map<String, FloatingDialogAction>? actions,
  }) {
    final kept = {for (final e in entries) e.id};
    for (final e in state.entries) {
      if (!kept.contains(e.id)) {
        _results.remove(e.id)?.complete(null);
        _forget(e.id);
      }
    }
    emit(state.copyWith(entries: entries, actions: actions));
    _persist();
  }

  /// Saves the display list only, and only when it changed. Items of
  /// unknown actions were loaded from storage (hence restorable) and kept.
  void _persist() {
    if (_userId == null) return;
    final data = {
      'userId': _userId,
      'entries': [
        for (final e in state.entries)
          if (_actions[e.id]?.isRestorable ?? true) e.toJson(clock.now()),
      ],
    };
    final String encoded;
    try {
      encoded = json.encode(data);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'dialog_dock',
          context: ErrorDescription(
            'while saving held windows (userId must '
            'be a JSON value)',
          ),
        ),
      );
      return;
    }
    if (encoded == _lastPersisted) return;
    _lastPersisted = encoded;
    unawaited(host.storage.writeEntries(data));
  }

  /// Evicts the least recently minimized windows beyond the limit.
  void _enforceMountLimit() {
    final max = config.maxMountedWindows;
    if (max == null) return;
    final candidates =
        state.entries
            .where((e) => e.isMounted && e.canExpire)
            .sortedBy((e) => e.minimizedAt ?? DateTime(0))
            .toList();
    if (candidates.length <= max) return;
    for (final e in candidates.take(candidates.length - max)) {
      _evict(e.id);
    }
  }

  /// Turns a mounted window dormant, saving its content state first.
  void _evict(String id) {
    final entry = state.entryOf(id);
    if (entry == null || entry.isDormant) return;
    final saved = _stateSavers.remove(id)?.call();
    if (saved != null) _savedStates[id] = saved;
    _pauseGuards.remove(id);
    _replace(entry.copyWith(isDormant: true));
  }

  /// Mounted minimized windows turn dormant when their lifetime ends.
  /// Dormant ones (evicted early, or restored from storage) are removed then.
  void _scheduleExpiry(String id) {
    _cancelExpiry(id);
    final entry = state.entryOf(id);
    final minimizedAt = entry?.minimizedAt;
    if (entry == null || !entry.canExpire || minimizedAt == null) return;
    final remaining = minimizedAt.add(state.lifetime).difference(clock.now());
    if (entry.isDormant && remaining <= Duration.zero) return;
    _expiryTimers[id] = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        _expiryTimers.remove(id);
        final current = state.entryOf(id);
        if (current == null || !current.canExpire) return;
        current.isDormant ? closeDialog(id) : _evict(id);
      },
    );
  }

  void _cancelExpiry(String id) => _expiryTimers.remove(id)?.cancel();

  @override
  Future<void> close() {
    _persist();
    _lifecycle?.dispose();
    _availabilityChanges?.removeListener(revalidate);
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    for (final completer in _results.values) {
      completer.complete(null);
    }
    _results.clear();
    _pauseGuards.clear();
    _stateSavers.clear();
    _savedStates.clear();
    return super.close();
  }
}
