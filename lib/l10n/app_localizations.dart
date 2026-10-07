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

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure Trends'**
  String get statsTitle;

  /// No description provided for @statsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get statsCustom;

  /// No description provided for @armBoth.
  ///
  /// In en, this message translates to:
  /// **'Both arms'**
  String get armBoth;

  /// No description provided for @onlyLeftArm.
  ///
  /// In en, this message translates to:
  /// **'Left arm only'**
  String get onlyLeftArm;

  /// No description provided for @onlyRightArm.
  ///
  /// In en, this message translates to:
  /// **'Right arm only'**
  String get onlyRightArm;

  /// No description provided for @seriesBp.
  ///
  /// In en, this message translates to:
  /// **'BP'**
  String get seriesBp;

  /// No description provided for @seriesPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get seriesPulse;

  /// No description provided for @statsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats: {error}'**
  String statsLoadFailed(String error);

  /// No description provided for @trendLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load trend: {error}'**
  String trendLoadFailed(String error);

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data in this range'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the time range or add a few records first'**
  String get statsEmptySubtitle;

  /// No description provided for @pulseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pulse data in this range'**
  String get pulseEmpty;

  /// No description provided for @chartReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Dashed lines are home-measurement reference levels (systolic 135 / diastolic 85; above means elevated). Multiple readings on the same day are averaged.'**
  String get chartReferenceHint;

  /// No description provided for @refSystolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic {value}'**
  String refSystolic(int value);

  /// No description provided for @refDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic {value}'**
  String refDiastolic(int value);

  /// No description provided for @range7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get range7;

  /// No description provided for @range30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get range30;

  /// No description provided for @range90.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get range90;

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rangeAll;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export & Share'**
  String get exportTitle;

  /// No description provided for @sectionCardShare.
  ///
  /// In en, this message translates to:
  /// **'Card Sharing'**
  String get sectionCardShare;

  /// No description provided for @cardTypeRecord.
  ///
  /// In en, this message translates to:
  /// **'Single Record Card'**
  String get cardTypeRecord;

  /// No description provided for @cardTypeStats.
  ///
  /// In en, this message translates to:
  /// **'Stats Summary Card'**
  String get cardTypeStats;

  /// No description provided for @shareWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat Chat'**
  String get shareWechat;

  /// No description provided for @shareMoments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get shareMoments;

  /// No description provided for @shareMore.
  ///
  /// In en, this message translates to:
  /// **'More Ways to Share'**
  String get shareMore;

  /// No description provided for @sectionDataExport.
  ///
  /// In en, this message translates to:
  /// **'Data Export'**
  String get sectionDataExport;

  /// No description provided for @exportCsvButton.
  ///
  /// In en, this message translates to:
  /// **'Export all records as CSV (opens in Excel)'**
  String get exportCsvButton;

  /// No description provided for @csvContentsHint.
  ///
  /// In en, this message translates to:
  /// **'CSV includes: time, systolic, diastolic, pulse, arm, posture, note, source.'**
  String get csvContentsHint;

  /// No description provided for @emptyExportTitle.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get emptyExportTitle;

  /// No description provided for @emptyExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a blood pressure record before sharing a card'**
  String get emptyExportSubtitle;

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'My blood pressure record (from BloodPressed)'**
  String get shareText;

  /// No description provided for @csvShareText.
  ///
  /// In en, this message translates to:
  /// **'BloodPressed blood pressure record export'**
  String get csvShareText;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed: {error}'**
  String shareFailed(String error);

  /// No description provided for @exportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records to export'**
  String get exportEmpty;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @cardNotReady.
  ///
  /// In en, this message translates to:
  /// **'Share card has not finished rendering'**
  String get cardNotReady;

  /// No description provided for @cardExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export card'**
  String get cardExportFailed;

  /// No description provided for @shareCardRecordHeader.
  ///
  /// In en, this message translates to:
  /// **'BloodPressed · BP Record'**
  String get shareCardRecordHeader;

  /// No description provided for @cardMeasuredAt.
  ///
  /// In en, this message translates to:
  /// **'{datetime} · Measured with {arm}'**
  String cardMeasuredAt(String datetime, String arm);

  /// No description provided for @cardFooterRecord.
  ///
  /// In en, this message translates to:
  /// **'Keep measuring to protect your heart'**
  String get cardFooterRecord;

  /// No description provided for @shareCardStatsHeader.
  ///
  /// In en, this message translates to:
  /// **'BloodPressed · BP Summary'**
  String get shareCardStatsHeader;

  /// No description provided for @statsOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'BP Overview — last {days}'**
  String statsOverviewTitle(String days);

  /// No description provided for @avgBpLabel.
  ///
  /// In en, this message translates to:
  /// **'Average BP'**
  String get avgBpLabel;

  /// No description provided for @bpRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'BP Range'**
  String get bpRangeLabel;

  /// No description provided for @avgPulseLabel.
  ///
  /// In en, this message translates to:
  /// **'Average Pulse'**
  String get avgPulseLabel;

  /// No description provided for @countLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get countLabel;

  /// No description provided for @onTargetRateLabel.
  ///
  /// In en, this message translates to:
  /// **'On-target rate (<135/85)'**
  String get onTargetRateLabel;

  /// No description provided for @bpRangeValue.
  ///
  /// In en, this message translates to:
  /// **'Sys {smin}~{smax} · Dia {dmin}~{dmax}'**
  String bpRangeValue(int smin, int smax, int dmin, int dmax);

  /// No description provided for @timesValue.
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String timesValue(int count);

  /// No description provided for @cardFooterStats.
  ///
  /// In en, this message translates to:
  /// **'Measure regularly, stay in control'**
  String get cardFooterStats;

  /// No description provided for @days7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get days7;

  /// No description provided for @days30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get days30;

  /// No description provided for @days90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get days90;

  /// No description provided for @daysPeriod.
  ///
  /// In en, this message translates to:
  /// **'a period'**
  String get daysPeriod;

  /// No description provided for @csvTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get csvTime;

  /// No description provided for @csvSystolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic(mmHg)'**
  String get csvSystolic;

  /// No description provided for @csvDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic(mmHg)'**
  String get csvDiastolic;

  /// No description provided for @csvPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse(bpm)'**
  String get csvPulse;

  /// No description provided for @csvArm.
  ///
  /// In en, this message translates to:
  /// **'Arm'**
  String get csvArm;

  /// No description provided for @csvPosture.
  ///
  /// In en, this message translates to:
  /// **'Posture'**
  String get csvPosture;

  /// No description provided for @csvNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get csvNote;

  /// No description provided for @csvSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get csvSource;

  /// No description provided for @cameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission Denied'**
  String get cameraPermissionTitle;

  /// No description provided for @cameraPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Please allow camera access in system settings and try again.'**
  String get cameraPermissionMessage;

  /// No description provided for @ocrRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get ocrRecognizing;

  /// No description provided for @ocrNoLcd.
  ///
  /// In en, this message translates to:
  /// **'LCD: no backlit display found'**
  String get ocrNoLcd;

  /// No description provided for @ocrLcdReadout.
  ///
  /// In en, this message translates to:
  /// **'LCD readings: {numbers}'**
  String ocrLcdReadout(String numbers);

  /// No description provided for @ocrLcdNoNumbers.
  ///
  /// In en, this message translates to:
  /// **'no readable digits'**
  String get ocrLcdNoNumbers;

  /// No description provided for @ocrLineCount.
  ///
  /// In en, this message translates to:
  /// **'; OCR lines: {count}'**
  String ocrLineCount(int count);

  /// No description provided for @ocrServiceError.
  ///
  /// In en, this message translates to:
  /// **'Recognition service error. Please try again; if it keeps failing, enter the values manually.'**
  String get ocrServiceError;

  /// No description provided for @ocrFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed: {error}'**
  String ocrFailed(String error);

  /// No description provided for @ocrFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recognition Failed'**
  String get ocrFailedTitle;

  /// No description provided for @ocrDiagSaved.
  ///
  /// In en, this message translates to:
  /// **'(Diagnostics saved to ocr_debug/{folder})'**
  String ocrDiagSaved(String folder);

  /// No description provided for @okGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get okGotIt;

  /// No description provided for @llmTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get llmTitle;

  /// No description provided for @llmLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profiles: {error}'**
  String llmLoadFailed(String error);

  /// No description provided for @llmIntro.
  ///
  /// In en, this message translates to:
  /// **'Set up a local or remote LLM to enable health guidance, AI photo reading and other smart features.'**
  String get llmIntro;

  /// No description provided for @llmEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No models configured yet'**
  String get llmEmptyTitle;

  /// No description provided for @llmEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download a local model from ModelScope (works offline),\nor configure a remote API (more capable).'**
  String get llmEmptySubtitle;

  /// No description provided for @llmInstallFromMarket.
  ///
  /// In en, this message translates to:
  /// **'Install a model from ModelScope'**
  String get llmInstallFromMarket;

  /// No description provided for @llmAddRemote.
  ///
  /// In en, this message translates to:
  /// **'Add Remote Model API'**
  String get llmAddRemote;

  /// No description provided for @llmAddFromFile.
  ///
  /// In en, this message translates to:
  /// **'Add from downloaded files'**
  String get llmAddFromFile;

  /// No description provided for @activatedProfile.
  ///
  /// In en, this message translates to:
  /// **'Activated “{name}”'**
  String activatedProfile(String name);

  /// No description provided for @deleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Model Profile'**
  String get deleteProfileTitle;

  /// No description provided for @deleteProfileContent.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?{keepFileNote}'**
  String deleteProfileContent(String name, String keepFileNote);

  /// No description provided for @deleteProfileKeepFile.
  ///
  /// In en, this message translates to:
  /// **'\nThe model file will not be deleted and can be re-added later.'**
  String get deleteProfileKeepFile;

  /// No description provided for @noModelFiles.
  ///
  /// In en, this message translates to:
  /// **'No downloaded .gguf model files found'**
  String get noModelFiles;

  /// No description provided for @pickModelFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Model File'**
  String get pickModelFileTitle;

  /// No description provided for @profileLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local model · {file}'**
  String profileLocalSubtitle(String file);

  /// No description provided for @profileRemoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remote API · {model}{multimodal}'**
  String profileRemoteSubtitle(String model, String multimodal);

  /// No description provided for @profileMultimodalSuffix.
  ///
  /// In en, this message translates to:
  /// **' · supports images'**
  String get profileMultimodalSuffix;

  /// No description provided for @engineLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get engineLoading;

  /// No description provided for @engineActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get engineActive;

  /// No description provided for @menuActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get menuActivate;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuDelete;

  /// No description provided for @remoteEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Remote Model'**
  String get remoteEditTitle;

  /// No description provided for @remoteAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Remote Model'**
  String get remoteAddTitle;

  /// No description provided for @presetSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a service preset (optional)'**
  String get presetSectionTitle;

  /// No description provided for @presetNameModelscope.
  ///
  /// In en, this message translates to:
  /// **'ModelScope API-Inference'**
  String get presetNameModelscope;

  /// No description provided for @presetNameArk.
  ///
  /// In en, this message translates to:
  /// **'Volcano Ark'**
  String get presetNameArk;

  /// No description provided for @presetNameDashScope.
  ///
  /// In en, this message translates to:
  /// **'Alibaba DashScope'**
  String get presetNameDashScope;

  /// No description provided for @presetNameDeepSeek.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek'**
  String get presetNameDeepSeek;

  /// No description provided for @presetNameOpenAI.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get presetNameOpenAI;

  /// No description provided for @presetNameOllama.
  ///
  /// In en, this message translates to:
  /// **'Ollama (local/LAN)'**
  String get presetNameOllama;

  /// No description provided for @presetDescModelscope.
  ///
  /// In en, this message translates to:
  /// **'Free inference API from ModelScope. Get a token on the ModelScope website.'**
  String get presetDescModelscope;

  /// No description provided for @presetDescArk.
  ///
  /// In en, this message translates to:
  /// **'ByteDance Volcano Engine. Get the API key in the Ark console under “API Key Management”.'**
  String get presetDescArk;

  /// No description provided for @presetDescDashScope.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Cloud Bailian, OpenAI-compatible mode.'**
  String get presetDescDashScope;

  /// No description provided for @presetDescDeepSeek.
  ///
  /// In en, this message translates to:
  /// **'Official DeepSeek API.'**
  String get presetDescDeepSeek;

  /// No description provided for @presetDescOpenAI.
  ///
  /// In en, this message translates to:
  /// **'Official OpenAI API (mainland China network access is on you).'**
  String get presetDescOpenAI;

  /// No description provided for @presetDescOllama.
  ///
  /// In en, this message translates to:
  /// **'Run Ollama on your computer with the port open; keep the phone on the same LAN.'**
  String get presetDescOllama;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ModelScope Qwen / DeepSeek'**
  String get nameHint;

  /// No description provided for @fieldBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API base URL (no trailing slash)'**
  String get fieldBaseUrl;

  /// No description provided for @fieldApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key (optional for some services)'**
  String get fieldApiKey;

  /// No description provided for @fieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model name (model)'**
  String get fieldModel;

  /// No description provided for @modelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Qwen/Qwen3-32B or deepseek-chat'**
  String get modelHint;

  /// No description provided for @fetchModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fetch model list'**
  String get fetchModelsTooltip;

  /// No description provided for @multimodalTitle.
  ///
  /// In en, this message translates to:
  /// **'Support image input (multimodal)'**
  String get multimodalTitle;

  /// No description provided for @multimodalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When on, this model can read blood pressure monitor photos (OCR fallback).'**
  String get multimodalSubtitle;

  /// No description provided for @saveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveBtn;

  /// No description provided for @addActivateBtn.
  ///
  /// In en, this message translates to:
  /// **'Add & Activate'**
  String get addActivateBtn;

  /// No description provided for @needBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter the API base URL first'**
  String get needBaseUrl;

  /// No description provided for @needAllFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in the name, base URL and model name'**
  String get needAllFields;

  /// No description provided for @fetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Fetch failed: {error}'**
  String fetchFailed(String error);

  /// No description provided for @searchModels.
  ///
  /// In en, this message translates to:
  /// **'Search models ({count} total)'**
  String searchModels(int count);

  /// No description provided for @noMatchModels.
  ///
  /// In en, this message translates to:
  /// **'No matching models'**
  String get noMatchModels;

  /// No description provided for @marketTitle.
  ///
  /// In en, this message translates to:
  /// **'ModelScope Market'**
  String get marketTitle;

  /// No description provided for @marketIntro.
  ///
  /// In en, this message translates to:
  /// **'Download GGUF models from ModelScope to run offline on your phone. Q4-quantized 0.6B–2B models balance quality and memory.'**
  String get marketIntro;

  /// No description provided for @sectionDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get sectionDownloads;

  /// No description provided for @sectionCurated.
  ///
  /// In en, this message translates to:
  /// **'Curated Models (official Qwen)'**
  String get sectionCurated;

  /// No description provided for @sectionOtherRepos.
  ///
  /// In en, this message translates to:
  /// **'Other Repositories'**
  String get sectionOtherRepos;

  /// No description provided for @customRepoHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a model ID, e.g. Qwen/Qwen3-1.7B-GGUF'**
  String get customRepoHint;

  /// No description provided for @viewBtn.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewBtn;

  /// No description provided for @customRepo.
  ///
  /// In en, this message translates to:
  /// **'Custom repository'**
  String get customRepo;

  /// No description provided for @customRepoDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetch the GGUF file list of this repository from ModelScope'**
  String get customRepoDesc;

  /// No description provided for @noGgufFiles.
  ///
  /// In en, this message translates to:
  /// **'No GGUF weights available in this repository'**
  String get noGgufFiles;

  /// No description provided for @marketConnError.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach ModelScope. Check your network and try again.'**
  String get marketConnError;

  /// No description provided for @listFilesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch file list: {error}'**
  String listFilesFailed(String error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @downloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadTooltip;

  /// No description provided for @failedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedTooltip;

  /// No description provided for @curatedDescQwen3_0_6B_GGUF.
  ///
  /// In en, this message translates to:
  /// **'Lightweight pick · works on low-end phones · 0.4–0.6GB'**
  String get curatedDescQwen3_0_6B_GGUF;

  /// No description provided for @curatedDescQwen3_1_7B_GGUF.
  ///
  /// In en, this message translates to:
  /// **'Balanced quality and speed · mid-range phones or better'**
  String get curatedDescQwen3_1_7B_GGUF;

  /// No description provided for @curatedDescQwen3_4B_GGUF.
  ///
  /// In en, this message translates to:
  /// **'Better answers · needs 6GB+ memory'**
  String get curatedDescQwen3_4B_GGUF;

  /// No description provided for @curatedDescQwen2_5_0_5B_Instruct_GGUF.
  ///
  /// In en, this message translates to:
  /// **'Previous-gen small model · memory-friendly'**
  String get curatedDescQwen2_5_0_5B_Instruct_GGUF;

  /// No description provided for @curatedDescQwen2_5_1_5B_Instruct_GGUF.
  ///
  /// In en, this message translates to:
  /// **'Previous-gen balanced pick'**
  String get curatedDescQwen2_5_1_5B_Instruct_GGUF;

  /// No description provided for @curatedDescQwen2_5_3B_Instruct_GGUF.
  ///
  /// In en, this message translates to:
  /// **'Previous-gen quality tier'**
  String get curatedDescQwen2_5_3B_Instruct_GGUF;

  /// No description provided for @curatedSizeQwen3_0_6B_GGUF.
  ///
  /// In en, this message translates to:
  /// **'about 0.4–0.7 GB'**
  String get curatedSizeQwen3_0_6B_GGUF;

  /// No description provided for @curatedSizeQwen3_1_7B_GGUF.
  ///
  /// In en, this message translates to:
  /// **'about 1.0–1.9 GB'**
  String get curatedSizeQwen3_1_7B_GGUF;

  /// No description provided for @curatedSizeQwen3_4B_GGUF.
  ///
  /// In en, this message translates to:
  /// **'about 2.3–4.4 GB'**
  String get curatedSizeQwen3_4B_GGUF;

  /// No description provided for @curatedSizeQwen2_5_0_5B_Instruct_GGUF.
  ///
  /// In en, this message translates to:
  /// **'about 0.4–0.7 GB'**
  String get curatedSizeQwen2_5_0_5B_Instruct_GGUF;

  /// No description provided for @curatedSizeQwen2_5_1_5B_Instruct_GGUF.
  ///
  /// In en, this message translates to:
  /// **'about 0.9–1.8 GB'**
  String get curatedSizeQwen2_5_1_5B_Instruct_GGUF;

  /// No description provided for @curatedSizeQwen2_5_3B_Instruct_GGUF.
  ///
  /// In en, this message translates to:
  /// **'about 1.8–3.2 GB'**
  String get curatedSizeQwen2_5_3B_Instruct_GGUF;
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
