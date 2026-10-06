# 修复相册/拍照识别 release 崩溃（ML Kit 中文库未打包 + R8 keep）

- id: `plan-003`
- name: `修复相册/拍照识别 release 崩溃（ML Kit 中文库未打包 + R8 keep）`
- time: `2026-10-05 10:55:00`
- requirement: `相册识别和拍照识别功能异常，存在报错。快速通道热修。`
- changelog: `chg-004`

## 目标

相册/拍照识别在 release 包可用：消除 NoClassDefFoundError 与 ML Kit 混淆 NPE，异常提示人性化。

## 范围

- 做：gradle 引入 text-recognition-chinese 运行时依赖；proguard 保留 ML Kit 内部类；OCR 异常提示改为用户可读文案（详情进日志）。
- 不做：七段屏预处理、识别白名单（后续优化项）。

## 步骤

- [x] 1. 模拟器复现：相册选图 → 识别失败（PlatformException NPE 混淆堆栈）
- [x] 2. 根因定位：插件 gradle 对 text-recognition-chinese 仅 compileOnly，运行时无此类 → NoClassDefFoundError（首版即坏，与 R8 无关）；R8 报警与混淆 NPE 为连带问题
- [x] 3. 修复：app build.gradle.kts 补 implementation 依赖；proguard-rules.pro 保留 ML Kit/GMS 内部类；ocr_flow 异常提示人性化（PlatformException → 友好文案，原始错误进 debugPrint）
- [x] 4. 验证：相册识别真实识别 125/82（置信度 75%）进确认表单；拍照识别无崩溃、空场景正确走"未能识别"兜底
- [x] 5. 全量测试 + 收尾提交 + 重建真机包（后续多轮全量 112 测试通过、真机包已随修复重建；收尾并入 plan-006/chg-007）

## 恢复

- 上次完成：步骤 4
- 下一步：步骤 5
- 阻塞：无

## 备注

- 经验：google_mlkit_text_recognition 插件对所有脚本识别库（中/日/韩/天城文）仅 compileOnly，使用 script=chinese 的应用必须自带 implementation 依赖。
