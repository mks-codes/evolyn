import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef LearnRow = Map<String, dynamic>;

const String _emptyLearnMarker = '__EVOLYN_NO_LEARN_ROWS__';

/// Per-user cache for learning state/resources stored in public.learn.
///
/// - Reads SharedPreferences first and replays the cache to new listeners.
/// - Performs one initial backend read for the active user.
/// - Listens to Supabase Realtime changes for that user's learn rows.
/// - Publishes successful local writes immediately and persists them locally.
/// - Keeps cached values available if a later request fails while offline.
class LearnCacheRepository {
  LearnCacheRepository(this._supabase);

  final SupabaseClient _supabase;
  final Map<String, _LearnWatchState> _states = <String, _LearnWatchState>{};

  Stream<List<LearnRow>> watch(String userId) {
    final state = _states.putIfAbsent(userId, () => _LearnWatchState(userId));
    if (!state.started) {
      state.started = true;
      _start(state);
    }

    return Stream<List<LearnRow>>.multi((sink) {
      final subscription = state.events.stream.listen(
        (rows) => sink.add(_copyRows(rows)),
        onError: (Object error, StackTrace stackTrace) =>
            sink.addError(error, stackTrace),
        onDone: sink.close,
      );
      if (state.hasValue) sink.add(_copyRows(state.rows));
      sink.onCancel = subscription.cancel;
    });
  }

  /// Explicit refresh for pull-to-refresh or error recovery.
  Future<List<LearnRow>> refresh(String userId) async {
    final state = _states.putIfAbsent(userId, () => _LearnWatchState(userId));
    if (!state.started) {
      state.started = true;
      _start(state);
    }
    return _fetchAndPublish(state);
  }

  /// Upserts a task's personal learning state/resource metadata.
  /// The SQL table must have UNIQUE (user_id, roadmap_id, task_key).
  Future<LearnRow> upsertTaskState(
    String userId,
    LearnRow payload,
  ) async {
    if (payload['user_id']?.toString() != userId) {
      throw StateError('Cannot save learn data for a different user.');
    }
    final state = _states.putIfAbsent(userId, () => _LearnWatchState(userId));
    final saved = await _supabase
        .from('learn')
        .upsert(payload, onConflict: 'user_id,roadmap_id,task_key')
        .select('*')
        .single();
    final row = Map<String, dynamic>.from(saved);

    // Do not start an initial fetch after a successful write unless there is
    // already a stream. We can publish the exact row returned by Postgres.
    if (!state.started) {
      state.started = true;
      _subscribeRealtime(state);
      unawaited(_loadCacheThenFetch(state));
    }
    _upsertIntoState(state, row);
    await _persist(state);
    return row;
  }

  void _start(_LearnWatchState state) {
    _subscribeRealtime(state);
    unawaited(_loadCacheThenFetch(state));
  }

  void _subscribeRealtime(_LearnWatchState state) {
    if (state.channel != null) return;
    state.channel = _supabase
        .channel('learn-cache-${state.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'learn',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: state.userId,
          ),
          callback: (payload) {
            final changed = payload.newRecord;
            final cached = state.rows;
            if (state.hasValue &&
                changed.isNotEmpty &&
                changed['id'] != null &&
                cached.any(
                  (row) => row['id']?.toString() == changed['id']?.toString() &&
                      row['updated_at']?.toString() ==
                          changed['updated_at']?.toString(),
                )) {
              return;
            }
            unawaited(() async {
              try {
                await _fetchAndPublish(state);
              } catch (error) {
                debugPrint('[LearnCache] Realtime refresh failed: $error');
              }
            }());
          },
        )
        .subscribe();
  }

  String _cacheKey(String userId) => 'evolyn.learn.rows.$userId.v1';

  Future<void> _loadCacheThenFetch(_LearnWatchState state) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey(state.userId));
      if (raw != null && !state.disposed && !state.hasValue) {
        if (raw == _emptyLearnMarker) {
          _publish(state, <LearnRow>[]);
        } else {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final rows = decoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((row) => row['user_id']?.toString() == state.userId)
                .toList();
            _publish(state, rows);
          } else {
            await preferences.remove(_cacheKey(state.userId));
          }
        }
      }
    } catch (error) {
      debugPrint('[LearnCache] Could not read local cache: $error');
    }

    if (state.disposed) return;
    try {
      await _fetchAndPublish(state);
    } catch (error, stackTrace) {
      if (!state.hasValue && !state.disposed) {
        state.events.addError(error, stackTrace);
      } else {
        debugPrint('[LearnCache] Keeping cached learning data: $error');
      }
    }
  }

  Future<List<LearnRow>> _fetchAndPublish(_LearnWatchState state) async {
    if (state.disposed) return _copyRows(state.rows);
    final revisionAtStart = state.revision;
    final fetchId = ++state.latestFetchId;
    final result = await _supabase
        .from('learn')
        .select('*')
        .eq('user_id', state.userId)
        .order('updated_at', ascending: false)
        .limit(1000);

    final rows = (result as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (state.disposed) return _copyRows(state.rows);
    // A newer query or successful local write wins over an older response.
    if (fetchId != state.latestFetchId || state.revision != revisionAtStart) {
      return _copyRows(state.rows);
    }

    _publish(state, rows);
    await _persist(state);
    return _copyRows(state.rows);
  }

  void _upsertIntoState(_LearnWatchState state, LearnRow row) {
    if (state.disposed || state.events.isClosed) return;
    final id = row['id']?.toString();
    final roadmapId = row['roadmap_id']?.toString();
    final taskKey = row['task_key']?.toString();
    final rows = _copyRows(state.rows);
    final existingIndex = rows.indexWhere((item) {
      if (id != null && item['id']?.toString() == id) return true;
      return item['roadmap_id']?.toString() == roadmapId &&
          item['task_key']?.toString() == taskKey;
    });
    if (existingIndex >= 0) {
      rows[existingIndex] = Map<String, dynamic>.from(row);
    } else {
      rows.insert(0, Map<String, dynamic>.from(row));
    }
    rows.sort((a, b) => _date(b['updated_at']).compareTo(_date(a['updated_at'])));
    _publish(state, rows);
  }

  void _publish(_LearnWatchState state, List<LearnRow> rows) {
    if (state.disposed || state.events.isClosed) return;
    state.rows = _copyRows(rows);
    state.hasValue = true;
    state.revision++;
    state.events.add(_copyRows(state.rows));
  }

  Future<void> _persist(_LearnWatchState state) async {
    if (state.disposed) return;
    final revision = state.revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (state.disposed || state.revision != revision) return;
      if (state.rows.isEmpty) {
        await preferences.setString(_cacheKey(state.userId), _emptyLearnMarker);
      } else {
        await preferences.setString(_cacheKey(state.userId), jsonEncode(state.rows));
      }
    } catch (error) {
      debugPrint('[LearnCache] Could not persist cache: $error');
    }
  }

  Future<void> dispose() async {
    for (final state in _states.values) {
      state.disposed = true;
      if (state.channel != null) {
        try {
          await _supabase.removeChannel(state.channel!);
        } catch (error) {
          debugPrint('[LearnCache] Could not remove Realtime channel: $error');
        }
      }
      await state.events.close();
    }
    _states.clear();
  }
}

class _LearnWatchState {
  _LearnWatchState(this.userId);

  final String userId;
  final StreamController<List<LearnRow>> events =
      StreamController<List<LearnRow>>.broadcast();
  RealtimeChannel? channel;
  bool started = false;
  bool disposed = false;
  bool hasValue = false;
  int revision = 0;
  int latestFetchId = 0;
  List<LearnRow> rows = <LearnRow>[];
}

DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

List<LearnRow> _copyRows(List<LearnRow> rows) => rows
    .map((row) => Map<String, dynamic>.from(row))
    .toList();

final learnCacheRepositoryProvider = Provider<LearnCacheRepository>((ref) {
  final repository = LearnCacheRepository(Supabase.instance.client);
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final userLearnRowsProvider =
    StreamProvider.family<List<LearnRow>, String>((ref, userId) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || user.id != userId) {
    return Stream<List<LearnRow>>.error(
      StateError('You must be signed in to view learning data.'),
    );
  }
  return ref.watch(learnCacheRepositoryProvider).watch(userId);
});
