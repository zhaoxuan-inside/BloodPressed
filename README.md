# BloodPressed 血压管家 🩺

跨 Android / iOS 的血压监控应用：记录血压脉搏、趋势图表、拍照识别读数、
本地/远端大模型健康指导、数据导出与卡片分享、健康知识阅读。

## 功能总览

| # | 功能 | 说明 |
|---|------|------|
| 1 | 大模型安装/配置 | 以"插件"形式从**魔搭社区**下载 GGUF 模型离线运行（断点续传）；也可配置 OpenAI 兼容远端 API（DashScope / DeepSeek / ModelScope API-Inference / Ollama 等） |
| 2 | 相机调用 | 实时取景拍摄血压计屏幕，带取景框提示 |
| 3 | 图片识别 | ML Kit 离线 OCR + 自研解析引擎（分数式/标签式/相邻数值三种模式 + 置信度评分）；低置信度自动用**多模态大模型兜底**；结果经人工确认后入库 |
| 4 | 记录管理 | 高压/低压/脉搏、时间、左/右臂、体位、备注、来源；软删除 |
| 5 | 趋势图表 | 高压/低压/脉搏折线（按天聚合），7/30/90 天与自定义范围、左右臂筛选、135/85 参考线、统计概览（均值/最值/达标率） |
| 6 | 健康指导 | 聊天式 AI 助手，自动注入近 30 天血压摘要（含双臂对比）作为上下文 |
| 7 | 数据导出 | CSV（UTF-8 BOM，Excel 直接打开） |
| 8 | 卡片分享 | 精美分享卡（单次记录卡/统计摘要卡）→ 微信好友/朋友圈（fluwx），未配置微信时回退系统分享面板 |
| 9 | 健康知识 | 内置 13 篇中文科普（测量方法/认识血压/生活方式/监测管理），支持收藏与字号调节 |

## 技术栈

- **Flutter 3.47**（Dart 3.13），Material 3，中文界面
- 状态管理：flutter_riverpod；路由：go_router（5 Tab Shell + 子页）
- 存储：sqflite（单会话 SQLite，UUID 主键 + 软删除 + outbox 变更日志）
- 相机/相册：camera + image_picker + permission_handler
- OCR：google_mlkit_text_recognition（中文脚本，依赖 GMS）
- 本地推理：[llamadart](https://pub.dev/packages/llamadart)（llama.cpp GGUF）
- 远端推理：自实现 OpenAI 兼容客户端（SSE 流式 + 多模态图片）
- 图表：fl_chart；Markdown：flutter_markdown_plus
- 分享：fluwx（微信）+ share_plus（系统分享）

## 架构与设计系统

项目遵循 **Clean Architecture 分层**（参考 awesome-mobile-development 的架构推荐），
每个 feature 内部按 `domain / data / presentation` 三层组织：

```
lib/
├── main.dart / app.dart          # 初始化装配 / 主题与路由根
├── core/
│   ├── design/                   # 设计令牌（Design Tokens）：AppColors / AppDimens /
│   │                             #   BpCategoryStyle——颜色、间距、圆角唯一来源
│   ├── widgets/                  # 共享组件：CategoryBadge / StatCard / QuickAction /
│   │                             #   EmptyState / SectionHeader / ErrorBanner
│   ├── db/                       # 建表迁移 + outbox DAO（基础设施）
│   ├── providers.dart            # Riverpod 依赖装配（main 覆盖注入）
│   ├── router/ theme/ utils/
└── features/
    └── <feature>/
        ├── domain/               # 实体、仓库契约、纯逻辑（如 OCR 解析引擎、SyncService 接口）
        ├── data/                 # 仓库实现、数据源（SQLite/REST/Assets）、引擎实现
        └── presentation/         # 页面 + 控制器（Riverpod StateNotifier = ViewModel）
            ├── controllers/
            └── widgets/
```

当前 feature 划分：

| feature | 职责 |
|---|---|
| records | ④ 记录：领域模型/仓库 + 录入表单 + 首页 |
| stats | ⑤ 趋势图：按天聚合控制器 + fl_chart 页面 |
| camera_ocr | ②③ 相机 + OCR：解析引擎（domain，纯 Dart 可测）/ ML Kit 服务（data）/ 兜底流程 |
| llm | ① 大模型：引擎抽象（domain）/ 远端 SSE + 本地 llama.cpp + 魔搭市场与下载器（data）/ 配置与市场页 |
| assistant | ⑥ 健康指导聊天：上下文构建 + 会话仓库 + 聊天页 |
| export | ⑦⑧ CSV + 分享卡 + 微信/系统分享 |
| knowledge | ⑨ 知识阅读：13 篇内置文章 |
| sync | 云同步抽象：SyncService 接口（domain）+ LocalOnly 实现（data）+ 占位页 |
| settings | 设置 / 提醒通知 / 微信配置 |

约束：presentation 层只依赖 domain 契约与 core；跨 feature 引用一律走
`package:blood_pressed/...` 绝对导入。

## 构建运行

```bash
flutter pub get
flutter run                # 连接设备或模拟器
flutter build apk --debug  # Android
```

> debug APK 约 400MB（含 4 个 ABI 的 llama.cpp 原生运行时与调试符号）。
> 发布请用 `flutter build apk --release --split-per-abi`，单 ABI 体积会小很多。
>
> 国内网络注意：`pubspec.yaml` 已为 `sqlite3` 构建钩子配置了 GitHub 镜像前缀
> （`hooks.user_defines`），镜像失效时替换 `url_pattern` 中的
> `https://ghproxy.net/` 前缀即可。

### 环境要求

- Flutter 3.35+（llamadart 依赖构建钩子下载原生运行时，首次构建需联网）
- Android：minSdk 24（已在 `android/app/build.gradle.kts` 配置）
- iOS：iOS 15+（模板默认 target），构建需 macOS + Xcode（本项目在 Windows 上开发，iOS 端只做了配置，未编译验证）

## 必要的配置项

### 1. 微信分享（可选，不配置自动降级为系统分享）

1. 到[微信开放平台](https://open.weixin.qq.com)创建移动应用，获取 AppID
2. App 内配置：**我的 → 微信分享配置**，填入 AppID（iOS 另填 Universal Link）
3. 打包前还需按平台调整：
   - Android：`applicationId` 改为开放平台登记的包名
     （微信回调 Activity 由 fluwx 6 内置的 activity-alias 自动提供，无需手写）
   - iOS：`ios/Runner/Info.plist` 中 `wxYOUR_WECHAT_APPID` 替换为真实 AppID，
     并在 Xcode 中配置 Associated Domains（Universal Link）

### 2. 本地大模型（离线可用）

App 内：**我的 → AI 模型 → 从魔搭社区安装模型**。精选列表均为 Qwen 官方仓库，
建议 0.6B~2B 的 Q4 量化版本（约 0.4~1.9GB），支持断点续传。
下载完成后在"AI 模型"页启用即可。

也可以在魔搭找任意 GGUF 仓库（如 `Qwen/Qwen3-1.7B-GGUF`），在市场页输入模型 ID 下载。

### 3. 远端大模型（可选，能力更强）

**我的 → AI 模型 → 添加远端模型 API**，内置预设：

| 服务 | baseUrl | 模型示例 |
|---|---|---|
| ModelScope API-Inference | `https://api-inference.modelscope.cn/v1` | `Qwen/Qwen3-32B` |
| 阿里云百炼 DashScope | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` / `qwen-vl-plus`（多模态） |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini`（多模态） |
| Ollama（局域网） | `http://<电脑IP>:11434/v1` | `qwen2.5:3b` |

勾选"支持图片输入"后，可用该模型做血压照片识别兜底。

### 4. 云同步（预留能力，默认关闭）

当前版本为纯本地存储。数据层已按同步友好设计：
UUID 主键、软删除、`updated_at` 时间戳、`sync_outbox` 离线变更日志。
确定云平台后，实现 `lib/features/sync/sync_service.dart` 中的 `SyncService`
接口并在 `syncServiceProvider` 替换实现即可，业务代码零改动。

## 已知限制

- **ML Kit OCR 依赖 Google Play Services**：无 GMS 的设备（如部分华为机型）离线识别不可用，
  App 会自动引导使用多模态大模型兜底或手动录入
- 本地推理对内存有要求：建议 6GB 以上内存手机运行 ≤2B 模型；4B 模型需 8GB+
- AI 建议仅供参考，不构成医疗建议；分级提示采用家庭自测标准（135/85）
- iOS 端未经真机编译验证（开发环境为 Windows）

## 测试

```bash
flutter analyze   # 0 issues
flutter test      # 36 个用例：OCR 解析引擎（多格式/非法输入/多行场景）、
                  # 血压分级、CSV 导出与转义、统计计算、记录仓库（内存 SQLite）
```
