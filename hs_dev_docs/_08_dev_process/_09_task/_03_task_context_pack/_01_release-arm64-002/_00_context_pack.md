# 上下文装载包 (Context Pack)：release-arm64-002

- **change_size**：`S`
- **任务 ID**：`release-arm64-002`
- **生成时间**：`2026-10-15T06:17:00Z`
- **状态**：`COMPLETED`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **查询**：`doc_index_db.py --root . search|slice`；Skill 详规用 `skill_ref_index.py search`（勿通读 references/）

---

## 1. 需求与目标（物化）
仅打包arm64-v8a，不包含32位原生库，交付最新release APK

- 用户要求：打包 APP，不需要兼容原来的 32 位系统。
- 产物：Android release APK，版本 1.2.1+3，仅 arm64-v8a。
- 验收：APK lib/ 下不存在 32 位 ABI，Manifest 版本正确，签名验证通过。
- 校验 SHA256，保留明确版本名的交付文件。
- 原有 debug 签名继续使用；真机验证与平台上传不在本轮执行范围。

---

## 2. 数据模型切片（物化）
N/A：仅构建配置与版本。

---

## 3. 接口与六元组签名（物化）
N/A：无业务接口变更。

---

## 4. 调用链与 Mock 契约（物化）
pubspec 版本 → Flutter android-arm64 AOT → Gradle release ABI 过滤 → APK → aapt / apksigner / ZIP 检查。

---

## 5. 查询轨迹（降 Token）
- 依据：release.md 的 JDK 21 环境、现有 Gradle release 签名配置。
- Skill 检索：release Android 构建无额外命中；沿用已读 process_continuity。
- 产物已验收：1.2.1+3 / arm64-v8a / 162.76 MiB / v2 签名验证通过，校验值见 release.md。
