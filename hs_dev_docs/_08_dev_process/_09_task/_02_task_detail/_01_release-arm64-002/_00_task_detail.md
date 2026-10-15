# 任务详细设计与执行记录：release-arm64-002

- **任务名称**：构建仅ARM64的Android发布包1.2.1
- **变更分级**：`S`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **开始时间**：`2026-10-15T06:17:00Z`
- **最后更新**：`2026-10-15T06:26:16Z`

---

## 1. 任务背景与目标
仅打包arm64-v8a，不包含32位原生库，交付最新release APK

---

## 2. 验收标准
release构建成功，APK架构和版本校验通过

---

## 3. 执行步骤 (Checklist)
- [x] 1. S / IMPLEMENT：Android release 仅 ARM64（arm64-v8a），不包含 32 位库。
- [x] 2. pubspec 版本升级为 1.2.1+3；不触达 DB、API 或界面。
- [x] 3. 固化 release ABI 配置与带 --target-platform android-arm64 的构建命令。
- [x] 4. 实际构建 APK，检查架构、版本、签名与 SHA256。
- [x] 5. 提交前执行一致性门禁、任务归档与本地提交。

---

## 4. 涉及文件修改清单 (Diff Tracking)
```text
android/app/build.gradle.kts
android/gradle.properties
pubspec.yaml
hs_dev_docs/_00_project/_09_dev_env/release.md
```

---

## 5. 验证与门禁记录
- 业务基线：前一提交 7027013 全量 270 项测试通过，静态分析无问题。
- 本轮仅修改构建配置与版本，以 release 构建及 APK 内容检查验证。
- 交付边界：沿用项目 debug 签名；未上传分发平台、未进行真机安装冒烟。
- 构建成功：1.2.1+3，170,668,649 字节（162.76 MiB）。
- aapt 版本：versionName=1.2.1、versionCode=3、minSdk=24。
- aapt native-code 与 ZIP lib/ 均仅 arm64-v8a；核心 Flutter、app、sherpa 原生库存在。
- apksigner verify：通过，v2 签名，Android Debug 证书。
- SHA256：1cb46adf70dc0ef962c7691769b7b33dd77a13997dfad96a0214a9dda3323f60。
- 交付：build/app/outputs/flutter-apk/BloodPressed-1.2.1+3-arm64-v8a.apk，附 .apk.sha256。
- 本机构建参数：JAVA_TOOL_OPTIONS 指定工作区 build/java-tmp，修复 Java NIO 回环连接错误。
- ABI 配置：defaultConfig.ndk + disable-abi-filtering=true，避免 Flutter 默认列表重新引入依赖中的其他 ABI。
