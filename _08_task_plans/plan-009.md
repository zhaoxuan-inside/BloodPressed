# 美化微信分享卡片质感（渐变层次/玻璃拟态/装饰元素）

- id: `plan-009`
- name: `美化微信分享卡片质感（渐变层次/玻璃拟态/装饰元素）`
- time: `2026-10-07 18:10:27`
- requirement: 用户反馈微信分享卡片"太简陋，要有质感一些"
- changelog: `chg-012`

## 目标

重设计 RecordShareCard / StatsShareCard 的视觉呈现，导出 PNG 有明显质感提升；公开 API（CardCapturer/两个卡片构造参数）与既有 l10n 文案键不变，export_page 无需改动。

## 范围

- 做：lib/features/export/presentation/share_card_widgets.dart 单文件重设计（背景层次、玻璃拟态指标块、ECG 主题装饰、排版层级、描边高光）。
- 不做：不改分享链路/截图逻辑（CardCapturer）、不加 ARB 键、不动 CSV。

## 设计要点

- 背景：深色三段渐变 + 径向光斑 + 右下装饰圆 + 1px 白色高光描边（玻璃质感）。
- 主题装饰：CustomPainter 绘制低透明度 ECG 心电波形横贯卡片（贴合血压主题）。
- 记录卡：品牌小徽章（图标圆角块+字距）、hero 数值加大加粗、单位 pill、分级 pill 带分类色圆点、脉搏 pill。
- 统计卡：标题 + 2×2 玻璃拟态指标瓦片（平均血压/平均脉搏/测量次数/达标率）+ 全宽血压范围瓦片。
- 验证：临时测试渲染两卡为 PNG（pixelRatio 3），人工查看迭代后删除临时测试。

## 步骤

- [x] 1. 重设计 share_card_widgets.dart（保留 API 与 l10n 键）
- [x] 2. 临时渲染测试出 PNG，目视迭代至满意，删除临时测试
- [x] 3. analyze + 全量测试通过，提交并记账（_10/勾选计划）

## 恢复

- 上次完成：全部步骤（两卡目视确认，124 测试 + analyze 0）
- 下一步：无（完成）
- 阻塞：无

## 备注

快速通道（单文件 UI 改动）。卡片在 export_page 的 RepaintBoundary 下构建，具有 Localizations，可直接用 AppLocalizations.of(context)。
