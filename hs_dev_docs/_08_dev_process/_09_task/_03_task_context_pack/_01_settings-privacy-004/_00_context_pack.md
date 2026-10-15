# 上下文装载包 (Context Pack)：settings-privacy-004

- **change_size**：`S`
- **任务 ID**：`settings-privacy-004`
- **生成时间**：`2026-10-15T11:36:32Z`
- **状态**：`READY`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **查询**：`doc_index_db.py --root . search|slice`；Skill 详规用 `skill_ref_index.py search`（勿通读 references/）

---

## 1. 需求与目标（物化）
用户希望隐藏微信开发者配置，并为 OPPO/vivo 提供无需自建服务器的隐私政策。
验收：普通设置和搜索不再显示 AppID 配置；现有分享行为保留。
隐私正文必须反映实际行为，APP 与静态 HTML 使用同一份 JSON。
用户提供运营者赵宣、邮箱 zhaoxuanmail@163.com，选择 GitHub Pages 并已完成开关配置。
交付公开 HTTPS 地址与 1.2.3+5 ARM64 包；不将政策上线等同于已满足全部上架要求。

---

## 2. 数据模型切片（物化）
N/A：未触达数据库结构。已有微信 AppID 设置继续保存，避免破坏已可用的原生分享。
政策数据：assets/legal/privacy-policy.zh.json，含 title、updated、effective、operator、contact、intro、sensitive、sections。

---

## 3. 接口与六元组签名（物化）
PrivacyPolicyPage extends StatefulWidget，无入参；rootBundle.loadString → jsonDecode → FutureBuilder。
加载显示进度，失败显示本地化错误，成功显示可选择文本。不增加服务端 API。

---

## 4. 调用链与 Mock 契约（物化）
设置隐私入口 → MaterialPageRoute → PrivacyPolicyPage → 本地 assets/legal JSON。
同一 JSON → scripts/build_privacy_page.py → docs/privacy-policy/index.html → gh-pages。
分享服务调用链未修改；系统语音可能联网，Sherpa 兜底使用包内离线模型；远端 AI 包含健康摘要。

---

## 5. 查询轨迹（降 Token）
- 续做以 settings-privacy-004_plan.md 与对应 changes.jsonl 为准。
- 已装载 hs-dev-skill S/IMPLEMENT 流程；未创建空 ADR 或无关 DB/API 文档。
- 政策实际数据流及上架差距记录在 docs/privacy-policy/README.md。
