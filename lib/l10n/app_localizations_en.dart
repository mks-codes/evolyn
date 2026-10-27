// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Evolyn';

  @override
  String get profileAccountCenter => 'Account Center';

  @override
  String get profileSetings => 'Profile & settings';

  @override
  String get profileYourProfile => 'Your profile';

  @override
  String get profileSignInToViewFocus => 'Sign in to view your focus';

  @override
  String get profileLoadingFocus => 'Loading your focus…';

  @override
  String get profileUnableToLoadFocus => 'Unable to load current focus';

  @override
  String get profileNoSavedRoadmap => 'No saved roadmap yet';

  @override
  String get profileRoadmapSaved => 'Roadmap saved';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profilePreferencesSubtitle => 'Saved on this device for your account.';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageSubtitle => 'Choose your preferred language.';

  @override
  String get profilePrivacySecurity => 'Privacy & security';

  @override
  String get profilePrivacySecuritySubtitle => 'Your account, your choice.';

  @override
  String get profileAccountCenterSubtitle => 'Manage your credentials and account data.';

  @override
  String get profileAccountCenterTileSubtitle => 'Password, mobile number and account deletion';

  @override
  String get profileYourSpace => 'YOUR SPACE';

  @override
  String get profileEmailUnavailable => 'Email unavailable';

  @override
  String get profileLearningJourney => 'Your learning journey';

  @override
  String get profileEditNameTooltip => 'Edit profile name';

  @override
  String get profileCurrentFocus => 'Current focus';

  @override
  String get profileLearningReminders => 'Learning reminders';

  @override
  String get profileLearningRemindersSubtitle => 'A gentle nudge for your daily learning goal';

  @override
  String get profileWeeklyRecap => 'Weekly progress recap';

  @override
  String get profileWeeklyRecapSubtitle => 'A summary of completed tasks';

  @override
  String get profileProductUpdates => 'Product updates';

  @override
  String get profileProductUpdatesSubtitle => 'News about new Evolyn features';

  @override
  String get profileDailyGoal => 'Daily learning goal';

  @override
  String profileDailyGoalSubtitle(String goal) {
    return '$goal per day';
  }

  @override
  String get profileDeletionGracePeriodTitle => 'Your account is scheduled for deletion';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String get profilePrivacyPolicySubtitle => 'How your account and learning data are handled';

  @override
  String get profileAccountSecurity => 'Account security';

  @override
  String get profileAccountSecuritySubtitle => 'Your sign-in credentials remain private';

  @override
  String get profileAccountSecurityMessage => 'Your account is managed by Supabase Authentication. Never share your password or verification codes with anyone.';

  @override
  String get profileSigningOut => 'Signing out…';

  @override
  String get profileFooter => 'EVOLYN • GROW AT YOUR PACE';

  @override
  String get profilePasswordUpdated => 'Password updated successfully.';

  @override
  String get profileCouldNotUpdatePassword => 'Could not update your password.';

  @override
  String get profilePhoneUpdated => 'Mobile number verified and updated.';

  @override
  String get profileCouldNotUpdatePhone => 'Could not update your mobile number.';

  @override
  String get profileDeletePermanentlyTitle => 'Permanently delete account?';

  @override
  String get profileDeleteWarning => 'This action is irreversible. Your account, saved roadmaps, learning progress, profile data and other associated data will be permanently deleted according to our deletion policy. Any data that must legally be retained will be handled as described in the privacy policy.';

  @override
  String get profileKeepAccount => 'Keep my account';

  @override
  String get profileDeletePermanently => 'Delete permanently';

  @override
  String get profileDeleteRequestFailed => 'Account deletion request failed.';

  @override
  String get profileDeletionCompleted => 'Your account deletion has been completed.';

  @override
  String get profileDeletionFailed => 'Account deletion could not be completed. Please try again.';

  @override
  String get profileSavePreferenceFailed => 'Could not save this preference locally. Please try again.';

  @override
  String get profileEditSignInAgain => 'Please sign in again to edit your profile.';

  @override
  String get profileNameUpdated => 'Profile name updated.';

  @override
  String get profileCouldNotUpdateName => 'Could not update your profile. Please try again.';

  @override
  String get profileChooseLanguage => 'Choose language';

  @override
  String get profileChooseAppLanguage => 'Choose your preferred app language.';

  @override
  String get profileLanguageUpdated => 'App language updated.';

  @override
  String get profileChooseDailyGoal => 'Choose a goal you can maintain consistently.';

  @override
  String get profileDailyGoalSaved => 'Daily goal saved on this device.';

  @override
  String get profilePrivacyDescription => 'Evolyn may process account details, learning progress, saved roadmaps, and AI mentor conversations to provide app features.';

  @override
  String get profilePrivacyReviewNotice => 'Before release, connect this section to your reviewed privacy policy and explain retention, data access, and deletion options.';

  @override
  String get profileDone => 'Done';

  @override
  String get profileGotIt => 'Got it';

  @override
  String get profileLogoutTitle => 'Log out of Evolyn?';

  @override
  String get profileLogoutMessage => 'You will need to sign in again to continue your learning journey.';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileLogoutFailed => 'Could not log out. Please try again.';

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileSave => 'Save';

  @override
  String get profileAccountSecurityHeading => 'ACCOUNT SECURITY';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileChangePasswordSubtitle => 'Set a new account password';

  @override
  String get profileMobileNumber => 'Mobile number';

  @override
  String get profileMobileNumberSubtitle => 'Add or change your verified phone number';

  @override
  String get profileAccountOwnershipHeading => 'ACCOUNT OWNERSHIP';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteAccountSubtitle => 'Permanently delete your account and associated data';

  @override
  String get profileDeletionCannotUndo => 'Account deletion cannot be undone. Review the deletion warning and privacy policy before confirming.';

  @override
  String get profilePasswordMinLength => 'Password must contain at least 8 characters.';

  @override
  String get profilePasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profileConfirmNewPassword => 'Confirm new password';

  @override
  String get profileUpdatePassword => 'Update password';

  @override
  String get profilePhoneNumberLabel => 'Phone number';

  @override
  String get profilePhoneNumberHint => '+919876543210';

  @override
  String get profilePhoneCountryCodeHelp => 'Include your country code.';

  @override
  String get profileInvalidPhone => 'Enter a valid international phone number.';

  @override
  String get profileSendVerificationCode => 'Send verification code';

  @override
  String get profileVerifyMobile => 'Verify mobile number';

  @override
  String profileOtpMessage(String phone) {
    return 'Enter the SMS verification code sent to $phone.';
  }

  @override
  String get profileVerificationCode => 'Verification code';

  @override
  String get profileInvalidOtp => 'Enter the 6-digit verification code.';

  @override
  String get profileVerify => 'Verify';

  @override
  String get profileWhyLeaving => 'Why are you leaving?';

  @override
  String get profileFeedbackOptional => 'Your feedback is optional and helps us improve Evolyn.';

  @override
  String get profileDeleteReasonNoNeed => 'I no longer need this account';

  @override
  String get profileDeleteReasonUnsatisfied => 'I am not satisfied with the app';

  @override
  String get profileDeleteReasonLearningNeeds => 'The app does not meet my learning needs';

  @override
  String get profileDeleteReasonPrivacy => 'I have privacy or data concerns';

  @override
  String get profileDeleteReasonTechnical => 'I am experiencing technical problems';

  @override
  String get profileDeleteReasonAnotherAccount => 'I created another account';

  @override
  String get profileDeleteReasonOther => 'Other';

  @override
  String get profileAnythingElse => 'Anything else? (optional)';

  @override
  String get profileFeedbackHint => 'Share your feedback...';

  @override
  String get profileSelectReason => 'Please select a reason to continue.';

  @override
  String get profileContinue => 'Continue';

  @override
  String get dashboardLoadErrorTitle => 'Could not load your dashboard';

  @override
  String get dashboardLoadErrorMessage => 'Check your connection and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get fallbackDisplayName => 'friend';

  @override
  String get roadmapFocus => 'YOUR ROADMAP FOCUS';

  @override
  String get noSavedRoadmap => 'No saved roadmap yet';

  @override
  String get chooseCareersDescription => 'Choose careers in Career Recommendations and generate a roadmap. Your saved plan will appear here.';

  @override
  String get openRoadmap => 'Open roadmap';

  @override
  String get nextActions => 'Next actions';

  @override
  String plannedTasks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned tasks',
      one: '1 planned task',
      zero: 'No planned tasks',
    );
    return '$_temp0';
  }

  @override
  String get nextStepsTitle => 'Your next steps will appear here';

  @override
  String get nextStepsSubtitle => 'Generate and save a roadmap to see tasks tailored to your selected careers.';

  @override
  String get noTasksTitle => 'No tasks were found in this roadmap';

  @override
  String get noTasksSubtitle => 'Open your roadmap and check that its phases include tasks.';

  @override
  String get allTasksCompletedTitle => 'All tasks completed!';

  @override
  String get allTasksCompletedSubtitle => 'You have completed every task in your roadmap. New tasks will appear here when added.';

  @override
  String get fallbackTaskTitle => 'Roadmap task';

  @override
  String get fallbackTaskCategory => 'Task';

  @override
  String get fallbackPhaseTitle => 'Roadmap';

  @override
  String get fallbackRoadmapTitle => 'Your career roadmap';

  @override
  String get oneHour => '1 hour';

  @override
  String hours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String weekNumber(num week) {
    return 'Week $week';
  }

  @override
  String get liveInProgress => 'LIVE · IN PROGRESS';

  @override
  String get sessionFinishedResume => 'SESSION FINISHED · RESUME';

  @override
  String get inProgress => 'IN PROGRESS';

  @override
  String get roadmapPhases => 'ROADMAP PHASES';

  @override
  String get stagesInPlan => 'Stages in your plan';

  @override
  String get timeHorizon => 'TIME HORIZON';

  @override
  String monthsShort(num count) {
    return '$count mo';
  }

  @override
  String get plannedLearningPeriod => 'Planned learning period';

  @override
  String get nextMilestone => 'NEXT MILESTONE';

  @override
  String nextMilestoneWeek(num week) {
    return 'NEXT MILESTONE · WEEK $week';
  }

  @override
  String get nextMilestoneFallback => 'Next milestone';

  @override
  String get categoryProject => 'Project';

  @override
  String get categoryReview => 'Review';

  @override
  String get categoryPractice => 'Practice';

  @override
  String get categoryFoundation => 'Foundation';

  @override
  String get categoryCareerSkill => 'Career skill';

  @override
  String get roadmapScreenTitle => 'Your roadmap';

  @override
  String get editRoadmap => 'Edit roadmap';

  @override
  String get personalizedRoadmap => 'PERSONALIZED ROADMAP';

  @override
  String get roadmapTitleLabel => 'Roadmap title';

  @override
  String get overviewLabel => 'Overview';

  @override
  String planningHorizonMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months planning horizon',
      one: '1 month planning horizon',
    );
    return '$_temp0';
  }

  @override
  String weeksPlanned(num count) {
    return '$count weeks planned';
  }

  @override
  String tasksChecked(num percent) {
    return '$percent% tasks checked';
  }

  @override
  String get phasesLabel => 'PHASES';

  @override
  String get timelineStages => 'timeline stages';

  @override
  String get milestonesLabel => 'Milestones';

  @override
  String get targetOutcomes => 'target outcomes';

  @override
  String get tasksLabel => 'TASKS';

  @override
  String get plannedActions => 'planned actions';

  @override
  String get yourTimeline => 'Your timeline';

  @override
  String phaseCount(num count) {
    return '$count phases';
  }

  @override
  String phaseNumber(num number) {
    return 'PHASE $number';
  }

  @override
  String weekRange(num start, num end) {
    return 'WEEK $start–$end';
  }

  @override
  String get phaseTitleLabel => 'Phase title';

  @override
  String phaseFallbackTitle(num number) {
    return 'Phase $number';
  }

  @override
  String get objectiveLabel => 'Objective';

  @override
  String taskCountSummary(num tasks, num completed) {
    return '$tasks tasks · $completed completed';
  }

  @override
  String durationWeeks(num count) {
    return '$count weeks';
  }

  @override
  String get startWeekLabel => 'Start week';

  @override
  String get endWeekLabel => 'End week';

  @override
  String get durationWeeksLabel => 'Duration (weeks)';

  @override
  String get expectedOutcomes => 'Expected outcomes';

  @override
  String outcomeNumber(num number) {
    return 'Outcome $number';
  }

  @override
  String get milestones => 'Milestones';

  @override
  String get milestoneLabel => 'Milestone';

  @override
  String milestoneNumber(num number) {
    return 'Milestone $number';
  }

  @override
  String get targetWeekLabel => 'Target week';

  @override
  String get tasksAndDeliverables => 'Tasks and deliverables';

  @override
  String get reviewCheckpoint => 'REVIEW CHECKPOINT';

  @override
  String get reviewCheckpointLabel => 'Review checkpoint';

  @override
  String get careerAlignment => 'Career alignment';

  @override
  String get selectedCareer => 'Selected career';

  @override
  String get careerAlignmentDescription => 'How this phase supports the career';

  @override
  String get taskTitleLabel => 'Task title';

  @override
  String taskNumber(num number) {
    return 'Task $number';
  }

  @override
  String get descriptionLabel => 'Description';

  @override
  String get estimatedHoursLabel => 'Estimated hours';

  @override
  String get dueWeekLabel => 'Due week';

  @override
  String hoursUnit(num count) {
    return '$count HOURS';
  }

  @override
  String dueWeekValue(num week) {
    return 'DUE WEEK $week';
  }

  @override
  String get deliverableLabel => 'Deliverable';

  @override
  String get successCriteriaLabel => 'Success criteria';

  @override
  String get weeklyRhythm => 'Weekly rhythm';

  @override
  String get weeklyRhythmSubtitle => 'A sustainable way to distribute your time';

  @override
  String get hoursPerWeekLabel => 'Hours per week';

  @override
  String get timeBlockLabel => 'Time block';

  @override
  String blockNumber(num number) {
    return 'Block $number';
  }

  @override
  String get activityLabel => 'Activity';

  @override
  String get hoursLabel => 'Hours';

  @override
  String get progressTracking => 'Progress tracking';

  @override
  String get progressTrackingSubtitle => 'How to review whether the roadmap is working';

  @override
  String get reviewFrequencyLabel => 'Review frequency';

  @override
  String metricNumber(num number) {
    return 'Metric $number';
  }

  @override
  String get nextActionLabel => 'Next action';

  @override
  String get risksAndAdjustments => 'Risks and adjustments';

  @override
  String get risksAndAdjustmentsSubtitle => 'Plan for setbacks without losing momentum';

  @override
  String get riskLabel => 'Risk';

  @override
  String get mitigationLabel => 'Mitigation';

  @override
  String get whenToAdjustLabel => 'When to adjust';

  @override
  String get assumptions => 'Assumptions';

  @override
  String get assumptionsSubtitle => 'Details used where your profile did not specify a preference';

  @override
  String assumptionNumber(num number) {
    return 'Assumption $number';
  }

  @override
  String get editRoadmapHint => 'Edit the text and timeline fields above, then save your changes. Numeric timeline values must remain valid numbers.';

  @override
  String get viewRoadmapHint => 'You can edit phase details, milestones, tasks and schedule before entering Evolyn. Save your changes to keep the roadmap in sync.';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saveProgress => 'Save progress';

  @override
  String get signInToRefresh => 'Sign in to refresh your roadmap.';

  @override
  String get waitUntilSavingFinishes => 'Please wait until saving finishes.';

  @override
  String get saveOrCancelBeforeRefreshing => 'Save or cancel your edits before refreshing.';

  @override
  String get noSavedRoadmapFound => 'No saved roadmap was found.';

  @override
  String get refreshRoadmapError => 'Could not refresh your roadmap. Please try again.';

  @override
  String get signInBeforeSaving => 'Please sign in before saving your roadmap.';

  @override
  String get noPhasesToSave => 'There are no roadmap phases to save.';

  @override
  String invalidPhaseWeekRange(num number) {
    return 'Phase $number has an invalid week range. Please check its timeline fields.';
  }

  @override
  String invalidTaskSchedule(num number) {
    return 'A task in phase $number has an invalid due week or estimate.';
  }

  @override
  String get roadmapNotUpdated => 'The saved roadmap could not be found or updated for this user.';

  @override
  String get saveRoadmapError => 'Could not save your roadmap. Check your connection and database permissions, then retry.';

  @override
  String get roadmapProgressSaved => 'Roadmap progress saved.';

  @override
  String get roadmapChangesSaved => 'Roadmap changes saved.';

  @override
  String get mentorLoadingConversation => 'Loading your conversation…';

  @override
  String get mentorSubtitle => 'Your AI mentor';

  @override
  String get mentorOptions => 'Mentor options';

  @override
  String get mentorCurrentFocus => 'YOUR CURRENT FOCUS';

  @override
  String get mentorAskNextStep => 'Ask AARYA to plan your next step';

  @override
  String get mentorRetry => 'Retry';

  @override
  String get mentorConversationUnavailable => 'Conversation unavailable.';

  @override
  String get mentorConversationHistory => 'Conversation history';

  @override
  String get mentorNoConversations => 'No conversations yet.';

  @override
  String get mentorStartNewConversation => 'Start a new conversation';

  @override
  String get mentorNewConversation => 'New conversation';

  @override
  String get mentorOpenPreviousChat => 'Open a previous chat';

  @override
  String get mentorStartSeparateChat => 'Start a separate chat';

  @override
  String get mentorRefreshMessages => 'Refresh messages';

  @override
  String get mentorSyncChat => 'Sync this chat with the server';

  @override
  String get mentorWelcomeTitle => 'What are we working on today?';

  @override
  String get mentorWelcomeDescription => 'Ask for help with a concept, a project, an interview, or your next roadmap task.';

  @override
  String get mentorConversationDivider => 'YOUR AARYA CONVERSATION';

  @override
  String get mentorTyping => 'Typing…';

  @override
  String get mentorSending => 'Sending…';

  @override
  String get mentorThinking => 'AARYA is thinking…';

  @override
  String get mentorSuggestedRoadmapTask => 'Help with my next roadmap task';

  @override
  String get mentorSuggestedExplainConcept => 'Explain a concept simply';

  @override
  String get mentorSuggestedStudySession => 'Plan a study session';

  @override
  String get mentorSuggestedInterview => 'Practice an interview';

  @override
  String get mentorInputHint => 'Ask AARYA anything…';

  @override
  String get mentorWaitingForReply => 'Waiting for AARYA…';

  @override
  String get mentorConnecting => 'Connecting to your chat…';

  @override
  String get mentorSignInToChat => 'Please sign in to chat with AARYA.';

  @override
  String get mentorConnectionFailed => 'Could not connect to your conversations. Check your connection and retry.';

  @override
  String get mentorOfflineConversation => 'Offline mode: showing your locally saved conversation.';

  @override
  String get mentorHistoryLoadFailed => 'Could not load chat history. Check your connection.';

  @override
  String get mentorOfflineMessages => 'Offline mode: showing locally saved messages.';

  @override
  String get mentorMessageTooLong => 'Please keep each message under 4,000 characters.';

  @override
  String get mentorNoActiveConversation => 'No active conversation is available. Sign in and retry.';

  @override
  String get mentorMissingSavedReply => 'AARYA finished, but the saved reply was missing.';

  @override
  String get mentorResponseFailed => 'AARYA could not finish the response. Please try again.';

  @override
  String get mentorApiKeyUnavailable => 'The Supabase API key is unavailable. Check Supabase initialization.';

  @override
  String get mentorInvalidResponse => 'AARYA returned an invalid response.';

  @override
  String get mentorReplyMissing => 'AARYA reply was missing.';

  @override
  String get mentorStreamEndedEarly => 'The response stream ended before AARYA saved its reply.';

  @override
  String get mentorGenericReplyFailed => 'AARYA could not reply. Check your connection and try again.';

  @override
  String mentorRequestFailed(int statusCode) {
    return 'AARYA request failed (HTTP $statusCode). Please try again.';
  }

  @override
  String get mentorCreateConversationFailed => 'Could not start a new conversation. Please retry.';

  @override
  String get mentorHistoryFailed => 'Could not load conversation history. Please retry.';

  @override
  String get mentorSavedConversation => 'Saved conversation';

  @override
  String get mentorNewConversationTitle => 'New conversation';

  @override
  String get mentorDefaultConversationTitle => 'Conversation';

  @override
  String mentorAskNextTaskPrompt(String taskTitle) {
    return 'Help me work through my next roadmap task: \"$taskTitle\". Break it into small practical steps and ask me one question if you need more context.';
  }

  @override
  String get mentorChooseNextStepPrompt => 'Help me choose a practical next learning step based on my career goals.';

  @override
  String mentorSuggestedTaskPrompt(String taskTitle) {
    return 'Help me work through my next roadmap task: \"$taskTitle\". Give me clear, practical steps.';
  }

  @override
  String get mentorExplainConceptPrompt => 'Help me understand a technical concept using a simple example. Ask which concept if needed.';

  @override
  String get mentorStudySessionPrompt => 'Help me plan a focused study session that fits my next roadmap task.';

  @override
  String get mentorInterviewPrompt => 'Help me practise a technical interview. Ask one question at a time and give constructive feedback.';

  @override
  String get learnSignInPrompt => 'Sign in to view your learning path.';

  @override
  String get learnLoadingErrorTitle => 'Could not load your learning path';

  @override
  String get learnLoadingErrorMessage => 'Check your connection and try again. If you have a cached roadmap, try refreshing again when online.';

  @override
  String get learnRetry => 'Retry';

  @override
  String get learnPreferencesSyncWarning => 'Learning preferences could not be synced. Run the supplied SQL setup for public.learn, then retry. Your roadmap tasks are still shown.';

  @override
  String get learnHeaderEyebrow => 'YOUR LEARNING SPACE';

  @override
  String get learnHeaderTitle => 'Learn and build.';

  @override
  String learnHeaderSubtitle(String roadmapTitle) {
    return 'Practical next steps from $roadmapTitle.';
  }

  @override
  String get learnTasksDone => 'Tasks done';

  @override
  String get learnTimeRemaining => 'Time remaining*';

  @override
  String get learnSavedTasks => 'Saved tasks';

  @override
  String learnProgressFootnote(int inProgress) {
    return '$inProgress currently in progress · *Based on estimated task hours, not tracked study time.';
  }

  @override
  String get learnContinueCurrentSession => 'CONTINUE YOUR CURRENT SESSION';

  @override
  String get learnContinueCurrentTask => 'CONTINUE YOUR TASK';

  @override
  String get learnNextRoadmapTask => 'YOUR NEXT ROADMAP TASK';

  @override
  String learnEstimatedHours(String duration) {
    return '$duration estimated';
  }

  @override
  String get learnResumeSession => 'Resume session';

  @override
  String get learnStartNextSession => 'Start next session';

  @override
  String get learnOpenTaskDetails => 'Open task details';

  @override
  String get learnAllTasksCompleteTitle => 'You completed every roadmap task!';

  @override
  String get learnAllTasksCompleteMessage => 'Review your roadmap or add a new career direction when you are ready.';

  @override
  String get learnSearchHint => 'Search tasks, skills, phases, deliverables';

  @override
  String get learnFilterAll => 'All';

  @override
  String get learnFilterToDo => 'To do';

  @override
  String get learnFilterInProgress => 'In progress';

  @override
  String get learnFilterCompleted => 'Completed';

  @override
  String get learnFilterSaved => 'Saved';

  @override
  String get learnTaskListTitle => 'Your learning tasks';

  @override
  String get learnTaskListSubtitle => 'Real actions from your saved roadmap.';

  @override
  String learnVisibleTaskCount(int visibleCount, int totalCount) {
    return '$visibleCount of $totalCount';
  }

  @override
  String get learnSaveTask => 'Save task';

  @override
  String get learnRemoveSavedTask => 'Remove saved task';

  @override
  String learnDueWeek(int week) {
    return 'Due week $week';
  }

  @override
  String get learnResourceAvailable => 'Resource available';

  @override
  String get learnStatusToDo => 'To do';

  @override
  String get learnStatusInProgress => 'In progress';

  @override
  String get learnStatusCompleted => 'Completed';

  @override
  String get learnNoRoadmapTitle => 'Your learning path starts with a roadmap';

  @override
  String get learnNoRoadmapMessage => 'Generate a roadmap from Career Recommendations. Its real tasks will appear here, and you can track them as you work.';

  @override
  String get learnNoTasksTitle => 'No learning tasks yet';

  @override
  String get learnNoTasksMessage => 'Your saved roadmap does not contain any tasks. Open the Roadmap tab to review it or generate an updated roadmap.';

  @override
  String get learnNoMatchingTasksTitle => 'No matching tasks';

  @override
  String get learnNoMatchingTasksMessage => 'Try a different search term or change the status/category filters.';

  @override
  String get learnSyncNoticeRetry => 'Retry sync';

  @override
  String get learnAaryaTip => 'AARYA tip: use the deliverable and success criteria in each task to decide when the skill is ready to move into practice.';

  @override
  String get learnDurationDialogTitle => 'How long is this work session?';

  @override
  String learnDurationEstimatedTotal(String estimated, String tracked) {
    return 'Estimated total: $estimated. Already tracked: $tracked. Choose a session; the final session is shortened to the remaining estimate.';
  }

  @override
  String get learnDurationNoEstimate => 'This task has no time estimate. Choose a session length; you can mark the task complete when you finish the work.';

  @override
  String get learnCancel => 'Cancel';

  @override
  String learnStartDuration(String duration) {
    return 'Start $duration';
  }

  @override
  String get learnTaskDetailsWhatToDo => 'What to do';

  @override
  String get learnTaskDetailsDeliverable => 'Deliverable';

  @override
  String get learnTaskDetailsSuccessCriteria => 'Success criteria';

  @override
  String learnPriority(String priority) {
    return '$priority priority';
  }

  @override
  String get learnLearningResource => 'Learning resource';

  @override
  String get learnOpenLearningResource => 'Open learning resource';

  @override
  String learnAnotherTaskInProgress(String taskTitle) {
    return '\"$taskTitle\" is already in progress. Complete it before starting another task.';
  }

  @override
  String get learnFinishCurrentSessionFirst => 'Finish current session first';

  @override
  String get learnContinueCurrentSessionButton => 'Continue current session';

  @override
  String get learnStartTask => 'Start task';

  @override
  String get learnReopenTask => 'Reopen task';

  @override
  String get learnFinishSessionEarly => 'Finish session early';

  @override
  String get learnMarkTaskCompleted => 'Mark task as completed';

  @override
  String get learnInvalidResourceUrl => 'This learning resource has an invalid URL.';

  @override
  String get learnCouldNotOpenResource => 'Could not open this learning resource.';

  @override
  String get learnTimerPermissionMessage => 'Allow Evolyn to display over other apps to show the floating timer.';

  @override
  String get learnOverlayPrepareError => 'Could not prepare the floating timer. Check Display over other apps permission.';

  @override
  String get learnNotificationTimerTitle => 'Evolyn • Task in progress';

  @override
  String get learnNotificationTimerChannel => 'Active task timer';

  @override
  String get learnNotificationTimerChannelDescription => 'Shows the countdown for your active learning task';

  @override
  String get learnNotificationFinishedTitle => 'Task time is up!';

  @override
  String learnNotificationFinishedBody(String taskTitle, String duration) {
    return '\"$taskTitle\" reached the end of its $duration session.';
  }

  @override
  String get learnNotificationFinishedChannel => 'Task timer finished';

  @override
  String get learnNotificationFinishedChannelDescription => 'Alerts when a learning task reaches its time limit';

  @override
  String get learnNotificationPermissionError => 'Could not show the task timer. Check notification permissions.';

  @override
  String get learnSessionTimeUp => 'Session time is up';

  @override
  String learnSessionTimeLeft(String countdown) {
    return 'Session time left $countdown';
  }

  @override
  String learnTrackedEstimatedLeft(String tracked, String remaining) {
    return '$tracked tracked · $remaining estimated time left';
  }

  @override
  String learnTrackedStartAnother(String tracked) {
    return '$tracked tracked · start another session';
  }

  @override
  String get learnReadyToStartSession => 'Ready to start a session';

  @override
  String learnTotalTime(String duration) {
    return 'Total time $duration';
  }

  @override
  String learnTrackedSoFar(String duration) {
    return '$duration tracked so far';
  }

  @override
  String get learnTaskRemovedFromSaved => 'Task removed from saved items.';

  @override
  String get learnTaskSavedForLater => 'Task saved for later.';

  @override
  String get learnBookmarkSaveError => 'Could not save this task. Check your connection and learn table permissions.';

  @override
  String get learnRoadmapTimeSavedLearnSyncError => 'Roadmap time was saved, but learning preferences could not sync. Check the learn table setup.';

  @override
  String get learnTaskCompletedEstimateReached => 'Task completed. Its estimated total time has been reached.';

  @override
  String learnSessionSavedTrackedOfEstimate(String tracked, String estimated) {
    return 'Session saved. $tracked tracked of $estimated. Start another session to continue.';
  }

  @override
  String learnSessionSavedNoEstimate(String tracked) {
    return 'Session saved ($tracked tracked). Open the task to start another session or mark it complete.';
  }

  @override
  String get learnTaskMarkedCompleted => 'Task marked as completed.';

  @override
  String get learnTaskReopened => 'Task reopened. Time tracking starts a new cycle.';

  @override
  String learnSessionStarted(String duration) {
    return 'Session started for $duration.';
  }

  @override
  String get learnSessionResumed => 'Session resumed.';

  @override
  String get learnTaskSessionSaveError => 'Could not save the task session. Please retry.';

  @override
  String get learnAnotherTaskStarting => 'Another task is starting. Please wait.';

  @override
  String learnFinishTaskBeforeStartingAnother(String taskTitle) {
    return 'Finish \"$taskTitle\" before starting another task.';
  }

  @override
  String learnTaskPhaseFallback(int phaseNumber) {
    return 'Phase $phaseNumber';
  }

  @override
  String learnTaskFallback(int taskNumber) {
    return 'Task $taskNumber';
  }

  @override
  String get learnGeneralCategory => 'General';

  @override
  String get learnInvalidRoadmapId => 'The saved roadmap ID is missing.';

  @override
  String get learnRoadmapPhaseChanged => 'The roadmap phase changed. Refresh and try again.';

  @override
  String get learnRoadmapTaskChanged => 'The roadmap task changed. Refresh and try again.';

  @override
  String get learnDurationMustBePositive => 'Session duration must be positive.';

  @override
  String get learnRoadmapUpdateFailed => 'The roadmap was not found or could not be updated for this user.';

  @override
  String get learnUnsupportedTaskAction => 'Unsupported task action';

  @override
  String get learnTimerOverlayFailed => 'Floating timer failed';

  @override
  String get learnOverlayDataDeliveryFailed => 'Overlay data delivery failed';

  @override
  String get learnCloseTimerFailed => 'Close timer failed';

  @override
  String get learnCouldNotShowOverlay => 'Could not show floating timer';

  @override
  String get learnNotificationInitializationFailed => 'Notification initialization failed';

  @override
  String get learnCouldNotScheduleTimer => 'Could not schedule task timer';

  @override
  String get learnCouldNotCancelNotifications => 'Could not cancel timer notifications';

  @override
  String get learnStartSoundFailed => 'Start sound failed';

  @override
  String get learnFinishedSoundFailed => 'Finished sound failed';

  @override
  String get learnExpiredTaskCheckFailed => 'Expired task check failed';

  @override
  String get learnResourceLaunchFailed => 'Resource launch failed';

  @override
  String get learnBookmarkSaveFailed => 'Bookmark save failed';

  @override
  String get learnLearnStateMirrorFailed => 'Learn state mirror failed';

  @override
  String get learnTaskStatusSaveFailed => 'Task status save failed';

  @override
  String get learnRoadmapRefreshFailed => 'Roadmap refresh failed';

  @override
  String get learnLearnRefreshFailed => 'Learn refresh failed';

  @override
  String get progressEyebrow => 'YOUR GROWTH, IN VIEW';

  @override
  String get progressTitle => 'Your progress';

  @override
  String get signInPrompt => 'Sign in to view your progress.';

  @override
  String get loadProgressError => 'Could not load progress';

  @override
  String get connectionRetry => 'Check your connection and try again.';

  @override
  String get comingSoon => 'Coming soon!';

  @override
  String get noRoadmapTitle => 'No saved roadmap yet';

  @override
  String get noRoadmapDescription => 'Generate a roadmap from Career Recommendations. Its phases, tasks, and milestones will appear here after they are saved.';

  @override
  String get currentRoadmap => 'CURRENT ROADMAP';

  @override
  String phasesCount(int count) {
    return '$count phases';
  }

  @override
  String tasksCount(int count) {
    return '$count tasks';
  }

  @override
  String milestonesCount(int count) {
    return '$count milestones';
  }

  @override
  String tasksCompleted(int completed, int total) {
    return '$completed of $total tasks completed';
  }

  @override
  String get timeSpentTitle => 'Time spent on each task';

  @override
  String get timeSpentSubtitle => 'Your tracked time for every task in the saved roadmap.';

  @override
  String get roadmapMilestonesTitle => 'Roadmap milestones';

  @override
  String get roadmapMilestonesSubtitle => 'Milestones saved with your current roadmap.';

  @override
  String get completedTasksTitle => 'Completed tasks';

  @override
  String get completedTasksSubtitle => 'Only tasks with a saved completion state appear here.';

  @override
  String get totalTrackedTime => 'TOTAL TRACKED TIME';

  @override
  String get notRecordedYet => 'Not recorded yet';

  @override
  String trackedCount(int tracked, int total) {
    return '$tracked/$total tracked';
  }

  @override
  String get sessionHistory => 'SESSION HISTORY';

  @override
  String savedSessionTimeline(Object count) {
    return 'SAVED SESSION TIMELINE ($count)';
  }

  @override
  String get currentSessionTimeline => 'CURRENT SESSION TIMELINE';

  @override
  String get started => 'Started';

  @override
  String get targetEnd => 'Target end';

  @override
  String get ended => 'Ended';

  @override
  String get completed => 'COMPLETED';

  @override
  String get planned => 'PLANNED';

  @override
  String get taskTotal => 'TASK TOTAL';

  @override
  String get sessionDuration => 'SESSION DURATION';

  @override
  String get dateLabel => 'DATE';

  @override
  String sessionLabel(int number) {
    return 'Session $number';
  }

  @override
  String liveDuration(String duration) {
    return 'LIVE · $duration';
  }

  @override
  String get noTime => 'No time';

  @override
  String get noTasksAvailable => 'No tasks available';

  @override
  String get noTasksSaved => 'No tasks are saved in this roadmap yet.';

  @override
  String get noMilestonesSaved => 'No milestones saved';

  @override
  String get noMilestonesDescription => 'Milestones will appear once they are included in your roadmap.';

  @override
  String get noCompletedTasks => 'No completed tasks recorded yet';

  @override
  String get completionNotTracked => 'Task completion is not tracked yet';

  @override
  String get completionSavedDescription => 'Completed work will appear here after its completion state is saved.';

  @override
  String get completionMissingDescription => 'Your saved roadmap contains planned tasks, but the current data does not include completion records. This screen will show real wins when task completion is persisted.';

  @override
  String get aaryaNote => 'A note from AARYA';

  @override
  String get plannedEffort => 'Planned effort';

  @override
  String get estimatedTaskHours => 'Estimated task hours';

  @override
  String get inSavedRoadmap => 'In saved roadmap';

  @override
  String get completionTracking => 'Completion tracking';

  @override
  String get savedCompletionStates => 'Saved completion states';

  @override
  String get taskCompletionUnavailable => 'Task completion is not yet recorded for every task.';

  @override
  String get noTasksInRoadmap => 'No tasks are saved in this roadmap yet.';

  @override
  String get startTimeNotSaved => 'Start date/time not saved';

  @override
  String get endTimeNotSaved => 'End date/time not saved';

  @override
  String get targetEndNotSaved => 'Target end not saved';

  @override
  String get inProgressValue => 'In progress';

  @override
  String get taskTimeFallback => 'A cumulative task total is saved, but individual session dates and start/end times are not available for older sessions.';

  @override
  String get sessionHistoryEmpty => 'No session history recorded yet. New completed sessions will appear here with their dates and timeline after session logging is enabled in LearnScreen.';

  @override
  String get sessionTotalExplanation => 'Session totals use saved session durations where available. Estimated hours are planned effort, not actual study time.';

  @override
  String get activeElapsedExplanation => 'Elapsed time is included in TASK TOTAL above.';

  @override
  String get roadmapTaskFallback => 'Roadmap task';

  @override
  String get roadmapMilestoneFallback => 'Roadmap milestone';

  @override
  String get taskCompletedDetail => 'Completed';

  @override
  String get taskCompletionNote => 'Task progress is calculated from completion fields saved with your roadmap. Estimated hours describe planned effort, not time actually studied.';

  @override
  String get progressDataNote => 'Progress information is based on saved roadmap data. No roadmap has been saved for this account yet.';

  @override
  String get trackingUnavailableNote => 'This dashboard uses your saved roadmap. Study-time logs, learning streaks, and a dated activity history are not available in the current schema, so they are not displayed as invented statistics.';
}
