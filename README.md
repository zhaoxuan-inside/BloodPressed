# BloodPressed 血压管家 🩺

跨 Android / iOS 的血压监控应用：记录血压脉搏、趋势图表、拍照识别读数、
本地/远端大模型健康指导、数据导出与卡片分享、健康知识阅读。

## 功能总览

| # | 功能 | 说明 |
|---|------|------|
| 1 | 大模型安装/配置 | 以"插件"形式从**魔搭社区**下载 GGUF 模型离线运行（断点续传）；也可配置 OpenAI 兼容远端 API（DashScope / DeepSeek / ModelScope API-Inference / Ollama 等） |
| 2 | 相机调用 | 系统相机拍摄血压计屏幕，支持相册选图 |
| 3 | 图片识别 | 本地七段码识别 + PP-OCRv5 ONNX 与位置解析；低置信度提示人工修正；结果经确认后入库 |
| 4 | 记录管理 | 高压/低压至少一项（支持缺项）、脉搏、时间、左/右臂、体位、备注、来源；软删除 |
| 5 | 趋势图表 | 每次高压/低压/脉搏原始测量折线与独立脉压差，缺日/缺项断线、缩放和每日首末极值明细，7/30/90 天与自定义范围、左右臂筛选、135/85 参考线；全屏与分享卡一致 |
| 6 | 健康指导 | 聊天式 AI 助手，自动注入近 30 天血压摘要（含双臂对比）作为上下文 |
| 7 | 数据导出 | CSV（UTF-8 BOM，Excel 直接打开） |
| 8 | 卡片分享 | 精美分享卡（单次记录卡/统计摘要卡）→ 微信好友/朋友圈（fluwx），未配置微信时回退系统分享面板 |
| 9 | 健康知识 | 内置 13 篇中文科普（测量方法/认识血压/生活方式/监测管理），支持收藏与字号调节 |

## 技术栈

- **Flutter 3.47**（Dart 3.13），Material 3，中文界面
- 状态管理：flutter_riverpod；路由：go_router（5 Tab Shell + 子页）
- 存储：sqflite（单会话 SQLite，UUID 主键 + 软删除 + outbox 变更日志）
- 相机/相册：image_picker + permission_handler
- OCR：七段码识别 + PP-OCRv5（onnxruntime，离线且不依赖 GMS）
- 本地推理：[llamadart](https://pub.dev/packages/llamadart)（llama.cpp GGUF）
- 远端推理：自实现 OpenAI 兼容客户端（SSE 流式）
- 图表：fl_chart；Markdown：flutter_markdown_plus
- 分享：fluwx（微信）+ share_plus（系统分享）

## 架构与设计系统

项目遵循 **Clean Architecture 分层**（参考 awesome-mobile-development 的架构推荐），
每个 feature 内部按 `domain / data / presentation` 三层组织：

```
lib/
├── main.dart / app.dart          # 初始化装配 / 主题与路由根
├── core/
│   ├── design/                   # AppColors / BpCategoryStyle——颜色与分级样式
│   ├── widgets/                  # 共享组件：CategoryBadge / StatCard / QuickAction /
│   │                             #   EmptyState / SectionHeader / ErrorBanner
│   ├── db/                       # 建表迁移 + outbox DAO（基础设施）
│   ├── providers.dart            # Riverpod 依赖装配（启动时注入基础存储）
│   ├── router/ theme/ utils/
└── features/
    └── <feature>/
        ├── domain/               # 实体、仓库契约、纯逻辑（如 OCR 解析引擎）
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
| camera_ocr | ②③ 相机 + OCR：解析引擎（domain，纯 Dart 可测）/ 七段码与 PP-OCR 服务（data）/ 确认流程 |
| llm | ① 大模型：引擎抽象（domain）/ 远端 SSE + 本地 llama.cpp + 魔搭市场与下载器（data）/ 配置与市场页 |
| assistant | ⑥ 健康指导聊天：上下文构建 + 会话仓库 + 聊天页 |
| export | ⑦⑧ CSV + 分享卡 + 微信/系统分享 |
| knowledge | ⑨ 知识阅读：13 篇内置文章 |
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

当前拍照识别使用本地七段码识别与 PP-OCR，不向远端模型上传图片。

### 4. 本地存储

当前版本为纯本地存储。数据层已按同步友好设计：
UUID 主键、软删除、`updated_at` 时间戳、`sync_outbox` 离线变更日志。
当前没有云同步服务或账号入口。未接入平台的同步页面与空服务已移除；
本地数据库及既有变更日志保持兼容。

## 已知限制

- **拍照识别需人工核对**：本地七段码与 PP-OCR 不依赖 Google Play Services；
  识别结果会进入确认表单，低置信度时可手动修正
- 本地推理对内存有要求：建议 6GB 以上内存手机运行 ≤2B 模型；4B 模型需 8GB+
- AI 建议仅供参考，不构成医疗建议；分级提示采用家庭自测标准（135/85）
- iOS 端未经真机编译验证（开发环境为 Windows）

## 版本管理范围

GitHub 保留应用源码、平台构建配置、`pubspec.lock`、测试及其夹具、内置语音/OCR 模型和必要设计/发布文档。
内置模型是离线功能所需资源，不属于可删除的构建缓存。
`.gitignore` 排除 APK、构建输出、日志、缓存、环境密钥、本地健康数据库和 `hs_dev_docs/_08_dev_process/` 内部任务流水/回退快照。
`android/app/src/main/jniLibs/` 中旧 ORT 副本不参与构建，也不再跟踪；运行库由 sherpa_onnx 依赖提供。
取消跟踪只更新 Git 索引，本机文件保留；历史提交不在本次清理中改写。

## 测试

```bash
flutter analyze   # 0 issues
flutter test      # 全功能用例均走真实数据：OCR 解析引擎、血压分级、
                  # CSV 导出、统计聚合、记录/会话/模型配置仓库（内存 SQLite）、
                  # 13 篇知识 assets、全链路 UI（录入/编辑/删除/趋势/知识/设置/导出）、
                  # 魔搭市场与远端推理端点（真实 HTTP，无 mock 响应）
```

> 业务层不再使用 FakeRecordsRepository 等内存假仓库。UI 集成测试注入与
> `main()` 相同的真实 `RecordsRepository` / `LlmProfileStore` / `ChatRepository`
> （sqflite_ffi 内存库）。魔搭与推理相关用例直连 modelscope.cn，
> 运行需外网；UI 通过 `overrideHttpClient=false` + `runAsync` 驱动真实请求。
>
> 相机拍摄、PP-OCR 离线识别、本地 GGUF 推理依赖真机/已下载模型，无法在
> Windows 单元测试进程里执行；解析引擎与 OCR 确认入库已覆盖。
