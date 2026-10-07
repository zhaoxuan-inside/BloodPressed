// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '血压了么';

  @override
  String get langTitle => '语言';

  @override
  String get langSubtitle => '界面语言 · 知识文章与 AI 指导暂为中文';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langChinese => '中文';

  @override
  String get langEnglish => 'English';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get delete => '删除';

  @override
  String loadDataFailed(String error) {
    return '数据加载失败：$error';
  }

  @override
  String get sectionEntry => '录入血压';

  @override
  String get actionManual => '手动录入';

  @override
  String get actionCamera => '拍照识别';

  @override
  String get actionGallery => '相册识别';

  @override
  String get sectionHistory => '历史记录';

  @override
  String get emptyHomeTitle => '还没有血压记录';

  @override
  String get emptyHomeSubtitle => '从上方“手动录入”开始，或直接拍照识别血压计读数';

  @override
  String get historyHint => '左滑删除 · 点击编辑';

  @override
  String get sheetManualSubtitle => '直接输入高压/低压/脉搏';

  @override
  String get sheetGalleryTitle => '从相册选择';

  @override
  String get sheetCameraSubtitle => '拍摄血压计屏幕，自动识别读数';

  @override
  String get sheetGallerySubtitle => '识别已有的血压计照片';

  @override
  String get welcomeTitle => '👋 欢迎使用血压了么';

  @override
  String get welcomeSubtitle => '记录第一次血压，开始你的健康之旅';

  @override
  String get latestMeasurement => '最近一次测量';

  @override
  String todayMeasuredTimes(int count) {
    return '今日已测 $count 次';
  }

  @override
  String get pulseUnit => '次/分';

  @override
  String get armLeft => '左臂';

  @override
  String get armRight => '右臂';

  @override
  String get postureNotRecorded => '未记录';

  @override
  String get postureLying => '卧位';

  @override
  String get postureSitting => '坐位';

  @override
  String get postureStanding => '站位';

  @override
  String get sourceManual => '手动';

  @override
  String get sourceOcr => '拍照识别';

  @override
  String get sourceAi => 'AI识别';

  @override
  String get categoryLow => '偏低';

  @override
  String get categoryNormal => '正常';

  @override
  String get categoryElevated => '正常高值';

  @override
  String get categoryGrade1 => '轻度升高';

  @override
  String get categoryGrade2 => '中重度升高';

  @override
  String get adviceLow => '血压偏低，若无不适无需处理；若伴头晕乏力请咨询医生。';

  @override
  String get adviceNormal => '血压处于理想范围，请继续保持健康生活方式。';

  @override
  String get adviceElevated => '血压偏高但未达高血压水平，建议限盐、运动并规律复测。';

  @override
  String get adviceGrade1 => '血压已达1级高血压水平（家庭自测），建议复测并咨询医生。';

  @override
  String get adviceGrade2 => '血压明显升高，建议尽快就医评估，切勿自行调整用药。';

  @override
  String get editRecordTitle => '编辑记录';

  @override
  String get newRecordTitle => '录入血压';

  @override
  String get sysLabel => '高压（收缩压）';

  @override
  String get diaLabel => '低压（舒张压）';

  @override
  String get pulseLabel => '脉搏（可选）';

  @override
  String get postureField => '体位（可选）';

  @override
  String get noteField => '备注（可选，如运动后、服药前）';

  @override
  String get saveEdit => '保存修改';

  @override
  String get saveNew => '保存记录';

  @override
  String get bannerSourceOcr => '拍照识别结果';

  @override
  String get bannerSourceAi => 'AI 识别结果';

  @override
  String bannerLowNoValue(String source) {
    return '$source未能读出数值，请手动录入并核对后保存';
  }

  @override
  String bannerLowConfidence(String source, int percent) {
    return '$source置信度低（$percent%），红框数值仅供参考，请核对修改后保存';
  }

  @override
  String bannerAutoFilled(String source, String confidence) {
    return '$source$confidence 已自动填入，请核对后保存';
  }

  @override
  String confidenceSuffix(int percent) {
    return '（置信度 $percent%）';
  }

  @override
  String get errNeedSysDia => '请填写高压与低压';

  @override
  String get errSysRange => '高压应在 40 ~ 300 之间';

  @override
  String get errDiaRange => '低压应在 30 ~ 200 之间';

  @override
  String get errSysGreater => '高压应大于低压';

  @override
  String get errPulseRange => '脉搏应在 20 ~ 300 之间';

  @override
  String get deleteRecordTitle => '删除记录';

  @override
  String deleteRecordContent(String datetime, int sys, int dia) {
    return '删除 $datetime 的记录（$sys/$dia）？删除后不可恢复。';
  }
}
