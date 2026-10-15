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

## 实际行为核对与上架边界

该网页不是“保证通过商店审核”的证明，也没有替 APP 自动补齐同意流程。
当前版本需要在上架前继续落实：

- 首次启动的隐私告知、明确同意/拒绝及持续访问政策的入口；不能用“继续使用视为同意”替代必要授权。
- 医疗健康属于敏感个人信息。远端 AI 会发送健康摘要；应按实际接收方、目的和信息范围进行告知及法律要求的单独同意，境外接收方另行核对跨境条件。
- 系统语音服务可能联网；不可将所有语音模式都宣传为纯离线。
- 有旧微信原生配置时当前仍可能在启动时注册 SDK，SDK 初始化时机应纳入首启同意改造；仅隐藏配置入口不会移除 SDK。
- SDK 清单、权限及实际打包版本应与商店检测结果逐项核对。未把未接入的远端图片识别当成已启用功能。
- APP 删除记录为软删除，照片和本地变更日志可能留存；政策如实解释清除应用数据及导出副本的边界，不宣称已实现一键彻底删除。
- 上架开发者身份须与运营者一致；本地 release 目前仍是调试证书，应用包名还是 `com.example.blood_pressed`，提交商店前应确定正式签名及应用身份。

这些是代码检查发现的实际差距；本轮提供正确的政策正文、离线入口和页面托管准备，尚未声称已完成完整上架合规改造。

## 以后更新

修改 JSON 后重新生成 HTML，检查 APP 与网页的正文一致，再更新 `gh-pages` 分支。
不要将密钥、用户健康数据或非必要的源码加入该发布分支。
记录政策更新版本、生效日期及对应 APP 版本；变更涉及重新同意时同步修改 APP 的真实授权流程。
