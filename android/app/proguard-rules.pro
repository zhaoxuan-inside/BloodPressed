# google_mlkit_text_recognition 插件统一引用中日韩/天城文识别器，
# 本应用仅打包中文识别库（text-recognition-chinese），其余脚本识别器
# 类在链接期合法缺失，R8 需显式抑制警告（missing_rules.txt 生成）。
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder

# R8 full mode 会重组 ML Kit / GMS 内部类导致运行期 NPE
# （"getClass() on a null object reference"，识别必现报错），
# 保留 ML Kit 与其 GMS 内部实现，禁止混淆与优化。
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
