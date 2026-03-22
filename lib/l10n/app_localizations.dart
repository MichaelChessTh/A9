import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'A9'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue chatting'**
  String get signInToContinue;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login Failed'**
  String get loginFailed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signUpAndChat.
  ///
  /// In en, this message translates to:
  /// **'Sign up and start chatting'**
  String get signUpAndChat;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match!'**
  String get passwordsDontMatch;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @setUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setUpProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username is already taken. Please choose another.'**
  String get usernameTaken;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello! 👋'**
  String get sayHello;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get typing;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lastSeen;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get deleteChat;

  /// No description provided for @deleteChatWarning.
  ///
  /// In en, this message translates to:
  /// **'This chat will be removed from your list.'**
  String get deleteChatWarning;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceNote;

  /// No description provided for @pickLanguage.
  ///
  /// In en, this message translates to:
  /// **'Pick your language'**
  String get pickLanguage;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by name or email...'**
  String get searchPlaceholder;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversations;

  /// No description provided for @noConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search for someone or create a group!'**
  String get noConversationsHint;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @deleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get deleteChatTitle;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group chat?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteChatContent.
  ///
  /// In en, this message translates to:
  /// **'This chat will be removed from your list.'**
  String get deleteChatContent;

  /// No description provided for @leaveGroupContent.
  ///
  /// In en, this message translates to:
  /// **'This group will be removed from your list.'**
  String get leaveGroupContent;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock User'**
  String get unblockUser;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockUser;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @callLog.
  ///
  /// In en, this message translates to:
  /// **'Call Log'**
  String get callLog;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo and tell us your name'**
  String get choosePhoto;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. john_doe'**
  String get usernameHint;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @usernameTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters'**
  String get usernameTooShort;

  /// No description provided for @statusHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Hey there! I\'m using this app 🙂'**
  String get statusHint;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+79001234567'**
  String get phoneHint;

  /// No description provided for @phoneRequiredPlus.
  ///
  /// In en, this message translates to:
  /// **'Phone number must start with +'**
  String get phoneRequiredPlus;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get profileUpdated;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @hangUpConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get hangUpConfirmTitle;

  /// No description provided for @hangUpConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end the call?'**
  String get hangUpConfirmMessage;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get editMessage;

  /// No description provided for @searchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search messages...'**
  String get searchMessages;

  /// No description provided for @sendingAttachment.
  ///
  /// In en, this message translates to:
  /// **'Sending attachment...'**
  String get sendingAttachment;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @at.
  ///
  /// In en, this message translates to:
  /// **'at'**
  String get at;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @editHint.
  ///
  /// In en, this message translates to:
  /// **'Edit your message...'**
  String get editHint;

  /// No description provided for @deleteForEveryoneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryoneConfirm;

  /// No description provided for @wasActive.
  ///
  /// In en, this message translates to:
  /// **'was active'**
  String get wasActive;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @hdPhoto.
  ///
  /// In en, this message translates to:
  /// **'HD Photo'**
  String get hdPhoto;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @audioMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice Message'**
  String get audioMessage;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted.'**
  String get messageDeleted;

  /// No description provided for @mediaRemoved.
  ///
  /// In en, this message translates to:
  /// **'Media removed'**
  String get mediaRemoved;

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get videoUnavailable;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get messageCopied;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @downloadedTo.
  ///
  /// In en, this message translates to:
  /// **'Downloaded to'**
  String get downloadedTo;

  /// No description provided for @webDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads on Web: Open image in new tab to save.'**
  String get webDownloadHint;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessage;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'New Message Notifications'**
  String get notificationChannelDescription;

  /// No description provided for @setNickname.
  ///
  /// In en, this message translates to:
  /// **'Set Nickname'**
  String get setNickname;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Best Friend'**
  String get nicknameHint;

  /// No description provided for @deleteChatOption.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get deleteChatOption;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @groupChatMembers.
  ///
  /// In en, this message translates to:
  /// **'Group chat · {count} members'**
  String groupChatMembers(Object count);

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'MEMBERS'**
  String get members;

  /// No description provided for @inviteMembers.
  ///
  /// In en, this message translates to:
  /// **'Invite Members'**
  String get inviteMembers;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leaveGroup;

  /// No description provided for @deleteGroupEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete Group for Everyone'**
  String get deleteGroupEveryone;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get makeAdmin;

  /// No description provided for @searchByUsernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by username or email...'**
  String get searchByUsernameOrEmail;

  /// No description provided for @typeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search'**
  String get typeToSearch;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get removeMember;

  /// No description provided for @removeMemberDescription.
  ///
  /// In en, this message translates to:
  /// **'This person will be removed from the group.'**
  String get removeMemberDescription;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave group?'**
  String get leaveGroupConfirm;

  /// No description provided for @leaveGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'You will stop seeing this group in your chats.'**
  String get leaveGroupDescription;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @promoteToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Promote to Admin?'**
  String get promoteToAdmin;

  /// No description provided for @promoteToAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'This person will become the new group admin. You will lose your admin role.'**
  String get promoteToAdminDescription;

  /// No description provided for @promote.
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get promote;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get deleteGroupConfirm;

  /// No description provided for @deleteGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'The entire group and all messages will be permanently deleted for everyone.'**
  String get deleteGroupDescription;

  /// No description provided for @pleaseEnterGroupName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name'**
  String get pleaseEnterGroupName;

  /// No description provided for @pleaseSelectOneMember.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one member'**
  String get pleaseSelectOneMember;

  /// No description provided for @failedToCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get failedToCreateGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @addMembers.
  ///
  /// In en, this message translates to:
  /// **'ADD MEMBERS'**
  String get addMembers;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @countSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String countSelected(Object count);

  /// No description provided for @noExistingContacts.
  ///
  /// In en, this message translates to:
  /// **'No existing contacts'**
  String get noExistingContacts;

  /// No description provided for @startChatFirst.
  ///
  /// In en, this message translates to:
  /// **'Start a chat with someone first'**
  String get startChatFirst;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @darkModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Dark theme enabled'**
  String get darkModeEnabled;

  /// No description provided for @lightModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Light theme enabled'**
  String get lightModeEnabled;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password below. You may need to have signed in recently for this to work.'**
  String get changePasswordDescription;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get passwordUpdated;

  /// No description provided for @passwordUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error updating password. Try re-logging in.'**
  String get passwordUpdateError;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @hdImage.
  ///
  /// In en, this message translates to:
  /// **'HD Image'**
  String get hdImage;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @passwordLengthError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordLengthError;

  /// No description provided for @settingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up...'**
  String get settingUp;

  /// No description provided for @statusLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Status (optional)'**
  String get statusLabelOptional;

  /// No description provided for @shareTo.
  ///
  /// In en, this message translates to:
  /// **'Share to'**
  String get shareTo;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @softwareUpdate.
  ///
  /// In en, this message translates to:
  /// **'Software Update'**
  String get softwareUpdate;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New Version Available'**
  String get newVersionAvailable;

  /// No description provided for @systemUpToDate.
  ///
  /// In en, this message translates to:
  /// **'System Up to Date'**
  String get systemUpToDate;

  /// No description provided for @versionReady.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready'**
  String versionReady(String version);

  /// No description provided for @latestVersionNotice.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version'**
  String get latestVersionNotice;

  /// No description provided for @currentVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current: v{version}'**
  String currentVersionLabel(String version);

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whatsNew;

  /// No description provided for @installNow.
  ///
  /// In en, this message translates to:
  /// **'INSTALL NOW'**
  String get installNow;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD UPDATE'**
  String get downloadUpdate;

  /// No description provided for @deleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete Messages'**
  String get deleteMessages;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @onlineMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String onlineMembersCount(int count);

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get statusSeen;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @youBlockedUser.
  ///
  /// In en, this message translates to:
  /// **'You blocked this user. They cannot see new messages.'**
  String get youBlockedUser;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @youAreBlocked.
  ///
  /// In en, this message translates to:
  /// **'You have been blocked by this user.'**
  String get youAreBlocked;

  /// No description provided for @deleteForEveryoneQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete these messages for everyone?'**
  String get deleteForEveryoneQuestion;

  /// No description provided for @deleteForMeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete these messages for yourself?'**
  String get deleteForMeQuestion;

  /// No description provided for @deleteForEveryoneTip.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryoneTip;

  /// No description provided for @deleteForMeTip.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMeTip;

  /// No description provided for @selectMessagesToDelete.
  ///
  /// In en, this message translates to:
  /// **'Select messages to delete'**
  String get selectMessagesToDelete;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username: {username}'**
  String usernameLabel(String username);

  /// No description provided for @statusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get statusAvailable;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @deleteChatLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get deleteChatLabel;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @forwardedMessage.
  ///
  /// In en, this message translates to:
  /// **'Forwarded message'**
  String get forwardedMessage;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to A9'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'A9 is a free anonymous messenger with end-to-end encryption, requiring absolutely no registration data except an email. Contacts can be searched by username, e-mail, or phone number, if provided. The development team wishes you pleasant communication.'**
  String get welcomeDescription;

  /// No description provided for @acceptPolicy.
  ///
  /// In en, this message translates to:
  /// **'I accept the privacy policy of the application'**
  String get acceptPolicy;

  /// No description provided for @encryptedImageLowQuality.
  ///
  /// In en, this message translates to:
  /// **'Encrypted Image (low quality)'**
  String get encryptedImageLowQuality;

  /// No description provided for @selectChatHint.
  ///
  /// In en, this message translates to:
  /// **'Select a chat to open'**
  String get selectChatHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
