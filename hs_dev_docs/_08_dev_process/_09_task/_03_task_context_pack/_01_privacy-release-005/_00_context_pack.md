# privacy-release-005 上下文

- **change_size**：`M`
- **work_mode**：`IMPLEMENT`

触达面冻结后实施。
用户要求补齐首启隐私、远端健康授权和正式签名，并隐藏登录信息。用户确认没有原商店身份，采用 com.zhaoxuan.bloodpressed + 新正式密钥，保留原身份测试覆盖包。

启动链：SharedPreferences → PrivacyStartup；未同意不触达业务。接受 → AppDatabase → UUID/分享/提醒/模型路径 → ProviderScope → BloodPressedApp。
撤回：清除 privacy_consent 和 remote_health_grants → 移除业务树（取消流与引擎）→ 停止提醒/关闭库 → 隐私说明。
远端发送：手动或 pending 分析 → 接收方披露与单独决定 → AppSettings.allowRemote → LlmEngineController.chatStream 再次校验实际引擎接收方 → RemoteChatEngine。
授权字段：privacy_consent=2026-10-15-v2；remote_health_grants 为 JSON 字符串列表，键含版本、档案ID、服务地址、模型、运营者、政策 URL 和处理地域。不存 API Key 到授权键。
持久化：SharedPreferences 新键与既有 llm_profiles.config 可扩展 JSON，无表迁移。
UI 原型与边界见 privacy-release-005_design.md。当前只允许用户核实的大陆处理 + HTTPS 服务发送健康信息；无默认接收方、不将用户填写内容当独立认证。
GitHub Pages 只发三个静态文件，默认分支不推送。正式密钥位于仓库外，默认 release 缺配置失败；legacy 显式保留旧身份。
门禁：新增授权/生命周期测试 + 281 全量测试 + analyze；包身份/签名/ABI/内置资源另验。真机和商店扫描未执行。
