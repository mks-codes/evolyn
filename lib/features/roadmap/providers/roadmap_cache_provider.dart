import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef RoadmapRow = Map<String, dynamic>;

const String _emptyRoadmapMarker = '__EVOLYN_NO_SAVED_ROADMAP__';

/// Shared per-user roadmap cache.
///
/// Cache policy:
/// - emit the local row immediately when available;
/// - fetch the latest row once when this repository starts for a user;
/// - listen for INSERT/UPDATE/DELETE events in `public.roadmaps`;
/// - update memory + SharedPreferences when remote changes arrive;
/// - allow the editor to update the cache immediately after a successful save.
///
/// The cache is scoped by user ID. Supabase RLS must still protect the table.
class RoadmapCacheRepository {
  RoadmapCacheRepository(this._supabase);

  final SupabaseClient _supabase;
  final Map<String, _RoadmapWatchState> _states = <String, _RoadmapWatchState>{};

  Stream<RoadmapRow?> watch(String userId) {
    final state = _states.putIfAbsent(userId, () => _RoadmapWatchState(userId));
    if (!state.started) {
      state.started = true;
      _start(state);
    }

    // Replay to new listeners; the underlying network/cache work is shared.
    return Stream<RoadmapRow?>.multi((sink) {
      final subscription = state.events.stream.listen(
        sink.add,
        onError: (Object error, StackTrace stackTrace) =>
            sink.addError(error, stackTrace),
        onDone: sink.close,
      );
      if (state.hasValue) sink.add(state.latestValue);
      sink.onCancel = subscription.cancel;
    });
  }

  /// Publish a row that has just been saved successfully by the editor.
  /// This does not issue a SELECT query.
  Future<void> storeLocal(String userId, RoadmapRow row) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }

    final safeRow = Map<String, dynamic>.from(row);
    if (safeRow['user_id']?.toString() != userId) {
      throw StateError('Cannot cache a roadmap for a different user.');
    }

    final state = _states.putIfAbsent(userId, () => _RoadmapWatchState(userId));
    final current = state.latestValue;
    if (state.hasValue && current != null) {
      final sameId = current['id']?.toString() == safeRow['id']?.toString();
      if (sameId) {
        final currentVersion = _date(current['updated_at'] ?? current['created_at']);
        final incomingVersion = _date(safeRow['updated_at'] ?? safeRow['created_at']);
        if (currentVersion != null &&
            incomingVersion != null &&
            currentVersion.isAfter(incomingVersion)) {
          // Do not replace an edited, newer cached version with stale route data.
          return;
        }
      } else {
        final currentCreated = _date(current['created_at']);
        final incomingCreated = _date(safeRow['created_at']);
        if (currentCreated != null &&
            incomingCreated != null &&
            currentCreated.isAfter(incomingCreated)) {
          // This repository represents the user's latest-created roadmap.
          // An older roadmap opened from a stale route must not replace it.
          return;
        }
      }
    }

    _publish(state, safeRow);
    final publishedRevision = state.revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      // Another edit/Realtime event may have published a newer row while the
      // preferences singleton was initializing. Do not write this stale value.
      if (state.revision != publishedRevision) return;
      await preferences.setString(_cacheKey(userId), jsonEncode(safeRow));
    } catch (error) {
      debugPrint('[RoadmapCache] Could not persist local roadmap update: $error');
    }
  }

  /// Explicit refresh for retry or pull-to-refresh UI.
  Future<RoadmapRow?> refresh(String userId) async {
    final state = _states.putIfAbsent(userId, () => _RoadmapWatchState(userId));
    if (!state.started) {
      state.started = true;
      _start(state);
    }
    return _fetchAndPublish(state);
  }

  void _start(_RoadmapWatchState state) {
    // Subscribe before initial loading so no concurrent update is missed.
    state.channel = _supabase
        .channel('roadmaps-cache-${state.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'roadmaps',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: state.userId,
          ),
          callback: (payload) {
            final changed = payload.newRecord;
            final cached = state.latestValue;
            final hasTimestamp = changed.containsKey('updated_at');

            // A successful editor save updates local cache first. If the
            // Realtime event is that exact version, no extra SELECT is needed.
            if (state.hasValue &&
                cached != null &&
                changed.isNotEmpty &&
                hasTimestamp &&
                changed['id']?.toString() == cached['id']?.toString() &&
                changed['updated_at']?.toString() ==
                    cached['updated_at']?.toString()) {
              return;
            }

            unawaited(() async {
              try {
                await _fetchAndPublish(state);
              } catch (error) {
                debugPrint('[RoadmapCache] Realtime refresh failed: $error');
              }
            }());
          },
        )
        .subscribe();

    unawaited(_loadCacheThenFetch(state));
  }

  String _cacheKey(String userId) => 'evolyn.latest_roadmap.$userId.v2';

  Future<void> _loadCacheThenFetch(_RoadmapWatchState state) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final cachedValue = preferences.getString(_cacheKey(state.userId));

      // Do not let disk data overwrite a row received from a live update while
      // SharedPreferences was initializing.
      if (cachedValue != null && !state.disposed && !state.hasValue) {
        if (cachedValue == _emptyRoadmapMarker) {
          _publish(state, null);
        } else {
          final decoded = jsonDecode(cachedValue);
          if (decoded is Map) {
            final cachedRow = Map<String, dynamic>.from(decoded);
            if (cachedRow['user_id']?.toString() == state.userId) {
              _publish(state, cachedRow);
            } else {
              await preferences.remove(_cacheKey(state.userId));
            }
          } else {
            await preferences.remove(_cacheKey(state.userId));
          }
        }
      }
    } catch (error) {
      debugPrint('[RoadmapCache] Could not read local cache: $error');
    }

    if (state.disposed) return;
    try {
      await _fetchAndPublish(state);
    } catch (error, stackTrace) {
      if (!state.hasValue && !state.disposed) {
        state.events.addError(error, stackTrace);
      } else {
        // Keep a usable cached value when offline. The UI can still render it.
        debugPrint('[RoadmapCache] Keeping cached roadmap: $error');
      }
    }
  }

  Future<RoadmapRow?> _fetchAndPublish(_RoadmapWatchState state) async {
    if (state.disposed) return state.latestValue;

    final revisionAtStart = state.revision;
    final fetchId = ++state.latestFetchId;
    final rows = await _supabase
        .from('roadmaps')
        .select('*')
        .eq('user_id', state.userId)
        .order('created_at', ascending: false)
        .limit(1);

    final RoadmapRow? row = rows.isEmpty
        ? null
        : Map<String, dynamic>.from(rows.first as Map);

    if (state.disposed) return state.latestValue;
    // If another SELECT started later, or a local/editor update came in while
    // this SELECT was running, don't let its stale result overwrite that update.
    if (fetchId != state.latestFetchId || state.revision != revisionAtStart) {
      return state.latestValue;
    }

    _publish(state, row);
    final publishedRevision = state.revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (state.revision != publishedRevision) return state.latestValue;
      if (row == null) {
        await preferences.setString(_cacheKey(state.userId), _emptyRoadmapMarker);
      } else {
        await preferences.setString(_cacheKey(state.userId), jsonEncode(row));
      }
    } catch (error) {
      debugPrint('[RoadmapCache] Could not persist local cache: $error');
    }

    return row;
  }

  void _publish(_RoadmapWatchState state, RoadmapRow? row) {
    if (state.disposed || state.events.isClosed) return;
    state.latestValue = row == null ? null : Map<String, dynamic>.from(row);
    state.hasValue = true;
    state.revision++;
    state.events.add(state.latestValue);
  }

  Future<void> dispose() async {
    for (final state in _states.values) {
      state.disposed = true;
      final channel = state.channel;
      if (channel != null) {
        try {
          await _supabase.removeChannel(channel);
        } catch (error) {
          debugPrint('[RoadmapCache] Could not remove Realtime channel: $error');
        }
      }
      await state.events.close();
    }
    _states.clear();
  }
}

class _RoadmapWatchState {
  _RoadmapWatchState(this.userId);

  final String userId;
  final StreamController<RoadmapRow?> events =
      StreamController<RoadmapRow?>.broadcast();
  RealtimeChannel? channel;
  bool started = false;
  bool disposed = false;
  bool hasValue = false;
  int revision = 0;
  int latestFetchId = 0;
  RoadmapRow? latestValue;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

final roadmapCacheRepositoryProvider = Provider<RoadmapCacheRepository>((ref) {
  final repository = RoadmapCacheRepository(Supabase.instance.client);
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

/// Shared stream consumed by the Roadmap, Home, and Progress screens.
final userRoadmapProvider = StreamProvider.family<RoadmapRow?, String>((ref, userId) {
  return ref.watch(roadmapCacheRepositoryProvider).watch(userId);
});

