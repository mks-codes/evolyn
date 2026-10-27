import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Evolyn'**
  String get appName;

  /// No description provided for @profileAccountCenter.
  ///
  /// In en, this message translates to:
  /// **'Account Center'**
  String get profileAccountCenter;

  /// No description provided for @profileSetings.
  ///
  /// In en, this message translates to:
  /// **'Profile & settings'**
  String get profileSetings;

  /// No description provided for @profileYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profileYourProfile;

  /// No description provided for @profileSignInToViewFocus.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your focus'**
  String get profileSignInToViewFocus;

  /// No description provided for @profileLoadingFocus.
  ///
  /// In en, this message translates to:
  /// **'Loading your focus…'**
  String get profileLoadingFocus;

  /// No description provided for @profileUnableToLoadFocus.
  ///
  /// In en, this message translates to:
  /// **'Unable to load current focus'**
  String get profileUnableToLoadFocus;

  /// No description provided for @profileNoSavedRoadmap.
  ///
  /// In en, this message translates to:
  /// **'No saved roadmap yet'**
  String get profileNoSavedRoadmap;

  /// No description provided for @profileRoadmapSaved.
  ///
  /// In en, this message translates to:
  /// **'Roadmap saved'**
  String get profileRoadmapSaved;

  /// No description provided for @profilePreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profilePreferences;

  /// No description provided for @profilePreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device for your account.'**
  String get profilePreferencesSubtitle;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language.'**
  String get profileLanguageSubtitle;

  /// No description provided for @profilePrivacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & security'**
  String get profilePrivacySecurity;

  /// No description provided for @profilePrivacySecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account, your choice.'**
  String get profilePrivacySecuritySubtitle;

  /// No description provided for @profileAccountCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your credentials and account data.'**
  String get profileAccountCenterSubtitle;

  /// No description provided for @profileAccountCenterTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password, mobile number and account deletion'**
  String get profileAccountCenterTileSubtitle;

  /// No description provided for @profileYourSpace.
  ///
  /// In en, this message translates to:
  /// **'YOUR SPACE'**
  String get profileYourSpace;

  /// No description provided for @profileEmailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Email unavailable'**
  String get profileEmailUnavailable;

  /// No description provided for @profileLearningJourney.
  ///
  /// In en, this message translates to:
  /// **'Your learning journey'**
  String get profileLearningJourney;

  /// No description provided for @profileEditNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit profile name'**
  String get profileEditNameTooltip;

  /// No description provided for @profileCurrentFocus.
  ///
  /// In en, this message translates to:
  /// **'Current focus'**
  String get profileCurrentFocus;

  /// No description provided for @profileLearningReminders.
  ///
  /// In en, this message translates to:
  /// **'Learning reminders'**
  String get profileLearningReminders;

  /// No description provided for @profileLearningRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge for your daily learning goal'**
  String get profileLearningRemindersSubtitle;

  /// No description provided for @profileWeeklyRecap.
  ///
  /// In en, this message translates to:
  /// **'Weekly progress recap'**
  String get profileWeeklyRecap;

  /// No description provided for @profileWeeklyRecapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A summary of completed tasks'**
  String get profileWeeklyRecapSubtitle;

  /// No description provided for @profileProductUpdates.
  ///
  /// In en, this message translates to:
  /// **'Product updates'**
  String get profileProductUpdates;

  /// No description provided for @profileProductUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'News about new Evolyn features'**
  String get profileProductUpdatesSubtitle;

  /// No description provided for @profileDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily learning goal'**
  String get profileDailyGoal;

  /// No description provided for @profileDailyGoalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{goal} per day'**
  String profileDailyGoalSubtitle(String goal);

  /// No description provided for @profileDeletionGracePeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion'**
  String get profileDeletionGracePeriodTitle;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profilePrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your account and learning data are handled'**
  String get profilePrivacyPolicySubtitle;

  /// No description provided for @profileAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get profileAccountSecurity;

  /// No description provided for @profileAccountSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in credentials remain private'**
  String get profileAccountSecuritySubtitle;

  /// No description provided for @profileAccountSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account is managed by Supabase Authentication. Never share your password or verification codes with anyone.'**
  String get profileAccountSecurityMessage;

  /// No description provided for @profileSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get profileSigningOut;

  /// No description provided for @profileFooter.
  ///
  /// In en, this message translates to:
  /// **'EVOLYN • GROW AT YOUR PACE'**
  String get profileFooter;

  /// No description provided for @profilePasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get profilePasswordUpdated;

  /// No description provided for @profileCouldNotUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Could not update your password.'**
  String get profileCouldNotUpdatePassword;

  /// No description provided for @profilePhoneUpdated.
  ///
  /// In en, this message translates to:
  /// **'Mobile number verified and updated.'**
  String get profilePhoneUpdated;

  /// No description provided for @profileCouldNotUpdatePhone.
  ///
  /// In en, this message translates to:
  /// **'Could not update your mobile number.'**
  String get profileCouldNotUpdatePhone;

  /// No description provided for @profileDeletePermanentlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete account?'**
  String get profileDeletePermanentlyTitle;

  /// No description provided for @profileDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. Your account, saved roadmaps, learning progress, profile data and other associated data will be permanently deleted according to our deletion policy. Any data that must legally be retained will be handled as described in the privacy policy.'**
  String get profileDeleteWarning;

  /// No description provided for @profileKeepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get profileKeepAccount;

  /// No description provided for @profileDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get profileDeletePermanently;

  /// No description provided for @profileDeleteRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Account deletion request failed.'**
  String get profileDeleteRequestFailed;

  /// No description provided for @profileDeletionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Your account deletion has been completed.'**
  String get profileDeletionCompleted;

  /// No description provided for @profileDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Account deletion could not be completed. Please try again.'**
  String get profileDeletionFailed;

  /// No description provided for @profileSavePreferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this preference locally. Please try again.'**
  String get profileSavePreferenceFailed;

  /// No description provided for @profileEditSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to edit your profile.'**
  String get profileEditSignInAgain;

  /// No description provided for @profileNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile name updated.'**
  String get profileNameUpdated;

  /// No description provided for @profileCouldNotUpdateName.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile. Please try again.'**
  String get profileCouldNotUpdateName;

  /// No description provided for @profileChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get profileChooseLanguage;

  /// No description provided for @profileChooseAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred app language.'**
  String get profileChooseAppLanguage;

  /// No description provided for @profileLanguageUpdated.
  ///
  /// In en, this message translates to:
  /// **'App language updated.'**
  String get profileLanguageUpdated;

  /// No description provided for @profileChooseDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Choose a goal you can maintain consistently.'**
  String get profileChooseDailyGoal;

  /// No description provided for @profileDailyGoalSaved.
  ///
  /// In en, this message translates to:
  /// **'Daily goal saved on this device.'**
  String get profileDailyGoalSaved;

  /// No description provided for @profilePrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Evolyn may process account details, learning progress, saved roadmaps, and AI mentor conversations to provide app features.'**
  String get profilePrivacyDescription;

  /// No description provided for @profilePrivacyReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Before release, connect this section to your reviewed privacy policy and explain retention, data access, and deletion options.'**
  String get profilePrivacyReviewNotice;

  /// No description provided for @profileDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get profileDone;

  /// No description provided for @profileGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get profileGotIt;

  /// No description provided for @profileLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of Evolyn?'**
  String get profileLogoutTitle;

  /// No description provided for @profileLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to continue your learning journey.'**
  String get profileLogoutMessage;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// No description provided for @profileLogoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not log out. Please try again.'**
  String get profileLogoutFailed;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// No description provided for @profileDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayName;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileAccountSecurityHeading.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT SECURITY'**
  String get profileAccountSecurityHeading;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new account password'**
  String get profileChangePasswordSubtitle;

  /// No description provided for @profileMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get profileMobileNumber;

  /// No description provided for @profileMobileNumberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or change your verified phone number'**
  String get profileMobileNumberSubtitle;

  /// No description provided for @profileAccountOwnershipHeading.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT OWNERSHIP'**
  String get profileAccountOwnershipHeading;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and associated data'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileDeletionCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'Account deletion cannot be undone. Review the deletion warning and privacy policy before confirming.'**
  String get profileDeletionCannotUndo;

  /// No description provided for @profilePasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 8 characters.'**
  String get profilePasswordMinLength;

  /// No description provided for @profilePasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get profilePasswordsDoNotMatch;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get profileNewPassword;

  /// No description provided for @profileConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get profileConfirmNewPassword;

  /// No description provided for @profileUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get profileUpdatePassword;

  /// No description provided for @profilePhoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profilePhoneNumberLabel;

  /// No description provided for @profilePhoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'+919876543210'**
  String get profilePhoneNumberHint;

  /// No description provided for @profilePhoneCountryCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Include your country code.'**
  String get profilePhoneCountryCodeHelp;

  /// No description provided for @profileInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid international phone number.'**
  String get profileInvalidPhone;

  /// No description provided for @profileSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get profileSendVerificationCode;

  /// No description provided for @profileVerifyMobile.
  ///
  /// In en, this message translates to:
  /// **'Verify mobile number'**
  String get profileVerifyMobile;

  /// No description provided for @profileOtpMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS verification code sent to {phone}.'**
  String profileOtpMessage(String phone);

  /// No description provided for @profileVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get profileVerificationCode;

  /// No description provided for @profileInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit verification code.'**
  String get profileInvalidOtp;

  /// No description provided for @profileVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get profileVerify;

  /// No description provided for @profileWhyLeaving.
  ///
  /// In en, this message translates to:
  /// **'Why are you leaving?'**
  String get profileWhyLeaving;

  /// No description provided for @profileFeedbackOptional.
  ///
  /// In en, this message translates to:
  /// **'Your feedback is optional and helps us improve Evolyn.'**
  String get profileFeedbackOptional;

  /// No description provided for @profileDeleteReasonNoNeed.
  ///
  /// In en, this message translates to:
  /// **'I no longer need this account'**
  String get profileDeleteReasonNoNeed;

  /// No description provided for @profileDeleteReasonUnsatisfied.
  ///
  /// In en, this message translates to:
  /// **'I am not satisfied with the app'**
  String get profileDeleteReasonUnsatisfied;

  /// No description provided for @profileDeleteReasonLearningNeeds.
  ///
  /// In en, this message translates to:
  /// **'The app does not meet my learning needs'**
  String get profileDeleteReasonLearningNeeds;

  /// No description provided for @profileDeleteReasonPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I have privacy or data concerns'**
  String get profileDeleteReasonPrivacy;

  /// No description provided for @profileDeleteReasonTechnical.
  ///
  /// In en, this message translates to:
  /// **'I am experiencing technical problems'**
  String get profileDeleteReasonTechnical;

  /// No description provided for @profileDeleteReasonAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'I created another account'**
  String get profileDeleteReasonAnotherAccount;

  /// No description provided for @profileDeleteReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get profileDeleteReasonOther;

  /// No description provided for @profileAnythingElse.
  ///
  /// In en, this message translates to:
  /// **'Anything else? (optional)'**
  String get profileAnythingElse;

  /// No description provided for @profileFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Share your feedback...'**
  String get profileFeedbackHint;

  /// No description provided for @profileSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason to continue.'**
  String get profileSelectReason;

  /// No description provided for @profileContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileContinue;

  /// No description provided for @dashboardLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your dashboard'**
  String get dashboardLoadErrorTitle;

  /// No description provided for @dashboardLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get dashboardLoadErrorMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @fallbackDisplayName.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get fallbackDisplayName;

  /// No description provided for @roadmapFocus.
  ///
  /// In en, this message translates to:
  /// **'YOUR ROADMAP FOCUS'**
  String get roadmapFocus;

  /// No description provided for @noSavedRoadmap.
  ///
  /// In en, this message translates to:
  /// **'No saved roadmap yet'**
  String get noSavedRoadmap;

  /// No description provided for @chooseCareersDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose careers in Career Recommendations and generate a roadmap. Your saved plan will appear here.'**
  String get chooseCareersDescription;

  /// No description provided for @openRoadmap.
  ///
  /// In en, this message translates to:
  /// **'Open roadmap'**
  String get openRoadmap;

  /// No description provided for @nextActions.
  ///
  /// In en, this message translates to:
  /// **'Next actions'**
  String get nextActions;

  /// Number of planned tasks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No planned tasks} =1{1 planned task} other{{count} planned tasks}}'**
  String plannedTasks(num count);

  /// No description provided for @nextStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your next steps will appear here'**
  String get nextStepsTitle;

  /// No description provided for @nextStepsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate and save a roadmap to see tasks tailored to your selected careers.'**
  String get nextStepsSubtitle;

  /// No description provided for @noTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks were found in this roadmap'**
  String get noTasksTitle;

  /// No description provided for @noTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open your roadmap and check that its phases include tasks.'**
  String get noTasksSubtitle;

  /// No description provided for @allTasksCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'All tasks completed!'**
  String get allTasksCompletedTitle;

  /// No description provided for @allTasksCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You have completed every task in your roadmap. New tasks will appear here when added.'**
  String get allTasksCompletedSubtitle;

  /// No description provided for @fallbackTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Roadmap task'**
  String get fallbackTaskTitle;

  /// No description provided for @fallbackTaskCategory.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get fallbackTaskCategory;

  /// No description provided for @fallbackPhaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Roadmap'**
  String get fallbackPhaseTitle;

  /// No description provided for @fallbackRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Your career roadmap'**
  String get fallbackRoadmapTitle;

  /// No description provided for @oneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get oneHour;

  /// Estimated duration in hours
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String hours(num count);

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String weekNumber(num week);

  /// No description provided for @liveInProgress.
  ///
  /// In en, this message translates to:
  /// **'LIVE · IN PROGRESS'**
  String get liveInProgress;

  /// No description provided for @sessionFinishedResume.
  ///
  /// In en, this message translates to:
  /// **'SESSION FINISHED · RESUME'**
  String get sessionFinishedResume;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get inProgress;

  /// No description provided for @roadmapPhases.
  ///
  /// In en, this message translates to:
  /// **'ROADMAP PHASES'**
  String get roadmapPhases;

  /// No description provided for @stagesInPlan.
  ///
  /// In en, this message translates to:
  /// **'Stages in your plan'**
  String get stagesInPlan;

  /// No description provided for @timeHorizon.
  ///
  /// In en, this message translates to:
  /// **'TIME HORIZON'**
  String get timeHorizon;

  /// No description provided for @monthsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} mo'**
  String monthsShort(num count);

  /// No description provided for @plannedLearningPeriod.
  ///
  /// In en, this message translates to:
  /// **'Planned learning period'**
  String get plannedLearningPeriod;

  /// No description provided for @nextMilestone.
  ///
  /// In en, this message translates to:
  /// **'NEXT MILESTONE'**
  String get nextMilestone;

  /// No description provided for @nextMilestoneWeek.
  ///
  /// In en, this message translates to:
  /// **'NEXT MILESTONE · WEEK {week}'**
  String nextMilestoneWeek(num week);

  /// No description provided for @nextMilestoneFallback.
  ///
  /// In en, this message translates to:
  /// **'Next milestone'**
  String get nextMilestoneFallback;

  /// No description provided for @categoryProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get categoryProject;

  /// No description provided for @categoryReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get categoryReview;

  /// No description provided for @categoryPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get categoryPractice;

  /// No description provided for @categoryFoundation.
  ///
  /// In en, this message translates to:
  /// **'Foundation'**
  String get categoryFoundation;

  /// No description provided for @categoryCareerSkill.
  ///
  /// In en, this message translates to:
  /// **'Career skill'**
  String get categoryCareerSkill;

  /// No description provided for @roadmapScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Your roadmap'**
  String get roadmapScreenTitle;

  /// No description provided for @editRoadmap.
  ///
  /// In en, this message translates to:
  /// **'Edit roadmap'**
  String get editRoadmap;

  /// No description provided for @personalizedRoadmap.
  ///
  /// In en, this message translates to:
  /// **'PERSONALIZED ROADMAP'**
  String get personalizedRoadmap;

  /// No description provided for @roadmapTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Roadmap title'**
  String get roadmapTitleLabel;

  /// No description provided for @overviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overviewLabel;

  /// No description provided for @planningHorizonMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month planning horizon} other{{count} months planning horizon}}'**
  String planningHorizonMonths(num count);

  /// No description provided for @weeksPlanned.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks planned'**
  String weeksPlanned(num count);

  /// No description provided for @tasksChecked.
  ///
  /// In en, this message translates to:
  /// **'{percent}% tasks checked'**
  String tasksChecked(num percent);

  /// No description provided for @phasesLabel.
  ///
  /// In en, this message translates to:
  /// **'PHASES'**
  String get phasesLabel;

  /// No description provided for @timelineStages.
  ///
  /// In en, this message translates to:
  /// **'timeline stages'**
  String get timelineStages;

  /// No description provided for @milestonesLabel.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestonesLabel;

  /// No description provided for @targetOutcomes.
  ///
  /// In en, this message translates to:
  /// **'target outcomes'**
  String get targetOutcomes;

  /// No description provided for @tasksLabel.
  ///
  /// In en, this message translates to:
  /// **'TASKS'**
  String get tasksLabel;

  /// No description provided for @plannedActions.
  ///
  /// In en, this message translates to:
  /// **'planned actions'**
  String get plannedActions;

  /// No description provided for @yourTimeline.
  ///
  /// In en, this message translates to:
  /// **'Your timeline'**
  String get yourTimeline;

  /// No description provided for @phaseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} phases'**
  String phaseCount(num count);

  /// No description provided for @phaseNumber.
  ///
  /// In en, this message translates to:
  /// **'PHASE {number}'**
  String phaseNumber(num number);

  /// No description provided for @weekRange.
  ///
  /// In en, this message translates to:
  /// **'WEEK {start}–{end}'**
  String weekRange(num start, num end);

  /// No description provided for @phaseTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Phase title'**
  String get phaseTitleLabel;

  /// No description provided for @phaseFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Phase {number}'**
  String phaseFallbackTitle(num number);

  /// No description provided for @objectiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get objectiveLabel;

  /// No description provided for @taskCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{tasks} tasks · {completed} completed'**
  String taskCountSummary(num tasks, num completed);

  /// No description provided for @durationWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks'**
  String durationWeeks(num count);

  /// No description provided for @startWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Start week'**
  String get startWeekLabel;

  /// No description provided for @endWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'End week'**
  String get endWeekLabel;

  /// No description provided for @durationWeeksLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (weeks)'**
  String get durationWeeksLabel;

  /// No description provided for @expectedOutcomes.
  ///
  /// In en, this message translates to:
  /// **'Expected outcomes'**
  String get expectedOutcomes;

  /// No description provided for @outcomeNumber.
  ///
  /// In en, this message translates to:
  /// **'Outcome {number}'**
  String outcomeNumber(num number);

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @milestoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get milestoneLabel;

  /// No description provided for @milestoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Milestone {number}'**
  String milestoneNumber(num number);

  /// No description provided for @targetWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Target week'**
  String get targetWeekLabel;

  /// No description provided for @tasksAndDeliverables.
  ///
  /// In en, this message translates to:
  /// **'Tasks and deliverables'**
  String get tasksAndDeliverables;

  /// No description provided for @reviewCheckpoint.
  ///
  /// In en, this message translates to:
  /// **'REVIEW CHECKPOINT'**
  String get reviewCheckpoint;

  /// No description provided for @reviewCheckpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Review checkpoint'**
  String get reviewCheckpointLabel;

  /// No description provided for @careerAlignment.
  ///
  /// In en, this message translates to:
  /// **'Career alignment'**
  String get careerAlignment;

  /// No description provided for @selectedCareer.
  ///
  /// In en, this message translates to:
  /// **'Selected career'**
  String get selectedCareer;

  /// No description provided for @careerAlignmentDescription.
  ///
  /// In en, this message translates to:
  /// **'How this phase supports the career'**
  String get careerAlignmentDescription;

  /// No description provided for @taskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitleLabel;

  /// No description provided for @taskNumber.
  ///
  /// In en, this message translates to:
  /// **'Task {number}'**
  String taskNumber(num number);

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @estimatedHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated hours'**
  String get estimatedHoursLabel;

  /// No description provided for @dueWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Due week'**
  String get dueWeekLabel;

  /// No description provided for @hoursUnit.
  ///
  /// In en, this message translates to:
  /// **'{count} HOURS'**
  String hoursUnit(num count);

  /// No description provided for @dueWeekValue.
  ///
  /// In en, this message translates to:
  /// **'DUE WEEK {week}'**
  String dueWeekValue(num week);

  /// No description provided for @deliverableLabel.
  ///
  /// In en, this message translates to:
  /// **'Deliverable'**
  String get deliverableLabel;

  /// No description provided for @successCriteriaLabel.
  ///
  /// In en, this message translates to:
  /// **'Success criteria'**
  String get successCriteriaLabel;

  /// No description provided for @weeklyRhythm.
  ///
  /// In en, this message translates to:
  /// **'Weekly rhythm'**
  String get weeklyRhythm;

  /// No description provided for @weeklyRhythmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A sustainable way to distribute your time'**
  String get weeklyRhythmSubtitle;

  /// No description provided for @hoursPerWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours per week'**
  String get hoursPerWeekLabel;

  /// No description provided for @timeBlockLabel.
  ///
  /// In en, this message translates to:
  /// **'Time block'**
  String get timeBlockLabel;

  /// No description provided for @blockNumber.
  ///
  /// In en, this message translates to:
  /// **'Block {number}'**
  String blockNumber(num number);

  /// No description provided for @activityLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityLabel;

  /// No description provided for @hoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hoursLabel;

  /// No description provided for @progressTracking.
  ///
  /// In en, this message translates to:
  /// **'Progress tracking'**
  String get progressTracking;

  /// No description provided for @progressTrackingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How to review whether the roadmap is working'**
  String get progressTrackingSubtitle;

  /// No description provided for @reviewFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Review frequency'**
  String get reviewFrequencyLabel;

  /// No description provided for @metricNumber.
  ///
  /// In en, this message translates to:
  /// **'Metric {number}'**
  String metricNumber(num number);

  /// No description provided for @nextActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get nextActionLabel;

  /// No description provided for @risksAndAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Risks and adjustments'**
  String get risksAndAdjustments;

  /// No description provided for @risksAndAdjustmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan for setbacks without losing momentum'**
  String get risksAndAdjustmentsSubtitle;

  /// No description provided for @riskLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get riskLabel;

  /// No description provided for @mitigationLabel.
  ///
  /// In en, this message translates to:
  /// **'Mitigation'**
  String get mitigationLabel;

  /// No description provided for @whenToAdjustLabel.
  ///
  /// In en, this message translates to:
  /// **'When to adjust'**
  String get whenToAdjustLabel;

  /// No description provided for @assumptions.
  ///
  /// In en, this message translates to:
  /// **'Assumptions'**
  String get assumptions;

  /// No description provided for @assumptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Details used where your profile did not specify a preference'**
  String get assumptionsSubtitle;

  /// No description provided for @assumptionNumber.
  ///
  /// In en, this message translates to:
  /// **'Assumption {number}'**
  String assumptionNumber(num number);

  /// No description provided for @editRoadmapHint.
  ///
  /// In en, this message translates to:
  /// **'Edit the text and timeline fields above, then save your changes. Numeric timeline values must remain valid numbers.'**
  String get editRoadmapHint;

  /// No description provided for @viewRoadmapHint.
  ///
  /// In en, this message translates to:
  /// **'You can edit phase details, milestones, tasks and schedule before entering Evolyn. Save your changes to keep the roadmap in sync.'**
  String get viewRoadmapHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @saveProgress.
  ///
  /// In en, this message translates to:
  /// **'Save progress'**
  String get saveProgress;

  /// No description provided for @signInToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sign in to refresh your roadmap.'**
  String get signInToRefresh;

  /// No description provided for @waitUntilSavingFinishes.
  ///
  /// In en, this message translates to:
  /// **'Please wait until saving finishes.'**
  String get waitUntilSavingFinishes;

  /// No description provided for @saveOrCancelBeforeRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Save or cancel your edits before refreshing.'**
  String get saveOrCancelBeforeRefreshing;

  /// No description provided for @noSavedRoadmapFound.
  ///
  /// In en, this message translates to:
  /// **'No saved roadmap was found.'**
  String get noSavedRoadmapFound;

  /// No description provided for @refreshRoadmapError.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh your roadmap. Please try again.'**
  String get refreshRoadmapError;

  /// No description provided for @signInBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Please sign in before saving your roadmap.'**
  String get signInBeforeSaving;

  /// No description provided for @noPhasesToSave.
  ///
  /// In en, this message translates to:
  /// **'There are no roadmap phases to save.'**
  String get noPhasesToSave;

  /// No description provided for @invalidPhaseWeekRange.
  ///
  /// In en, this message translates to:
  /// **'Phase {number} has an invalid week range. Please check its timeline fields.'**
  String invalidPhaseWeekRange(num number);

  /// No description provided for @invalidTaskSchedule.
  ///
  /// In en, this message translates to:
  /// **'A task in phase {number} has an invalid due week or estimate.'**
  String invalidTaskSchedule(num number);

  /// No description provided for @roadmapNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'The saved roadmap could not be found or updated for this user.'**
  String get roadmapNotUpdated;

  /// No description provided for @saveRoadmapError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your roadmap. Check your connection and database permissions, then retry.'**
  String get saveRoadmapError;

  /// No description provided for @roadmapProgressSaved.
  ///
  /// In en, this message translates to:
  /// **'Roadmap progress saved.'**
  String get roadmapProgressSaved;

  /// No description provided for @roadmapChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'Roadmap changes saved.'**
  String get roadmapChangesSaved;

  /// No description provided for @mentorLoadingConversation.
  ///
  /// In en, this message translates to:
  /// **'Loading your conversation…'**
  String get mentorLoadingConversation;

  /// No description provided for @mentorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI mentor'**
  String get mentorSubtitle;

  /// No description provided for @mentorOptions.
  ///
  /// In en, this message translates to:
  /// **'Mentor options'**
  String get mentorOptions;

  /// No description provided for @mentorCurrentFocus.
  ///
  /// In en, this message translates to:
  /// **'YOUR CURRENT FOCUS'**
  String get mentorCurrentFocus;

  /// No description provided for @mentorAskNextStep.
  ///
  /// In en, this message translates to:
  /// **'Ask AARYA to plan your next step'**
  String get mentorAskNextStep;

  /// No description provided for @mentorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mentorRetry;

  /// No description provided for @mentorConversationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Conversation unavailable.'**
  String get mentorConversationUnavailable;

  /// No description provided for @mentorConversationHistory.
  ///
  /// In en, this message translates to:
  /// **'Conversation history'**
  String get mentorConversationHistory;

  /// No description provided for @mentorNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get mentorNoConversations;

  /// No description provided for @mentorStartNewConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation'**
  String get mentorStartNewConversation;

  /// No description provided for @mentorNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get mentorNewConversation;

  /// No description provided for @mentorOpenPreviousChat.
  ///
  /// In en, this message translates to:
  /// **'Open a previous chat'**
  String get mentorOpenPreviousChat;

  /// No description provided for @mentorStartSeparateChat.
  ///
  /// In en, this message translates to:
  /// **'Start a separate chat'**
  String get mentorStartSeparateChat;

  /// No description provided for @mentorRefreshMessages.
  ///
  /// In en, this message translates to:
  /// **'Refresh messages'**
  String get mentorRefreshMessages;

  /// No description provided for @mentorSyncChat.
  ///
  /// In en, this message translates to:
  /// **'Sync this chat with the server'**
  String get mentorSyncChat;

  /// No description provided for @mentorWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'What are we working on today?'**
  String get mentorWelcomeTitle;

  /// No description provided for @mentorWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask for help with a concept, a project, an interview, or your next roadmap task.'**
  String get mentorWelcomeDescription;

  /// No description provided for @mentorConversationDivider.
  ///
  /// In en, this message translates to:
  /// **'YOUR AARYA CONVERSATION'**
  String get mentorConversationDivider;

  /// No description provided for @mentorTyping.
  ///
  /// In en, this message translates to:
  /// **'Typing…'**
  String get mentorTyping;

  /// No description provided for @mentorSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get mentorSending;

  /// No description provided for @mentorThinking.
  ///
  /// In en, this message translates to:
  /// **'AARYA is thinking…'**
  String get mentorThinking;

  /// No description provided for @mentorSuggestedRoadmapTask.
  ///
  /// In en, this message translates to:
  /// **'Help with my next roadmap task'**
  String get mentorSuggestedRoadmapTask;

  /// No description provided for @mentorSuggestedExplainConcept.
  ///
  /// In en, this message translates to:
  /// **'Explain a concept simply'**
  String get mentorSuggestedExplainConcept;

  /// No description provided for @mentorSuggestedStudySession.
  ///
  /// In en, this message translates to:
  /// **'Plan a study session'**
  String get mentorSuggestedStudySession;

  /// No description provided for @mentorSuggestedInterview.
  ///
  /// In en, this message translates to:
  /// **'Practice an interview'**
  String get mentorSuggestedInterview;

  /// No description provided for @mentorInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask AARYA anything…'**
  String get mentorInputHint;

  /// No description provided for @mentorWaitingForReply.
  ///
  /// In en, this message translates to:
  /// **'Waiting for AARYA…'**
  String get mentorWaitingForReply;

  /// No description provided for @mentorConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to your chat…'**
  String get mentorConnecting;

  /// No description provided for @mentorSignInToChat.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to chat with AARYA.'**
  String get mentorSignInToChat;

  /// No description provided for @mentorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to your conversations. Check your connection and retry.'**
  String get mentorConnectionFailed;

  /// No description provided for @mentorOfflineConversation.
  ///
  /// In en, this message translates to:
  /// **'Offline mode: showing your locally saved conversation.'**
  String get mentorOfflineConversation;

  /// No description provided for @mentorHistoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load chat history. Check your connection.'**
  String get mentorHistoryLoadFailed;

  /// No description provided for @mentorOfflineMessages.
  ///
  /// In en, this message translates to:
  /// **'Offline mode: showing locally saved messages.'**
  String get mentorOfflineMessages;

  /// No description provided for @mentorMessageTooLong.
  ///
  /// In en, this message translates to:
  /// **'Please keep each message under 4,000 characters.'**
  String get mentorMessageTooLong;

  /// No description provided for @mentorNoActiveConversation.
  ///
  /// In en, this message translates to:
  /// **'No active conversation is available. Sign in and retry.'**
  String get mentorNoActiveConversation;

  /// No description provided for @mentorMissingSavedReply.
  ///
  /// In en, this message translates to:
  /// **'AARYA finished, but the saved reply was missing.'**
  String get mentorMissingSavedReply;

  /// No description provided for @mentorResponseFailed.
  ///
  /// In en, this message translates to:
  /// **'AARYA could not finish the response. Please try again.'**
  String get mentorResponseFailed;

  /// No description provided for @mentorApiKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Supabase API key is unavailable. Check Supabase initialization.'**
  String get mentorApiKeyUnavailable;

  /// No description provided for @mentorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'AARYA returned an invalid response.'**
  String get mentorInvalidResponse;

  /// No description provided for @mentorReplyMissing.
  ///
  /// In en, this message translates to:
  /// **'AARYA reply was missing.'**
  String get mentorReplyMissing;

  /// No description provided for @mentorStreamEndedEarly.
  ///
  /// In en, this message translates to:
  /// **'The response stream ended before AARYA saved its reply.'**
  String get mentorStreamEndedEarly;

  /// No description provided for @mentorGenericReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'AARYA could not reply. Check your connection and try again.'**
  String get mentorGenericReplyFailed;

  /// No description provided for @mentorRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'AARYA request failed (HTTP {statusCode}). Please try again.'**
  String mentorRequestFailed(int statusCode);

  /// No description provided for @mentorCreateConversationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start a new conversation. Please retry.'**
  String get mentorCreateConversationFailed;

  /// No description provided for @mentorHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load conversation history. Please retry.'**
  String get mentorHistoryFailed;

  /// No description provided for @mentorSavedConversation.
  ///
  /// In en, this message translates to:
  /// **'Saved conversation'**
  String get mentorSavedConversation;

  /// No description provided for @mentorNewConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get mentorNewConversationTitle;

  /// No description provided for @mentorDefaultConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get mentorDefaultConversationTitle;

  /// No description provided for @mentorAskNextTaskPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me work through my next roadmap task: \"{taskTitle}\". Break it into small practical steps and ask me one question if you need more context.'**
  String mentorAskNextTaskPrompt(String taskTitle);

  /// No description provided for @mentorChooseNextStepPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me choose a practical next learning step based on my career goals.'**
  String get mentorChooseNextStepPrompt;

  /// No description provided for @mentorSuggestedTaskPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me work through my next roadmap task: \"{taskTitle}\". Give me clear, practical steps.'**
  String mentorSuggestedTaskPrompt(String taskTitle);

  /// No description provided for @mentorExplainConceptPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me understand a technical concept using a simple example. Ask which concept if needed.'**
  String get mentorExplainConceptPrompt;

  /// No description provided for @mentorStudySessionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me plan a focused study session that fits my next roadmap task.'**
  String get mentorStudySessionPrompt;

  /// No description provided for @mentorInterviewPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me practise a technical interview. Ask one question at a time and give constructive feedback.'**
  String get mentorInterviewPrompt;

  /// No description provided for @learnSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your learning path.'**
  String get learnSignInPrompt;

  /// No description provided for @learnLoadingErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your learning path'**
  String get learnLoadingErrorTitle;

  /// No description provided for @learnLoadingErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. If you have a cached roadmap, try refreshing again when online.'**
  String get learnLoadingErrorMessage;

  /// No description provided for @learnRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get learnRetry;

  /// No description provided for @learnPreferencesSyncWarning.
  ///
  /// In en, this message translates to:
  /// **'Learning preferences could not be synced. Run the supplied SQL setup for public.learn, then retry. Your roadmap tasks are still shown.'**
  String get learnPreferencesSyncWarning;

  /// No description provided for @learnHeaderEyebrow.
  ///
  /// In en, this message translates to:
  /// **'YOUR LEARNING SPACE'**
  String get learnHeaderEyebrow;

  /// No description provided for @learnHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn and build.'**
  String get learnHeaderTitle;

  /// No description provided for @learnHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Practical next steps from {roadmapTitle}.'**
  String learnHeaderSubtitle(String roadmapTitle);

  /// No description provided for @learnTasksDone.
  ///
  /// In en, this message translates to:
  /// **'Tasks done'**
  String get learnTasksDone;

  /// No description provided for @learnTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time remaining*'**
  String get learnTimeRemaining;

  /// No description provided for @learnSavedTasks.
  ///
  /// In en, this message translates to:
  /// **'Saved tasks'**
  String get learnSavedTasks;

  /// No description provided for @learnProgressFootnote.
  ///
  /// In en, this message translates to:
  /// **'{inProgress} currently in progress · *Based on estimated task hours, not tracked study time.'**
  String learnProgressFootnote(int inProgress);

  /// No description provided for @learnContinueCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE YOUR CURRENT SESSION'**
  String get learnContinueCurrentSession;

  /// No description provided for @learnContinueCurrentTask.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE YOUR TASK'**
  String get learnContinueCurrentTask;

  /// No description provided for @learnNextRoadmapTask.
  ///
  /// In en, this message translates to:
  /// **'YOUR NEXT ROADMAP TASK'**
  String get learnNextRoadmapTask;

  /// No description provided for @learnEstimatedHours.
  ///
  /// In en, this message translates to:
  /// **'{duration} estimated'**
  String learnEstimatedHours(String duration);

  /// No description provided for @learnResumeSession.
  ///
  /// In en, this message translates to:
  /// **'Resume session'**
  String get learnResumeSession;

  /// No description provided for @learnStartNextSession.
  ///
  /// In en, this message translates to:
  /// **'Start next session'**
  String get learnStartNextSession;

  /// No description provided for @learnOpenTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'Open task details'**
  String get learnOpenTaskDetails;

  /// No description provided for @learnAllTasksCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'You completed every roadmap task!'**
  String get learnAllTasksCompleteTitle;

  /// No description provided for @learnAllTasksCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Review your roadmap or add a new career direction when you are ready.'**
  String get learnAllTasksCompleteMessage;

  /// No description provided for @learnSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, skills, phases, deliverables'**
  String get learnSearchHint;

  /// No description provided for @learnFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get learnFilterAll;

  /// No description provided for @learnFilterToDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get learnFilterToDo;

  /// No description provided for @learnFilterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get learnFilterInProgress;

  /// No description provided for @learnFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get learnFilterCompleted;

  /// No description provided for @learnFilterSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get learnFilterSaved;

  /// No description provided for @learnTaskListTitle.
  ///
  /// In en, this message translates to:
  /// **'Your learning tasks'**
  String get learnTaskListTitle;

  /// No description provided for @learnTaskListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real actions from your saved roadmap.'**
  String get learnTaskListSubtitle;

  /// No description provided for @learnVisibleTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{visibleCount} of {totalCount}'**
  String learnVisibleTaskCount(int visibleCount, int totalCount);

  /// No description provided for @learnSaveTask.
  ///
  /// In en, this message translates to:
  /// **'Save task'**
  String get learnSaveTask;

  /// No description provided for @learnRemoveSavedTask.
  ///
  /// In en, this message translates to:
  /// **'Remove saved task'**
  String get learnRemoveSavedTask;

  /// No description provided for @learnDueWeek.
  ///
  /// In en, this message translates to:
  /// **'Due week {week}'**
  String learnDueWeek(int week);

  /// No description provided for @learnResourceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Resource available'**
  String get learnResourceAvailable;

  /// No description provided for @learnStatusToDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get learnStatusToDo;

  /// No description provided for @learnStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get learnStatusInProgress;

  /// No description provided for @learnStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get learnStatusCompleted;

  /// No description provided for @learnNoRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Your learning path starts with a roadmap'**
  String get learnNoRoadmapTitle;

  /// No description provided for @learnNoRoadmapMessage.
  ///
  /// In en, this message translates to:
  /// **'Generate a roadmap from Career Recommendations. Its real tasks will appear here, and you can track them as you work.'**
  String get learnNoRoadmapMessage;

  /// No description provided for @learnNoTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No learning tasks yet'**
  String get learnNoTasksTitle;

  /// No description provided for @learnNoTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved roadmap does not contain any tasks. Open the Roadmap tab to review it or generate an updated roadmap.'**
  String get learnNoTasksMessage;

  /// No description provided for @learnNoMatchingTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get learnNoMatchingTasksTitle;

  /// No description provided for @learnNoMatchingTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or change the status/category filters.'**
  String get learnNoMatchingTasksMessage;

  /// No description provided for @learnSyncNoticeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry sync'**
  String get learnSyncNoticeRetry;

  /// No description provided for @learnAaryaTip.
  ///
  /// In en, this message translates to:
  /// **'AARYA tip: use the deliverable and success criteria in each task to decide when the skill is ready to move into practice.'**
  String get learnAaryaTip;

  /// No description provided for @learnDurationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'How long is this work session?'**
  String get learnDurationDialogTitle;

  /// No description provided for @learnDurationEstimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated total: {estimated}. Already tracked: {tracked}. Choose a session; the final session is shortened to the remaining estimate.'**
  String learnDurationEstimatedTotal(String estimated, String tracked);

  /// No description provided for @learnDurationNoEstimate.
  ///
  /// In en, this message translates to:
  /// **'This task has no time estimate. Choose a session length; you can mark the task complete when you finish the work.'**
  String get learnDurationNoEstimate;

  /// No description provided for @learnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get learnCancel;

  /// No description provided for @learnStartDuration.
  ///
  /// In en, this message translates to:
  /// **'Start {duration}'**
  String learnStartDuration(String duration);

  /// No description provided for @learnTaskDetailsWhatToDo.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get learnTaskDetailsWhatToDo;

  /// No description provided for @learnTaskDetailsDeliverable.
  ///
  /// In en, this message translates to:
  /// **'Deliverable'**
  String get learnTaskDetailsDeliverable;

  /// No description provided for @learnTaskDetailsSuccessCriteria.
  ///
  /// In en, this message translates to:
  /// **'Success criteria'**
  String get learnTaskDetailsSuccessCriteria;

  /// No description provided for @learnPriority.
  ///
  /// In en, this message translates to:
  /// **'{priority} priority'**
  String learnPriority(String priority);

  /// No description provided for @learnLearningResource.
  ///
  /// In en, this message translates to:
  /// **'Learning resource'**
  String get learnLearningResource;

  /// No description provided for @learnOpenLearningResource.
  ///
  /// In en, this message translates to:
  /// **'Open learning resource'**
  String get learnOpenLearningResource;

  /// No description provided for @learnAnotherTaskInProgress.
  ///
  /// In en, this message translates to:
  /// **'\"{taskTitle}\" is already in progress. Complete it before starting another task.'**
  String learnAnotherTaskInProgress(String taskTitle);

  /// No description provided for @learnFinishCurrentSessionFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish current session first'**
  String get learnFinishCurrentSessionFirst;

  /// No description provided for @learnContinueCurrentSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Continue current session'**
  String get learnContinueCurrentSessionButton;

  /// No description provided for @learnStartTask.
  ///
  /// In en, this message translates to:
  /// **'Start task'**
  String get learnStartTask;

  /// No description provided for @learnReopenTask.
  ///
  /// In en, this message translates to:
  /// **'Reopen task'**
  String get learnReopenTask;

  /// No description provided for @learnFinishSessionEarly.
  ///
  /// In en, this message translates to:
  /// **'Finish session early'**
  String get learnFinishSessionEarly;

  /// No description provided for @learnMarkTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark task as completed'**
  String get learnMarkTaskCompleted;

  /// No description provided for @learnInvalidResourceUrl.
  ///
  /// In en, this message translates to:
  /// **'This learning resource has an invalid URL.'**
  String get learnInvalidResourceUrl;

  /// No description provided for @learnCouldNotOpenResource.
  ///
  /// In en, this message translates to:
  /// **'Could not open this learning resource.'**
  String get learnCouldNotOpenResource;

  /// No description provided for @learnTimerPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow Evolyn to display over other apps to show the floating timer.'**
  String get learnTimerPermissionMessage;

  /// No description provided for @learnOverlayPrepareError.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the floating timer. Check Display over other apps permission.'**
  String get learnOverlayPrepareError;

  /// No description provided for @learnNotificationTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Evolyn • Task in progress'**
  String get learnNotificationTimerTitle;

  /// No description provided for @learnNotificationTimerChannel.
  ///
  /// In en, this message translates to:
  /// **'Active task timer'**
  String get learnNotificationTimerChannel;

  /// No description provided for @learnNotificationTimerChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows the countdown for your active learning task'**
  String get learnNotificationTimerChannelDescription;

  /// No description provided for @learnNotificationFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Task time is up!'**
  String get learnNotificationFinishedTitle;

  /// No description provided for @learnNotificationFinishedBody.
  ///
  /// In en, this message translates to:
  /// **'\"{taskTitle}\" reached the end of its {duration} session.'**
  String learnNotificationFinishedBody(String taskTitle, String duration);

  /// No description provided for @learnNotificationFinishedChannel.
  ///
  /// In en, this message translates to:
  /// **'Task timer finished'**
  String get learnNotificationFinishedChannel;

  /// No description provided for @learnNotificationFinishedChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts when a learning task reaches its time limit'**
  String get learnNotificationFinishedChannelDescription;

  /// No description provided for @learnNotificationPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Could not show the task timer. Check notification permissions.'**
  String get learnNotificationPermissionError;

  /// No description provided for @learnSessionTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Session time is up'**
  String get learnSessionTimeUp;

  /// No description provided for @learnSessionTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Session time left {countdown}'**
  String learnSessionTimeLeft(String countdown);

  /// No description provided for @learnTrackedEstimatedLeft.
  ///
  /// In en, this message translates to:
  /// **'{tracked} tracked · {remaining} estimated time left'**
  String learnTrackedEstimatedLeft(String tracked, String remaining);

  /// No description provided for @learnTrackedStartAnother.
  ///
  /// In en, this message translates to:
  /// **'{tracked} tracked · start another session'**
  String learnTrackedStartAnother(String tracked);

  /// No description provided for @learnReadyToStartSession.
  ///
  /// In en, this message translates to:
  /// **'Ready to start a session'**
  String get learnReadyToStartSession;

  /// No description provided for @learnTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time {duration}'**
  String learnTotalTime(String duration);

  /// No description provided for @learnTrackedSoFar.
  ///
  /// In en, this message translates to:
  /// **'{duration} tracked so far'**
  String learnTrackedSoFar(String duration);

  /// No description provided for @learnTaskRemovedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Task removed from saved items.'**
  String get learnTaskRemovedFromSaved;

  /// No description provided for @learnTaskSavedForLater.
  ///
  /// In en, this message translates to:
  /// **'Task saved for later.'**
  String get learnTaskSavedForLater;

  /// No description provided for @learnBookmarkSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this task. Check your connection and learn table permissions.'**
  String get learnBookmarkSaveError;

  /// No description provided for @learnRoadmapTimeSavedLearnSyncError.
  ///
  /// In en, this message translates to:
  /// **'Roadmap time was saved, but learning preferences could not sync. Check the learn table setup.'**
  String get learnRoadmapTimeSavedLearnSyncError;

  /// No description provided for @learnTaskCompletedEstimateReached.
  ///
  /// In en, this message translates to:
  /// **'Task completed. Its estimated total time has been reached.'**
  String get learnTaskCompletedEstimateReached;

  /// No description provided for @learnSessionSavedTrackedOfEstimate.
  ///
  /// In en, this message translates to:
  /// **'Session saved. {tracked} tracked of {estimated}. Start another session to continue.'**
  String learnSessionSavedTrackedOfEstimate(String tracked, String estimated);

  /// No description provided for @learnSessionSavedNoEstimate.
  ///
  /// In en, this message translates to:
  /// **'Session saved ({tracked} tracked). Open the task to start another session or mark it complete.'**
  String learnSessionSavedNoEstimate(String tracked);

  /// No description provided for @learnTaskMarkedCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task marked as completed.'**
  String get learnTaskMarkedCompleted;

  /// No description provided for @learnTaskReopened.
  ///
  /// In en, this message translates to:
  /// **'Task reopened. Time tracking starts a new cycle.'**
  String get learnTaskReopened;

  /// No description provided for @learnSessionStarted.
  ///
  /// In en, this message translates to:
  /// **'Session started for {duration}.'**
  String learnSessionStarted(String duration);

  /// No description provided for @learnSessionResumed.
  ///
  /// In en, this message translates to:
  /// **'Session resumed.'**
  String get learnSessionResumed;

  /// No description provided for @learnTaskSessionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the task session. Please retry.'**
  String get learnTaskSessionSaveError;

  /// No description provided for @learnAnotherTaskStarting.
  ///
  /// In en, this message translates to:
  /// **'Another task is starting. Please wait.'**
  String get learnAnotherTaskStarting;

  /// No description provided for @learnFinishTaskBeforeStartingAnother.
  ///
  /// In en, this message translates to:
  /// **'Finish \"{taskTitle}\" before starting another task.'**
  String learnFinishTaskBeforeStartingAnother(String taskTitle);

  /// No description provided for @learnTaskPhaseFallback.
  ///
  /// In en, this message translates to:
  /// **'Phase {phaseNumber}'**
  String learnTaskPhaseFallback(int phaseNumber);

  /// No description provided for @learnTaskFallback.
  ///
  /// In en, this message translates to:
  /// **'Task {taskNumber}'**
  String learnTaskFallback(int taskNumber);

  /// No description provided for @learnGeneralCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get learnGeneralCategory;

  /// No description provided for @learnInvalidRoadmapId.
  ///
  /// In en, this message translates to:
  /// **'The saved roadmap ID is missing.'**
  String get learnInvalidRoadmapId;

  /// No description provided for @learnRoadmapPhaseChanged.
  ///
  /// In en, this message translates to:
  /// **'The roadmap phase changed. Refresh and try again.'**
  String get learnRoadmapPhaseChanged;

  /// No description provided for @learnRoadmapTaskChanged.
  ///
  /// In en, this message translates to:
  /// **'The roadmap task changed. Refresh and try again.'**
  String get learnRoadmapTaskChanged;

  /// No description provided for @learnDurationMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Session duration must be positive.'**
  String get learnDurationMustBePositive;

  /// No description provided for @learnRoadmapUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'The roadmap was not found or could not be updated for this user.'**
  String get learnRoadmapUpdateFailed;

  /// No description provided for @learnUnsupportedTaskAction.
  ///
  /// In en, this message translates to:
  /// **'Unsupported task action'**
  String get learnUnsupportedTaskAction;

  /// No description provided for @learnTimerOverlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Floating timer failed'**
  String get learnTimerOverlayFailed;

  /// No description provided for @learnOverlayDataDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Overlay data delivery failed'**
  String get learnOverlayDataDeliveryFailed;

  /// No description provided for @learnCloseTimerFailed.
  ///
  /// In en, this message translates to:
  /// **'Close timer failed'**
  String get learnCloseTimerFailed;

  /// No description provided for @learnCouldNotShowOverlay.
  ///
  /// In en, this message translates to:
  /// **'Could not show floating timer'**
  String get learnCouldNotShowOverlay;

  /// No description provided for @learnNotificationInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Notification initialization failed'**
  String get learnNotificationInitializationFailed;

  /// No description provided for @learnCouldNotScheduleTimer.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule task timer'**
  String get learnCouldNotScheduleTimer;

  /// No description provided for @learnCouldNotCancelNotifications.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel timer notifications'**
  String get learnCouldNotCancelNotifications;

  /// No description provided for @learnStartSoundFailed.
  ///
  /// In en, this message translates to:
  /// **'Start sound failed'**
  String get learnStartSoundFailed;

  /// No description provided for @learnFinishedSoundFailed.
  ///
  /// In en, this message translates to:
  /// **'Finished sound failed'**
  String get learnFinishedSoundFailed;

  /// No description provided for @learnExpiredTaskCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Expired task check failed'**
  String get learnExpiredTaskCheckFailed;

  /// No description provided for @learnResourceLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Resource launch failed'**
  String get learnResourceLaunchFailed;

  /// No description provided for @learnBookmarkSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Bookmark save failed'**
  String get learnBookmarkSaveFailed;

  /// No description provided for @learnLearnStateMirrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Learn state mirror failed'**
  String get learnLearnStateMirrorFailed;

  /// No description provided for @learnTaskStatusSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Task status save failed'**
  String get learnTaskStatusSaveFailed;

  /// No description provided for @learnRoadmapRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Roadmap refresh failed'**
  String get learnRoadmapRefreshFailed;

  /// No description provided for @learnLearnRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Learn refresh failed'**
  String get learnLearnRefreshFailed;

  /// No description provided for @progressEyebrow.
  ///
  /// In en, this message translates to:
  /// **'YOUR GROWTH, IN VIEW'**
  String get progressEyebrow;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get progressTitle;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your progress.'**
  String get signInPrompt;

  /// No description provided for @loadProgressError.
  ///
  /// In en, this message translates to:
  /// **'Could not load progress'**
  String get loadProgressError;

  /// No description provided for @connectionRetry.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get connectionRetry;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon!'**
  String get comingSoon;

  /// No description provided for @noRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved roadmap yet'**
  String get noRoadmapTitle;

  /// No description provided for @noRoadmapDescription.
  ///
  /// In en, this message translates to:
  /// **'Generate a roadmap from Career Recommendations. Its phases, tasks, and milestones will appear here after they are saved.'**
  String get noRoadmapDescription;

  /// No description provided for @currentRoadmap.
  ///
  /// In en, this message translates to:
  /// **'CURRENT ROADMAP'**
  String get currentRoadmap;

  /// No description provided for @phasesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} phases'**
  String phasesCount(int count);

  /// No description provided for @tasksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String tasksCount(int count);

  /// No description provided for @milestonesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} milestones'**
  String milestonesCount(int count);

  /// No description provided for @tasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} tasks completed'**
  String tasksCompleted(int completed, int total);

  /// No description provided for @timeSpentTitle.
  ///
  /// In en, this message translates to:
  /// **'Time spent on each task'**
  String get timeSpentTitle;

  /// No description provided for @timeSpentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your tracked time for every task in the saved roadmap.'**
  String get timeSpentSubtitle;

  /// No description provided for @roadmapMilestonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Roadmap milestones'**
  String get roadmapMilestonesTitle;

  /// No description provided for @roadmapMilestonesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Milestones saved with your current roadmap.'**
  String get roadmapMilestonesSubtitle;

  /// No description provided for @completedTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks'**
  String get completedTasksTitle;

  /// No description provided for @completedTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only tasks with a saved completion state appear here.'**
  String get completedTasksSubtitle;

  /// No description provided for @totalTrackedTime.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TRACKED TIME'**
  String get totalTrackedTime;

  /// No description provided for @notRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'Not recorded yet'**
  String get notRecordedYet;

  /// No description provided for @trackedCount.
  ///
  /// In en, this message translates to:
  /// **'{tracked}/{total} tracked'**
  String trackedCount(int tracked, int total);

  /// No description provided for @sessionHistory.
  ///
  /// In en, this message translates to:
  /// **'SESSION HISTORY'**
  String get sessionHistory;

  /// No description provided for @savedSessionTimeline.
  ///
  /// In en, this message translates to:
  /// **'SAVED SESSION TIMELINE ({count})'**
  String savedSessionTimeline(Object count);

  /// No description provided for @currentSessionTimeline.
  ///
  /// In en, this message translates to:
  /// **'CURRENT SESSION TIMELINE'**
  String get currentSessionTimeline;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @targetEnd.
  ///
  /// In en, this message translates to:
  /// **'Target end'**
  String get targetEnd;

  /// No description provided for @ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ended;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completed;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'PLANNED'**
  String get planned;

  /// No description provided for @taskTotal.
  ///
  /// In en, this message translates to:
  /// **'TASK TOTAL'**
  String get taskTotal;

  /// No description provided for @sessionDuration.
  ///
  /// In en, this message translates to:
  /// **'SESSION DURATION'**
  String get sessionDuration;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get dateLabel;

  /// No description provided for @sessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session {number}'**
  String sessionLabel(int number);

  /// No description provided for @liveDuration.
  ///
  /// In en, this message translates to:
  /// **'LIVE · {duration}'**
  String liveDuration(String duration);

  /// No description provided for @noTime.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get noTime;

  /// No description provided for @noTasksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tasks available'**
  String get noTasksAvailable;

  /// No description provided for @noTasksSaved.
  ///
  /// In en, this message translates to:
  /// **'No tasks are saved in this roadmap yet.'**
  String get noTasksSaved;

  /// No description provided for @noMilestonesSaved.
  ///
  /// In en, this message translates to:
  /// **'No milestones saved'**
  String get noMilestonesSaved;

  /// No description provided for @noMilestonesDescription.
  ///
  /// In en, this message translates to:
  /// **'Milestones will appear once they are included in your roadmap.'**
  String get noMilestonesDescription;

  /// No description provided for @noCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks recorded yet'**
  String get noCompletedTasks;

  /// No description provided for @completionNotTracked.
  ///
  /// In en, this message translates to:
  /// **'Task completion is not tracked yet'**
  String get completionNotTracked;

  /// No description provided for @completionSavedDescription.
  ///
  /// In en, this message translates to:
  /// **'Completed work will appear here after its completion state is saved.'**
  String get completionSavedDescription;

  /// No description provided for @completionMissingDescription.
  ///
  /// In en, this message translates to:
  /// **'Your saved roadmap contains planned tasks, but the current data does not include completion records. This screen will show real wins when task completion is persisted.'**
  String get completionMissingDescription;

  /// No description provided for @aaryaNote.
  ///
  /// In en, this message translates to:
  /// **'A note from AARYA'**
  String get aaryaNote;

  /// No description provided for @plannedEffort.
  ///
  /// In en, this message translates to:
  /// **'Planned effort'**
  String get plannedEffort;

  /// No description provided for @estimatedTaskHours.
  ///
  /// In en, this message translates to:
  /// **'Estimated task hours'**
  String get estimatedTaskHours;

  /// No description provided for @inSavedRoadmap.
  ///
  /// In en, this message translates to:
  /// **'In saved roadmap'**
  String get inSavedRoadmap;

  /// No description provided for @completionTracking.
  ///
  /// In en, this message translates to:
  /// **'Completion tracking'**
  String get completionTracking;

  /// No description provided for @savedCompletionStates.
  ///
  /// In en, this message translates to:
  /// **'Saved completion states'**
  String get savedCompletionStates;

  /// No description provided for @taskCompletionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Task completion is not yet recorded for every task.'**
  String get taskCompletionUnavailable;

  /// No description provided for @noTasksInRoadmap.
  ///
  /// In en, this message translates to:
  /// **'No tasks are saved in this roadmap yet.'**
  String get noTasksInRoadmap;

  /// No description provided for @startTimeNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Start date/time not saved'**
  String get startTimeNotSaved;

  /// No description provided for @endTimeNotSaved.
  ///
  /// In en, this message translates to:
  /// **'End date/time not saved'**
  String get endTimeNotSaved;

  /// No description provided for @targetEndNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Target end not saved'**
  String get targetEndNotSaved;

  /// No description provided for @inProgressValue.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgressValue;

  /// No description provided for @taskTimeFallback.
  ///
  /// In en, this message translates to:
  /// **'A cumulative task total is saved, but individual session dates and start/end times are not available for older sessions.'**
  String get taskTimeFallback;

  /// No description provided for @sessionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No session history recorded yet. New completed sessions will appear here with their dates and timeline after session logging is enabled in LearnScreen.'**
  String get sessionHistoryEmpty;

  /// No description provided for @sessionTotalExplanation.
  ///
  /// In en, this message translates to:
  /// **'Session totals use saved session durations where available. Estimated hours are planned effort, not actual study time.'**
  String get sessionTotalExplanation;

  /// No description provided for @activeElapsedExplanation.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time is included in TASK TOTAL above.'**
  String get activeElapsedExplanation;

  /// No description provided for @roadmapTaskFallback.
  ///
  /// In en, this message translates to:
  /// **'Roadmap task'**
  String get roadmapTaskFallback;

  /// No description provided for @roadmapMilestoneFallback.
  ///
  /// In en, this message translates to:
  /// **'Roadmap milestone'**
  String get roadmapMilestoneFallback;

  /// No description provided for @taskCompletedDetail.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskCompletedDetail;

  /// No description provided for @taskCompletionNote.
  ///
  /// In en, this message translates to:
  /// **'Task progress is calculated from completion fields saved with your roadmap. Estimated hours describe planned effort, not time actually studied.'**
  String get taskCompletionNote;

  /// No description provided for @progressDataNote.
  ///
  /// In en, this message translates to:
  /// **'Progress information is based on saved roadmap data. No roadmap has been saved for this account yet.'**
  String get progressDataNote;

  /// No description provided for @trackingUnavailableNote.
  ///
  /// In en, this message translates to:
  /// **'This dashboard uses your saved roadmap. Study-time logs, learning streaks, and a dated activity history are not available in the current schema, so they are not displayed as invented statistics.'**
  String get trackingUnavailableNote;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'hi': return AppLocalizationsHi();
    case 'mr': return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
