import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
    Locale('en'),
    Locale('zh'),
  ];

  /// In-app app title (task switcher).
  ///
  /// In en, this message translates to:
  /// **'BloodPressed'**
  String get appTitle;

  /// No description provided for @langTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langTitle;

  /// No description provided for @langSubtitle.
  ///
  /// In en, this message translates to:
  /// **'UI language · Knowledge articles and AI guidance remain in Chinese'**
  String get langSubtitle;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @langChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get langChinese;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @loadDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data: {error}'**
  String loadDataFailed(String error);

  /// No description provided for @sectionEntry.
  ///
  /// In en, this message translates to:
  /// **'Record Blood Pressure'**
  String get sectionEntry;

  /// No description provided for @actionManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get actionManual;

  /// No description provided for @actionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera Scan'**
  String get actionCamera;

  /// No description provided for @actionGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo Scan'**
  String get actionGallery;

  /// No description provided for @sectionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get sectionHistory;

  /// No description provided for @emptyHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'No blood pressure records yet'**
  String get emptyHomeTitle;

  /// No description provided for @emptyHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start with “Manual Entry” above, or scan a monitor reading with your camera'**
  String get emptyHomeSubtitle;

  /// No description provided for @historyHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to delete · Tap to edit'**
  String get historyHint;

  /// No description provided for @sheetManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter systolic, diastolic and pulse directly'**
  String get sheetManualSubtitle;

  /// No description provided for @sheetGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose from Photos'**
  String get sheetGalleryTitle;

  /// No description provided for @sheetCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the monitor screen to read values automatically'**
  String get sheetCameraSubtitle;

  /// No description provided for @sheetGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read values from an existing monitor photo'**
  String get sheetGallerySubtitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'👋 Welcome to BloodPressed'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record your first blood pressure and start your health journey'**
  String get welcomeSubtitle;

  /// No description provided for @latestMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Latest measurement'**
  String get latestMeasurement;

  /// No description provided for @todayMeasuredTimes.
  ///
  /// In en, this message translates to:
  /// **'Measured {count} times today'**
  String todayMeasuredTimes(int count);

  /// No description provided for @pulseUnit.
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get pulseUnit;

  /// No description provided for @armLeft.
  ///
  /// In en, this message translates to:
  /// **'Left arm'**
  String get armLeft;

  /// No description provided for @armRight.
  ///
  /// In en, this message translates to:
  /// **'Right arm'**
  String get armRight;

  /// No description provided for @postureNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get postureNotRecorded;

  /// No description provided for @postureLying.
  ///
  /// In en, this message translates to:
  /// **'Lying down'**
  String get postureLying;

  /// No description provided for @postureSitting.
  ///
  /// In en, this message translates to:
  /// **'Sitting'**
  String get postureSitting;

  /// No description provided for @postureStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get postureStanding;

  /// No description provided for @sourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get sourceManual;

  /// No description provided for @sourceOcr.
  ///
  /// In en, this message translates to:
  /// **'Camera scan'**
  String get sourceOcr;

  /// No description provided for @sourceAi.
  ///
  /// In en, this message translates to:
  /// **'AI scan'**
  String get sourceAi;

  /// No description provided for @categoryLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get categoryLow;

  /// No description provided for @categoryNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get categoryNormal;

  /// No description provided for @categoryElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get categoryElevated;

  /// No description provided for @categoryGrade1.
  ///
  /// In en, this message translates to:
  /// **'Grade 1'**
  String get categoryGrade1;

  /// No description provided for @categoryGrade2.
  ///
  /// In en, this message translates to:
  /// **'Grade 2+'**
  String get categoryGrade2;

  /// No description provided for @adviceLow.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is low. No action needed if you feel well; see a doctor if you feel dizzy or weak.'**
  String get adviceLow;

  /// No description provided for @adviceNormal.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is in the ideal range. Keep up the healthy lifestyle.'**
  String get adviceNormal;

  /// No description provided for @adviceElevated.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is high but not yet hypertension. Reduce salt, exercise, and re-measure regularly.'**
  String get adviceElevated;

  /// No description provided for @adviceGrade1.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure has reached stage 1 hypertension (home measurement). Re-measure and consult a doctor.'**
  String get adviceGrade1;

  /// No description provided for @adviceGrade2.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure is markedly high. Seek medical care promptly; never adjust medication on your own.'**
  String get adviceGrade2;

  /// No description provided for @editRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Record'**
  String get editRecordTitle;

  /// No description provided for @newRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Blood Pressure'**
  String get newRecordTitle;

  /// No description provided for @sysLabel.
  ///
  /// In en, this message translates to:
  /// **'Systolic (high)'**
  String get sysLabel;

  /// No description provided for @diaLabel.
  ///
  /// In en, this message translates to:
  /// **'Diastolic (low)'**
  String get diaLabel;

  /// No description provided for @pulseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pulse (optional)'**
  String get pulseLabel;

  /// No description provided for @postureField.
  ///
  /// In en, this message translates to:
  /// **'Posture (optional)'**
  String get postureField;

  /// No description provided for @noteField.
  ///
  /// In en, this message translates to:
  /// **'Note (optional, e.g. after exercise, before medication)'**
  String get noteField;

  /// No description provided for @saveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveEdit;

  /// No description provided for @saveNew.
  ///
  /// In en, this message translates to:
  /// **'Save Record'**
  String get saveNew;

  /// No description provided for @bannerSourceOcr.
  ///
  /// In en, this message translates to:
  /// **'Camera scan result'**
  String get bannerSourceOcr;

  /// No description provided for @bannerSourceAi.
  ///
  /// In en, this message translates to:
  /// **'AI scan result'**
  String get bannerSourceAi;

  /// No description provided for @bannerLowNoValue.
  ///
  /// In en, this message translates to:
  /// **'{source} could not read any values. Please enter them manually and review before saving.'**
  String bannerLowNoValue(String source);

  /// No description provided for @bannerLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'{source} returned low confidence ({percent}%). Values in red boxes are for reference only — please review and correct before saving.'**
  String bannerLowConfidence(String source, int percent);

  /// No description provided for @bannerAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'{source}{confidence} was filled in automatically. Please review and save.'**
  String bannerAutoFilled(String source, String confidence);

  /// No description provided for @confidenceSuffix.
  ///
  /// In en, this message translates to:
  /// **' ({percent}% confidence)'**
  String confidenceSuffix(int percent);

  /// No description provided for @errNeedSysDia.
  ///
  /// In en, this message translates to:
  /// **'Please enter systolic and diastolic values'**
  String get errNeedSysDia;

  /// No description provided for @errSysRange.
  ///
  /// In en, this message translates to:
  /// **'Systolic must be between 40 and 300'**
  String get errSysRange;

  /// No description provided for @errDiaRange.
  ///
  /// In en, this message translates to:
  /// **'Diastolic must be between 30 and 200'**
  String get errDiaRange;

  /// No description provided for @errSysGreater.
  ///
  /// In en, this message translates to:
  /// **'Systolic must be greater than diastolic'**
  String get errSysGreater;

  /// No description provided for @errPulseRange.
  ///
  /// In en, this message translates to:
  /// **'Pulse must be between 20 and 300'**
  String get errPulseRange;

  /// No description provided for @deleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Record'**
  String get deleteRecordTitle;

  /// No description provided for @deleteRecordContent.
  ///
  /// In en, this message translates to:
  /// **'Delete the record from {datetime} ({sys}/{dia})? This cannot be undone.'**
  String deleteRecordContent(String datetime, int sys, int dia);
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
