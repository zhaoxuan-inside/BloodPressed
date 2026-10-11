# 任务详细设计与执行记录：td-001-mlkit

- **任务名称**：移除 ML Kit 双依赖（pubspec/gradle/proguard 三层残留）
- **变更分级**：`S`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **开始时间**：`2026-10-11T00:37:08Z`
- **最后更新**：`2026-10-11T00:47:03Z`

---

## 1. 任务背景与目标
确认 Dart 层零引用后，移除 google_mlkit_text_recognition 依赖、gradle 中文捆绑库与 R8 keep 规则，减 APK 体积

---

## 2. 验收标准
1) pubspec/gradle/proguard 无 mlkit 残留 2) flutter pub get + analyze 0 issue 3) flutter test 全绿 4) release APK 构建成功（R8 验证）

---

## 3. 执行步骤 (Checklist)
- [ ] 1. 完善设计文档与接口定义
- [ ] 2. 同步 DB 迁移脚本（V/U）
- [ ] 3. 编写/修改核心六元组业务逻辑
- [ ] 4. 编写全覆盖单测与契约测试
- [ ] 5. 本地质量门禁与提交前自检

---

## 4. 涉及文件修改清单 (Diff Tracking)
```text
(待更新)
```

---

## 5. 验证与门禁记录
- 单测覆盖率：`0%`
- 契约比对：`PENDING`
