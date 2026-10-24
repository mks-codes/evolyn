import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../learn/presentation/learn_screen.dart';
import '../../mentor/presentation/mentor_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../roadmap/presentation/roadmap_screen.dart';
import '../../roadmap/providers/roadmap_cache_provider.dart';
import 'tabs/home_tab.dart';
import 'widgets/evolyn_bottom_navigation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
   bool _roadmapRefreshInFlight = false;

     @override
  void initState() {
    super.initState();

    // Let the first frame render before starting network synchronization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshRoadmap());
    });
  }


 Future<void> _refreshRoadmap() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || _roadmapRefreshInFlight) return;

    _roadmapRefreshInFlight = true;

    try {
      await ref
          .read(roadmapCacheRepositoryProvider)
          .refresh(user.id);
    } catch (error, stackTrace) {
      debugPrint(
        '[HomeScreen] Roadmap refresh failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _roadmapRefreshInFlight = false;
    }
  }

  void _onItemSelected(int index) {
    if (index < 0 || index > 4 || index == _selectedIndex) {
      return;
    }

    setState(() => _selectedIndex = index);

    // Refresh quietly when the roadmap tab is selected.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_refreshRoadmap());
      });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: const Color(0xFF050614),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  HomeTab(),
                  _SavedRoadmapTab(),
                  MentorScreen(),
                  LearnScreen(),
                  ProgressScreen(),
                ],
              ),
            ),
            if (!keyboardVisible)
              EvolynBottomNavigation(
                selectedIndex: _selectedIndex,
                onItemSelected:_onItemSelected
              ),
          ],
        ),
      ),
    );
  }
}

/// Displays the latest roadmap from the shared local-first cache.
///
/// It intentionally does not query Supabase here. The shared provider loads
/// local storage first, performs its initial server verification once, and
/// listens for row changes through Supabase Realtime.
class _SavedRoadmapTab extends ConsumerWidget {
  const _SavedRoadmapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const _RoadmapTabMessage(
        icon: Icons.lock_outline_rounded,
        message: 'Please sign in to view your saved roadmap.',
      );
    }

    final roadmapAsync = ref.watch(userRoadmapProvider(user.id));

    return roadmapAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFA78BFA)),
      ),
      error: (error, stackTrace) => _RoadmapTabMessage(
        icon: Icons.cloud_off_outlined,
        message:
            'Could not load your saved roadmap. Check your connection and retry.',
        buttonLabel: 'Try again',
        onPressed: () => _refresh(ref, user.id),
      ),
      data: (row) {
        if (row == null) {
          return _RoadmapTabMessage(
            icon: Icons.route_rounded,
            message:
                'You have not saved a roadmap yet. Select careers and generate your first roadmap.',
            buttonLabel: 'Refresh',
            onPressed: () => _refresh(ref, user.id),
          );
        }

        final roadmapData = _jsonMap(row['roadmap_data'] ?? row['roadmap']);
        if (roadmapData == null) {
          return _RoadmapTabMessage(
            icon: Icons.data_object_rounded,
            message: 'Your saved roadmap record is missing valid roadmap data.',
            buttonLabel: 'Refresh',
            onPressed: () => _refresh(ref, user.id),
          );
        }

        final selectedCareers = _jsonMapList(row['selected_careers']);
        final selectedCareerIds = _jsonStringList(row['selected_career_ids']);
        final requestId = (row['career_request_id'] ?? row['request_id'])
            ?.toString();
        final generationRequestId = row['generation_request_id']?.toString();
        final roadmapId = row['id']?.toString();

        // Preserve the response shape used by the GoRouter roadmap route and
        // by RoadmapScreen after successful AI generation.
        final response = <String, dynamic>{
          ...roadmapData,
          'success': true,
          'persisted': true,
          'roadmap_data': roadmapData,
          'roadmap_id': roadmapId,
          'request_id': requestId,
          'generation_request_id': generationRequestId,
          'selected_career_ids': selectedCareerIds,
          'selected_careers': selectedCareers,
          'status': row['status'] ?? 'draft',
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
        };

        return RoadmapScreen(
          roadmapData: response,
          selectedCareers: selectedCareers,
          roadmapId: roadmapId,
          requestId: requestId,
          generationRequestId: generationRequestId,
        );
      },
    );
  }

  Future<void> _refresh(WidgetRef ref, String userId) async {
    try {
      await ref.read(roadmapCacheRepositoryProvider).refresh(userId);
    } catch (error) {
      debugPrint('[HomeScreen roadmap tab] Refresh failed: $error');
    }
  }
}

class _RoadmapTabMessage extends StatelessWidget {
  const _RoadmapTabMessage({
    required this.message,
    this.icon = Icons.route_rounded,
    this.buttonLabel,
    this.onPressed,
  });

  final String message;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFFA78BFA)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic>? _jsonMap(dynamic value) {
  dynamic decoded = value;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return null;
    }
  }
  if (decoded is! Map) return null;
  return Map<String, dynamic>.from(decoded);
}

List<Map<String, dynamic>> _jsonMapList(dynamic value) {
  dynamic decoded = value;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return <Map<String, dynamic>>[];
    }
  }
  if (decoded is! List) return <Map<String, dynamic>>[];
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _jsonStringList(dynamic value) {
  dynamic decoded = value;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return <String>[];
    }
  }
  if (decoded is! List) return <String>[];
  return decoded
      .map((item) => item?.toString())
      .whereType<String>()
      .where((item) => item.trim().isNotEmpty)
      .toSet()
      .toList(growable: false);
}
