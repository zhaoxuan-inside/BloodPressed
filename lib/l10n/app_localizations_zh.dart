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

  @override
  String get statsTitle => '血压趋势';

  @override
  String get statsCustom => '自定义';

  @override
  String get armBoth => '双臂';

  @override
  String get onlyLeftArm => '仅左臂';

  @override
  String get onlyRightArm => '仅右臂';

  @override
  String get seriesBp => '血压';

  @override
  String get seriesPulse => '脉搏';

  @override
  String statsLoadFailed(String error) {
    return '统计加载失败：$error';
  }

  @override
  String trendLoadFailed(String error) {
    return '趋势加载失败：$error';
  }

  @override
  String get statsEmptyTitle => '该范围内暂无数据';

  @override
  String get statsEmptySubtitle => '调整时间范围或先添加几条记录';

  @override
  String get pulseEmpty => '该范围内没有脉搏数据';

  @override
  String get chartReferenceHint =>
      '水平虚线为家庭自测参考线（高压 135 / 低压 85，超过即为升高）。同日多次测量取平均值。';

  @override
  String refSystolic(int value) {
    return '高压$value';
  }

  @override
  String refDiastolic(int value) {
    return '低压$value';
  }

  @override
  String get range7 => '近7天';

  @override
  String get range30 => '近30天';

  @override
  String get range90 => '近90天';

  @override
  String get rangeAll => '全部';

  @override
  String get exportTitle => '导出与分享';

  @override
  String get sectionCardShare => '卡片分享';

  @override
  String get cardTypeRecord => '单次记录卡';

  @override
  String get cardTypeStats => '统计摘要卡';

  @override
  String get shareWechat => '微信好友';

  @override
  String get shareMoments => '朋友圈';

  @override
  String get shareMore => '更多方式分享';

  @override
  String get sectionDataExport => '数据导出';

  @override
  String get exportCsvButton => '导出全部记录为 CSV（Excel 可打开）';

  @override
  String get csvContentsHint => 'CSV 包含：时间、高压、低压、脉搏、测量臂、体位、备注、来源。';

  @override
  String get emptyExportTitle => '暂无记录';

  @override
  String get emptyExportSubtitle => '先添加一条血压记录再分享卡片';

  @override
  String get shareText => '我的血压记录（来自血压了么）';

  @override
  String get csvShareText => '血压了么 血压记录导出';

  @override
  String shareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get exportEmpty => '暂无记录可导出';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get cardNotReady => '分享卡片尚未渲染完成';

  @override
  String get cardExportFailed => '卡片导出失败';

  @override
  String get shareCardRecordHeader => '血压了么 · 血压记录';

  @override
  String cardMeasuredAt(String datetime, String arm) {
    return '$datetime · $arm测量';
  }

  @override
  String get cardFooterRecord => '坚持测量，守护心血管健康 💪';

  @override
  String get shareCardStatsHeader => '血压了么 · 血压周报';

  @override
  String statsOverviewTitle(String days) {
    return '近$days血压概览';
  }

  @override
  String get avgBpLabel => '平均血压';

  @override
  String get bpRangeLabel => '血压范围';

  @override
  String get avgPulseLabel => '平均脉搏';

  @override
  String get countLabel => '测量次数';

  @override
  String get onTargetRateLabel => '达标率（<135/85）';

  @override
  String bpRangeValue(int smin, int smax, int dmin, int dmax) {
    return '高压 $smin~$smax · 低压 $dmin~$dmax';
  }

  @override
  String timesValue(int count) {
    return '$count 次';
  }

  @override
  String get cardFooterStats => '规律监测，心中有数 📈';

  @override
  String get days7 => '7天';

  @override
  String get days30 => '30天';

  @override
  String get days90 => '90天';

  @override
  String get daysPeriod => '一段时间';

  @override
  String get csvTime => '测量时间';

  @override
  String get csvSystolic => '高压(mmHg)';

  @override
  String get csvDiastolic => '低压(mmHg)';

  @override
  String get csvPulse => '脉搏(次/分)';

  @override
  String get csvArm => '测量臂';

  @override
  String get csvPosture => '体位';

  @override
  String get csvNote => '备注';

  @override
  String get csvSource => '来源';

  @override
  String get cameraPermissionTitle => '未获得相机权限';

  @override
  String get cameraPermissionMessage => '请在系统设置中允许相机后重试。';

  @override
  String get ocrRecognizing => '正在识别…';

  @override
  String get ocrNoLcd => 'LCD: 未找到彩色背光屏';

  @override
  String ocrLcdReadout(String numbers) {
    return 'LCD 读数: $numbers';
  }

  @override
  String get ocrLcdNoNumbers => '无可读数字';

  @override
  String ocrLineCount(int count) {
    return '；OCR 行数: $count';
  }

  @override
  String get ocrServiceError => '识别服务异常，请重试；若持续失败请改用手动录入';

  @override
  String ocrFailed(String error) {
    return '识别失败：$error';
  }

  @override
  String get ocrFailedTitle => '识别失败';

  @override
  String ocrDiagSaved(String folder) {
    return '（诊断已存 ocr_debug/$folder）';
  }

  @override
  String get okGotIt => '知道了';
}
