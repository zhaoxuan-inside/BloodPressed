# 血压了么隐私政策发布

运营者：赵宣；隐私联系邮箱：zhaoxuanmail@163.com。
正文日期：2026-10-15。以实际发布 APK 的行为及商店审核结果为准。

## 同源正文

- 唯一正文：`assets/legal/privacy-policy.zh.json`。
- APP「我的 → 隐私政策」直接加载该文件，离线可读。
- `py -3 scripts/build_privacy_page.py` 生成本目录 `index.html`。
- 网页为 UTF-8 静态 HTML，适配手机；无外部脚本、图片、字体和统计请求。
- 网站托管方 GitHub 会按其政策记录访问 IP，正文已说明。

## GitHub Pages（不用购买服务器）

仓库：<https://github.com/zhaoxuan-inside/BloodPressed>（已有公开仓库）。
隐私网页使用独立 `gh-pages` 分支；分支内只有 `.nojekyll`、`index.html` 和
`privacy-policy/index.html`，没有将本地 APP 开发提交一起推送。

1. 用仓库管理账号打开 <https://github.com/zhaoxuan-inside/BloodPressed/settings/pages>。
2. Build and deployment 的 Source 选择 **Deploy from a branch**。
3. Branch 选择 **gh-pages**，目录 **/(root)**，保存。
4. 等待 GitHub 的 Pages build/deployment 成功，然后在未登录浏览器中打开预期链接：
   <https://zhaoxuan-inside.github.io/BloodPressed/privacy-policy/>。
5. 检查 HTTP 200、HTTPS、中文正文、赵宣与联系邮箱均可读后，才把这个地址填入 OPPO/vivo 后台。

**2026-10-15：管理账号已启用 Pages，公开链接已验证返回 HTTP 200，正文中的运营者“赵宣”和邮箱正确，可填写上述隐私政策地址。**

GitHub Pages 不需要自建后端，公开仓库可以使用 GitHub Free 的 Pages。
国内实际可达性需用手机移动网络检查；不能仅因电脑能访问就保证商店审核环境可访问。

官方说明：

- [GitHub Pages 是什么](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [创建 Pages 与配置来源](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site)
- [OPPO SDK 隐私指引](https://open.oppomobile.com/new/developmentDoc/info?id=13095)
- [个人信息保护法（工信部转载）](https://www.miit.gov.cn/jgsj/zfs/fl/art/2022/art_515a4b20c12f430eab54bb4f56d89f56.html)

## 当前实现与上架检查

1.2.4+6 已补齐以下流程，政策页面和 APP 正文同步更新：

- 首次启动显示同意/暂不同意和离线政策；同意前不打开业务库、不生成 UUID、不注册微信 SDK、不加载模型、不恢复提醒。旧版本未留存同意记录的用户也会看到说明。
- “我的”可撤回总体同意，业务组件销毁、停止提醒并回到说明；本地记录保留。
- 远端 AI 需填写实际运营者、政策 HTTPS URL 和已核实的数据处理地域。当前仅对符合 HTTPS 地址要求且声明大陆处理的配置开放健康信息授权；境外/未知地域不发送健康信息。这是应用功能限制，不是对用户填写内容的独立认证。
- 首次发送按接收方单独告知问题、聊天历史、近30天健康摘要及趋势数据范围，拒绝不发送。授权绑定档案、地址、模型和披露信息；变更需重授。“我的”可撤回全部远端授权并关闭连接；已发送信息需联系服务商处理。
- 云同步及账号登录占位已从设置、搜索和路由隐藏，无真实账号系统。
- 系统语音服务可能联网；不可将所有语音模式都宣传为纯离线。
- 有旧微信原生配置时只在隐私同意后注册 SDK；系统分享作为未配置时的正常路径。
- SDK 清单、权限及实际打包版本应与商店检测结果逐项核对。未把未接入的远端图片识别当成已启用功能。
- APP 删除记录为软删除，照片和本地变更日志可能留存；政策如实解释清除应用数据及导出副本的边界，不宣称已实现一键彻底删除。
- 正式身份 `com.zhaoxuan.bloodpressed`，使用独立正式密钥；原身份仅用于覆盖测试包。备份和构建见 `docs/android-signing.md`。

尚需在最终商店包上做真机权限和 SDK 检测、网络行为核验，填写商店开发者身份/资质并完成各商店审核；页面上线与自动测试不能替代这些实际审核。

## 以后更新

修改 JSON 后重新生成 HTML，检查 APP 与网页的正文一致，再更新 `gh-pages` 分支。
不要将密钥、用户健康数据或非必要的源码加入该发布分支。
记录政策更新版本、生效日期及对应 APP 版本；变更涉及重新同意时同步修改 APP 的真实授权流程。
