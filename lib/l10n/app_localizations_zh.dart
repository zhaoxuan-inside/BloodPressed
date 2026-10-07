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

  @override
  String get llmTitle => 'AI 模型';

  @override
  String llmLoadFailed(String error) {
    return '配置加载失败：$error';
  }

  @override
  String get llmIntro => '配置本地或远端大模型后，可以使用健康指导、AI 识别血压照片等智能功能。';

  @override
  String get llmEmptyTitle => '尚未配置任何模型';

  @override
  String get llmEmptySubtitle => '从魔搭社区下载一个本地模型（离线可用），\n或配置一个远端 API（能力更强）。';

  @override
  String get llmInstallFromMarket => '从魔搭社区安装模型';

  @override
  String get llmAddRemote => '添加远端模型 API';

  @override
  String get llmAddFromFile => '从已下载文件添加';

  @override
  String activatedProfile(String name) {
    return '已启用「$name」';
  }

  @override
  String get deleteProfileTitle => '删除模型配置';

  @override
  String deleteProfileContent(String name, String keepFileNote) {
    return '删除「$name」？$keepFileNote';
  }

  @override
  String get deleteProfileKeepFile => '\n模型文件不会被删除，可稍后重新添加。';

  @override
  String get noModelFiles => '没有找到已下载的 .gguf 模型文件';

  @override
  String get pickModelFileTitle => '选择模型文件';

  @override
  String profileLocalSubtitle(String file) {
    return '本地模型 · $file';
  }

  @override
  String profileRemoteSubtitle(String model, String multimodal) {
    return '远端 API · $model$multimodal';
  }

  @override
  String get profileMultimodalSuffix => ' · 支持图片';

  @override
  String get engineLoading => '加载中';

  @override
  String get engineActive => '使用中';

  @override
  String get menuActivate => '启用';

  @override
  String get menuEdit => '编辑';

  @override
  String get menuDelete => '删除';

  @override
  String get remoteEditTitle => '编辑远端模型';

  @override
  String get remoteAddTitle => '添加远端模型';

  @override
  String get presetSectionTitle => '选择服务预设（可选）';

  @override
  String get presetNameModelscope => 'ModelScope API-Inference（魔搭）';

  @override
  String get presetNameArk => '火山方舟 Ark';

  @override
  String get presetNameDashScope => '阿里云百炼 DashScope';

  @override
  String get presetNameDeepSeek => 'DeepSeek';

  @override
  String get presetNameOpenAI => 'OpenAI';

  @override
  String get presetNameOllama => 'Ollama（本地/局域网）';

  @override
  String get presetDescModelscope => '魔搭社区提供的免费推理 API，需在魔搭官网获取 Token';

  @override
  String get presetDescArk => '字节跳动火山引擎；API Key 在方舟控制台「API Key 管理」获取';

  @override
  String get presetDescDashScope => '阿里云百炼 OpenAI 兼容模式';

  @override
  String get presetDescDeepSeek => 'DeepSeek 官方 API';

  @override
  String get presetDescOpenAI => 'OpenAI 官方 API（国内访问需自行解决网络）';

  @override
  String get presetDescOllama => '电脑上运行 Ollama 并开放端口，手机与电脑同一局域网';

  @override
  String get fieldName => '名称';

  @override
  String get nameHint => '如：魔搭 Qwen / DeepSeek';

  @override
  String get fieldBaseUrl => 'API 地址（baseUrl，无需以 / 结尾）';

  @override
  String get fieldApiKey => 'API Key（部分服务可留空）';

  @override
  String get fieldModel => '模型名称（model）';

  @override
  String get modelHint => '如 Qwen/Qwen3-32B 或 deepseek-chat';

  @override
  String get fetchModelsTooltip => '获取模型列表';

  @override
  String get multimodalTitle => '支持图片输入（多模态）';

  @override
  String get multimodalSubtitle => '开启后可用该模型识别血压计照片（OCR 兜底）';

  @override
  String get saveBtn => '保存';

  @override
  String get addActivateBtn => '添加并启用';

  @override
  String get needBaseUrl => '请先填写 API 地址（baseUrl）';

  @override
  String get needAllFields => '请填写名称、服务地址和模型名称';

  @override
  String fetchFailed(String error) {
    return '获取失败：$error';
  }

  @override
  String searchModels(int count) {
    return '搜索模型（共 $count 个）';
  }

  @override
  String get noMatchModels => '无匹配模型';

  @override
  String get marketTitle => '魔搭模型市场';

  @override
  String get marketIntro =>
      '从魔搭社区（ModelScope）下载 GGUF 模型到手机，离线运行。建议选择 0.6B~2B 的 Q4 量化版本，兼顾效果与内存。';

  @override
  String get sectionDownloads => '下载任务';

  @override
  String get sectionCurated => '精选模型（Qwen 官方）';

  @override
  String get sectionOtherRepos => '其他仓库';

  @override
  String get customRepoHint => '输入模型ID，如 Qwen/Qwen3-1.7B-GGUF';

  @override
  String get viewBtn => '查看';

  @override
  String get customRepo => '自定义仓库';

  @override
  String get customRepoDesc => '从魔搭拉取该仓库的 GGUF 文件列表';

  @override
  String get noGgufFiles => '该仓库没有可用的 GGUF 权重文件';

  @override
  String get marketConnError => '无法连接魔搭服务器，请检查网络后重试';

  @override
  String listFilesFailed(String error) {
    return '获取文件列表失败：$error';
  }

  @override
  String get retry => '重试';

  @override
  String get downloadTooltip => '下载';

  @override
  String get failedTooltip => '失败';

  @override
  String get curatedDescQwen3_0_6B_GGUF => '轻量首选 · 低端机可用 · 0.4~0.6GB';

  @override
  String get curatedDescQwen3_1_7B_GGUF => '效果与速度均衡 · 推荐中端及以上机型';

  @override
  String get curatedDescQwen3_4B_GGUF => '回答质量更好 · 需要 6GB+ 内存';

  @override
  String get curatedDescQwen2_5_0_5B_Instruct_GGUF => '上一代小模型 · 省内存';

  @override
  String get curatedDescQwen2_5_1_5B_Instruct_GGUF => '上一代均衡之选';

  @override
  String get curatedDescQwen2_5_3B_Instruct_GGUF => '上一代质量档';

  @override
  String get curatedSizeQwen3_0_6B_GGUF => '约 0.4~0.7 GB';

  @override
  String get curatedSizeQwen3_1_7B_GGUF => '约 1.0~1.9 GB';

  @override
  String get curatedSizeQwen3_4B_GGUF => '约 2.3~4.4 GB';

  @override
  String get curatedSizeQwen2_5_0_5B_Instruct_GGUF => '约 0.4~0.7 GB';

  @override
  String get curatedSizeQwen2_5_1_5B_Instruct_GGUF => '约 0.9~1.8 GB';

  @override
  String get curatedSizeQwen2_5_3B_Instruct_GGUF => '约 1.8~3.2 GB';

  @override
  String get assistantTitle => '健康指导';

  @override
  String assistantModelLabel(String name) {
    return '模型：$name';
  }

  @override
  String get clearConversationTooltip => '清空对话';

  @override
  String get clearConversationTitle => '清空对话';

  @override
  String get clearConversationContent => '确定删除全部对话记录吗？';

  @override
  String get clearConversationConfirm => '清空';

  @override
  String get assistantInputHint => '例如：我最近血压偏高，饮食上要注意什么？';

  @override
  String get assistantInputNoModel => '请先配置模型';

  @override
  String get assistantDisclaimer => 'AI 建议仅供参考，不能替代专业医疗意见';

  @override
  String get noModelYet => '尚未配置 AI 模型';

  @override
  String get noModelHint => '配置本地模型（离线可用）或远端 API 后，\n即可获得个性化血压健康指导。';

  @override
  String get goConfigure => '去配置模型';

  @override
  String get assistantWelcomeTitle => '👋 你好，我是你的血压健康助手';

  @override
  String get assistantWelcomeBody => '我会结合你近 30 天的血压记录给出建议。\n你可以这样问我：';

  @override
  String get suggestAnalyze => '帮我分析一下最近的血压情况';

  @override
  String get suggestDiet => '血压偏高，饮食上应该注意什么？';

  @override
  String get suggestMeasure => '如何正确测量血压？';

  @override
  String get suggestExercise => '运动对降压有帮助吗？怎么运动？';

  @override
  String get knowledgeTitle => '健康知识';

  @override
  String get categoryAll => '全部';

  @override
  String get noArticlesInCategory => '该分类暂无文章';

  @override
  String minutesRead(int minutes) {
    return '约 $minutes 分钟阅读';
  }

  @override
  String loadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get fontSmaller => '缩小字号';

  @override
  String get fontLarger => '放大字号';

  @override
  String get favorite => '收藏';

  @override
  String get aiModelSection => 'AI 模型';

  @override
  String get aiModelConfig => 'AI 模型配置';

  @override
  String get aiModelNotConfigured => '未配置 · 点击添加本地或远端模型';

  @override
  String aiModelCurrent(String name, String kind) {
    return '当前：$name（$kind）';
  }

  @override
  String get kindLocal => '本地';

  @override
  String get kindRemote => '远端';

  @override
  String llmLoadError(String error) {
    return '模型加载失败：$error';
  }

  @override
  String get sectionPreference => '测量偏好';

  @override
  String get defaultArm => '默认测量臂';

  @override
  String get reminderTitle => '测量提醒';

  @override
  String get reminderOff => '关闭';

  @override
  String get reminderDaily => '定时';

  @override
  String get reminderInterval => '周期';

  @override
  String get reminderDailyTime => '提醒时间';

  @override
  String get reminderDailySubtitle => '每天在固定时刻提醒测量';

  @override
  String get reminderWindowTitle => '提醒窗口';

  @override
  String get reminderWindowSubtitle => '仅在窗口内按周期提醒';

  @override
  String get reminderIntervalTitle => '提醒周期';

  @override
  String get reminderIntervalSubtitle => '窗口内每隔该时长提醒一次';

  @override
  String intervalMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get windowEndAfterStart => '结束时间需晚于开始时间';

  @override
  String get notificationDenied => '未获得通知权限，提醒可能无法显示';

  @override
  String get sectionData => '数据';

  @override
  String get exportShare => '导出与分享';

  @override
  String get exportShareSubtitle => 'CSV 导出 · 卡片分享 · 微信';

  @override
  String get cloudSync => '云同步';

  @override
  String get cloudSyncSubtitle => '未开启 · 多设备同步（预留）';

  @override
  String get sectionGeneral => '通用';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '亮色';

  @override
  String get themeDark => '暗色';

  @override
  String get wechatConfig => '微信分享配置';

  @override
  String get wechatNotConfigured => '未配置 AppID（未配置时使用系统分享）';

  @override
  String wechatAppIdMasked(String masked) {
    return 'AppID：$masked';
  }

  @override
  String get wechatDialogTitle => '微信分享配置';

  @override
  String get wechatAppIdField => '微信开放平台 AppID';

  @override
  String get wechatAppIdHint => '留空则使用系统分享';

  @override
  String get wechatUniversalLinkField => 'iOS Universal Link（可选）';

  @override
  String get sectionAbout => '关于';

  @override
  String get appVersionSubtitle => 'v1.0.0 · 跨平台血压健康助手';

  @override
  String get disclaimer => '免责声明';

  @override
  String get disclaimerBody =>
      '本应用提供的所有内容（包括但不限于血压分级提示、AI 健康指导、健康知识文章）仅用于健康信息参考与自我管理辅助，不构成医学诊断或治疗建议。\n\nAI 生成内容可能存在错误或遗漏，请勿据此调整用药或做出医疗决策。如有健康问题，请咨询专业医疗机构。\n\n本应用数据仅保存在您的设备本地（云同步开启前不上传任何数据），请自行通过导出功能妥善备份。';

  @override
  String get syncTitle => '云同步';

  @override
  String get syncOn => '已开启';

  @override
  String get syncOff => '未开启';

  @override
  String get syncEnabledBody => '数据将自动同步到云端。';

  @override
  String get syncDisabledBody =>
      '云同步是增值服务，当前版本尚未接入云平台。你的所有数据仍完整保存在本机，可通过“导出与分享”随时备份 CSV。';

  @override
  String get syncReadiness => '同步能力准备情况';

  @override
  String get readyLocal => '本机数据保护（软删除 + updated_at 时间戳）';

  @override
  String get readyDeviceId => '跨设备唯一标识（UUID 主键 + 设备ID）';

  @override
  String readyOutbox(int count) {
    return '离线变更日志（Outbox，待同步 $count 条）';
  }

  @override
  String get readyPlatform => '云平台接入（候选：Supabase / 自建 API 等）';

  @override
  String get readyE2E => '端到端加密传输';

  @override
  String get sectionAccount => '账号（预留）';

  @override
  String get notLoggedIn => '未登录';

  @override
  String get loginAfterPlatform => '云平台接入后可在此登录账号';

  @override
  String get syncNote =>
      '说明：确定云平台后，只需实现 SyncService 接口并替换默认实现，本地数据模型与界面无需改动即可获得多设备同步能力。';

  @override
  String get notifDailyTitle => '该测量血压啦 🩺';

  @override
  String get notifDailyBody => '坚持记录，血压趋势才有意义。';

  @override
  String get channelDailyName => '每日测量提醒';

  @override
  String get channelDailyDesc => '提醒您每天定时测量血压';

  @override
  String get channelIntervalName => '周期测量提醒';

  @override
  String get channelIntervalDesc => '在提醒窗口内按固定周期提醒您测量血压';

  @override
  String get settingsTitle => '我的';

  @override
  String get avgSystolicCard => '平均高压';

  @override
  String get avgDiastolicCard => '平均低压';

  @override
  String get avgPulseCard => '平均脉搏';

  @override
  String minMaxHint(String high, String low) {
    return '最高 $high · 最低 $low';
  }

  @override
  String replyInterrupted(String error) {
    return '回复中断：$error';
  }

  @override
  String get llmNotConfigured => '尚未配置大模型';

  @override
  String get llmNotReady => '模型尚未就绪';

  @override
  String get navHome => '首页';

  @override
  String get navStats => '趋势';

  @override
  String get navAssistant => 'AI助手';

  @override
  String get navKnowledge => '知识';

  @override
  String get navMe => '我的';
}
