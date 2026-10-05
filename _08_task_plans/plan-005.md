# 拍照识别改用系统相机

- id: `plan-005`
- name: `拍照识别改用系统相机`
- time: `2026-10-05 14:05:00`
- requirement: `拍摄框不适合手机，高低被压缩了；直接调用系统的相机，然后使用拍照的照片进行分析。快速通道。`
- changelog: `chg-006`

## 目标

拍照识别不再使用自绘取景页（取景框纵向比例不适配手机），改为直接调起系统相机拍照，照片进入原有识别管线。

## 范围

- 做：startCamera 请求相机权限后用 image_picker 系统相机；删除 CameraCapturePage 与 camera 插件依赖；模拟器实测系统相机拍照→识别管线。
- 不做：自绘取景引导（系统相机自带 UX）。

## 步骤

- [x] 1. ocr_flow.startCamera 改 image_picker 系统相机 + 相机权限请求；移除 CameraCapturePage 引用
- [x] 2. 删除 camera_capture_page.dart；pubspec 移除 camera 依赖；pub get
- [x] 3. analyze + 全量测试
- [x] 4. 模拟器实测：拍照识别→系统相机→拍照→识别管线兜底路径
- [x] 5. 收尾：_10 记账、提交

## 恢复

- 上次完成：全部步骤
- 下一步：无（模拟器实测通过：系统相机调起→拍照→识别兜底）
- 阻塞：无

## 备注

- image_picker 的 source: camera 在 Android 上即 ACTION_IMAGE_CAPTURE 调起系统相机；应用声明了 CAMERA 权限时必须先授权。
