# 任务详细设计与执行记录：privacy-release-005

- **任务名称**：补齐隐私授权与正式签名并隐藏登录入口
- **变更分级**：`M`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **开始时间**：`2026-10-15T12:02:31Z`
- **最后更新**：`2026-10-15T12:23:03Z`

---

## 1. 任务背景与目标
首启同意前不启动业务、远端健康数据单独授权可撤回、隐藏云登录、正式签名双包

---

## 2. 验收标准
拒绝零业务初始化；远端未授权不发请求；授权按接收方失效；登录入口不可见；正式与覆盖包验证

---

## 3. 触达面冻结与实现

change_size=M；work_mode=IMPLEMENT。需求及原型已冻结于 privacy-release-005_design.md；沿用现有 Flutter/Riverpod/SQLite，不改数据库表和服务端接口。
用户确认新正式身份 com.zhaoxuan.bloodpressed、新密钥；原包名/签名只用于覆盖测试。
- [x] PrivacyStartup 同意前只显示离线政策，接受后才创建业务 ProviderScope、数据库、UUID、模型和分享服务。
- [x] 可撤回总同意，移除业务树、停止提醒并保留本地数据。
- [x] 远端发送单独告知接收方/地址/模型/政策和数据范围；引擎层再次校验授权，防止绕过 UI。
- [x] 授权绑定地址、模型、接收方及告知版本；撤回关闭连接。未核实或境外地域、非 HTTPS 服务暂不发送健康信息。
- [x] 删除云同步设置、搜索和路由入口，隐藏无服务支撑的登录提示。
- [x] 新正式密钥保存在用户目录外置配置，默认 release 禁止 debug 签名回退，显式 legacy 构建保留覆盖身份。
- [x] 隐私正文更新并发布到 gh-pages（3f6f1f5）。
- [x] 双包身份、签名、ARM64、政策、四个离线语音模型及 ORT 验证通过，进入本地归档提交。

## 4. 验证

新增测试先红后绿。281 项全量测试通过，静态分析无问题。
覆盖拒绝/查看政策零初始化、接受/撤回、无授权引擎拒绝、接收方变化、境外/未知/不安全地址拒绝授权、趋势请求和设置搜索回归。
未做真机权限和应用商店 SDK 扫描，不能用自动测试替代最终审核。

## 5. 文件与约束

main、settings、assistant、llm、feature_registry、router、l10n、Android Gradle、policy JSON/HTML 与对应测试；详见 git diff。
无数据库迁移。LLM 配置沿用 config JSON，新增 recipientName、recipientPolicyUrl、recipientRegion。
正式密钥与密码禁止加入 Git；备份和双包构建见 docs/android-signing.md。

最终包哈希：store 2c92a369751ff283fbc21ab5263ec3bfdcc4958c07f80649d2ce0bd0915df762；legacy 775c8160fba9658601683890437e431ce8dd81885c235fbf294e2e83f8e5bc73。
正式证书 87c43a7a7f202eeceb64477b17cad8b0ec4fbb3c3ab43b7fc28ac249245ba8b9；覆盖包证书与旧版一致。
发布脚本改为显式 Gradle 项目参数，并在命名产物前校验实际包名/ABI/签名，修复环境变量未生效导致身份相同的问题。
