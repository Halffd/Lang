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
    Locale('es'),
    Locale('ja'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Lang'**
  String get appName;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// No description provided for @lists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get lists;

  /// No description provided for @dictionaries.
  ///
  /// In en, this message translates to:
  /// **'Dictionaries'**
  String get dictionaries;

  /// No description provided for @translator.
  ///
  /// In en, this message translates to:
  /// **'Translator'**
  String get translator;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @dictionaryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Language'**
  String get dictionaryLanguage;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @useDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme'**
  String get useDarkTheme;

  /// No description provided for @uiAndNavigation.
  ///
  /// In en, this message translates to:
  /// **'UI & Navigation'**
  String get uiAndNavigation;

  /// No description provided for @autoHideNavigation.
  ///
  /// In en, this message translates to:
  /// **'Auto-hide Navigation'**
  String get autoHideNavigation;

  /// No description provided for @hideNavigationBottom.
  ///
  /// In en, this message translates to:
  /// **'Hide navigation bar when mouse is not near bottom'**
  String get hideNavigationBottom;

  /// No description provided for @defaultFlexMode.
  ///
  /// In en, this message translates to:
  /// **'Default Flex Mode'**
  String get defaultFlexMode;

  /// No description provided for @useFlexibleGrid.
  ///
  /// In en, this message translates to:
  /// **'Use flexible grid layout for word lists by default'**
  String get useFlexibleGrid;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

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

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search Settings'**
  String get searchSettings;

  /// No description provided for @clipboardMonitor.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Monitor'**
  String get clipboardMonitor;

  /// No description provided for @autoSearchClipboard.
  ///
  /// In en, this message translates to:
  /// **'Automatically search for clipboard content'**
  String get autoSearchClipboard;

  /// No description provided for @autoKanaConversion.
  ///
  /// In en, this message translates to:
  /// **'Automatic Kana Conversion'**
  String get autoKanaConversion;

  /// No description provided for @convertRomajiToKana.
  ///
  /// In en, this message translates to:
  /// **'Convert romaji to kana while typing'**
  String get convertRomajiToKana;

  /// No description provided for @displayOptions.
  ///
  /// In en, this message translates to:
  /// **'Display Options'**
  String get displayOptions;

  /// No description provided for @showParticles.
  ///
  /// In en, this message translates to:
  /// **'Show Particles'**
  String get showParticles;

  /// No description provided for @highlightParticles.
  ///
  /// In en, this message translates to:
  /// **'Highlight Japanese particles in text'**
  String get highlightParticles;

  /// No description provided for @showKanji.
  ///
  /// In en, this message translates to:
  /// **'Show Kanji'**
  String get showKanji;

  /// No description provided for @displayKanjiInfo.
  ///
  /// In en, this message translates to:
  /// **'Display kanji information'**
  String get displayKanjiInfo;

  /// No description provided for @minFrequency.
  ///
  /// In en, this message translates to:
  /// **'Minimum Frequency'**
  String get minFrequency;

  /// No description provided for @filterByFrequency.
  ///
  /// In en, this message translates to:
  /// **'Filter words by frequency (lower = more common)'**
  String get filterByFrequency;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @ankiProfiles.
  ///
  /// In en, this message translates to:
  /// **'Anki & Profiles'**
  String get ankiProfiles;

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

  /// No description provided for @enhancedFeatures.
  ///
  /// In en, this message translates to:
  /// **'Enhanced Features'**
  String get enhancedFeatures;

  /// No description provided for @clipboardAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Auto-Detect'**
  String get clipboardAutoDetect;

  /// No description provided for @autoDetectProcessText.
  ///
  /// In en, this message translates to:
  /// **'Automatically detect and process text from clipboard'**
  String get autoDetectProcessText;

  /// No description provided for @forvoAudio.
  ///
  /// In en, this message translates to:
  /// **'Forvo Audio'**
  String get forvoAudio;

  /// No description provided for @enableForvoPronunciations.
  ///
  /// In en, this message translates to:
  /// **'Enable audio pronunciations from Forvo'**
  String get enableForvoPronunciations;

  /// No description provided for @autoTranslation.
  ///
  /// In en, this message translates to:
  /// **'Auto Translation'**
  String get autoTranslation;

  /// No description provided for @autoTranslateWords.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate words in reader mode'**
  String get autoTranslateWords;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(Object version);

  /// No description provided for @japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get korean;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @searchOptions.
  ///
  /// In en, this message translates to:
  /// **'Search Options'**
  String get searchOptions;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @italian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get italian;

  /// No description provided for @portuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portuguese;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @afrikaans.
  ///
  /// In en, this message translates to:
  /// **'Afrikaans'**
  String get afrikaans;

  /// No description provided for @bulgarian.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian'**
  String get bulgarian;

  /// No description provided for @catalan.
  ///
  /// In en, this message translates to:
  /// **'Catalan'**
  String get catalan;

  /// No description provided for @croatian.
  ///
  /// In en, this message translates to:
  /// **'Croatian'**
  String get croatian;

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

  /// No description provided for @dutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get dutch;

  /// No description provided for @estonian.
  ///
  /// In en, this message translates to:
  /// **'Estonian'**
  String get estonian;

  /// No description provided for @filipino.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get filipino;

  /// No description provided for @finnish.
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get finnish;

  /// No description provided for @greek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get greek;

  /// No description provided for @hebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get hebrew;

  /// No description provided for @hungarian.
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get hungarian;

  /// No description provided for @indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonésian'**
  String get indonesian;

  /// No description provided for @latvian.
  ///
  /// In en, this message translates to:
  /// **'Latvian'**
  String get latvian;

  /// No description provided for @lithuanian.
  ///
  /// In en, this message translates to:
  /// **'Lithuanian'**
  String get lithuanian;

  /// No description provided for @norwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get norwegian;

  /// No description provided for @polish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get polish;

  /// No description provided for @romanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get romanian;

  /// No description provided for @serbian.
  ///
  /// In en, this message translates to:
  /// **'Serbian'**
  String get serbian;

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

  /// No description provided for @swedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get swedish;

  /// No description provided for @thai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get thai;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @ukrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get ukrainian;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @multilingualLearningTool.
  ///
  /// In en, this message translates to:
  /// **'A multilingual language learning tool with dictionary and word saving features.'**
  String get multilingualLearningTool;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'ja': return AppLocalizationsJa();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
