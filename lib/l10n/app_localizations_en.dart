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
}
