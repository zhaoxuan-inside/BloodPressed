# 任务简述清单分片 002

### 任务简述：voice-download-002
- **标题**：修复离线语音模型续传与完整性校验
- **change_size**：`S`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **核心目标**：修复离线语音模型下载覆盖、进度累计与损坏文件验收
- **详情索引**：`_02_task_detail/_01_voice-download-002/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_voice-download-002/_00_context_pack.md`
- **更新时间**：`2026-10-15T06:15:34Z`
---

### 任务简述：release-arm64-002
- **标题**：构建仅ARM64的Android发布包1.2.1
- **change_size**：`S`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **核心目标**：仅打包arm64-v8a，不包含32位原生库，交付最新release APK
- **详情索引**：`_02_task_detail/_01_release-arm64-002/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_release-arm64-002/_00_context_pack.md`
- **更新时间**：`2026-10-15T06:26:16Z`
---

### 任务简述：voice-builtin-003
- **标题**：内置离线语音模型并修复初始化不可用
- **change_size**：`M`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **核心目标**：ARM64安装包内置离线语音模型，系统语音缺失时无需下载即可录入，修复Zipformer模型加载并提供可重试诊断
- **详情索引**：`_02_task_detail/_01_voice-builtin-003/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_voice-builtin-003/_00_context_pack.md`
- **更新时间**：`2026-10-15T07:09:43Z`
---

### 任务简述：settings-privacy-004
- **标题**：隐藏微信开发者配置并准备无服务器隐私政策草案
- **change_size**：`S`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **核心目标**：移除我的及搜索中的微信AppID配置入口，保留分享；按实际数据流形成静态隐私政策草案与托管指南
- **详情索引**：`_02_task_detail/_01_settings-privacy-004/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_settings-privacy-004/_00_context_pack.md`
- **更新时间**：`2026-10-15T11:55:40Z`
---

### 任务简述：privacy-release-005
- **标题**：补齐隐私授权与正式签名并隐藏登录入口
- **change_size**：`M`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **核心目标**：首启同意前不启动业务、远端健康数据单独授权可撤回、隐藏云登录、正式签名双包
- **详情索引**：`_02_task_detail/_01_privacy-release-005/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_privacy-release-005/_00_context_pack.md`
- **更新时间**：`2026-10-15T12:23:03Z`
---

