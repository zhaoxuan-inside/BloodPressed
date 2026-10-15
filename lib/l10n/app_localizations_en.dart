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
  String get searchTitle => 'Search';

  @override
  String get marketSearchHint => 'Search models, e.g. qwen3 1.7b gguf';

  @override
  String get marketSearchResults => 'Search Results';

  @override
  String get marketNoResults => 'No models found';

  @override
  String get searchHint =>
      'Search features and settings, e.g. \"reminder\", \"export\"';

  @override
  String get searchNoResults => 'No matching features';

  @override
  String get searchSmartMatching => 'Smart matching…';

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
  String get armLeft => 'Left';

  @override
  String get armRight => 'Right';

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
  String get sourceVoice => 'Voice';

  @override
  String get voiceInputAction => 'Voice input blood pressure';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceNotAvailable =>
      'Speech recognition unavailable on this device';

  @override
  String get voiceNeedPermission =>
      'Microphone permission required — tap to grant';

  @override
  String get voiceModelMissing => 'Download offline voice model (~50 MB)';

  @override
  String voiceModelDownloading(int percent) {
    return 'Downloading offline voice model $percent%';
  }

  @override
  String get voiceErrorTitle => 'Voice Input Failed';

  @override
  String get voiceErrorCopyHint =>
      'Tap \"Copy error details\" to copy the diagnostic context (error code, recognized text, device and app info) for troubleshooting.';

  @override
  String get voiceErrorCopy => 'Copy error details';

  @override
  String get voiceErrorCopied => 'Error details copied';

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
  String get bannerSourceVoice => 'Voice input result';

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
  String get bucketNight => 'Night';

  @override
  String get bucketMorning => 'Morning';

  @override
  String get bucketAfternoon => 'Afternoon';

  @override
  String get bucketEvening => 'Evening';

  @override
  String get analysisTitle => 'BP Patterns';

  @override
  String analysisOnTargetShort(int count, int total) {
    return '$count/$total on target';
  }

  @override
  String analysisPeakLine(int sys, int dia, String time) {
    return 'Peak $sys/$dia · $time';
  }

  @override
  String analysisConclusionElevated(
    String bucket,
    String avgSys,
    String avgDia,
  ) {
    return 'Average BP elevated in the $bucket window ($avgSys/$avgDia)';
  }

  @override
  String get analysisConclusionIdeal =>
      'Average BP is within the ideal range across all windows';

  @override
  String get statsAiAnalyze => 'AI Analysis';

  @override
  String aiAnalysisPrompt(String range, String summary) {
    return 'Please analyze my blood pressure data for $range: $summary. Point out time-of-day patterns, weekday differences and trends worth attention, and give suggestions.';
  }

  @override
  String get shareCardTrendHeader => 'BloodPressed · BP Trend';

  @override
  String get shareCardAnalysisHeader => 'BloodPressed · BP Patterns';

  @override
  String get fullscreenTrendHint => 'Fullscreen';

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
  String get cardCaptureFailed =>
      'Failed to render share card, please try again';

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

  @override
  String get cameraPermissionTitle => 'Camera Permission Denied';

  @override
  String get cameraPermissionMessage =>
      'Please allow camera access in system settings and try again.';

  @override
  String get ocrRecognizing => 'Recognizing…';

  @override
  String get ocrNoLcd => 'LCD: no backlit display found';

  @override
  String ocrLcdReadout(String numbers) {
    return 'LCD readings: $numbers';
  }

  @override
  String get ocrLcdNoNumbers => 'no readable digits';

  @override
  String ocrLineCount(int count) {
    return '; OCR lines: $count';
  }

  @override
  String get ocrServiceError =>
      'Recognition service error. Please try again; if it keeps failing, enter the values manually.';

  @override
  String ocrFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String get ocrFailedTitle => 'Recognition Failed';

  @override
  String ocrDiagSaved(String folder) {
    return '(Diagnostics saved to ocr_debug/$folder)';
  }

  @override
  String get okGotIt => 'Got it';

  @override
  String get llmTitle => 'AI Models';

  @override
  String llmLoadFailed(String error) {
    return 'Failed to load profiles: $error';
  }

  @override
  String get builtinModelTitle => 'Built-in Model · Qwen3-1.7B';

  @override
  String get builtinModelReadySubtitle => 'Downloaded · works offline';

  @override
  String get builtinModelMissingSubtitle =>
      'Default model for the AI assistant and feature search, about 1.8GB, works offline once downloaded';

  @override
  String get builtinDownloadTitle => 'Download the built-in model?';

  @override
  String get builtinDownloadBody =>
      'Qwen3-1.7B (Q8_0 quantized) is about 1.8GB. Once downloaded, the AI assistant and feature search work offline. Wi-Fi recommended.';

  @override
  String get builtinDownloadConfirm => 'Download';

  @override
  String builtinDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get builtinDownloadPaused => 'Paused';

  @override
  String get builtinDownloadFailed => 'Download failed';

  @override
  String get builtinUseNow => 'Use built-in model';

  @override
  String get llmIntro =>
      'Set up a local or remote LLM to enable health guidance, AI photo reading and other smart features.';

  @override
  String get llmEmptyTitle => 'No models configured yet';

  @override
  String get llmEmptySubtitle =>
      'Download a local model from the Model Center (works offline),\nor configure a remote API (more capable).';

  @override
  String get llmInstallFromMarket => 'Install a model from Model Center';

  @override
  String get llmAddRemote => 'Add Remote Model API';

  @override
  String get llmAddFromFile => 'Add from downloaded files';

  @override
  String activatedProfile(String name) {
    return 'Activated “$name”';
  }

  @override
  String get deleteProfileTitle => 'Delete Model Profile';

  @override
  String deleteProfileContent(String name, String keepFileNote) {
    return 'Delete “$name”?$keepFileNote';
  }

  @override
  String get deleteProfileKeepFile =>
      '\nThe model file will not be deleted and can be re-added later.';

  @override
  String get noModelFiles => 'No downloaded .gguf model files found';

  @override
  String get pickModelFileTitle => 'Choose Model File';

  @override
  String profileLocalSubtitle(String file) {
    return 'Local model · $file';
  }

  @override
  String profileRemoteSubtitle(String model, String multimodal) {
    return 'Remote API · $model$multimodal';
  }

  @override
  String get profileMultimodalSuffix => ' · supports images';

  @override
  String get engineLoading => 'Loading';

  @override
  String get engineActive => 'Active';

  @override
  String get menuActivate => 'Activate';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuDelete => 'Delete';

  @override
  String get remoteEditTitle => 'Edit Remote Model';

  @override
  String get remoteAddTitle => 'Add Remote Model';

  @override
  String get presetSectionTitle => 'Choose a service preset (optional)';

  @override
  String get presetNameModelscope => 'ModelScope API-Inference';

  @override
  String get presetNameArk => 'Volcano Ark';

  @override
  String get presetNameDashScope => 'Alibaba DashScope';

  @override
  String get presetNameDeepSeek => 'DeepSeek';

  @override
  String get presetNameOpenAI => 'OpenAI';

  @override
  String get presetNameOllama => 'Ollama (local/LAN)';

  @override
  String get presetDescModelscope =>
      'Free inference API from ModelScope. Get a token on the ModelScope website.';

  @override
  String get presetDescArk =>
      'ByteDance Volcano Engine. Get the API key in the Ark console under “API Key Management”.';

  @override
  String get presetDescDashScope =>
      'Alibaba Cloud Bailian, OpenAI-compatible mode.';

  @override
  String get presetDescDeepSeek => 'Official DeepSeek API.';

  @override
  String get presetDescOpenAI =>
      'Official OpenAI API (mainland China network access is on you).';

  @override
  String get presetDescOllama =>
      'Run Ollama on your computer with the port open; keep the phone on the same LAN.';

  @override
  String get fieldName => 'Name';

  @override
  String get nameHint => 'e.g. ModelScope Qwen / DeepSeek';

  @override
  String get fieldBaseUrl => 'API base URL (no trailing slash)';

  @override
  String get fieldApiKey => 'API Key (optional for some services)';

  @override
  String get fieldModel => 'Model name (model)';

  @override
  String get modelHint => 'e.g. Qwen/Qwen3-32B or deepseek-chat';

  @override
  String get fetchModelsTooltip => 'Fetch model list';

  @override
  String get multimodalTitle => 'Support image input (multimodal)';

  @override
  String get multimodalSubtitle =>
      'When on, this model can read blood pressure monitor photos (OCR fallback).';

  @override
  String get saveBtn => 'Save';

  @override
  String get addActivateBtn => 'Add & Activate';

  @override
  String get needBaseUrl => 'Enter the API base URL first';

  @override
  String get needAllFields => 'Fill in the name, base URL and model name';

  @override
  String fetchFailed(String error) {
    return 'Fetch failed: $error';
  }

  @override
  String searchModels(int count) {
    return 'Search models ($count total)';
  }

  @override
  String get noMatchModels => 'No matching models';

  @override
  String get marketTitle => 'Model Center';

  @override
  String get marketIntro =>
      'Search and download GGUF models to run offline on your phone. Multiple model communities are queried in parallel — whichever has it wins. Q4-quantized 0.6B–2B models balance quality and memory.';

  @override
  String get sectionDownloads => 'Downloads';

  @override
  String get sectionCurated => 'Curated Models (official Qwen)';

  @override
  String get sectionOtherRepos => 'Other Repositories';

  @override
  String get customRepoHint => 'Enter a model ID, e.g. Qwen/Qwen3-1.7B-GGUF';

  @override
  String get viewBtn => 'View';

  @override
  String get customRepo => 'Custom repository';

  @override
  String get customRepoDesc =>
      'Find this repository\'s GGUF files across the connected model communities';

  @override
  String get noGgufFiles => 'No GGUF weights available in this repository';

  @override
  String get marketConnError =>
      'Cannot reach the model communities. Check your network and try again.';

  @override
  String listFilesFailed(String error) {
    return 'Failed to fetch file list: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get downloadTooltip => 'Download';

  @override
  String get failedTooltip => 'Failed';

  @override
  String get curatedDescQwen3_0_6B_GGUF =>
      'Lightweight pick · works on low-end phones · 0.4–0.6GB';

  @override
  String get curatedDescQwen3_1_7B_GGUF =>
      'Balanced quality and speed · mid-range phones or better';

  @override
  String get curatedDescQwen3_4B_GGUF => 'Better answers · needs 6GB+ memory';

  @override
  String get curatedDescQwen2_5_0_5B_Instruct_GGUF =>
      'Previous-gen small model · memory-friendly';

  @override
  String get curatedDescQwen2_5_1_5B_Instruct_GGUF =>
      'Previous-gen balanced pick';

  @override
  String get curatedDescQwen2_5_3B_Instruct_GGUF => 'Previous-gen quality tier';

  @override
  String get curatedSizeQwen3_0_6B_GGUF => 'about 0.4–0.7 GB';

  @override
  String get curatedSizeQwen3_1_7B_GGUF => 'about 1.0–1.9 GB';

  @override
  String get curatedSizeQwen3_4B_GGUF => 'about 2.3–4.4 GB';

  @override
  String get curatedSizeQwen2_5_0_5B_Instruct_GGUF => 'about 0.4–0.7 GB';

  @override
  String get curatedSizeQwen2_5_1_5B_Instruct_GGUF => 'about 0.9–1.8 GB';

  @override
  String get curatedSizeQwen2_5_3B_Instruct_GGUF => 'about 1.8–3.2 GB';

  @override
  String get assistantTitle => 'Health Guidance';

  @override
  String assistantModelLabel(String name) {
    return 'Model: $name';
  }

  @override
  String get clearConversationTooltip => 'Clear chat';

  @override
  String get clearConversationTitle => 'Clear Chat';

  @override
  String get clearConversationContent => 'Delete the entire conversation?';

  @override
  String get clearConversationConfirm => 'Clear';

  @override
  String get assistantInputHint =>
      'e.g. My blood pressure has been high lately — any diet tips?';

  @override
  String get assistantInputNoModel => 'Configure a model first';

  @override
  String get assistantDisclaimer =>
      'AI suggestions are for reference only and do not replace professional medical advice';

  @override
  String get gatedRefusal =>
      'I\'m not confident enough to answer this reliably. Try rephrasing, or configure a stronger model under Me → AI Models.';

  @override
  String get noModelYet => 'No AI model configured';

  @override
  String get noModelHint =>
      'Set up a local model (offline) or a remote API to get personalized blood pressure guidance.';

  @override
  String get goConfigure => 'Configure Model';

  @override
  String get assistantWelcomeTitle =>
      '👋 Hi, I\'m your blood pressure assistant';

  @override
  String get assistantWelcomeBody =>
      'I base suggestions on your last 30 days of records.\nTry asking:';

  @override
  String get suggestAnalyze => 'Analyze my recent blood pressure readings';

  @override
  String get suggestDiet => 'My BP is high — what should I watch in my diet?';

  @override
  String get suggestMeasure => 'How do I measure blood pressure correctly?';

  @override
  String get suggestExercise => 'Does exercise help lower BP? What kind?';

  @override
  String get knowledgeTitle => 'Health Knowledge';

  @override
  String get categoryAll => 'All';

  @override
  String get noArticlesInCategory => 'No articles in this category';

  @override
  String minutesRead(int minutes) {
    return 'about $minutes min read';
  }

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get fontSmaller => 'Smaller text';

  @override
  String get fontLarger => 'Larger text';

  @override
  String get favorite => 'Favorite';

  @override
  String get aiModelSection => 'AI Model';

  @override
  String get aiModelConfig => 'AI Model Configuration';

  @override
  String get aiModelNotConfigured =>
      'Not configured · Tap to add a local or remote model';

  @override
  String aiModelCurrent(String name, String kind) {
    return 'Current: $name ($kind)';
  }

  @override
  String get kindLocal => 'local';

  @override
  String get kindRemote => 'remote';

  @override
  String llmLoadError(String error) {
    return 'Model failed to load: $error';
  }

  @override
  String get sectionPreference => 'Measurement Preferences';

  @override
  String get defaultArm => 'Default Measurement Arm';

  @override
  String get reminderTitle => 'Measurement Reminder';

  @override
  String get reminderOff => 'Off';

  @override
  String get reminderDaily => 'Daily';

  @override
  String get reminderInterval => 'Interval';

  @override
  String get reminderDailyTime => 'Reminder Time';

  @override
  String get reminderDailySubtitle => 'Remind at a fixed time every day';

  @override
  String get reminderWindowTitle => 'Reminder Window';

  @override
  String get reminderWindowSubtitle =>
      'Remind within the window at fixed intervals';

  @override
  String get reminderIntervalTitle => 'Reminder Interval';

  @override
  String get reminderIntervalSubtitle =>
      'Repeat at this interval within the window';

  @override
  String intervalMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get windowEndAfterStart => 'End time must be after start time';

  @override
  String get notificationDenied =>
      'Notification permission not granted; reminders may not show';

  @override
  String get sectionData => 'Data';

  @override
  String get exportShare => 'Export & Share';

  @override
  String get exportShareSubtitle => 'CSV export · Card sharing · WeChat';

  @override
  String get cloudSync => 'Cloud Sync';

  @override
  String get cloudSyncSubtitle => 'Off · Multi-device sync (planned)';

  @override
  String get sectionGeneral => 'General';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get wechatConfig => 'WeChat Sharing Setup';

  @override
  String get wechatNotConfigured =>
      'AppID not set (system share is used until configured)';

  @override
  String wechatAppIdMasked(String masked) {
    return 'AppID: $masked';
  }

  @override
  String get wechatDialogTitle => 'WeChat Sharing Setup';

  @override
  String get wechatAppIdField => 'WeChat Open Platform AppID';

  @override
  String get wechatAppIdHint => 'Leave empty to use system sharing';

  @override
  String get wechatUniversalLinkField => 'iOS Universal Link (optional)';

  @override
  String get sectionAbout => 'About';

  @override
  String get appVersionSubtitle => 'Cross-platform blood pressure companion';

  @override
  String get disclaimer => 'Disclaimer';

  @override
  String get disclaimerBody =>
      'All content in this app (blood pressure classification hints, AI health guidance, knowledge articles) is for health information reference and self-management only, and is not medical diagnosis or treatment advice.\n\nAI-generated content may contain errors or omissions. Do not adjust medication or make medical decisions based on it. Consult a professional medical institution for any health concern.\n\nMeasurement records are stored on your device by default. Remote AI sends your questions, conversation context and relevant blood pressure summaries to the provider you configure. Exporting or sharing hands the selected content to your chosen recipient. Read the privacy policy for details and back up local data.';

  @override
  String get syncTitle => 'Cloud Sync';

  @override
  String get syncOn => 'On';

  @override
  String get syncOff => 'Off';

  @override
  String get syncEnabledBody => 'Data will sync to the cloud automatically.';

  @override
  String get syncDisabledBody =>
      'Cloud sync is a premium feature and is not available yet. All data stays on this device; back it up as CSV anytime via “Export & Share”.';

  @override
  String get syncReadiness => 'Sync Readiness';

  @override
  String get readyLocal =>
      'Local data protection (soft delete + updated_at timestamps)';

  @override
  String get readyDeviceId =>
      'Cross-device identity (UUID primary keys + device ID)';

  @override
  String readyOutbox(int count) {
    return 'Offline change log (outbox, $count pending)';
  }

  @override
  String get readyPlatform =>
      'Cloud platform integration (candidates: Supabase / self-hosted API)';

  @override
  String get readyE2E => 'End-to-end encrypted transport';

  @override
  String get sectionAccount => 'Account (planned)';

  @override
  String get notLoggedIn => 'Not signed in';

  @override
  String get loginAfterPlatform =>
      'Sign in here once the cloud platform is available';

  @override
  String get syncNote =>
      'Note: once a cloud platform is chosen, only a SyncService implementation is needed to enable multi-device sync — local data models and UI stay unchanged.';

  @override
  String get notifDailyTitle => 'Time to measure your blood pressure 🩺';

  @override
  String get notifDailyBody =>
      'Keep logging — your blood pressure trend matters.';

  @override
  String get channelDailyName => 'Daily measurement reminder';

  @override
  String get channelDailyDesc => 'Daily blood pressure measurement reminders';

  @override
  String get channelIntervalName => 'Interval measurement reminder';

  @override
  String get channelIntervalDesc =>
      'Interval blood pressure reminders within the window';

  @override
  String get settingsTitle => 'Me';

  @override
  String get avgSystolicCard => 'Avg Systolic';

  @override
  String get avgDiastolicCard => 'Avg Diastolic';

  @override
  String get avgPulseCard => 'Avg Pulse';

  @override
  String minMaxHint(String high, String low) {
    return 'High $high · Low $low';
  }

  @override
  String replyInterrupted(String error) {
    return 'Reply interrupted: $error';
  }

  @override
  String get llmNotConfigured => 'No LLM configured';

  @override
  String get llmNotReady => 'Model not ready';

  @override
  String get navHome => 'Home';

  @override
  String get navStats => 'Trends';

  @override
  String get navAssistant => 'AI';

  @override
  String get navKnowledge => 'Knowledge';

  @override
  String get navMe => 'Me';

  @override
  String get privacyPolicy => 'Privacy policy (Chinese)';

  @override
  String get privacyPolicyLoadError =>
      'Unable to load the privacy policy. Please reopen this page.';

  @override
  String get privacyWelcomeTitle => 'Welcome to BloodPressed';

  @override
  String get privacyWelcomeBody =>
      'Blood pressure and pulse are sensitive health data. Records stay on your device by default. Camera, speech, reminders and remote AI are optional; permissions are requested when used. System speech services may use the network; bundled recognition runs locally. Remote health sharing requires separate consent. Read the privacy policy before accepting. Business and sharing services start only after acceptance. Operator: Zhao Xuan; contact: zhaoxuanmail@163.com.';

  @override
  String get privacyAccept => 'Agree and continue';

  @override
  String get privacyDecline => 'Not now';

  @override
  String get privacyRefused =>
      'You have not agreed. Business services remain stopped. You can still read the policy and decide later.';

  @override
  String get privacyStartupError =>
      'Startup failed. Return to the privacy notice and try again.';

  @override
  String get privacyWithdraw => 'Withdraw privacy consent';

  @override
  String get privacyWithdrawBody =>
      'This stops the current session and reminders and returns to the privacy notice. Local records and settings are retained. Data already sent to a provider cannot be recalled. You must agree again to resume.';

  @override
  String get remoteConsentTitle => 'Separate consent for remote health data';

  @override
  String get remoteConsentBody =>
      'The recipient, endpoint, model and privacy policy above come from your configuration. Health analysis sends your question, chat history and a summary of the past 30 days of blood pressure, pulse and measurement times. Trend analysis also includes the selected trend data. The provider receives your IP address and API key for authentication, and handles retention under its policy. Verify the recipient, retention and rights process first. This feature is available only for services you have verified as processing in mainland China. You may decline and keep using local records and local models, or withdraw in Settings. Declining sends no request.';

  @override
  String get remoteConsentAccept => 'Agree to send health data';

  @override
  String get remoteConsentRequired =>
      'Separate consent is required for this health data recipient.';

  @override
  String get remoteConsentWithdraw => 'Withdraw remote AI consent';

  @override
  String get remoteWithdrawBody =>
      'Stop the current reply and clear all remote health data grants. You will be asked again before sending. Contact the provider about data already sent.';

  @override
  String get remoteWithdrawDone => 'Remote AI consent withdrawn';

  @override
  String get remoteDisclosureTitle => 'Health data recipient';

  @override
  String get remoteDisclosureHelp =>
      'Enter the actual service operator and its privacy policy. Verify the processing location with the provider. Health data cannot currently be sent to unknown or overseas locations, or non-HTTPS endpoints. Local models remain available.';

  @override
  String get remoteRecipientName => 'Actual service operator';

  @override
  String get remoteRecipientPolicy => 'Provider privacy policy HTTPS URL';

  @override
  String get remoteRecipientRegion => 'Verified data processing location';

  @override
  String get remoteRegionUnknown => 'Not verified';

  @override
  String get remoteRegionMainland => 'Mainland China';

  @override
  String get remoteRegionOverseas => 'Overseas (health sharing unavailable)';

  @override
  String get remoteDisclosureMissing =>
      'Complete the actual operator, HTTPS privacy policy URL and verified processing location in AI model settings. Health sharing currently requires HTTPS, no credentials embedded in the endpoint, and verified mainland China processing. Use a local model otherwise.';
}
