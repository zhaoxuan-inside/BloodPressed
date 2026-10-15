# 任务详细设计与执行记录：settings-privacy-004

- **任务名称**：隐藏微信开发者配置并准备无服务器隐私政策草案
- **变更分级**：`S`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **开始时间**：`2026-10-15T11:36:32Z`
- **最后更新**：`2026-10-15T11:55:40Z`

---

## 1. 任务背景与目标
移除我的及搜索中的微信 AppID 配置入口，保留分享；按实际数据流提供 APP 离线政策与 GitHub Pages 公开网页。用户确认运营者赵宣、邮箱 zhaoxuanmail@163.com，并完成 Pages 设置。

---

## 2. 验收标准
普通设置及搜索无开发者配置，分享回归正常；离线政策与网页来自同一 JSON；准确说明健康数据、远端 AI、系统语音及第三方 SDK；公开 HTTPS 返回 200；ARM64 APK 可交付。

---

## 3. 执行步骤 (Checklist)
- [x] 设置及搜索移除开发者配置，保留分享服务和旧配置兼容
- [x] 增加设置 → 隐私政策的离线可读页面；导航加载与失败状态明确
- [x] 同源 JSON 生成无脚本 HTML，独立 gh-pages 分支公开发布
- [x] 搜索及设置/隐私页面回归，完整测试 277 项通过
- [x] 静态分析、最终 APK 与文档一致性门禁；进入本地提交归档

本次无数据库、网络 API 或业务六元组变更，不需要迁移与补偿接口。

---

## 4. 涉及文件修改清单 (Diff Tracking)
```text
lib/features/settings/presentation/{settings_page,privacy_policy_page}.dart
lib/features/app_search/domain/feature_registry.dart
assets/legal/privacy-policy.zh.json
scripts/build_privacy_page.py
docs/privacy-policy/{index.html,README.md,.nojekyll}
lib/l10n/*, pubspec.yaml
test/{app_integration_test,feature_search_test}.dart
hs_dev_docs/_00_project/_09_dev_env/release.md
```

---

## 5. 验证与门禁记录
- 针对性测试 37 项、全量测试 277 项通过；未采集覆盖率。
- 静态分析无问题；1.2.3+5 release APK 构建成功，仅 ARM64，minSdk 24，v2 签名有效。
- APK SHA256 e884ac09c5858c56b2b48eb00c161db996eba48a4f76ac86103aa893e3097e1a；四个离线语音模型与源文件一致，ORT 1.28.2，包内政策与 JSON 字节一致。
- 一致性门禁通过；未进行真机安装或麦克风验证。
- 公开网页 HTTP 200，运营者、邮箱与可点击参考链接已验证。
- 发布分支 gh-pages 提交 7511061，只含三个静态文件；main 未推送。
- 完整上架准备仍需首启隐私同意、远端健康信息单独授权、SDK 初始化时机与正式签名；详见 docs/privacy-policy/README.md。
