# 上下文装载包 (Context Pack)：voice-download-002

- **change_size**：`S`
- **任务 ID**：`voice-download-002`
- **生成时间**：`2026-10-15T06:09:45Z`
- **状态**：`COMPLETED`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **查询**：`doc_index_db.py --root . search|slice`；Skill 详规用 `skill_ref_index.py search`（勿通读 references/）

---

## 1. 需求与目标（物化）
修复离线语音模型下载覆盖、进度累计与损坏文件验收

- 206 必须从本地已有字节偏移开始追加；范围不匹配拒收且保留前缀。
- 200 视为服务器忽略 Range，从头覆写，防止重复追加。
- 断流保留已写入字节，重试从新偏移续传。
- 文件字节数精确匹配才转正；超大文件清理；完整 .part 无需联网。
- 进度包含已完成文件及当前文件偏移，限制在 0～1。
- 通过定向回归、全量测试、静态分析与一致性门禁后本地提交。

---

## 2. 数据模型切片（物化）
N/A：无持久化结构变更，沿用模型目录及 .part 临时文件。

---

## 3. 接口与六元组签名（物化）
`VoiceModelFetcher(url, File target, int startFrom, onReceived) -> Future<void>`。
`onReceived(int receivedInFile)` 是文件内累计字节数，包含 startFrom。
`VoiceModelManager.download()` 保留入口，失败抛异常且 finally 复位 isDownloading。
注入 Dio 时复用该客户端；默认客户端设定超时并在本次请求结束时关闭。

---

## 4. 调用链与 Mock 契约（物化）
录入页 → VoiceInputNotifier.startModelDownload → VoiceModelStore.download →
VoiceModelManager → Dio ResponseBody.stream → .part → 精确长度校验 → 模型文件。
测试使用真实文件系统与 Dio adapter，仅替换 HTTP 响应；禁用公网回退。

---

## 5. 查询轨迹（降 Token）
- 续做扫描：0 活跃任务；基于最近提交 2c2da46 的离线语音增量收口。
- 项目依据：现有 voice_model_manager.dart 的下载与回调契约。
- 已读 Skill references：load_latch.md、process_continuity.md。
- 验证：定向 8/8；全量 270/270；静态分析 0 issue；无真机验证。
