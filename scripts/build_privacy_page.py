"""Render the same policy JSON used by Flutter into a self-contained HTML page."""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "assets/legal/privacy-policy.zh.json"
policy = json.loads(source.read_text(encoding="utf-8"))
escape = html.escape

def paragraph_html(value):
    parts = re.split(r"(https?://[^\s]+)", value)
    return "".join(
        f'<a href="{escape(part, quote=True)}">{escape(part)}</a>'
        if part.startswith(("https://", "http://")) else escape(part)
        for part in parts
    )
parts = [f"<h1>{escape(policy['title'])}</h1>",
         f"<p class='meta'>更新日期：{escape(policy['updated'])}　生效日期：{escape(policy['effective'])}</p>",
         f"<p>运营者：{escape(policy['operator'])}<br>联系邮箱：<a href='mailto:{escape(policy['contact'])}'>{escape(policy['contact'])}</a></p>",
         f"<p>{escape(policy['intro'])}</p>",
         f"<p class='important'><strong>{escape(policy['sensitive'])}</strong></p>"]
for index, section in enumerate(policy["sections"], 1):
    parts.append(f"<section id='section-{index}'><h2>{escape(section['title'])}</h2>")
    parts.extend(f"<p>{paragraph_html(paragraph)}</p>" for paragraph in section["paragraphs"])
    parts.append("</section>")
body = "\n".join(parts)
output = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="血压了么应用隐私政策：数据处理、可选远端AI、权限、第三方服务及联系我们。">
<title>{escape(policy['title'])}</title>
<style>
:root{{color-scheme:light dark}}*{{box-sizing:border-box}}body{{margin:0;background:#f4f8f6;color:#1e3029;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;line-height:1.9}}main{{max-width:860px;margin:32px auto;padding:32px 40px;background:white;border:1px solid #dde7e1;border-radius:16px}}h1{{font-size:1.9rem;line-height:1.4;margin:0 0 12px}}h2{{font-size:1.2rem;margin:32px 0 12px}}p{{overflow-wrap:anywhere;margin:12px 0}}a{{color:#006f5b}}.meta{{color:#597064;font-size:.9rem}}.important{{padding:16px;background:#eaf5ef;border-left:4px solid #168267}}@media(max-width:600px){{main{{margin:0;border:0;border-radius:0;padding:24px 20px}}h1{{font-size:1.55rem}}}}@media(prefers-color-scheme:dark){{body{{background:#101b16;color:#e5eee8}}main{{background:#17271f;border-color:#355043}}.meta{{color:#afc2b6}}a{{color:#8de0be}}.important{{background:#213c2e}}}}@media print{{main{{border:0;margin:0;padding:0}}}}
</style></head><body><main>{body}</main></body></html>
"""
target = ROOT / "docs/privacy-policy/index.html"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(output, encoding="utf-8", newline="\n")
(target.parent / ".nojekyll").write_text("", encoding="utf-8")
print(target)
