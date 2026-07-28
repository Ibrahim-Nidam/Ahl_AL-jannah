/// Cubit for the standalone Digital Tasbeeh counter.
///
/// Business rules live here; the UI only renders [TasbeehState] and
/// forwards user intents. Persistence goes through the existing Adhkar
/// repository so future cloud sync can swap the data layer only.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/adhkar_entities.dart';
import '../../domain/usecases/adhkar_usecases.dart';

// ── State ──

@immutable
class TasbeehState {
  final String dhikrText;
  final TasbeehDhikrSource dhikrSource;
  final String? catalogUniqueKey;
  final int currentCount;
  final TasbeehCounterMode counterMode;
  final int customTarget;
  final int elapsedMs;
  final bool isTimingActive;
  final bool justCompleted;

  /// Repetitions / time already flushed into [stats] for this session.
  final int flushedRepetitions;
  final int flushedElapsedMs;
  final bool targetCompletionCounted;

  final TasbeehStats stats;
  final List<TasbeehCollectionItem> collection;
  final bool isLoading;

  const TasbeehState({
    this.dhikrText = '',
    this.dhikrSource = TasbeehDhikrSource.empty,
    this.catalogUniqueKey,
    this.currentCount = 0,
    this.counterMode = TasbeehCounterMode.preset33,
    this.customTarget = 33,
    this.elapsedMs = 0,
    this.isTimingActive = false,
    this.justCompleted = false,
    this.flushedRepetitions = 0,
    this.flushedElapsedMs = 0,
    this.targetCompletionCounted = false,
    this.stats = const TasbeehStats(),
    this.collection = const [],
    this.isLoading = true,
  });

  int get goalCount =>
      counterMode.resolveTarget(customTarget: customTarget);

  bool get hasDhikrText => dhikrText.trim().isNotEmpty;

  bool get isCompleted => goalCount > 0 && currentCount >= goalCount;

  int? get remainingCount {
    if (goalCount <= 0) return null;
    final left = goalCount - currentCount;
    return left < 0 ? 0 : left;
  }

  double get progress =>
      goalCount > 0 ? (currentCount / goalCount).clamp(0.0, 1.0) : 0.0;

  TasbeehState copyWith({
    String? dhikrText,
    TasbeehDhikrSource? dhikrSource,
    String? catalogUniqueKey,
    bool clearCatalogUniqueKey = false,
    int? currentCount,
    TasbeehCounterMode? counterMode,
    int? customTarget,
    int? elapsedMs,
    bool? isTimingActive,
    bool? justCompleted,
    int? flushedRepetitions,
    int? flushedElapsedMs,
    bool? targetCompletionCounted,
    TasbeehStats? stats,
    List<TasbeehCollectionItem>? collection,
    bool? isLoading,
  }) {
    return TasbeehState(
      dhikrText: dhikrText ?? this.dhikrText,
      dhikrSource: dhikrSource ?? this.dhikrSource,
      catalogUniqueKey: clearCatalogUniqueKey
          ? null
          : (catalogUniqueKey ?? this.catalogUniqueKey),
      currentCount: currentCount ?? this.currentCount,
      counterMode: counterMode ?? this.counterMode,
      customTarget: customTarget ?? this.customTarget,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      isTimingActive: isTimingActive ?? this.isTimingActive,
      justCompleted: justCompleted ?? this.justCompleted,
      flushedRepetitions: flushedRepetitions ?? this.flushedRepetitions,
      flushedElapsedMs: flushedElapsedMs ?? this.flushedElapsedMs,
      targetCompletionCounted:
          targetCompletionCounted ?? this.targetCompletionCounted,
      stats: stats ?? this.stats,
      collection: collection ?? this.collection,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Cubit ──

@lazySingleton
class TasbeehCubit extends Cubit<TasbeehState> {
  final GetTasbeehStatsUseCase _getStats;
  final RecordTasbeehProgressUseCase _recordProgress;
  final ClearTasbeehStatsDayUseCase _clearDay;
  final ClearAllTasbeehStatsUseCase _clearAll;
  final GetSavedTasbeehSessionUseCase _getSession;
  final SaveTasbeehSessionUseCase _saveSession;
  final GetTasbeehCollectionUseCase _getCollection;
  final SaveTasbeehCollectionUseCase _saveCollection;

  /// Wall-clock moment when the active timing segment started.
  DateTime? _timingSegmentStartedAt;

  /// Prevents overlapping flushes.
  bool _flushing = false;

  TasbeehCubit(
    this._getStats,
    this._recordProgress,
    this._clearDay,
    this._clearAll,
    this._getSession,
    this._saveSession,
    this._getCollection,
    this._saveCollection,
  ) : super(const TasbeehState());

  /// Restore previous session, collection, and stats (no prompt).
  Future<void> loadSession() async {
    emit(state.copyWith(isLoading: true));
    final results = await Future.wait([
      _getStats(),
      _getSession(),
      _getCollection(),
    ]);
    final stats = results[0] as TasbeehStats;
    final session = results[1] as Map<String, dynamic>?;
    final collection = results[2] as List<TasbeehCollectionItem>;

    if (session != null) {
      final mode = _modeFromSession(session);
      final customTarget = (session['customTarget'] as num?)?.toInt() ??
          (session['goalCount'] as num?)?.toInt() ??
          33;
      final dhikrText = session['dhikrText'] as String? ?? '';
      final currentCount = (session['currentCount'] as num?)?.toInt() ?? 0;
      final elapsedMs = (session['elapsedMs'] as num?)?.toInt() ?? 0;
      final flushedReps = (session['flushedRepetitions'] as num?)?.toInt() ?? 0;
      final flushedElapsed = (session['flushedElapsedMs'] as num?)?.toInt() ?? 0;
      
      // Flush any unsaved progress from the previous session
      if (dhikrText.trim().isNotEmpty && currentCount > flushedReps) {
        final pendingReps = currentCount - flushedReps;
        final pendingMs = elapsedMs - flushedElapsed;
        if (pendingReps > 0 || pendingMs > 0) {
          await _recordProgress(
            dhikrText: dhikrText,
            repetitions: pendingReps > 0 ? pendingReps : 0,
            durationMs: pendingMs > 0 ? pendingMs : 0,
            countAsCompletedSession: false,
          );
          // Reload stats after flushing
          final updatedStats = await _getStats();
          emit(TasbeehState(
            dhikrText: dhikrText,
            dhikrSource: _sourceFromSession(session, dhikrText),
            catalogUniqueKey: session['catalogUniqueKey'] as String?,
            currentCount: currentCount,
            counterMode: mode,
            customTarget: customTarget < 1 ? 33 : customTarget,
            elapsedMs: elapsedMs,
            isTimingActive: false,
            justCompleted: false,
            flushedRepetitions: currentCount,
            flushedElapsedMs: elapsedMs,
            targetCompletionCounted:
                session['targetCompletionCounted'] as bool? ??
                    session['completionRecorded'] as bool? ??
                    false,
            stats: updatedStats,
            collection: collection,
            isLoading: false,
          ));
          return;
        }
      }
      
      emit(TasbeehState(
        dhikrText: dhikrText,
        dhikrSource: _sourceFromSession(session, dhikrText),
        catalogUniqueKey: session['catalogUniqueKey'] as String?,
        currentCount: currentCount,
        counterMode: mode,
        customTarget: customTarget < 1 ? 33 : customTarget,
        elapsedMs: elapsedMs,
        isTimingActive: false,
        justCompleted: false,
        flushedRepetitions: flushedReps,
        flushedElapsedMs: flushedElapsed,
        targetCompletionCounted:
            session['targetCompletionCounted'] as bool? ??
                session['completionRecorded'] as bool? ??
                false,
        stats: stats,
        collection: collection,
        isLoading: false,
      ));
    } else {
      emit(state.copyWith(
        stats: stats,
        collection: collection,
        isLoading: false,
      ));
    }
  }

  void resumeTiming() {
    if (state.currentCount <= 0) return;
    if (state.isTimingActive) return;
    _timingSegmentStartedAt = DateTime.now();
    emit(state.copyWith(isTimingActive: true));
  }

  Future<void> pauseTiming({bool flushStats = true}) async {
    final started = _timingSegmentStartedAt;
    if (started == null && !state.isTimingActive) {
      if (flushStats) await flushUnsavedProgress();
      return;
    }

    var elapsed = state.elapsedMs;
    if (started != null) {
      elapsed += DateTime.now().difference(started).inMilliseconds;
      _timingSegmentStartedAt = null;
    }
    emit(state.copyWith(elapsedMs: elapsed, isTimingActive: false));
    _persistSession();
    if (flushStats) await flushUnsavedProgress();
  }

  int liveElapsedMs() {
    final started = _timingSegmentStartedAt;
    if (started == null) return state.elapsedMs;
    return state.elapsedMs +
        DateTime.now().difference(started).inMilliseconds;
  }

  /// Persist any uncounted reps/time for non-empty dhikr sessions.
  Future<void> flushUnsavedProgress({bool countCompleted = false}) async {
    if (_flushing) return;
    if (!state.hasDhikrText) return;

    final liveElapsed = liveElapsedMs();
    final pendingReps = state.currentCount - state.flushedRepetitions;
    final pendingMs = liveElapsed - state.flushedElapsedMs;
    final shouldCountSession =
        countCompleted && !state.targetCompletionCounted;

    if (pendingReps <= 0 && pendingMs <= 0 && !shouldCountSession) {
      return;
    }

    _flushing = true;
    try {
      final stats = await _recordProgress(
        dhikrText: state.dhikrText,
        repetitions: pendingReps > 0 ? pendingReps : 0,
        durationMs: pendingMs > 0 ? pendingMs : 0,
        countAsCompletedSession: shouldCountSession,
      );
      emit(state.copyWith(
        stats: stats,
        flushedRepetitions: state.currentCount,
        flushedElapsedMs: liveElapsed,
        targetCompletionCounted:
            state.targetCompletionCounted || shouldCountSession,
        elapsedMs: liveElapsed,
      ));
      _persistSession();
    } finally {
      _flushing = false;
    }
  }

  /// Increment the counter by 1. Returns whether target was just hit.
  Future<bool> increment() async {
    final wasCompleted = state.isCompleted;
    final newCount = state.currentCount + 1;

    var elapsed = state.elapsedMs;
    var timingActive = state.isTimingActive;
    if (state.currentCount == 0) {
      _timingSegmentStartedAt = DateTime.now();
      timingActive = true;
      elapsed = 0;
    } else if (!timingActive) {
      _timingSegmentStartedAt = DateTime.now();
      timingActive = true;
    }

    final goal = state.goalCount;
    final justHit = !wasCompleted && goal > 0 && newCount >= goal;

    if (justHit) {
      if (_timingSegmentStartedAt != null) {
        elapsed += DateTime.now().difference(_timingSegmentStartedAt!).inMilliseconds;
        _timingSegmentStartedAt = null;
      }
      timingActive = false;
    }

    emit(state.copyWith(
      currentCount: newCount,
      elapsedMs: elapsed,
      isTimingActive: timingActive,
      justCompleted: justHit,
    ));
    _persistSession();

    if (justHit) {
      await flushUnsavedProgress(countCompleted: true);
    }

    return justHit;
  }

  void clearJustCompleted() {
    if (!state.justCompleted) return;
    emit(state.copyWith(justCompleted: false));
  }

  /// Reset the counter after flushing any unsaved progress.
  Future<void> resetCount() async {
    await pauseTiming(flushStats: true);
    _timingSegmentStartedAt = null;
    emit(state.copyWith(
      currentCount: 0,
      elapsedMs: 0,
      isTimingActive: false,
      justCompleted: false,
      flushedRepetitions: 0,
      flushedElapsedMs: 0,
      targetCompletionCounted: false,
    ));
    _persistSession();
  }

  Future<void> setCounterMode(
    TasbeehCounterMode mode, {
    int? customTarget,
  }) async {
    await pauseTiming(flushStats: true);
    final target = customTarget ?? state.customTarget;
    _timingSegmentStartedAt = null;
    emit(state.copyWith(
      counterMode: mode,
      customTarget: target < 1 ? 1 : target,
      currentCount: 0,
      elapsedMs: 0,
      isTimingActive: false,
      justCompleted: false,
      flushedRepetitions: 0,
      flushedElapsedMs: 0,
      targetCompletionCounted: false,
    ));
    _persistSession();
  }

  Future<void> setCustomTarget(int target) =>
      setCounterMode(TasbeehCounterMode.custom, customTarget: target);

  Future<void> startWithCatalogDhikr(AdhkarItem item) => _startDhikr(
        text: item.arabic,
        source: TasbeehDhikrSource.catalog,
        catalogUniqueKey: item.uniqueKey,
      );

  Future<void> startWithCollectionItem(TasbeehCollectionItem item) =>
      _startDhikr(
        text: item.arabic,
        source: TasbeehDhikrSource.collection,
        catalogUniqueKey: item.catalogUniqueKey,
      );

  Future<void> startWithCustomDhikr(String text) => _startDhikr(
        text: text.trim(),
        source: TasbeehDhikrSource.custom,
        catalogUniqueKey: null,
      );

  Future<void> startEmptyCounter() => _startDhikr(
        text: '',
        source: TasbeehDhikrSource.empty,
        catalogUniqueKey: null,
      );

  Future<void> _startDhikr({
    required String text,
    required TasbeehDhikrSource source,
    required String? catalogUniqueKey,
  }) async {
    await pauseTiming(flushStats: true);
    _timingSegmentStartedAt = null;
    emit(state.copyWith(
      dhikrText: text,
      dhikrSource: source,
      catalogUniqueKey: catalogUniqueKey,
      clearCatalogUniqueKey: catalogUniqueKey == null,
      currentCount: 0,
      elapsedMs: 0,
      isTimingActive: false,
      justCompleted: false,
      flushedRepetitions: 0,
      flushedElapsedMs: 0,
      targetCompletionCounted: false,
    ));
    _persistSession();
  }

  Future<bool> addToCollection(AdhkarItem item) async {
    final entry = TasbeehCollectionItem.fromAdhkar(item);
    if (_collectionContains(entry)) return false;
    final updated = [...state.collection, entry];
    await _saveCollection(updated);
    emit(state.copyWith(collection: updated));
    return true;
  }

  Future<void> removeFromCollection(TasbeehCollectionItem item) async {
    final updated = state.collection
        .where((e) => !_sameCollectionItem(e, item))
        .toList(growable: false);
    await _saveCollection(updated);
    emit(state.copyWith(collection: updated));
  }

  Future<void> clearStatsForDay(String date) async {
    final stats = await _clearDay(date);
    emit(state.copyWith(stats: stats));
  }

  Future<void> clearAllStats() async {
    final stats = await _clearAll();
    emit(state.copyWith(stats: stats));
  }

  bool isInCollection(AdhkarItem item) {
    return state.collection.any(
      (e) =>
          (e.catalogUniqueKey != null &&
              e.catalogUniqueKey == item.uniqueKey) ||
          e.arabic.trim() == item.arabic.trim(),
    );
  }

  bool _collectionContains(TasbeehCollectionItem item) {
    return state.collection.any((e) => _sameCollectionItem(e, item));
  }

  bool _sameCollectionItem(TasbeehCollectionItem a, TasbeehCollectionItem b) {
    if (a.catalogUniqueKey != null &&
        b.catalogUniqueKey != null &&
        a.catalogUniqueKey == b.catalogUniqueKey) {
      return true;
    }
    return a.arabic.trim() == b.arabic.trim();
  }

  void _persistSession() {
    _saveSession({
      'dhikrText': state.dhikrText,
      'dhikrSource': state.dhikrSource.name,
      'catalogUniqueKey': state.catalogUniqueKey,
      'currentCount': state.currentCount,
      'counterMode': state.counterMode.name,
      'customTarget': state.customTarget,
      'elapsedMs': liveElapsedMs(),
      'flushedRepetitions': state.flushedRepetitions,
      'flushedElapsedMs': state.flushedElapsedMs,
      'targetCompletionCounted': state.targetCompletionCounted,
    });
  }

  static TasbeehCounterMode _modeFromSession(Map<String, dynamic> session) {
    final named = session['counterMode'] as String?;
    if (named != null) {
      for (final mode in TasbeehCounterMode.values) {
        if (mode.name == named) return mode;
      }
    }
    final goal = (session['goalCount'] as num?)?.toInt();
    if (goal == null) return TasbeehCounterMode.preset33;
    if (goal == 0) return TasbeehCounterMode.unlimited;
    if (goal == 33) return TasbeehCounterMode.preset33;
    if (goal == 99) return TasbeehCounterMode.preset99;
    if (goal == 100) return TasbeehCounterMode.preset100;
    return TasbeehCounterMode.custom;
  }

  static TasbeehDhikrSource _sourceFromSession(
    Map<String, dynamic> session,
    String dhikrText,
  ) {
    final named = session['dhikrSource'] as String?;
    if (named != null) {
      for (final source in TasbeehDhikrSource.values) {
        if (source.name == named) return source;
      }
    }
    if (dhikrText.trim().isEmpty) return TasbeehDhikrSource.empty;
    if (session['isCustomDhikr'] as bool? ?? false) {
      return TasbeehDhikrSource.custom;
    }
    return TasbeehDhikrSource.catalog;
  }
}
