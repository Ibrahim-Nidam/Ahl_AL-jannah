import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @navQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get navQuran;

  /// No description provided for @navPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get navPrayer;

  /// No description provided for @navQibla.
  ///
  /// In en, this message translates to:
  /// **'Qibla'**
  String get navQibla;

  /// No description provided for @navAdhkar.
  ///
  /// In en, this message translates to:
  /// **'Adhkar'**
  String get navAdhkar;

  /// Title of the More tab / page.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTabTitle;

  /// No description provided for @hadithTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Prophetic Hadith'**
  String get hadithTileTitle;

  /// No description provided for @hadithTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sahih Bukhari & Muslim'**
  String get hadithTileSubtitle;

  /// No description provided for @settingsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTileTitle;

  /// No description provided for @settingsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, font size, and notifications'**
  String get settingsTileSubtitle;

  /// No description provided for @aboutTileTitle.
  ///
  /// In en, this message translates to:
  /// **'About the App'**
  String get aboutTileTitle;

  /// No description provided for @aboutTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'About Ahl Jannah'**
  String get aboutTileSubtitle;

  /// Fixed Quranic-Arabic phrase. Intentionally identical across all locales and always rendered right-to-left, regardless of app language.
  ///
  /// In en, this message translates to:
  /// **'بسم الله الرحمن الرحيم'**
  String get basmala;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language. Arabic displays right-to-left automatically.'**
  String get languageSectionDescription;

  /// No description provided for @languageSystemOption.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystemOption;

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSectionTitle;

  /// No description provided for @appearanceSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how Ahl Jannah looks across the whole app.'**
  String get appearanceSectionDescription;

  /// No description provided for @themePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get themePreviewTitle;

  /// No description provided for @themeModeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeModeSectionTitle;

  /// No description provided for @themeModeSystemOption.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeModeSystemOption;

  /// No description provided for @themeModeLightOption.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLightOption;

  /// No description provided for @themeModeDarkOption.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDarkOption;

  /// No description provided for @colorPaletteSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Palette'**
  String get colorPaletteSectionTitle;

  /// No description provided for @colorPaletteSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick the color theme used throughout the app.'**
  String get colorPaletteSectionDescription;

  /// No description provided for @paletteClassicName.
  ///
  /// In en, this message translates to:
  /// **'Emerald'**
  String get paletteClassicName;

  /// No description provided for @paletteOceanName.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get paletteOceanName;

  /// No description provided for @paletteDesertName.
  ///
  /// In en, this message translates to:
  /// **'Desert'**
  String get paletteDesertName;

  /// No description provided for @quranFontSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran Font'**
  String get quranFontSectionTitle;

  /// No description provided for @quranFontSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the Arabic font used for Quran text.'**
  String get quranFontSectionDescription;

  /// No description provided for @quranFontUthmanicName.
  ///
  /// In en, this message translates to:
  /// **'Uthmanic (Lateef)'**
  String get quranFontUthmanicName;

  /// No description provided for @adhkarRemindersSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Adhkar Reminders'**
  String get adhkarRemindersSectionTitle;

  /// No description provided for @adhkarRemindersSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Get reminded to recite your morning and evening Adhkar.'**
  String get adhkarRemindersSectionDescription;

  /// No description provided for @morningAdhkarReminderOption.
  ///
  /// In en, this message translates to:
  /// **'Morning Adhkar Reminder'**
  String get morningAdhkarReminderOption;

  /// No description provided for @eveningAdhkarReminderOption.
  ///
  /// In en, this message translates to:
  /// **'Evening Adhkar Reminder'**
  String get eveningAdhkarReminderOption;

  /// No description provided for @morningAdhkarNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning Adhkar'**
  String get morningAdhkarNotificationTitle;

  /// No description provided for @morningAdhkarNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'It is time to remember Allah with your morning Adhkar.'**
  String get morningAdhkarNotificationBody;

  /// No description provided for @eveningAdhkarNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Evening Adhkar'**
  String get eveningAdhkarNotificationTitle;

  /// No description provided for @eveningAdhkarNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'It is time to remember Allah with your evening Adhkar.'**
  String get eveningAdhkarNotificationBody;

  /// No description provided for @batteryOptimizationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization'**
  String get batteryOptimizationSectionTitle;

  /// No description provided for @batteryOptimizationSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimization to ensure prayer notifications arrive on time.'**
  String get batteryOptimizationSectionDescription;

  /// No description provided for @batteryOptimizationDisableOption.
  ///
  /// In en, this message translates to:
  /// **'Disable Battery Optimization'**
  String get batteryOptimizationDisableOption;

  /// No description provided for @morePageMessage.
  ///
  /// In en, this message translates to:
  /// **'Peace and blessings be upon the best of Allah\'s creation, our Prophet Muhammad bin Abdullah, and upon his family and companions, one and all. To proceed:\n\nAll praise is due to Allah, much good and blessed praise therein. All praise is due to Allah for His apparent and hidden blessings, and all praise is due to Allah Who inspired me with this idea and guided me to complete it. I ask Him, glorified and exalted, to make this work a continuous charity, whose reward is not limited to me alone, but extends to everyone whom Allah has written to enter Paradise, from our father Adam, peace be upon him, until the Day of Resurrection, so that Allah may raise us by it, even by one degree, and our Lord, glorified and exalted, is more generous than that and more vast in bounty, and all praise is due to Allah, Lord of the Worlds.\n\nAnd the Messenger of Allah ﷺ said: \"Convey from me, even if it is only one verse.\"\n\nAnd I ask Allah Almighty to make this work sincere for His noble face, and to benefit Muslims by it, and to make it a cause for guidance and steadfastness, and to bless it, and accept it with good acceptance, and place it in the scale of good deeds on the Day of Resurrection. And all praise is due to Allah, Lord of the Worlds.'**
  String get morePageMessage;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String commonError(String message);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get commonTomorrow;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonRefreshLocation.
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get commonRefreshLocation;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @startupPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable prayer and Qibla permissions'**
  String get startupPermissionsTitle;

  /// No description provided for @startupPermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'Ahl Jannah needs notification permission for prayer reminders and location permission for prayer times and Qibla direction. Exact alarm permission helps deliver prayer alerts on time.'**
  String get startupPermissionsBody;

  /// No description provided for @startupBatteryOptimizationBody.
  ///
  /// In en, this message translates to:
  /// **'To ensure Adhan notifications arrive on time, please disable battery optimization for Ahl Jannah. You will be taken to the system settings to allow unrestricted background access.'**
  String get startupBatteryOptimizationBody;

  /// No description provided for @quranTabSurah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get quranTabSurah;

  /// No description provided for @quranTabJuz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get quranTabJuz;

  /// No description provided for @quranTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get quranTabSearch;

  /// No description provided for @quranContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get quranContinueReading;

  /// No description provided for @quranBookmarksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get quranBookmarksTooltip;

  /// No description provided for @quranBookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran Bookmarks'**
  String get quranBookmarksTitle;

  /// No description provided for @quranBookmarksPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get quranBookmarksPages;

  /// No description provided for @quranBookmarksAyahs.
  ///
  /// In en, this message translates to:
  /// **'Ayahs'**
  String get quranBookmarksAyahs;

  /// No description provided for @quranNoBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks saved yet'**
  String get quranNoBookmarksYet;

  /// No description provided for @quranNoPageBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No page bookmarks yet'**
  String get quranNoPageBookmarks;

  /// No description provided for @quranNoAyahBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No ayah bookmarks yet'**
  String get quranNoAyahBookmarks;

  /// No description provided for @quranSavedVersesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved verses'**
  String quranSavedVersesCount(int count);

  /// No description provided for @quranPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String quranPageLabel(int page);

  /// No description provided for @quranJuzLabel.
  ///
  /// In en, this message translates to:
  /// **'Juz {juz}'**
  String quranJuzLabel(int juz);

  /// No description provided for @quranHizbLabel.
  ///
  /// In en, this message translates to:
  /// **'Hizb {hizb}'**
  String quranHizbLabel(int hizb);

  /// No description provided for @quranJuzPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Juz {juz} • Page {page}'**
  String quranJuzPageSubtitle(int juz, int page);

  /// No description provided for @quranFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Quran: {message}'**
  String quranFailedToLoad(String message);

  /// No description provided for @quranFilterSurahsHint.
  ///
  /// In en, this message translates to:
  /// **'Filter surahs…'**
  String get quranFilterSurahsHint;

  /// No description provided for @quranSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the Quran…'**
  String get quranSearchHint;

  /// No description provided for @quranSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type a word to search the Quran'**
  String get quranSearchPrompt;

  /// No description provided for @quranNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get quranNoResults;

  /// No description provided for @quranFoundResults.
  ///
  /// In en, this message translates to:
  /// **'Found {count} results for \"{query}\"'**
  String quranFoundResults(int count, String query);

  /// No description provided for @quranNoVersesOnPage.
  ///
  /// In en, this message translates to:
  /// **'No verses on this page'**
  String get quranNoVersesOnPage;

  /// No description provided for @quranSettingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Settings & Appearance'**
  String get quranSettingsAppearance;

  /// No description provided for @quranReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading Mode'**
  String get quranReadingMode;

  /// No description provided for @quranModeMushaf.
  ///
  /// In en, this message translates to:
  /// **'Mushaf'**
  String get quranModeMushaf;

  /// No description provided for @quranModeStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get quranModeStudy;

  /// No description provided for @quranArabicFontSize.
  ///
  /// In en, this message translates to:
  /// **'Arabic Font Size: {size} px'**
  String quranArabicFontSize(int size);

  /// No description provided for @quranShowTranslations.
  ///
  /// In en, this message translates to:
  /// **'Show Translations'**
  String get quranShowTranslations;

  /// No description provided for @quranTranslationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translation Language'**
  String get quranTranslationLanguage;

  /// No description provided for @quranLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get quranLangEnglish;

  /// No description provided for @quranLangFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get quranLangFrench;

  /// No description provided for @quranSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quran Settings'**
  String get quranSettingsTooltip;

  /// No description provided for @quranManageBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Manage Bookmarks'**
  String get quranManageBookmarks;

  /// No description provided for @quranBookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark page'**
  String get quranBookmarkPage;

  /// No description provided for @quranUnmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Unmark page'**
  String get quranUnmarkPage;

  /// No description provided for @quranBookmarkVerse.
  ///
  /// In en, this message translates to:
  /// **'Bookmark Verse'**
  String get quranBookmarkVerse;

  /// No description provided for @quranUnmarkVerse.
  ///
  /// In en, this message translates to:
  /// **'Unmark Verse'**
  String get quranUnmarkVerse;

  /// No description provided for @quranClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get quranClearSelection;

  /// No description provided for @quranPageBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Page {page} bookmarked'**
  String quranPageBookmarked(int page);

  /// No description provided for @quranPageRemovedBookmark.
  ///
  /// In en, this message translates to:
  /// **'Page {page} removed from bookmarks'**
  String quranPageRemovedBookmark(int page);

  /// No description provided for @quranVerseBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Verse {surah}:{ayah} bookmarked'**
  String quranVerseBookmarked(int surah, int ayah);

  /// No description provided for @quranVerseRemovedBookmark.
  ///
  /// In en, this message translates to:
  /// **'Verse {surah}:{ayah} removed from bookmarks'**
  String quranVerseRemovedBookmark(int surah, int ayah);

  /// No description provided for @quranVerseCopied.
  ///
  /// In en, this message translates to:
  /// **'Verse copied to clipboard'**
  String get quranVerseCopied;

  /// No description provided for @quranVerseShareReady.
  ///
  /// In en, this message translates to:
  /// **'Verse format ready to share (copied)'**
  String get quranVerseShareReady;

  /// No description provided for @quranFailedBookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Failed to bookmark page: {message}'**
  String quranFailedBookmarkPage(String message);

  /// No description provided for @quranFailedRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove bookmark: {message}'**
  String quranFailedRemoveBookmark(String message);

  /// No description provided for @quranFailedBookmarkVerse.
  ///
  /// In en, this message translates to:
  /// **'Failed to bookmark verse: {message}'**
  String quranFailedBookmarkVerse(String message);

  /// No description provided for @quranVerseLabel.
  ///
  /// In en, this message translates to:
  /// **'Verse {surah}:{ayah}'**
  String quranVerseLabel(int surah, int ayah);

  /// No description provided for @quranAyahBookmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Ayah {surah}:{ayah}'**
  String quranAyahBookmarkLabel(int surah, int ayah);

  /// No description provided for @quranPageDotSurah.
  ///
  /// In en, this message translates to:
  /// **'Page {page} • {surah}'**
  String quranPageDotSurah(int page, String surah);

  /// No description provided for @quranAyahCount.
  ///
  /// In en, this message translates to:
  /// **'• {count} Ayahs'**
  String quranAyahCount(int count);

  /// No description provided for @quranSurahFallback.
  ///
  /// In en, this message translates to:
  /// **'Surah {id}'**
  String quranSurahFallback(int id);

  /// No description provided for @quranShareQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran Quote'**
  String get quranShareQuoteTitle;

  /// No description provided for @quranShareViaApp.
  ///
  /// In en, this message translates to:
  /// **'Shared via Ahl Jannah App'**
  String get quranShareViaApp;

  /// No description provided for @quranRevelationMeccan.
  ///
  /// In en, this message translates to:
  /// **'Meccan'**
  String get quranRevelationMeccan;

  /// No description provided for @quranRevelationMedinan.
  ///
  /// In en, this message translates to:
  /// **'Medinan'**
  String get quranRevelationMedinan;

  /// No description provided for @prayerPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get prayerPageTitle;

  /// No description provided for @prayerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer Settings'**
  String get prayerSettingsTitle;

  /// No description provided for @prayerEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get prayerEnableNotifications;

  /// No description provided for @prayerEnableNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive adhan alerts and reminders'**
  String get prayerEnableNotificationsSubtitle;

  /// No description provided for @prayerReminderBefore.
  ///
  /// In en, this message translates to:
  /// **'Reminder Before Prayer'**
  String get prayerReminderBefore;

  /// No description provided for @prayerReminder5Min.
  ///
  /// In en, this message translates to:
  /// **'5 min'**
  String get prayerReminder5Min;

  /// No description provided for @prayerReminder15Min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get prayerReminder15Min;

  /// No description provided for @prayerAdhanSound.
  ///
  /// In en, this message translates to:
  /// **'Adhan Sound'**
  String get prayerAdhanSound;

  /// No description provided for @prayerFullAdhan.
  ///
  /// In en, this message translates to:
  /// **'Full Adhan'**
  String get prayerFullAdhan;

  /// No description provided for @prayerShortAdhan.
  ///
  /// In en, this message translates to:
  /// **'Short Adhan'**
  String get prayerShortAdhan;

  /// No description provided for @prayerMadhab.
  ///
  /// In en, this message translates to:
  /// **'Madhab (Asr)'**
  String get prayerMadhab;

  /// No description provided for @prayerMadhabStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard (Shafi/Maliki/Hanbali)'**
  String get prayerMadhabStandard;

  /// No description provided for @prayerMadhabHanafi.
  ///
  /// In en, this message translates to:
  /// **'Hanafi'**
  String get prayerMadhabHanafi;

  /// No description provided for @prayerCalculationMethod.
  ///
  /// In en, this message translates to:
  /// **'Calculation Method'**
  String get prayerCalculationMethod;

  /// No description provided for @prayerNextPrayer.
  ///
  /// In en, this message translates to:
  /// **'NEXT PRAYER'**
  String get prayerNextPrayer;

  /// No description provided for @prayerTodaysPrayers.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Prayers'**
  String get prayerTodaysPrayers;

  /// No description provided for @prayerTimesHeading.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get prayerTimesHeading;

  /// No description provided for @prayerAdhanPlaying.
  ///
  /// In en, this message translates to:
  /// **'Adhan is playing...'**
  String get prayerAdhanPlaying;

  /// No description provided for @prayerGpsLocation.
  ///
  /// In en, this message translates to:
  /// **'GPS Location'**
  String get prayerGpsLocation;

  /// No description provided for @prayerMuteAdhan.
  ///
  /// In en, this message translates to:
  /// **'Mute adhan'**
  String get prayerMuteAdhan;

  /// No description provided for @prayerUnmuteAdhan.
  ///
  /// In en, this message translates to:
  /// **'Unmute adhan'**
  String get prayerUnmuteAdhan;

  /// No description provided for @prayerPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get prayerPreviousDay;

  /// No description provided for @prayerNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get prayerNextDay;

  /// No description provided for @prayerFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load prayer times'**
  String get prayerFailedLoad;

  /// No description provided for @prayerLocationTimesError.
  ///
  /// In en, this message translates to:
  /// **'Location/Times Error'**
  String get prayerLocationTimesError;

  /// No description provided for @prayerNameFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerNameFajr;

  /// No description provided for @prayerNameSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayerNameSunrise;

  /// No description provided for @prayerNameDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerNameDhuhr;

  /// No description provided for @prayerNameAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerNameAsr;

  /// No description provided for @prayerNameMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerNameMaghrib;

  /// No description provided for @prayerNameIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerNameIsha;

  /// No description provided for @prayerNotificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Prayer Reminders'**
  String get prayerNotificationChannelName;

  /// No description provided for @prayerReminderChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminder before prayer time'**
  String get prayerReminderChannelDescription;

  /// No description provided for @prayerAdhanChannelName.
  ///
  /// In en, this message translates to:
  /// **'Adhan Alerts'**
  String get prayerAdhanChannelName;

  /// No description provided for @prayerAdhanChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Adhan plays at prayer time'**
  String get prayerAdhanChannelDescription;

  /// No description provided for @prayerAdhanPlayingChannelName.
  ///
  /// In en, this message translates to:
  /// **'Adhan Playing'**
  String get prayerAdhanPlayingChannelName;

  /// No description provided for @prayerAdhanPlayingChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Shown while an Adhan is playing, with a Stop Adhan action'**
  String get prayerAdhanPlayingChannelDescription;

  /// No description provided for @adhkarNotificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Adhkar Reminders'**
  String get adhkarNotificationChannelName;

  /// No description provided for @adhkarNotificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders to recite morning and evening Adhkar'**
  String get adhkarNotificationChannelDescription;

  /// No description provided for @prayerCancelAdhan.
  ///
  /// In en, this message translates to:
  /// **'Cancel Adhan'**
  String get prayerCancelAdhan;

  /// No description provided for @prayerStopAdhan.
  ///
  /// In en, this message translates to:
  /// **'Stop Adhan'**
  String get prayerStopAdhan;

  /// No description provided for @prayerAdhanNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Adhan - {prayer}'**
  String prayerAdhanNotificationTitle(String prayer);

  /// No description provided for @prayerAdhanNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'It is time for {prayer} prayer'**
  String prayerAdhanNotificationBody(String prayer);

  /// No description provided for @prayerReminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{prayer} in {minutes} minutes'**
  String prayerReminderNotificationBody(String prayer, int minutes);

  /// No description provided for @prayerAdhanPlayingBody.
  ///
  /// In en, this message translates to:
  /// **'Adhan is playing'**
  String get prayerAdhanPlayingBody;

  /// No description provided for @prayerFajrAdhanHint.
  ///
  /// In en, this message translates to:
  /// **'Fajr always uses its dedicated Adhan unless Short is selected.'**
  String get prayerFajrAdhanHint;

  /// No description provided for @prayerAutomaticMethod.
  ///
  /// In en, this message translates to:
  /// **'Automatic Method'**
  String get prayerAutomaticMethod;

  /// No description provided for @prayerAutomaticMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selects the optimal method for your region'**
  String get prayerAutomaticMethodSubtitle;

  /// No description provided for @prayerShowingTimesFor.
  ///
  /// In en, this message translates to:
  /// **'Showing prayer times for {location}'**
  String prayerShowingTimesFor(String location);

  /// No description provided for @qiblaPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Qibla'**
  String get qiblaPageTitle;

  /// No description provided for @qiblaCompassUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Compass Unavailable'**
  String get qiblaCompassUnavailable;

  /// No description provided for @qiblaDirectionLabel.
  ///
  /// In en, this message translates to:
  /// **'QIBLA DIRECTION'**
  String get qiblaDirectionLabel;

  /// No description provided for @qiblaAligned.
  ///
  /// In en, this message translates to:
  /// **'ALIGNED WITH QIBLA'**
  String get qiblaAligned;

  /// No description provided for @qiblaRotateDevice.
  ///
  /// In en, this message translates to:
  /// **'ROTATE DEVICE'**
  String get qiblaRotateDevice;

  /// No description provided for @qiblaDegreesFromNorth.
  ///
  /// In en, this message translates to:
  /// **'Degrees clockwise from North (for {location})'**
  String qiblaDegreesFromNorth(String location);

  /// No description provided for @qiblaYourLocation.
  ///
  /// In en, this message translates to:
  /// **'your location'**
  String get qiblaYourLocation;

  /// No description provided for @qiblaErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading Qibla'**
  String get qiblaErrorLoading;

  /// No description provided for @qiblaCalibrateHint.
  ///
  /// In en, this message translates to:
  /// **'Move your phone in a figure-8 motion to calibrate the compass.'**
  String get qiblaCalibrateHint;

  /// No description provided for @qiblaBearingLabel.
  ///
  /// In en, this message translates to:
  /// **'Qibla bearing: {degrees}°'**
  String qiblaBearingLabel(String degrees);

  /// No description provided for @qiblaSensorUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Compass sensor is not available on this platform/device.'**
  String get qiblaSensorUnavailableMessage;

  /// No description provided for @qiblaSensorNotEmittingMessage.
  ///
  /// In en, this message translates to:
  /// **'Compass sensor is not emitting readings. This happens on emulators or if sensors are disabled.'**
  String get qiblaSensorNotEmittingMessage;

  /// No description provided for @qiblaSensorNullReadingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Compass sensor returned null readings. Calibration or device sensors might be disabled.'**
  String get qiblaSensorNullReadingsMessage;

  /// No description provided for @qiblaSensorReadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error reading compass sensor: {error}'**
  String qiblaSensorReadErrorMessage(String error);

  /// No description provided for @qiblaPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to calculate Qibla direction.'**
  String get qiblaPermissionDeniedMessage;

  /// No description provided for @qiblaLocationUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine your location. Please try again.'**
  String get qiblaLocationUnavailableMessage;

  /// No description provided for @qiblaFacingKaaba.
  ///
  /// In en, this message translates to:
  /// **'You are now facing the direction of the Kaaba.'**
  String get qiblaFacingKaaba;

  /// No description provided for @qiblaAlignMarkerHint.
  ///
  /// In en, this message translates to:
  /// **'Align the gold marker at the top with the gold Kaaba pointer.'**
  String get qiblaAlignMarkerHint;

  /// No description provided for @qiblaNorth.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get qiblaNorth;

  /// No description provided for @qiblaEast.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get qiblaEast;

  /// No description provided for @qiblaSouth.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get qiblaSouth;

  /// No description provided for @qiblaWest.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get qiblaWest;

  /// No description provided for @adhkarPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Adhkar'**
  String get adhkarPageTitle;

  /// No description provided for @adhkarCountInCategory.
  ///
  /// In en, this message translates to:
  /// **'{count} adhkar in this category'**
  String adhkarCountInCategory(int count);

  /// No description provided for @adhkarComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Adhkar & counter coming soon'**
  String get adhkarComingSoon;

  /// No description provided for @adhkarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Arabic, translation, or transliteration'**
  String get adhkarSearchHint;

  /// No description provided for @adhkarNoResults.
  ///
  /// In en, this message translates to:
  /// **'No adhkar found'**
  String get adhkarNoResults;

  /// No description provided for @adhkarEmptyCategory.
  ///
  /// In en, this message translates to:
  /// **'No adhkar in this category'**
  String get adhkarEmptyCategory;

  /// No description provided for @adhkarRepeatHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat {count}×'**
  String adhkarRepeatHint(int count);

  /// No description provided for @adhkarReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get adhkarReferenceLabel;

  /// No description provided for @adhkarAuthenticityLabel.
  ///
  /// In en, this message translates to:
  /// **'Authenticity'**
  String get adhkarAuthenticityLabel;

  /// No description provided for @adhkarNarratorLabel.
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get adhkarNarratorLabel;

  /// No description provided for @adhkarBookLabel.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get adhkarBookLabel;

  /// No description provided for @adhkarHadithNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Hadith number'**
  String get adhkarHadithNumberLabel;

  /// No description provided for @adhkarBenefitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Benefits'**
  String get adhkarBenefitsLabel;

  /// No description provided for @adhkarResetCounter.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get adhkarResetCounter;

  /// No description provided for @adhkarCatalogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String adhkarCatalogSubtitle(int count);

  /// No description provided for @adhkarProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String adhkarProgressLabel(int current, int total);

  /// No description provided for @adhkarSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe for next / previous'**
  String get adhkarSwipeHint;

  /// No description provided for @adhkarShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get adhkarShowTranslation;

  /// No description provided for @adhkarHideTranslation.
  ///
  /// In en, this message translates to:
  /// **'Hide translation'**
  String get adhkarHideTranslation;

  /// No description provided for @adhkarShowTransliteration.
  ///
  /// In en, this message translates to:
  /// **'Show transliteration'**
  String get adhkarShowTransliteration;

  /// No description provided for @adhkarHideTransliteration.
  ///
  /// In en, this message translates to:
  /// **'Hide transliteration'**
  String get adhkarHideTransliteration;

  /// No description provided for @adhkarDailySection.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get adhkarDailySection;

  /// No description provided for @adhkarAllCategoriesSection.
  ///
  /// In en, this message translates to:
  /// **'ALL CATEGORIES'**
  String get adhkarAllCategoriesSection;

  /// No description provided for @hadithPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get hadithPageTitle;

  /// No description provided for @hadithComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Hadith collection coming soon'**
  String get hadithComingSoon;

  /// No description provided for @tasbeehPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh'**
  String get tasbeehPageTitle;

  /// No description provided for @tasbeehSettingsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh'**
  String get tasbeehSettingsSectionTitle;

  /// No description provided for @tasbeehSettingsSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback while counting on the digital Tasbeeh.'**
  String get tasbeehSettingsSectionDescription;

  /// No description provided for @tasbeehVibrateOnTapOption.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on every tap'**
  String get tasbeehVibrateOnTapOption;

  /// No description provided for @tasbeehVibrateOnTapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light vibration for each count.'**
  String get tasbeehVibrateOnTapSubtitle;

  /// No description provided for @tasbeehStrongVibrateOption.
  ///
  /// In en, this message translates to:
  /// **'Strong vibration on completion'**
  String get tasbeehStrongVibrateOption;

  /// No description provided for @tasbeehStrongVibrateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A stronger pulse when you reach the target.'**
  String get tasbeehStrongVibrateSubtitle;

  /// No description provided for @tasbeehCompletionMessage.
  ///
  /// In en, this message translates to:
  /// **'Target completed — may Allah accept it. You can keep counting.'**
  String get tasbeehCompletionMessage;

  /// No description provided for @tasbeehContinueCounting.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get tasbeehContinueCounting;

  /// No description provided for @tasbeehChooseDhikr.
  ///
  /// In en, this message translates to:
  /// **'Choose dhikr'**
  String get tasbeehChooseDhikr;

  /// No description provided for @tasbeehEmptyCounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Empty counter — tap to count'**
  String get tasbeehEmptyCounterLabel;

  /// No description provided for @tasbeehEmptyCounterOption.
  ///
  /// In en, this message translates to:
  /// **'Empty counter (no text)'**
  String get tasbeehEmptyCounterOption;

  /// No description provided for @tasbeehCustomDhikrOption.
  ///
  /// In en, this message translates to:
  /// **'Custom dhikr'**
  String get tasbeehCustomDhikrOption;

  /// No description provided for @tasbeehCustomDhikrHint.
  ///
  /// In en, this message translates to:
  /// **'Type your dhikr here'**
  String get tasbeehCustomDhikrHint;

  /// No description provided for @tasbeehCollectionSection.
  ///
  /// In en, this message translates to:
  /// **'My Tasbeeh collection'**
  String get tasbeehCollectionSection;

  /// No description provided for @tasbeehCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved dhikr yet. Add one from the Adhkar catalog.'**
  String get tasbeehCollectionEmpty;

  /// No description provided for @tasbeehCatalogSearchSection.
  ///
  /// In en, this message translates to:
  /// **'From Adhkar catalog'**
  String get tasbeehCatalogSearchSection;

  /// No description provided for @tasbeehAddToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get tasbeehAddToCollection;

  /// No description provided for @tasbeehAddAndOpen.
  ///
  /// In en, this message translates to:
  /// **'Add to Tasbeeh'**
  String get tasbeehAddAndOpen;

  /// No description provided for @tasbeehResetSession.
  ///
  /// In en, this message translates to:
  /// **'Reset session'**
  String get tasbeehResetSession;

  /// No description provided for @tasbeehTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target: {count}'**
  String tasbeehTargetLabel(int count);

  /// No description provided for @tasbeehRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {count}'**
  String tasbeehRemainingLabel(int count);

  /// No description provided for @tasbeehUnlimitedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get tasbeehUnlimitedLabel;

  /// No description provided for @tasbeehElapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String tasbeehElapsedLabel(String time);

  /// No description provided for @tasbeehModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom ({count})'**
  String tasbeehModeCustom(int count);

  /// No description provided for @tasbeehModeUnlimited.
  ///
  /// In en, this message translates to:
  /// **'∞'**
  String get tasbeehModeUnlimited;

  /// No description provided for @tasbeehCustomTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom target'**
  String get tasbeehCustomTargetTitle;

  /// No description provided for @tasbeehCustomTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of repetitions'**
  String get tasbeehCustomTargetLabel;

  /// No description provided for @tasbeehStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get tasbeehStatsTitle;

  /// No description provided for @tasbeehStatsDaily.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tasbeehStatsDaily;

  /// No description provided for @tasbeehStatsLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get tasbeehStatsLifetime;

  /// No description provided for @tasbeehStatSessions.
  ///
  /// In en, this message translates to:
  /// **'Completed sessions: {count}'**
  String tasbeehStatSessions(int count);

  /// No description provided for @tasbeehStatRepetitions.
  ///
  /// In en, this message translates to:
  /// **'Total repetitions: {count}'**
  String tasbeehStatRepetitions(int count);

  /// No description provided for @tasbeehStatMinutes.
  ///
  /// In en, this message translates to:
  /// **'Time: {count}'**
  String tasbeehStatMinutes(String count);

  /// No description provided for @tasbeehStatsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tasbeehStatsToday;

  /// No description provided for @tasbeehStatsByDhikr.
  ///
  /// In en, this message translates to:
  /// **'By dhikr'**
  String get tasbeehStatsByDhikr;

  /// No description provided for @tasbeehClearToday.
  ///
  /// In en, this message translates to:
  /// **'Clear today\'s stats'**
  String get tasbeehClearToday;

  /// No description provided for @tasbeehClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all stats'**
  String get tasbeehClearAll;

  /// No description provided for @hadithSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search hadith...'**
  String get hadithSearchHint;

  /// No description provided for @hadithNoResults.
  ///
  /// In en, this message translates to:
  /// **'No hadith found.'**
  String get hadithNoResults;

  /// No description provided for @hadithNoCollections.
  ///
  /// In en, this message translates to:
  /// **'No hadith collections found.'**
  String get hadithNoCollections;

  /// No description provided for @hadithCollectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hadith} other{{count} hadiths}}'**
  String hadithCollectionCount(int count);

  /// No description provided for @hadithNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'No. {number}'**
  String hadithNumberLabel(int number);
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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
