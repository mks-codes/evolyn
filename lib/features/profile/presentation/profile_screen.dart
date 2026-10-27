import 'dart:async';
import 'dart:convert';

import 'package:evolyn/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_locale_provider.dart';
import '../../authentication/providers/auth_providers.dart';
import '../../roadmap/providers/roadmap_cache_provider.dart';
import 'package:evolyn/features/profile/providers/user_display_name_provider.dart';
import 'package:evolyn/core/widgets/top_message.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const Color _background = Color(0xFF050614);
  static const Color _panel = Color(0xFF101126);
  static const Color _panelAlt = Color(0xFF151630);
  static const Color _border = Color(0xFF292A46);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _muted = Color(0xFF9294AD);
  static const Color _cyan = Color(0xFF63D9DD);
  static const Color _danger = Color(0xFFFF858F);

  bool _learningReminders = true;
  bool _weeklyRecap = true;
  bool _productUpdates = false;
  bool _isSigningOut = false;
  bool _isSavingName = false;
  bool _preferencesLoaded = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  SupabaseClient get _supabase => Supabase.instance.client;
  User? get _user => _supabase.auth.currentUser;
  String get _userId => _user?.id ?? 'signed_out';
  String _preferenceKey(String key) => 'evolyn.profile.$_userId.$key';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _openAccountCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AccountCenterScreen(
          onChangePassword: _changePassword,
          onDeleteAccount: _requestAccountDeletion,
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || !mounted) return;

    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      if (mounted) _showSnack(_l10n.profilePasswordUpdated);
    } on AuthException catch (error) {
      if (mounted) _showSnack(error.message);
    } catch (error) {
      debugPrint('Password update failed: $error');
      if (mounted) _showSnack(_l10n.profileCouldNotUpdatePassword);
    }
  }

  Future<void> _requestAccountDeletion() async {
    final result = await showDialog<_DeletionRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (result == null || !mounted) return;

    // Deploy the server-side delete-account Edge Function before enabling this.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _l10n.profileDeletePermanentlyTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          _l10n.profileDeleteWarning,
          style: const TextStyle(color: _muted, height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              _l10n.profileKeepAccount,
              style: const TextStyle(color: _muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _l10n.profileDeletePermanently,
              style: const TextStyle(color: _danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response = await _supabase.functions.invoke(
        'delete-account',
        body: {
          'action': 'request',
          'reason': result.reason,
          'details': result.details,
        },
      );

      final responseData = response.data;

      if (response.status < 200 ||
          response.status >= 300 ||
          responseData is! Map ||
          responseData['success'] != true) {
        if (mounted) {
          _showSnack(_l10n.profileDeleteRequestFailed);
        }
        return;
      }

      if (!mounted) return;

      // This dialog explains the grace period before the session is cleared.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _panel,
          title: Text(
            _l10n.profileDeletionGracePeriodTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _l10n.profileDeletionGracePeriodTitle,
            style: const TextStyle(color: _muted, height: 1.5, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.profileDeletionGracePeriodTitle),
            ),
          ],
        ),
      );

      if (!mounted) return;

      await _supabase.auth.signOut(scope: SignOutScope.local);

      if (mounted) {
        _showSnack(_l10n.profileDeletionCompleted);
      }
      if (mounted) _showSnack(_l10n.profileDeletionCompleted);
    } on FunctionException catch (error) {
      debugPrint('Account deletion failed: ${error.details}');
      if (mounted) _showSnack(_l10n.profileDeletionFailed);
    } catch (error) {
      debugPrint('Account deletion failed: $error');
      if (mounted) _showSnack(_l10n.profileDeletionFailed);
    }
  }



Future<void> _loadPreferences() async {
  var learning = true;
  var recap = true;
  var updates = false;

  try {
    final prefs = await SharedPreferences.getInstance();

    learning = prefs.getBool(_preferenceKey('learning_reminders')) ?? true;
    recap = prefs.getBool(_preferenceKey('weekly_recap')) ?? true;
    updates = prefs.getBool(_preferenceKey('product_updates')) ?? false;

    final user = _user;

    if (user != null) {
      final row = await _supabase
          .from('notification_preferences')
          .select(
            'learning_reminders, weekly_recap, product_updates',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      if (row != null) {
        learning = row['learning_reminders'] as bool? ?? true;
        recap = row['weekly_recap'] as bool? ?? true;
        updates = row['product_updates'] as bool? ?? false;
      } else {
        await _supabase.from('notification_preferences').upsert({
          'user_id': user.id,
          'learning_reminders': learning,
          'weekly_recap': recap,
          'product_updates': updates,
        }, onConflict: 'user_id');
      }
    }

    await prefs.setBool(_preferenceKey('learning_reminders'), learning);
    await prefs.setBool(_preferenceKey('weekly_recap'), recap);
    await prefs.setBool(_preferenceKey('product_updates'), updates);
  } catch (error) {
    debugPrint('[ProfileScreen] Could not load notification settings: $error');
  }

  if (!mounted) return;

  setState(() {
    _learningReminders = learning;
    _weeklyRecap = recap;
    _productUpdates = updates;
    _preferencesLoaded = true;
  });
}

  Future<bool> _ensureNotificationsAllowed() async {
  if (_user == null) {
    _showSnack('Please sign in to configure notifications.');
    return false;
  }

  try {
    final success = await NotificationService.instance
        .requestPermissionAndRegister();

    if (!success && mounted) {
      _showSnack(
        'Allow notifications in your device settings to receive updates.',
      );
    }

    return success;
  } catch (error) {
    debugPrint('Notification setup failed: $error');

    if (mounted) {
      _showSnack('Unable to enable notifications. Please try again.');
    }

    return false;
  }
}

Future<void> _saveBoolPreference(String key, bool value) async {
  final prefs = await SharedPreferences.getInstance();
  final user = _user;

  // Keep local preferences available if the user is signed out.
  if (user == null) {
    await prefs.setBool(_preferenceKey(key), value);
    return;
  }

  await _supabase.from('notification_preferences').upsert(
    {
      'user_id': user.id,
      'learning_reminders': _learningReminders,
      'weekly_recap': _weeklyRecap,
      'product_updates': _productUpdates,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    },
    onConflict: 'user_id',
  );

  await prefs.setBool(_preferenceKey(key), value);
}

Future<void> _setLearningReminders(bool value) async {
  if (value && !await _ensureNotificationsAllowed()) return;

  final previous = _learningReminders;
  setState(() => _learningReminders = value);

  try {
    await _saveBoolPreference('learning_reminders', value);
  } catch (error) {
    debugPrint('Could not save learning reminder setting: $error');
    if (!mounted) return;
    setState(() => _learningReminders = previous);
    _showSnack(_l10n.profileSavePreferenceFailed);
  }
}

Future<void> _setWeeklyRecap(bool value) async {
  if (value && !await _ensureNotificationsAllowed()) return;

  final previous = _weeklyRecap;
  setState(() => _weeklyRecap = value);

  try {
    await _saveBoolPreference('weekly_recap', value);
  } catch (error) {
    debugPrint('Could not save weekly recap setting: $error');
    if (!mounted) return;
    setState(() => _weeklyRecap = previous);
    _showSnack(_l10n.profileSavePreferenceFailed);
  }
}

Future<void> _setProductUpdates(bool value) async {
  if (value && !await _ensureNotificationsAllowed()) return;

  final previous = _productUpdates;
  setState(() => _productUpdates = value);

  try {
    await _saveBoolPreference('product_updates', value);
  } catch (error) {
    debugPrint('Could not save product update setting: $error');
    if (!mounted) return;
    setState(() => _productUpdates = previous);
    _showSnack(_l10n.profileSavePreferenceFailed);
  }
}

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final user = _user;
    final userId = user?.id;
    AsyncValue<RoadmapRow?>? roadmapAsync;
    if (userId != null) {
      roadmapAsync = ref.watch(userRoadmapProvider(userId));
    }

    final currentFocus = user == null
        ? l10n.profileSignInToViewFocus
        : (roadmapAsync?.when(
                data: _focusFromRoadmap,
                loading: () => l10n.profileLoadingFocus,
                error: (error, stack) => l10n.profileUnableToLoadFocus,
              ) ??
              l10n.profileNoSavedRoadmap);

    final displayNameAsync = ref.watch(userDisplayNameProvider);

    final resolvedName = displayNameAsync.when(
      data: (name) => name,
      loading: () => '',
      error: (error, stackTrace) => '',
    );

    final displayName = resolvedName.isNotEmpty
        ? resolvedName
        : l10n.profileYourProfile;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _buildProfileCard(user, currentFocus, displayName),
              const SizedBox(height: 25),
              _sectionHeading(
                l10n.profilePreferences,
                l10n.profilePreferencesSubtitle,
              ),
              const SizedBox(height: 12),
              _buildPreferencesCard(),
              const SizedBox(height: 24),
              _sectionHeading(
                l10n.profileLanguage,
                l10n.profileLanguageSubtitle,
              ),
              const SizedBox(height: 12),
              _buildLanguageCard(),
              const SizedBox(height: 24),
              _sectionHeading(
                l10n.profilePrivacySecurity,
                l10n.profilePrivacySecuritySubtitle,
              ),
              const SizedBox(height: 12),
              _buildPrivacyCard(),
              const SizedBox(height: 24),
              _sectionHeading(
                l10n.profileAccountCenter,
                l10n.profileAccountCenterSubtitle,
              ),
              const SizedBox(height: 12),
              _card(
                child: _settingsTile(
                  icon: Icons.manage_accounts_outlined,
                  title: l10n.profileAccountCenter,
                  subtitle: l10n.profileAccountCenterTileSubtitle,
                  onTap: _openAccountCenter,
                ),
              ),
              const SizedBox(height: 24),
              _buildLogoutButton(),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  l10n.profileFooter,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _focusFromRoadmap(RoadmapRow? row) {
    if (row == null) return _l10n.profileNoSavedRoadmap;
    final selected = row['selected_careers'];
    if (selected is List) {
      final titles = selected
          .whereType<Map>()
          .map((item) => item['career_title']?.toString().trim() ?? '')
          .where((title) => title.isNotEmpty)
          .toList();
      if (titles.isNotEmpty) return titles.take(2).join(' · ');
    }

    dynamic raw = row['roadmap_data'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = null;
      }
    }
    if (raw is Map) {
      final title = raw['title']?.toString().trim();
      if (title != null && title.isNotEmpty) return title;
      final nested = raw['roadmap'];
      if (nested is Map) {
        final nestedTitle = nested['title']?.toString().trim();
        if (nestedTitle != null && nestedTitle.isNotEmpty) return nestedTitle;
      }
    }
    final title = row['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    return _l10n.profileRoadmapSaved;
  }

  Widget _buildHeader() {
    final l10n = _l10n;
    return Row(
      children: [
        Material(
          color: _panel,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileYourSpace,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.profileSetings,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    User? user,
    String currentFocus,
    String displayName,
  ) {
    final l10n = _l10n;
    final email = user?.email ?? l10n.profileEmailUnavailable;
    final initials = _initials(displayName);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D1940), Color(0xFF101D31), Color(0xFF101126)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF464071)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _purple, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF242343),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFFD7CEFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: _cyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.profileLearningJourney,
                          style: const TextStyle(
                            color: Color(0xFF9ADFE1),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.profileEditNameTooltip,
                onPressed: _isSavingName ? null : _editProfile,
                icon: _isSavingName
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _purple,
                        ),
                      )
                    : const Icon(
                        Icons.edit_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.route_rounded, color: _purple, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.profileCurrentFocus,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282344),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4A3F78)),
                  ),
                  child: Text(
                    currentFocus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFFD2C7FF),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final l10n = _l10n;
    return _card(
      child: Column(
        children: [
          _switchTile(
            icon: Icons.notifications_active_outlined,
            title: l10n.profileLearningReminders,
            subtitle: l10n.profileLearningRemindersSubtitle,
            value: _learningReminders,
            onChanged: _setLearningReminders,
          ),
          _thinDivider(),
          _switchTile(
            icon: Icons.insights_outlined,
            title: l10n.profileWeeklyRecap,
            subtitle: l10n.profileWeeklyRecapSubtitle,
            value: _weeklyRecap,
            onChanged: _setWeeklyRecap,
          ),
          _thinDivider(),
          _switchTile(
            icon: Icons.campaign_outlined,
            title: l10n.profileProductUpdates,
            subtitle: l10n.profileProductUpdatesSubtitle,
            value: _productUpdates,
            onChanged: _setProductUpdates,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard() {
    final l10n = _l10n;
    final locale = ref.watch(appLocaleProvider);
    final languageLabel = switch (locale.languageCode) {
      'hi' => 'हिन्दी (Hindi)',
      'mr' => 'मराठी (Marathi)',
      _ => 'English',
    };

    return _card(
      child: _settingsTile(
        icon: Icons.translate_rounded,
        title: l10n.profileLanguage,
        subtitle: l10n.profileChooseAppLanguage,
        trailing: _trailingValue(languageLabel),
        onTap: _chooseLanguage,
      ),
    );
  }

  Widget _buildPrivacyCard() {
    final l10n = _l10n;
    return _card(
      child: Column(
        children: [
          _settingsTile(
            icon: Icons.shield_outlined,
            title: l10n.profilePrivacyPolicy,
            subtitle: l10n.profilePrivacyPolicySubtitle,
            onTap: _showPrivacyPolicy,
          ),
          _thinDivider(),
          _settingsTile(
            icon: Icons.lock_outline_rounded,
            title: l10n.profileAccountSecurity,
            subtitle: l10n.profileAccountSecuritySubtitle,
            onTap: () => _showInfo(
              l10n.profileAccountSecurity,
              l10n.profileAccountSecurityMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    final l10n = _l10n;
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: OutlinedButton.icon(
        onPressed: _isSigningOut ? null : _confirmLogout,
        icon: _isSigningOut
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _danger,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          _isSigningOut ? l10n.profileSigningOut : l10n.profileLogout,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          side: BorderSide(color: _danger.withOpacity(0.45)),
          backgroundColor: const Color(0xFF1A111F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Switch.adaptive(
            value: value,
            onChanged: _preferencesLoaded ? onChanged : null,
            activeColor: _purple,
            activeTrackColor: _purple.withOpacity(0.32),
            inactiveTrackColor: const Color(0xFF303149),
            inactiveThumbColor: const Color(0xFF85869D),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _preferencesLoaded ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              if (trailing != null) trailing,
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF777991),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF2B2C4B)),
      ),
      child: Icon(icon, color: _purple, size: 18),
    );
  }

  Widget _trailingValue(String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 86),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC4B8FF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _thinDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(height: 1, color: Colors.white.withOpacity(0.055)),
  );

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'E';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Future<void> _editProfile() async {
    final user = _user;

    if (user == null) {
      _showSnack(_l10n.profileEditSignInAgain);
      return;
    }

    final currentName = await ref.read(userDisplayNameProvider.future);

    if (!mounted) return;

    final initialName = currentName.isNotEmpty
        ? currentName
        : _l10n.profileYourProfile;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditProfileNameDialog(initialName: initialName),
    );

    if (name == null || name.isEmpty || !mounted || name == initialName) {
      return;
    }

    setState(() => _isSavingName = true);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{
            'full_name': name,
            'display_name': name,
            'name': name,
          },
        ),
      );

      if (!mounted) return;

      // Refresh the shared name source.
      // HomeTab will also rebuild because it depends on this provider.
      ref.invalidate(userDisplayNameProvider);

      _showSnack(_l10n.profileNameUpdated);
    } catch (error) {
      debugPrint('[ProfileScreen] Profile update failed: $error');

      if (mounted) {
        _showSnack(_l10n.profileCouldNotUpdateName);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  Future<void> _chooseLanguage() async {
    const languages = <String, String>{
      'English': 'en',
      'हिन्दी (Hindi)': 'hi',
      'मराठी (Marathi)': 'mr',
    };
    final currentCode = ref.read(appLocaleProvider).languageCode;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileChooseLanguage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.profileChooseAppLanguage,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                ...languages.entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    trailing: currentCode == entry.value
                        ? const Icon(Icons.check_circle_rounded, color: _purple)
                        : const Icon(
                            Icons.circle_outlined,
                            color: Colors.white24,
                          ),
                    onTap: () => Navigator.of(sheetContext).pop(entry.value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    await ref.read(appLocaleProvider.notifier).setLanguageCode(selected);
    if (mounted) _showSnack(_l10n.profileLanguageUpdated);
  }

  Future<void> _showPrivacyPolicy() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: _purple, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      l10n.profilePrivacyPolicy,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.profilePrivacyDescription,
                  style: const TextStyle(
                    color: Color(0xFFCACBDA),
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.profilePrivacyReviewNotice,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: const Color(0xFF100D24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      l10n.profileDone,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInfo(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: _panel,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: const TextStyle(
              color: Color(0xFFCACBDA),
              height: 1.5,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.profileGotIt,
                style: const TextStyle(color: _purple),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.profileLogoutTitle,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            l10n.profileLogoutMessage,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                l10n.profileCancel,
                style: const TextStyle(color: _muted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.profileLogout,
                style: const TextStyle(
                  color: _danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await NotificationService.instance.unregisterCurrentDevice();
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      debugPrint('[ProfileScreen] Sign-out failed: $error');
      if (mounted) _showSnack(_l10n.profileLogoutFailed);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    TopMessage.show(context, message);
  }
}

/// Owns the TextEditingController for the lifetime of the dialog route.
class _EditProfileNameDialog extends StatefulWidget {
  const _EditProfileNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditProfileNameDialog> createState() => _EditProfileNameDialogState();
}

class _EditProfileNameDialogState extends State<_EditProfileNameDialog> {
  static const Color _panel = Color(0xFF101126);
  static const Color _border = Color(0xFF292A46);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _muted = Color(0xFF9294AD);

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: _panel,
      title: Text(
        l10n.profileEditProfile,
        style: const TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: l10n.profileDisplayName,
          labelStyle: const TextStyle(color: _muted),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _border),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _purple),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.profileCancel,
            style: const TextStyle(color: _muted),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(l10n.profileSave, style: const TextStyle(color: _purple)),
        ),
      ],
    );
  }
}

class _AccountCenterScreen extends StatelessWidget {
  const _AccountCenterScreen({
    required this.onChangePassword,
    required this.onDeleteAccount,
  });

  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;

  static const _panel = Color(0xFF101126);
  static const _border = Color(0xFF292A46);
  static const _purple = Color(0xFFA78BFA);
  static const _muted = Color(0xFF9294AD);
  static const _danger = Color(0xFFFF858F);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF050614),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050614),
        foregroundColor: Colors.white,
        title: Text(l10n.profileAccountCenter),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.profileAccountSecurityHeading,
            style: const TextStyle(
              color: _purple,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _item(
            icon: Icons.lock_outline_rounded,
            title: l10n.profileChangePassword,
            subtitle: l10n.profileChangePasswordSubtitle,
            onTap: onChangePassword,
          ),
          const SizedBox(height: 10),
          _item(
            icon: Icons.phone_android_rounded,
            title: l10n.profileMobileNumber,
            subtitle: l10n.profileMobileNumberSubtitle,
            onTap: () => TopMessage.show(context, l10n.comingSoon),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.profileAccountOwnershipHeading,
            style: const TextStyle(
              color: _purple,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _item(
            icon: Icons.delete_outline_rounded,
            title: l10n.profileDeleteAccount,
            subtitle: l10n.profileDeleteAccountSubtitle,
            onTap: onDeleteAccount,
            danger: true,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.profileDeletionCannotUndo,
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? _danger : _purple;
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? _danger.withOpacity(0.3) : _border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: danger ? _danger : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final password = _password.text;
    if (password.length < 8) {
      _message(l10n.profilePasswordMinLength);
      return;
    }
    if (password != _confirm.text) {
      _message(l10n.profilePasswordsDoNotMatch);
      return;
    }
    Navigator.pop(context, password);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF101126),
      title: Text(
        l10n.profileChangePassword,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _password,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.profileNewPassword,
              labelStyle: const TextStyle(color: Color(0xFF9294AD)),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.profileConfirmNewPassword,
              labelStyle: const TextStyle(color: Color(0xFF9294AD)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.profileCancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(l10n.profileUpdatePassword),
        ),
      ],
    );
  }
}

class _PhoneDialog extends StatefulWidget {
  const _PhoneDialog({required this.currentPhone});

  final String currentPhone;

  @override
  State<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends State<_PhoneDialog> {
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF101126),
      title: Text(
        l10n.profileMobileNumber,
        style: const TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: l10n.profilePhoneNumberLabel,
          hintText: l10n.profilePhoneNumberHint,
          helperText: l10n.profilePhoneCountryCodeHelp,
          labelStyle: const TextStyle(color: Color(0xFF9294AD)),
          helperStyle: const TextStyle(color: Color(0xFF9294AD)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.profileCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final phone = _phone.text.trim();
            if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.profileInvalidPhone)));
              return;
            }
            Navigator.pop(context, phone);
          },
          child: Text(l10n.profileSendVerificationCode),
        ),
      ],
    );
  }
}

class _OtpDialog extends StatefulWidget {
  const _OtpDialog({required this.phone});

  final String phone;

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final _otp = TextEditingController();

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF101126),
      title: Text(
        l10n.profileVerifyMobile,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileOtpMessage(widget.phone),
            style: const TextStyle(
              color: Color(0xFF9294AD),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.profileVerificationCode,
              labelStyle: const TextStyle(color: Color(0xFF9294AD)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.profileCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final code = _otp.text.trim();
            if (!RegExp(r'^\d{6}$').hasMatch(code)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.profileInvalidOtp)));
              return;
            }
            Navigator.pop(context, code);
          },
          child: Text(l10n.profileVerify),
        ),
      ],
    );
  }
}

class _DeletionRequest {
  const _DeletionRequest({required this.reason, required this.details});

  final String reason;
  final String details;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  // Codes are stable internally; backend values remain the original English
  // reason strings so existing server-side handling is unchanged.
  static const Map<String, String> _backendReasons = {
    'no_need': 'I no longer need this account',
    'unsatisfied': 'I am not satisfied with the app',
    'learning_needs': 'The app does not meet my learning needs',
    'privacy': 'I have privacy or data concerns',
    'technical': 'I am experiencing technical problems',
    'another_account': 'I created another account',
    'other': 'Other',
  };

  String? _selectedReason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _reasonLabel(String code, AppLocalizations l10n) {
    return switch (code) {
      'no_need' => l10n.profileDeleteReasonNoNeed,
      'unsatisfied' => l10n.profileDeleteReasonUnsatisfied,
      'learning_needs' => l10n.profileDeleteReasonLearningNeeds,
      'privacy' => l10n.profileDeleteReasonPrivacy,
      'technical' => l10n.profileDeleteReasonTechnical,
      'another_account' => l10n.profileDeleteReasonAnotherAccount,
      'other' => l10n.profileDeleteReasonOther,
      _ => code,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF101126),
      title: Text(
        l10n.profileWhyLeaving,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileFeedbackOptional,
                style: const TextStyle(
                  color: Color(0xFF9294AD),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              ..._backendReasons.keys.map(
                (code) => RadioListTile<String>(
                  value: code,
                  groupValue: _selectedReason,
                  onChanged: (value) => setState(() => _selectedReason = value),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFFA78BFA),
                  title: Text(
                    _reasonLabel(code, l10n),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.profileAnythingElse,
                style: const TextStyle(
                  color: Color(0xFFCACBDA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                maxLines: 3,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.profileFeedbackHint,
                  hintStyle: const TextStyle(color: Color(0xFF777991)),
                  filled: true,
                  fillColor: const Color(0xFF151630),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.profileKeepAccount,
            style: const TextStyle(color: Color(0xFF9294AD)),
          ),
        ),
        TextButton(
          onPressed: () {
            if (_selectedReason == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.profileSelectReason)));
              return;
            }
            Navigator.pop(
              context,
              _DeletionRequest(
                reason: _backendReasons[_selectedReason!]!,
                details: _details.text.trim(),
              ),
            );
          },
          child: Text(
            l10n.profileContinue,
            style: const TextStyle(color: Color(0xFFFF858F)),
          ),
        ),
      ],
    );
  }
}
