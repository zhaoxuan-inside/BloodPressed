/// 健康知识文章（内置 assets）。
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.assetPath,
    this.minutes = 3,
  });

  final String id;
  final String title;
  final String category;
  final String assetPath;
  final int minutes;

  /// 中文分类列表
  static const List<String> categoriesZh = [
    '测量方法',
    '认识血压',
    '生活方式',
    '监测管理',
  ];

  /// 英文分类列表
  static const List<String> categoriesEn = [
    'Measurement',
    'Understanding BP',
    'Lifestyle',
    'Monitoring',
  ];

  /// 保持向后兼容的默认分类列表
  static const List<String> categories = categoriesZh;

  /// 根据当前语言获取分类列表
  static List<String> categoriesForLocale(bool isEn) =>
      isEn ? categoriesEn : categoriesZh;

  /// 中文知识库（依据《中国高血压防治指南》和《中国居民膳食指南》）
  static const List<KnowledgeArticle> allZh = [
    KnowledgeArticle(
      id: 'measure-guide',
      title: '在家如何正确测量血压？',
      category: '测量方法',
      assetPath: 'assets/knowledge/measure_guide.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'arm-choice',
      title: '左臂还是右臂？测量臂的选择',
      category: '测量方法',
      assetPath: 'assets/knowledge/arm_choice.md',
      minutes: 3,
    ),
    KnowledgeArticle(
      id: 'common-mistakes',
      title: '让血压"虚高"的 8 个常见错误',
      category: '测量方法',
      assetPath: 'assets/knowledge/common_mistakes.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'bp-basics',
      title: '高压、低压、脉搏，分别代表什么？',
      category: '认识血压',
      assetPath: 'assets/knowledge/bp_basics.md',
      minutes: 5,
    ),
    KnowledgeArticle(
      id: 'bp-categories',
      title: '血压分级：你的读数处于什么水平？',
      category: '认识血压',
      assetPath: 'assets/knowledge/bp_categories.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'home-vs-clinic',
      title: '家庭自测 135/85：为什么和医院标准不同？',
      category: '认识血压',
      assetPath: 'assets/knowledge/home_vs_clinic.md',
      minutes: 3,
    ),
    KnowledgeArticle(
      id: 'diet-salt',
      title: '减盐是降血压的第一步',
      category: '生活方式',
      assetPath: 'assets/knowledge/diet_salt.md',
      minutes: 5,
    ),
    KnowledgeArticle(
      id: 'exercise',
      title: '运动降压：怎么动、动多少？',
      category: '生活方式',
      assetPath: 'assets/knowledge/exercise.md',
      minutes: 5,
    ),
    KnowledgeArticle(
      id: 'sleep-stress',
      title: '睡眠与情绪：看不见的血压推手',
      category: '生活方式',
      assetPath: 'assets/knowledge/sleep_stress.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'weight-alcohol',
      title: '体重与饮酒：两个关键因素',
      category: '生活方式',
      assetPath: 'assets/knowledge/weight_alcohol.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'monitor-habit',
      title: '家庭监测的正确姿势：频次与记录',
      category: '监测管理',
      assetPath: 'assets/knowledge/monitor_habit.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'medication-note',
      title: '吃药的高血压患者，为什么要坚持自测？',
      category: '监测管理',
      assetPath: 'assets/knowledge/medication_note.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'warning-signs',
      title: '这些情况请立即就医',
      category: '监测管理',
      assetPath: 'assets/knowledge/warning_signs.md',
      minutes: 3,
    ),
  ];

  /// 英文知识库（依据美国 ACC/AHA、CDC、DASH 及 HHS 指南）
  static const List<KnowledgeArticle> allEn = [
    KnowledgeArticle(
      id: 'measure-guide',
      title: 'How to Measure Blood Pressure Accurately at Home',
      category: 'Measurement',
      assetPath: 'assets/knowledge/en/measure_guide.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'arm-choice',
      title: 'Left Arm or Right Arm? Choosing the Measurement Arm',
      category: 'Measurement',
      assetPath: 'assets/knowledge/en/arm_choice.md',
      minutes: 3,
    ),
    KnowledgeArticle(
      id: 'common-mistakes',
      title: '8 Common Mistakes That Artificially Inflate Blood Pressure',
      category: 'Measurement',
      assetPath: 'assets/knowledge/en/common_mistakes.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'bp-basics',
      title: 'Systolic, Diastolic, and Pulse: What Do the Numbers Mean?',
      category: 'Understanding BP',
      assetPath: 'assets/knowledge/en/bp_basics.md',
      minutes: 5,
    ),
    KnowledgeArticle(
      id: 'bp-categories',
      title: 'Blood Pressure Categories: Where Do Your Numbers Stand?',
      category: 'Understanding BP',
      assetPath: 'assets/knowledge/en/bp_categories.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'home-vs-clinic',
      title: 'Home vs. Clinic Readings: Why the Targets Differ',
      category: 'Understanding BP',
      assetPath: 'assets/knowledge/en/home_vs_clinic.md',
      minutes: 3,
    ),
    KnowledgeArticle(
      id: 'diet-salt',
      title: 'Sodium Reduction and the DASH Diet: Food as Medicine',
      category: 'Lifestyle',
      assetPath: 'assets/knowledge/en/diet_salt.md',
      minutes: 5,
    ),
    KnowledgeArticle(
      id: 'exercise',
      title: 'Exercise and Physical Activity: Natural Blood Pressure Therapy',
      category: 'Lifestyle',
      assetPath: 'assets/knowledge/en/exercise.md',
      minutes: 5,
    ),
    KnowledgeArticle(
      id: 'sleep-stress',
      title: 'Sleep and Stress: The Silent Accelerators of Hypertension',
      category: 'Lifestyle',
      assetPath: 'assets/knowledge/en/sleep_stress.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'weight-alcohol',
      title: 'Body Weight and Alcohol: Two Critical Cardiovascular Levers',
      category: 'Lifestyle',
      assetPath: 'assets/knowledge/en/weight_alcohol.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'monitor-habit',
      title: 'The Proper Routine for Home BP Monitoring: Frequency & Logging',
      category: 'Monitoring',
      assetPath: 'assets/knowledge/en/monitor_habit.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'medication-note',
      title: 'Taking Blood Pressure Medications: Why Home Monitoring Matters',
      category: 'Monitoring',
      assetPath: 'assets/knowledge/en/medication_note.md',
      minutes: 4,
    ),
    KnowledgeArticle(
      id: 'warning-signs',
      title: 'Warning Signs: When to Seek Immediate Medical Attention',
      category: 'Monitoring',
      assetPath: 'assets/knowledge/en/warning_signs.md',
      minutes: 3,
    ),
  ];

  /// 默认全量知识库（保持向后兼容）
  static const List<KnowledgeArticle> all = allZh;

  /// 根据当前语言返回对应的知识库文章列表
  static List<KnowledgeArticle> forLocale(bool isEn) => isEn ? allEn : allZh;
}
