/// 应用功能注册表：功能搜索的数据源与跳转目的地。
///
/// 每个条目是一个用户可直达的功能/设置项：go_router 路由 + 标题（经
/// l10n 求值）+ 双语关键词。新增可搜索功能时在此登记即可；需要新页面
/// 可直达时先提升为 go_router 路由（见 app_router「为功能搜索而提升」段）。
library;

import 'package:flutter/material.dart';

import 'package:blood_pressed/l10n/app_localizations.dart';

class AppFeatureEntry {
  const AppFeatureEntry({
    required this.id,
    required this.route,
    required this.icon,
    required this.title,
    required this.keywords,
    this.pinyin = const [],
    this.rootNavigator = false,
  });

  final String id;
  final String route;
  final IconData icon;

  /// 显示标题（经 l10n 求值，随界面语言）。
  final String Function(AppLocalizations l10n) title;

  /// 检索关键词（中英混排，匹配时大小写不敏感）。
  final List<String> keywords;

  /// 手工注音（无声调拼音，用于 T1/T2 拼音检索；15 条目规模不引入拼音库）。
  final List<String> pinyin;

  /// true = 根导航独立页（push）；false = 底部 Tab 分支（go 切换，
  /// push 会叠加第二层 StatefulShellRoute 导致 key 冲突崩溃）。
  final bool rootNavigator;
}

/// 全部可搜索条目（顺序即无查询时的展示顺序）。
final List<AppFeatureEntry> kAppFeatureRegistry = [
  AppFeatureEntry(
    id: 'home',
    route: '/home',
    icon: Icons.home_outlined,
    title: (l10n) => l10n.navHome,
    keywords: ['首页', '主页', '记录', '血压记录', 'home'],
    pinyin: ['shouye', 'zhuye'],
  ),
  AppFeatureEntry(
    id: 'record_new',
    route: '/record/new',
    icon: Icons.edit_note,
    title: (l10n) => l10n.sectionEntry,
    keywords: ['录入', '手动录入', '记血压', '测量', '添加记录', 'entry', 'manual'],
    pinyin: ['luru', 'jixueya', 'banya'],
    rootNavigator: true
  ),
  AppFeatureEntry(
    id: 'stats',
    route: '/stats',
    icon: Icons.show_chart_outlined,
    title: (l10n) => l10n.navStats,
    keywords: ['趋势', '统计', '图表', '曲线', '血压趋势', 'trend', 'stats'],
    pinyin: ['qushi', 'tongji', 'tubiao'],
  ),
  AppFeatureEntry(
    id: 'assistant',
    route: '/assistant',
    icon: Icons.smart_toy_outlined,
    title: (l10n) => l10n.navAssistant,
    keywords: ['ai', '助手', '问答', '健康指导', '聊天', 'assistant'],
    pinyin: ['zhushou', 'jiankangzhidao', 'liaotian'],
  ),
  AppFeatureEntry(
    id: 'knowledge',
    route: '/knowledge',
    icon: Icons.menu_book_outlined,
    title: (l10n) => l10n.navKnowledge,
    keywords: ['知识', '文章', '科普', '阅读', 'knowledge'],
    pinyin: ['zhishi', 'wenzhang', 'kexue'],
  ),
  AppFeatureEntry(
    id: 'llm',
    route: '/llm',
    icon: Icons.psychology_outlined,
    title: (l10n) => l10n.aiModelConfig,
    keywords: ['模型', '大模型', 'llm', '本地模型', '远端', 'api', '配置'],
    pinyin: ['moxing', 'peizhi', 'damoxing'],
    rootNavigator: true
  ),
  AppFeatureEntry(
    id: 'market',
    route: '/market',
    icon: Icons.cloud_download_outlined,
    title: (l10n) => l10n.marketTitle,
    keywords: ['模型中心', '模型市场', '搜索模型', '下载模型', 'gguf', 'qwen', 'market', 'center'],
    pinyin: ['moxingshichang', 'xiazai', 'moda'],
    rootNavigator: true
  ),
  AppFeatureEntry(
    id: 'settings',
    route: '/settings',
    icon: Icons.person_outline,
    title: (l10n) => l10n.settingsTitle,
    keywords: ['设置', '我的', '偏好', '个人', 'settings', 'me'],
    pinyin: ['shezhi', 'wode', 'geren'],
  ),
  AppFeatureEntry(
    id: 'reminder',
    route: '/settings',
    icon: Icons.alarm_outlined,
    title: (l10n) => l10n.reminderTitle,
    keywords: ['提醒', '测量提醒', '定时', '闹钟', '周期提醒', 'reminder'],
    pinyin: ['tixing', 'dingshi', 'naozhong', 'zhouqi'],
  ),
  AppFeatureEntry(
    id: 'export',
    route: '/export',
    icon: Icons.ios_share_outlined,
    title: (l10n) => l10n.exportShare,
    keywords: ['导出', '分享', 'csv', 'excel', '微信', '卡片', 'export'],
    pinyin: ['daochu', 'fenxiang', 'daoru'],
    rootNavigator: true
  ),
  AppFeatureEntry(
    id: 'sync',
    route: '/sync',
    icon: Icons.cloud_outlined,
    title: (l10n) => l10n.cloudSync,
    keywords: ['同步', '云同步', '备份', '多设备', 'sync', 'cloud'],
    pinyin: ['tongbu', 'beifen', 'yunkongbu'],
    rootNavigator: true
  ),
  AppFeatureEntry(
    id: 'appearance',
    route: '/settings',
    icon: Icons.palette_outlined,
    title: (l10n) => l10n.appearance,
    keywords: ['外观', '主题', '暗色', '亮色', '深色', 'theme', 'appearance'],
    pinyin: ['waiguan', 'zhuti', 'anse'],
  ),
  AppFeatureEntry(
    id: 'language',
    route: '/settings',
    icon: Icons.language,
    title: (l10n) => l10n.langTitle,
    keywords: ['语言', '中文', '英文', 'english', 'language'],
    pinyin: ['yuyan', 'zhongwen', 'yingwen'],
  ),
  AppFeatureEntry(
    id: 'wechat',
    route: '/settings',
    icon: Icons.chat_bubble_outline,
    title: (l10n) => l10n.wechatConfig,
    keywords: ['微信', 'appid', '分享配置', 'wechat'],
    pinyin: ['weixin', 'fenxiangpeizhi'],
  ),
  AppFeatureEntry(
    id: 'disclaimer',
    route: '/settings',
    icon: Icons.info_outline,
    title: (l10n) => l10n.disclaimer,
    keywords: ['免责', '免责声明', '声明', 'disclaimer'],
    pinyin: ['mianze', 'mianzeshengming', 'shengming'],
  ),
];
