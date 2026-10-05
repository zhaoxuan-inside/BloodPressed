# 底部 AI助手入口按模型配置动态显示

- id: `plan-002`
- name: `底部 AI助手入口按模型配置动态显示`
- time: `2026-10-05 10:09:30`
- requirement: `底部 AI助手按钮只有在安装了大模型或者配置了远端大模型的情况下再显示`
- changelog: `<chg-xxx，记账后填写>`

## 目标

ShellScaffold 监听 llmProfilesProvider：无任何模型配置时隐藏 AI助手 destination（显示索引与 branch 索引映射），停留在该分支时配置删空自动跳回首页。

## 范围

- 做：ShellScaffold 改 ConsumerWidget，动态 destinations + 显示索引→branch 索引映射；配置删空且停留在 assistant 分支时自动跳首页；更新集成测试（未配置断言隐藏）。
- 不做：AssistantPage 页面本身保留（其他入口兜底）；不区分"已安装文件未建档"（以 LlmProfile 存在为准）。

## 步骤

- [x] 1. ShellScaffold 改 ConsumerWidget：watch llmProfilesProvider，hasModel=false 时隐藏 AI助手 destination，构建显示索引→branch 索引映射；ref.listen 处理"停留 AI助手分支时配置删空→跳 /home"
- [x] 2. 更新集成测试：未配置模型时断言底部无 AI助手（4 个 destination）；有配置（添加远端用例）断言显示
- [x] 3. flutter analyze + 全量测试通过
- [x] 4. 模拟器实测：有配置（Qwen3-0.6B 本地）5 tab 显示 AI助手 → 删除配置后 4 tab 消失，选中高亮正确前移
- [x] 5. 收尾：_07 登记变更、_10 记账、提交

## 恢复

- 上次完成：无
- 下一步：步骤 1
- 阻塞：无

## 备注

- 快速通道：影响面 2 个文件（app_router.dart + 集成测试）。
