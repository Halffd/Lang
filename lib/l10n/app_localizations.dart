import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

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
    Locale('en'),
    Locale('es'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @afrikaans.
  ///
  /// In en, this message translates to:
  /// **'Afrikaans'**
  String get afrikaans;

  /// No description provided for @ai.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get ai;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @aiBreakdown.
  ///
  /// In en, this message translates to:
  /// **'AI Breakdown'**
  String get aiBreakdown;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChatTitle;

  /// No description provided for @aiInsights.
  ///
  /// In en, this message translates to:
  /// **'AI Insights'**
  String get aiInsights;

  /// No description provided for @analyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyze;

  /// No description provided for @analyzeIndividualCharacters.
  ///
  /// In en, this message translates to:
  /// **'Analyze Individual Characters'**
  String get analyzeIndividualCharacters;

  /// No description provided for @analyzeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze Screen'**
  String get analyzeScreenTitle;

  /// No description provided for @analyzeText.
  ///
  /// In en, this message translates to:
  /// **'Analyze Text'**
  String get analyzeText;

  /// No description provided for @ankiProfiles.
  ///
  /// In en, this message translates to:
  /// **'Anki & Profiles'**
  String get ankiProfiles;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Lang'**
  String get appName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Lang'**
  String get appTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @areYouSureYouWantToDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String areYouSureYouWantToDelete(Object title);

  /// No description provided for @askAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask anything'**
  String get askAnything;

  /// No description provided for @autoDetectProcessText.
  ///
  /// In en, this message translates to:
  /// **'Automatically detect and process text from clipboard'**
  String get autoDetectProcessText;

  /// No description provided for @autoHideNavigation.
  ///
  /// In en, this message translates to:
  /// **'Auto-hide Navigation'**
  String get autoHideNavigation;

  /// No description provided for @autoKanaConversion.
  ///
  /// In en, this message translates to:
  /// **'Automatic Kana Conversion'**
  String get autoKanaConversion;

  /// No description provided for @autoPasteReader.
  ///
  /// In en, this message translates to:
  /// **'Auto-paste in Reader Mode'**
  String get autoPasteReader;

  /// No description provided for @autoPasteReaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically paste text from clipboard into reader mode'**
  String get autoPasteReaderSubtitle;

  /// No description provided for @autoSearchClipboard.
  ///
  /// In en, this message translates to:
  /// **'Automatically search for clipboard content'**
  String get autoSearchClipboard;

  /// No description provided for @autoTranslateWords.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate words in reader mode'**
  String get autoTranslateWords;

  /// No description provided for @autoTranslation.
  ///
  /// In en, this message translates to:
  /// **'Auto Translation'**
  String get autoTranslation;

  /// No description provided for @breakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get breakdown;

  /// No description provided for @bulgarian.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian'**
  String get bulgarian;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @catalan.
  ///
  /// In en, this message translates to:
  /// **'Catalan'**
  String get catalan;

  /// No description provided for @chatGptMock.
  ///
  /// In en, this message translates to:
  /// **'ChatGPT'**
  String get chatGptMock;

  /// No description provided for @chatWithAI.
  ///
  /// In en, this message translates to:
  /// **'Chat with AI'**
  String get chatWithAI;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @clipboardAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Auto-Detect'**
  String get clipboardAutoDetect;

  /// No description provided for @clipboardMonitor.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Monitor'**
  String get clipboardMonitor;

  /// No description provided for @column.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get column;

  /// No description provided for @columns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// No description provided for @context.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get context;

  /// No description provided for @convertRomajiToKana.
  ///
  /// In en, this message translates to:
  /// **'Convert romaji to kana while typing'**
  String get convertRomajiToKana;

  /// No description provided for @croatian.
  ///
  /// In en, this message translates to:
  /// **'Croatian'**
  String get croatian;

  /// No description provided for @ctrl1Search.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + 1: Search'**
  String get ctrl1Search;

  /// No description provided for @ctrl2Reader.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + 2: Reader'**
  String get ctrl2Reader;

  /// No description provided for @ctrl3Lists.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + 3: Lists'**
  String get ctrl3Lists;

  /// No description provided for @ctrl4Dictionaries.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + 4: Dictionaries'**
  String get ctrl4Dictionaries;

  /// No description provided for @ctrl5Translator.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + 5: Translator'**
  String get ctrl5Translator;

  /// No description provided for @ctrl6Settings.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + 6: Settings'**
  String get ctrl6Settings;

  /// No description provided for @currentAnkiDeck.
  ///
  /// In en, this message translates to:
  /// **'Current Anki Deck'**
  String get currentAnkiDeck;

  /// No description provided for @currentProfile.
  ///
  /// In en, this message translates to:
  /// **'Current Profile'**
  String get currentProfile;

  /// No description provided for @czech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get czech;

  /// No description provided for @danish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get danish;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get darkTheme;

  /// No description provided for @defaultFlexMode.
  ///
  /// In en, this message translates to:
  /// **'Default Flex Mode'**
  String get defaultFlexMode;

  /// No description provided for @defaultScreen.
  ///
  /// In en, this message translates to:
  /// **'Default Screen'**
  String get defaultScreen;

  /// No description provided for @defaultScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select which screen to show when app starts'**
  String get defaultScreenSubtitle;

  /// No description provided for @definitionsHidden.
  ///
  /// In en, this message translates to:
  /// **'Definitions hidden'**
  String get definitionsHidden;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @dictionaries.
  ///
  /// In en, this message translates to:
  /// **'Dictionaries'**
  String get dictionaries;

  /// No description provided for @dictionaryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Language'**
  String get dictionaryLanguage;

  /// No description provided for @displayKanjiInfo.
  ///
  /// In en, this message translates to:
  /// **'Display kanji information'**
  String get displayKanjiInfo;

  /// No description provided for @displayOptions.
  ///
  /// In en, this message translates to:
  /// **'Display Options'**
  String get displayOptions;

  /// No description provided for @dutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get dutch;

  /// No description provided for @enableForvoPronunciations.
  ///
  /// In en, this message translates to:
  /// **'Enable audio pronunciations from Forvo'**
  String get enableForvoPronunciations;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @enhancedFeatures.
  ///
  /// In en, this message translates to:
  /// **'Enhanced Features'**
  String get enhancedFeatures;

  /// No description provided for @enterTextToAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Enter text to analyze'**
  String get enterTextToAnalyze;

  /// No description provided for @estonian.
  ///
  /// In en, this message translates to:
  /// **'Estonian'**
  String get estonian;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @filipino.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get filipino;

  /// No description provided for @filterByFrequency.
  ///
  /// In en, this message translates to:
  /// **'Filter words by frequency (lower = more common)'**
  String get filterByFrequency;

  /// No description provided for @finnish.
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get finnish;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @fontSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the font size multiplier for text'**
  String get fontSizeSubtitle;

  /// No description provided for @forvoAudio.
  ///
  /// In en, this message translates to:
  /// **'Forvo Audio'**
  String get forvoAudio;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency: {freq}'**
  String frequency(Object freq);

  /// No description provided for @frequencyHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Frequency High to Low'**
  String get frequencyHighToLow;

  /// No description provided for @frequencyLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Frequency Low to High'**
  String get frequencyLowToHigh;

  /// No description provided for @fullTranslation.
  ///
  /// In en, this message translates to:
  /// **'Full Translation'**
  String get fullTranslation;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @generateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate Image'**
  String get generateImage;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @greek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get greek;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @groupByFirstChar.
  ///
  /// In en, this message translates to:
  /// **'Group by First Character'**
  String get groupByFirstChar;

  /// No description provided for @groupByFrequency.
  ///
  /// In en, this message translates to:
  /// **'Group by Frequency'**
  String get groupByFrequency;

  /// No description provided for @groupByKanji.
  ///
  /// In en, this message translates to:
  /// **'Group by Kanji'**
  String get groupByKanji;

  /// No description provided for @hasDefinition.
  ///
  /// In en, this message translates to:
  /// **'Has Definition'**
  String get hasDefinition;

  /// No description provided for @hasKanji.
  ///
  /// In en, this message translates to:
  /// **'Has Kanji'**
  String get hasKanji;

  /// No description provided for @hasReading.
  ///
  /// In en, this message translates to:
  /// **'Has Reading'**
  String get hasReading;

  /// No description provided for @hebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get hebrew;

  /// No description provided for @hideDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Hide Definitions'**
  String get hideDefinitions;

  /// No description provided for @hideNavigationBottom.
  ///
  /// In en, this message translates to:
  /// **'Hide navigation bar when mouse is not near bottom'**
  String get hideNavigationBottom;

  /// No description provided for @highFrequency.
  ///
  /// In en, this message translates to:
  /// **'High Frequency (1-1K)'**
  String get highFrequency;

  /// No description provided for @highlightParticles.
  ///
  /// In en, this message translates to:
  /// **'Highlight Japanese particles in text'**
  String get highlightParticles;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @hungarian.
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get hungarian;

  /// No description provided for @ichiMoe.
  ///
  /// In en, this message translates to:
  /// **'ichi.moe'**
  String get ichiMoe;

  /// No description provided for @indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonésian'**
  String get indonesian;

  /// No description provided for @italian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get italian;

  /// No description provided for @japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// No description provided for @japaneseKanjiOriginAndUsage.
  ///
  /// In en, this message translates to:
  /// **'Japanese kanji origin and usage'**
  String get japaneseKanjiOriginAndUsage;

  /// No description provided for @kanjiBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Kanji Breakdown'**
  String get kanjiBreakdown;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get korean;

  /// No description provided for @langAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Lang Analyze'**
  String get langAnalyze;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @latvian.
  ///
  /// In en, this message translates to:
  /// **'Latvian'**
  String get latvian;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get lightTheme;

  /// No description provided for @lists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get lists;

  /// No description provided for @lithuanian.
  ///
  /// In en, this message translates to:
  /// **'Lithuanian'**
  String get lithuanian;

  /// No description provided for @localDictionary.
  ///
  /// In en, this message translates to:
  /// **'Local Dictionary'**
  String get localDictionary;

  /// No description provided for @lowFrequency.
  ///
  /// In en, this message translates to:
  /// **'Low Frequency'**
  String get lowFrequency;

  /// No description provided for @mediumFrequency.
  ///
  /// In en, this message translates to:
  /// **'Medium Frequency (1K-5K)'**
  String get mediumFrequency;

  /// No description provided for @minFrequency.
  ///
  /// In en, this message translates to:
  /// **'Minimum Frequency'**
  String get minFrequency;

  /// No description provided for @multilingualLearningTool.
  ///
  /// In en, this message translates to:
  /// **'A multilingual language learning tool with dictionary and word saving features.'**
  String get multilingualLearningTool;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @first.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get first;

  /// No description provided for @last.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get last;

  /// No description provided for @navFirstLast.
  ///
  /// In en, this message translates to:
  /// **'First / Last'**
  String get navFirstLast;

  /// No description provided for @navPrevNext.
  ///
  /// In en, this message translates to:
  /// **'Prev / Next'**
  String get navPrevNext;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @noGroup.
  ///
  /// In en, this message translates to:
  /// **'No Group'**
  String get noGroup;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistory;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYet;

  /// No description provided for @noResultsYet.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get noResultsYet;

  /// No description provided for @noSavedWords.
  ///
  /// In en, this message translates to:
  /// **'No saved words yet'**
  String get noSavedWords;

  /// No description provided for @norwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get norwegian;

  /// No description provided for @ofStatic.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofStatic;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String page(Object current, Object total);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String pageOf(Object current, Object total);

  /// No description provided for @pasteTextHere.
  ///
  /// In en, this message translates to:
  /// **'Paste text here...'**
  String get pasteTextHere;

  /// No description provided for @pasteYourText.
  ///
  /// In en, this message translates to:
  /// **'Paste your text here to analyze'**
  String get pasteYourText;

  /// No description provided for @perPagePage.
  ///
  /// In en, this message translates to:
  /// **'{count} per page'**
  String perPagePage(Object count);

  /// No description provided for @perPageRow.
  ///
  /// In en, this message translates to:
  /// **'{count} per row'**
  String perPageRow(Object count);

  /// No description provided for @polish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get polish;

  /// No description provided for @portuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portuguese;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading: {reading}'**
  String reading(Object reading);

  /// No description provided for @readingAtoZ.
  ///
  /// In en, this message translates to:
  /// **'Reading A-Z'**
  String get readingAtoZ;

  /// No description provided for @readingZtoA.
  ///
  /// In en, this message translates to:
  /// **'Reading Z-A'**
  String get readingZtoA;

  /// No description provided for @readings.
  ///
  /// In en, this message translates to:
  /// **'Readings: {readings}'**
  String readings(Object readings);

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @romanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get romanian;

  /// No description provided for @runAiBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Run AI Breakdown'**
  String get runAiBreakdown;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @saveWordsToSeeThemHere.
  ///
  /// In en, this message translates to:
  /// **'Save words to see them here'**
  String get saveWordsToSeeThemHere;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @savedWord.
  ///
  /// In en, this message translates to:
  /// **'Saved word'**
  String savedWord(Object word);

  /// No description provided for @savedWords.
  ///
  /// In en, this message translates to:
  /// **'Saved Words'**
  String get savedWords;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @searchOptions.
  ///
  /// In en, this message translates to:
  /// **'Search Options'**
  String get searchOptions;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search Settings'**
  String get searchSettings;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @sentenceTranslations.
  ///
  /// In en, this message translates to:
  /// **'Sentence Translations'**
  String get sentenceTranslations;

  /// No description provided for @sentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get sentences;

  /// No description provided for @sentencesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences found'**
  String sentencesFound(Object count);

  /// No description provided for @serbian.
  ///
  /// In en, this message translates to:
  /// **'Serbian'**
  String get serbian;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @showDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Show Definitions'**
  String get showDefinitions;

  /// No description provided for @showKanji.
  ///
  /// In en, this message translates to:
  /// **'Show Kanji'**
  String get showKanji;

  /// No description provided for @showParticles.
  ///
  /// In en, this message translates to:
  /// **'Show Particles'**
  String get showParticles;

  /// No description provided for @slovak.
  ///
  /// In en, this message translates to:
  /// **'Slovak'**
  String get slovak;

  /// No description provided for @slovenian.
  ///
  /// In en, this message translates to:
  /// **'Slovenian'**
  String get slovenian;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @summarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get summarize;

  /// No description provided for @swedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get swedish;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System Theme'**
  String get systemTheme;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @thai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get thai;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select how the app theme should be determined'**
  String get themeModeSubtitle;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @translator.
  ///
  /// In en, this message translates to:
  /// **'Translator'**
  String get translator;

  /// No description provided for @translationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Translation unavailable'**
  String get translationUnavailable;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get type;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @uiAndNavigation.
  ///
  /// In en, this message translates to:
  /// **'UI & Navigation'**
  String get uiAndNavigation;

  /// No description provided for @ukrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get ukrainian;

  /// No description provided for @usage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// No description provided for @useDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme'**
  String get useDarkTheme;

  /// No description provided for @useFlexibleGrid.
  ///
  /// In en, this message translates to:
  /// **'Use flexible grid layout for word lists by default'**
  String get useFlexibleGrid;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(Object version);

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @wiktionary.
  ///
  /// In en, this message translates to:
  /// **'Wiktionary'**
  String get wiktionary;

  /// No description provided for @wordAtoZ.
  ///
  /// In en, this message translates to:
  /// **'Word A-Z'**
  String get wordAtoZ;

  /// No description provided for @wordDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Word Definitions'**
  String get wordDefinitions;

  /// No description provided for @wordLists.
  ///
  /// In en, this message translates to:
  /// **'Word Lists'**
  String get wordLists;

  /// No description provided for @wordZtoA.
  ///
  /// In en, this message translates to:
  /// **'Word Z-A'**
  String get wordZtoA;

  /// No description provided for @wordsAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'{count} words analyzed'**
  String wordsAnalyzed(Object count);

  /// No description provided for @zoomLevel.
  ///
  /// In en, this message translates to:
  /// **'Zoom Level'**
  String get zoomLevel;

  /// No description provided for @zoomLevelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the zoom level for the entire app'**
  String get zoomLevelSubtitle;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @categorySearches.
  ///
  /// In en, this message translates to:
  /// **'Searches'**
  String get categorySearches;

  /// No description provided for @categoryWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get categoryWords;

  /// No description provided for @categoryKanji.
  ///
  /// In en, this message translates to:
  /// **'Kanji'**
  String get categoryKanji;

  /// No description provided for @categoryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get categoryFavorites;

  /// No description provided for @categoryAnki.
  ///
  /// In en, this message translates to:
  /// **'Anki Added'**
  String get categoryAnki;

  /// No description provided for @categoryDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get categoryDocuments;

  /// No description provided for @categoryVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get categoryVisits;

  /// No description provided for @categoryActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get categoryActions;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityYet;

  /// No description provided for @noActivityInCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get noActivityInCategory;

  /// No description provided for @activitySearch.
  ///
  /// In en, this message translates to:
  /// **'Searched'**
  String get activitySearch;

  /// No description provided for @activityWordLookup.
  ///
  /// In en, this message translates to:
  /// **'Looked up word'**
  String get activityWordLookup;

  /// No description provided for @activityKanjiLookup.
  ///
  /// In en, this message translates to:
  /// **'Viewed kanji'**
  String get activityKanjiLookup;

  /// No description provided for @activityFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get activityFavorite;

  /// No description provided for @activityUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get activityUnfavorite;

  /// No description provided for @activityAnkiAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to Anki'**
  String get activityAnkiAdded;

  /// No description provided for @activityAnkiLocal.
  ///
  /// In en, this message translates to:
  /// **'Saved to Anki list'**
  String get activityAnkiLocal;

  /// No description provided for @activityDocument.
  ///
  /// In en, this message translates to:
  /// **'Opened document'**
  String get activityDocument;

  /// No description provided for @activityVisit.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get activityVisit;

  /// No description provided for @activitySaveWord.
  ///
  /// In en, this message translates to:
  /// **'Saved word'**
  String get activitySaveWord;

  /// No description provided for @activityRemoveWord.
  ///
  /// In en, this message translates to:
  /// **'Removed word'**
  String get activityRemoveWord;

  /// No description provided for @activitySrsAdd.
  ///
  /// In en, this message translates to:
  /// **'Added to SRS'**
  String get activitySrsAdd;

  /// No description provided for @activitySrsRemove.
  ///
  /// In en, this message translates to:
  /// **'Removed from SRS'**
  String get activitySrsRemove;

  /// No description provided for @categoryAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analyses'**
  String get categoryAnalysis;

  /// No description provided for @categoryClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get categoryClipboard;

  /// No description provided for @activityAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analyzed text'**
  String get activityAnalysis;

  /// No description provided for @activityClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied text'**
  String get activityClipboard;

  /// No description provided for @clipboardMonitorMode.
  ///
  /// In en, this message translates to:
  /// **'Clipboard monitor mode'**
  String get clipboardMonitorMode;

  /// No description provided for @clipboardModeHistoryOnly.
  ///
  /// In en, this message translates to:
  /// **'History only'**
  String get clipboardModeHistoryOnly;

  /// No description provided for @clipboardModeHistoryOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Record copied text to activity history without searching'**
  String get clipboardModeHistoryOnlyDesc;

  /// No description provided for @clipboardModeAutoSearch.
  ///
  /// In en, this message translates to:
  /// **'Auto search'**
  String get clipboardModeAutoSearch;

  /// No description provided for @clipboardModeAutoSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Record and automatically search copied text'**
  String get clipboardModeAutoSearchDesc;

  /// No description provided for @clipboardModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get clipboardModeOff;

  /// No description provided for @clipboardModeOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Do not monitor the clipboard'**
  String get clipboardModeOffDesc;

  /// No description provided for @autoSearchOnlyWhenFocused.
  ///
  /// In en, this message translates to:
  /// **'Only when app is focused'**
  String get autoSearchOnlyWhenFocused;

  /// No description provided for @autoSearchOnlyWhenFocusedDesc.
  ///
  /// In en, this message translates to:
  /// **'Skip auto search when the app window is not focused'**
  String get autoSearchOnlyWhenFocusedDesc;

  /// No description provided for @autoSearchRegex.
  ///
  /// In en, this message translates to:
  /// **'Only matching text'**
  String get autoSearchRegex;

  /// No description provided for @autoSearchRegexDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto search only when copied text matches a pattern: enter a regex, or \'ja\' for any Japanese text'**
  String get autoSearchRegexDesc;

  /// No description provided for @autoSearchRegexHint.
  ///
  /// In en, this message translates to:
  /// **'regex or \'ja\''**
  String get autoSearchRegexHint;

  /// No description provided for @clipboardImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get clipboardImage;

  /// No description provided for @fontGroupSizes.
  ///
  /// In en, this message translates to:
  /// **'Font sizes by section'**
  String get fontGroupSizes;

  /// No description provided for @fontGroupHeaders.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get fontGroupHeaders;

  /// No description provided for @fontGroupSentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get fontGroupSentences;

  /// No description provided for @fontGroupTranslations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get fontGroupTranslations;

  /// No description provided for @fontGroupWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get fontGroupWords;

  /// No description provided for @fontGroupKanji.
  ///
  /// In en, this message translates to:
  /// **'Kanji'**
  String get fontGroupKanji;

  /// No description provided for @fontGroupUi.
  ///
  /// In en, this message translates to:
  /// **'Small UI text'**
  String get fontGroupUi;

  /// No description provided for @convertRomanizedToScript.
  ///
  /// In en, this message translates to:
  /// **'Convert romanized text to native script while typing'**
  String get convertRomanizedToScript;

  /// No description provided for @scriptConversionTitle.
  ///
  /// In en, this message translates to:
  /// **'Script conversion while typing'**
  String get scriptConversionTitle;

  /// No description provided for @screenshotTab.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshotTab;

  /// No description provided for @textTab.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textTab;

  /// No description provided for @captureFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get captureFullscreen;

  /// No description provided for @captureMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get captureMonitor;

  /// No description provided for @captureWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get captureWindow;

  /// No description provided for @captureRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get captureRegion;

  /// No description provided for @capturePreviousRegion.
  ///
  /// In en, this message translates to:
  /// **'Previous region'**
  String get capturePreviousRegion;

  /// No description provided for @autoScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Auto screenshot'**
  String get autoScreenshot;

  /// No description provided for @autoOcr.
  ///
  /// In en, this message translates to:
  /// **'Auto OCR after capture'**
  String get autoOcr;

  /// No description provided for @copyOcrText.
  ///
  /// In en, this message translates to:
  /// **'Copy OCR text to clipboard'**
  String get copyOcrText;

  /// No description provided for @copyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy image to clipboard'**
  String get copyImage;

  /// No description provided for @screenshotHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get screenshotHistory;

  /// No description provided for @screenshotAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get screenshotAlbum;

  /// No description provided for @noScreenshots.
  ///
  /// In en, this message translates to:
  /// **'No screenshots yet'**
  String get noScreenshots;

  /// No description provided for @screenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Screenshot failed'**
  String get screenshotFailed;

  /// No description provided for @screenshotCaptured.
  ///
  /// In en, this message translates to:
  /// **'Screenshot saved'**
  String get screenshotCaptured;

  /// No description provided for @deleteAllScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Delete all screenshots'**
  String get deleteAllScreenshots;

  /// No description provided for @intervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} min'**
  String intervalMinutes(int minutes);

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @screenshotHotkeys.
  ///
  /// In en, this message translates to:
  /// **'Hotkeys: Ctrl+Shift+PrtSc full · Ctrl+PrtSc monitor · Shift+PrtSc window · Alt+PrtSc region · Alt+Shift+PrtSc previous region · Ctrl+Alt+PrtSc auto'**
  String get screenshotHotkeys;
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
      <String>['en', 'es', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
