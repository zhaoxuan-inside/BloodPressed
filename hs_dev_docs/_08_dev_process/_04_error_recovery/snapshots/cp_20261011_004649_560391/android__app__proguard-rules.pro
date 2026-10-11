# 自定义 R8 规则（当前为空）。
#
# 历史：曾为 google_mlkit_text_recognition 配置 -dontwarn / -keep 规则，
# ML Kit 依赖已随 PP-OCR 七段码引擎替换而移除（TD-001，commit 待查
# `git log -- android/app/proguard-rules.pro`），规则一并清除。
# 后续插件若出现 R8 missing class 警告，按需在此追加 -dontwarn / -keep。
