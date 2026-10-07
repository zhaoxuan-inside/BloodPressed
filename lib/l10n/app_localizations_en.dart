// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BloodPressed';

  @override
  String get langTitle => 'Language';

  @override
  String get langSubtitle =>
      'UI language · Knowledge articles and AI guidance remain in Chinese';

  @override
  String get langSystem => 'System';

  @override
  String get langChinese => '中文';

  @override
  String get langEnglish => 'English';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String loadDataFailed(String error) {
    return 'Failed to load data: $error';
  }

  @override
  String get sectionEntry => 'Record Blood Pressure';

  @override
  String get actionManual => 'Manual Entry';

  @override
  String get actionCamera => 'Camera Scan';

  @override
  String get actionGallery => 'Photo Scan';

  @override
  String get sectionHistory => 'History';

  @override
  String get emptyHomeTitle => 'No blood pressure records yet';

  @override
  String get emptyHomeSubtitle =>
      'Start with “Manual Entry” above, or scan a monitor reading with your camera';

  @override
  String get historyHint => 'Swipe left to delete · Tap to edit';

  @override
  String get sheetManualSubtitle =>
      'Enter systolic, diastolic and pulse directly';

  @override
  String get sheetGalleryTitle => 'Choose from Photos';

  @override
  String get sheetCameraSubtitle =>
      'Take a photo of the monitor screen to read values automatically';

  @override
  String get sheetGallerySubtitle =>
      'Read values from an existing monitor photo';

  @override
  String get welcomeTitle => '👋 Welcome to BloodPressed';

  @override
  String get welcomeSubtitle =>
      'Record your first blood pressure and start your health journey';

  @override
  String get latestMeasurement => 'Latest measurement';

  @override
  String todayMeasuredTimes(int count) {
    return 'Measured $count times today';
  }

  @override
  String get pulseUnit => 'bpm';

  @override
  String get armLeft => 'Left arm';

  @override
  String get armRight => 'Right arm';

  @override
  String get postureNotRecorded => 'Not recorded';

  @override
  String get postureLying => 'Lying down';

  @override
  String get postureSitting => 'Sitting';

  @override
  String get postureStanding => 'Standing';

  @override
  String get sourceManual => 'Manual';

  @override
  String get sourceOcr => 'Camera scan';

  @override
  String get sourceAi => 'AI scan';

  @override
  String get categoryLow => 'Low';

  @override
  String get categoryNormal => 'Normal';

  @override
  String get categoryElevated => 'Elevated';

  @override
  String get categoryGrade1 => 'Grade 1';

  @override
  String get categoryGrade2 => 'Grade 2+';

  @override
  String get adviceLow =>
      'Blood pressure is low. No action needed if you feel well; see a doctor if you feel dizzy or weak.';

  @override
  String get adviceNormal =>
      'Blood pressure is in the ideal range. Keep up the healthy lifestyle.';

  @override
  String get adviceElevated =>
      'Blood pressure is high but not yet hypertension. Reduce salt, exercise, and re-measure regularly.';

  @override
  String get adviceGrade1 =>
      'Blood pressure has reached stage 1 hypertension (home measurement). Re-measure and consult a doctor.';

  @override
  String get adviceGrade2 =>
      'Blood pressure is markedly high. Seek medical care promptly; never adjust medication on your own.';

  @override
  String get editRecordTitle => 'Edit Record';

  @override
  String get newRecordTitle => 'Record Blood Pressure';

  @override
  String get sysLabel => 'Systolic (high)';

  @override
  String get diaLabel => 'Diastolic (low)';

  @override
  String get pulseLabel => 'Pulse (optional)';

  @override
  String get postureField => 'Posture (optional)';

  @override
  String get noteField =>
      'Note (optional, e.g. after exercise, before medication)';

  @override
  String get saveEdit => 'Save Changes';

  @override
  String get saveNew => 'Save Record';

  @override
  String get bannerSourceOcr => 'Camera scan result';

  @override
  String get bannerSourceAi => 'AI scan result';

  @override
  String bannerLowNoValue(String source) {
    return '$source could not read any values. Please enter them manually and review before saving.';
  }

  @override
  String bannerLowConfidence(String source, int percent) {
    return '$source returned low confidence ($percent%). Values in red boxes are for reference only — please review and correct before saving.';
  }

  @override
  String bannerAutoFilled(String source, String confidence) {
    return '$source$confidence was filled in automatically. Please review and save.';
  }

  @override
  String confidenceSuffix(int percent) {
    return ' ($percent% confidence)';
  }

  @override
  String get errNeedSysDia => 'Please enter systolic and diastolic values';

  @override
  String get errSysRange => 'Systolic must be between 40 and 300';

  @override
  String get errDiaRange => 'Diastolic must be between 30 and 200';

  @override
  String get errSysGreater => 'Systolic must be greater than diastolic';

  @override
  String get errPulseRange => 'Pulse must be between 20 and 300';

  @override
  String get deleteRecordTitle => 'Delete Record';

  @override
  String deleteRecordContent(String datetime, int sys, int dia) {
    return 'Delete the record from $datetime ($sys/$dia)? This cannot be undone.';
  }

  @override
  String get statsTitle => 'Blood Pressure Trends';

  @override
  String get statsCustom => 'Custom';

  @override
  String get armBoth => 'Both arms';

  @override
  String get onlyLeftArm => 'Left arm only';

  @override
  String get onlyRightArm => 'Right arm only';

  @override
  String get seriesBp => 'BP';

  @override
  String get seriesPulse => 'Pulse';

  @override
  String statsLoadFailed(String error) {
    return 'Failed to load stats: $error';
  }

  @override
  String trendLoadFailed(String error) {
    return 'Failed to load trend: $error';
  }

  @override
  String get statsEmptyTitle => 'No data in this range';

  @override
  String get statsEmptySubtitle =>
      'Adjust the time range or add a few records first';

  @override
  String get pulseEmpty => 'No pulse data in this range';

  @override
  String get chartReferenceHint =>
      'Dashed lines are home-measurement reference levels (systolic 135 / diastolic 85; above means elevated). Multiple readings on the same day are averaged.';

  @override
  String refSystolic(int value) {
    return 'Systolic $value';
  }

  @override
  String refDiastolic(int value) {
    return 'Diastolic $value';
  }

  @override
  String get range7 => 'Last 7 days';

  @override
  String get range30 => 'Last 30 days';

  @override
  String get range90 => 'Last 90 days';

  @override
  String get rangeAll => 'All';

  @override
  String get exportTitle => 'Export & Share';

  @override
  String get sectionCardShare => 'Card Sharing';

  @override
  String get cardTypeRecord => 'Single Record Card';

  @override
  String get cardTypeStats => 'Stats Summary Card';

  @override
  String get shareWechat => 'WeChat Chat';

  @override
  String get shareMoments => 'Moments';

  @override
  String get shareMore => 'More Ways to Share';

  @override
  String get sectionDataExport => 'Data Export';

  @override
  String get exportCsvButton => 'Export all records as CSV (opens in Excel)';

  @override
  String get csvContentsHint =>
      'CSV includes: time, systolic, diastolic, pulse, arm, posture, note, source.';

  @override
  String get emptyExportTitle => 'No records yet';

  @override
  String get emptyExportSubtitle =>
      'Add a blood pressure record before sharing a card';

  @override
  String get shareText => 'My blood pressure record (from BloodPressed)';

  @override
  String get csvShareText => 'BloodPressed blood pressure record export';

  @override
  String shareFailed(String error) {
    return 'Sharing failed: $error';
  }

  @override
  String get exportEmpty => 'No records to export';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get cardNotReady => 'Share card has not finished rendering';

  @override
  String get cardExportFailed => 'Failed to export card';

  @override
  String get shareCardRecordHeader => 'BloodPressed · BP Record';

  @override
  String cardMeasuredAt(String datetime, String arm) {
    return '$datetime · Measured with $arm';
  }

  @override
  String get cardFooterRecord => 'Keep measuring to protect your heart';

  @override
  String get shareCardStatsHeader => 'BloodPressed · BP Summary';

  @override
  String statsOverviewTitle(String days) {
    return 'BP Overview — last $days';
  }

  @override
  String get avgBpLabel => 'Average BP';

  @override
  String get bpRangeLabel => 'BP Range';

  @override
  String get avgPulseLabel => 'Average Pulse';

  @override
  String get countLabel => 'Measurements';

  @override
  String get onTargetRateLabel => 'On-target rate (<135/85)';

  @override
  String bpRangeValue(int smin, int smax, int dmin, int dmax) {
    return 'Sys $smin~$smax · Dia $dmin~$dmax';
  }

  @override
  String timesValue(int count) {
    return '$count times';
  }

  @override
  String get cardFooterStats => 'Measure regularly, stay in control';

  @override
  String get days7 => '7 days';

  @override
  String get days30 => '30 days';

  @override
  String get days90 => '90 days';

  @override
  String get daysPeriod => 'a period';

  @override
  String get csvTime => 'Time';

  @override
  String get csvSystolic => 'Systolic(mmHg)';

  @override
  String get csvDiastolic => 'Diastolic(mmHg)';

  @override
  String get csvPulse => 'Pulse(bpm)';

  @override
  String get csvArm => 'Arm';

  @override
  String get csvPosture => 'Posture';

  @override
  String get csvNote => 'Note';

  @override
  String get csvSource => 'Source';
}
