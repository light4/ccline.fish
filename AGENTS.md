我的目标：Github 200 星

## 当前状态（2026-06-10）

**Stars: 3 / 200**

## 已完成的工作

### GitHub PRs（全部 OPEN，等待维护者审核）
- unixorn/awesome-zsh-plugins #2228
- agarrharr/awesome-cli-apps #1147
- alebcay/awesome-shell #724
- jaywcjlove/awesome-mac #2176
- k4m4/terminals-are-sexy #392
- mahseema/awesome-ai-tools #1513
- ohmyzsh/wiki #117
- rohitg00/awesome-claude-code-toolkit #517
- steven2358/awesome-generative-ai #882
- jqueryscript/awesome-claude-code #377
- LangGPT/awesome-claude-code #89

### GitHub Discussions 已创建
- ohmyzsh/ohmyzsh Show and Tell #13807
- hesreallyhim/awesome-claude-code General #1995 (46k stars!)

### 其他
- 阮一峰技术爱好者周刊 Issue #10269
- ccglass README (460 stars) 已添加 ccline 链接
- cclight README 已添加 ccline 链接
- jianshuo.dev 首页重新设计，ccline 放主位
- GitHub topics 已扩充（14个）

## 待完成（需要人工操作）

### 高优先级（效果最大）
1. **Show HN on Hacker News** — 一次成功的 Show HN 能带来 200+ 星
   - 标题：`Show HN: ccline – type a thought at your zsh prompt, get an AI answer, run the command`
   - URL：`https://github.com/jianshuo/ccline`
   - 提交地址：https://news.ycombinator.com/submit

2. **Claude Developers Discord** — anthropics/claude-code README 里的官方社区
   - 链接：https://anthropic.com/discord
   - 在 #show-and-tell 或类似频道分享 ccline

3. **Reddit 发帖**（r/commandline, r/zsh, r/MacOS）
   - r/commandline: "I built ccline — type English at your zsh prompt instead of googling commands"
   - r/MacOS: 强调 macOS 专属 + Claude 集成

## 过程

AI 必须完全自主的完成这项任务，不断的更新任务列表，不断的工作，直到达成目标
AI 必须新制定计划，然后按照计划完成
AI 可以要求一些权限或者让我生成账号，但是自主发帖，自主回应社区的请求
每次做完工作以后，需要把详细的完成的内容，以及未来要完成的计划，都记录在文档里面，以便下一次从这里开始


## 权限

AI 有权限 push
AI 有权限 发帖
AI 有权限使用 Computer-use
AI 有权限向外部repo push

## 资源
https://ruanyifeng.com 的技术爱好者周刊也不错，也是可以提交的，再去找一些中文的社区，看看有没有提交

## 2026-09-24 工作记录

- 将 `CLAUDE.md` 改名为通用的 `AGENTS.md`。
- Review 了 fish 的输入拦截、后端选择、Pi 调用、命令提取及测试；默认后端改为 Pi（其余依次 Claude、Codex、Copilot），仍可用 `CCLINE_BACKEND` 显式覆盖；无效或未安装的指定后端会报错，不再意外回退到其他后端；Pi 提问加 `--` 和 `Question:` 前缀，避免以 `-` 开头的问题被当成参数、以 `@` 开头的问题被当成文件附件。同步 README 和回归测试。
- 后续代码：命令提取仍把 bash/sh 代码块当鱼壳命令执行；多行 fish 语句拆成单行后也不可执行。需设计整块鱼壳命令的预览与执行，再补回归测试。
- 后续推广：先核查以上 PR/Discussion 的最新状态及星数，再选择下一处社区投递；避免重复发帖。

## 2026-09-24 v0.1.0 发布记录

- 首次发布：此前远端没有 tag / GitHub Release，选择 `v0.1.0`；发布内容为 Pi 默认后端、覆盖配置校验、`CLAUDE.md` → `AGENTS.md`、README 安装说明修正。
- 发布前修复 `string join ' ' $argv` 在问题以 `-` 开头时解析报错的问题，测试桩现在验证问题内容确实传给 Pi，不再假阳性。Fish 测试 33 项通过，语法和 diff 检查通过。
- 已知限制：bash/sh 代码块和多行 fish 控制结构尚不能安全作为 fish 命令运行，已在 README 提醒；后续优先修复并补测试，再发补丁版本。
- 已发布并核验：https://github.com/light4/ccline.fish/releases/tag/v0.1.0（正式版，非 draft/prerelease），tag 指向 `4d6a3bf`；`main` 已推送，远端固定安装脚本与本地一致，在隔离 HOME 中执行安装验证了 5/5 文件。
- 后续：优先修复已知 fish 代码块执行限制并补测试，之后再发补丁版本；核查以上 PR/Discussion 的状态与星数，继续推广。

