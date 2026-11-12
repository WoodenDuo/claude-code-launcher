# Claude Code 配置固化器

**一句话**：在 shell 里装一个 `cla` 函数，启动 Claude Code 时把当前配置固化到一份临时文件，让同一台机器上的多个会话各用各的模型，互不干扰。

> 名字说明：它不"启动"任何新东西，只是在 claude 启动前把配置拍一份快照，所以叫固化器更准确。

## 安装

前提：已安装 `claude`；机器上有 `python3`、`python`、`jq` 中的任意一个（用来读 JSON）。

### 1. 下载脚本

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/WoodenDuo/claude-code-launcher/main/install-claude-wrapper.sh -o ~/.claude/install-claude-wrapper.sh
```

### 2. 选一种模式执行

三种模式都**必须**用 `source` 执行。直接 `bash install-claude-wrapper.sh` 只会跑一遍，不会写进你的 shell 配置。

#### 模式 A：正常模式（推荐，默认别名 `cla`）

```bash
source ~/.claude/install-claude-wrapper.sh
```

- 命令：`cla`
- 效果：shell 配置文件里多一个 `cla()` 函数
- 权限：保留 Claude Code 默认的权限确认

#### 模式 B：自定义别名

```bash
source ~/.claude/install-claude-wrapper.sh zz
```

- 命令：`zz`
- 别名可以随便取，但别用 `cc`（系统 C 编译器）、`git`、`ls` 这类已存在的命令
- 权限：同模式 A

#### 模式 C：免授权模式

```bash
source ~/.claude/install-claude-wrapper.sh cla --skip-permissions
```

- 命令：`cla`
- 权限：每次启动自动附加 `--dangerously-skip-permissions`，不再逐条确认
- 谨慎使用：模型可以不经确认直接改文件、跑命令

| 模式 | 命令 | 生成别名 | 权限确认 |
| --- | --- | --- | --- |
| A 正常 | `source ...install-claude-wrapper.sh` | `cla` | 保留 |
| B 自定义别名 | `source ...install-claude-wrapper.sh zz` | `zz` | 保留 |
| C 免授权 | `source ...install-claude-wrapper.sh cla --skip-permissions` | `cla` | 跳过 |

> B 和 C 可以组合：`source ...install-claude-wrapper.sh zz --skip-permissions`。

### 3. 生效并验证

```bash
source ~/.zshrc              # zsh；bash 用 source ~/.bashrc 或 ~/.bash_profile
type cla                     # 输出 cla is a function 即成功
```

## 支持的系统

安装脚本会自动识别当前 shell，把函数写进对应的 rc 文件：

| 系统 | shell | 写入的 rc 文件 | 状态 |
| --- | --- | --- | --- |
| macOS | zsh（默认） | `~/.zshrc` | 已测试 |
| macOS | bash | `~/.bash_profile` | 已测试 |
| Linux | bash（默认） | `~/.bashrc` | 已支持 |
| Linux | zsh | `~/.zshrc` | 已支持 |

想强制指定或用非默认路径：

```bash
source ...install-claude-wrapper.sh --shell=bash          # 强制按 bash 安装
source ...install-claude-wrapper.sh --rc=~/.config/zsh/.zshrc   # 直接指定 rc 文件
```

Windows 原生 cmd / PowerShell 不支持；请在 WSL 里按 Linux 方式安装。

## 使用

```bash
cla                 # 用当前全局配置启动
cla --resume        # 后面所有参数原样传给 claude
cla --help
```

## 执行原理

### 启动时：一次会话一份配置快照

`cla` 不是新程序，就是一个 shell 函数。每次执行它，依次做这几件事：

1. **读全局配置**：打开 `~/.claude/settings.json`，取其中的 `env` 字段（模型名、API 地址、key 这类环境变量）。
   - 文件不存在 → 直接 `claude "$@"`
   - 没有 `python3 / python / jq` → 打一行警告，直接 `claude "$@"`，不会中断
2. **写临时文件**：把 `env` 原样写到 `$TMPDIR/.claude-frozen-config-$$.json`（没设 `$TMPDIR` 时用 `/tmp`）。`$$` 是当前 shell 的进程号，每开一个终端文件名都不一样。
3. **挂清理钩子**：`trap "rm -f 临时文件" EXIT INT TERM`，正常退出或 Ctrl+C 都会删掉。
4. **带 settings 启动**：`claude --settings 临时文件 "$@"`。这次会话只认这份快照里的 `env`，不再关心全局文件被改成了什么。
5. **收尾**：退出后清掉 trap、删掉临时文件，并把 claude 的退出码透传出去。

```
settings.json ──取 env──▶ $TMPDIR/.claude-frozen-config-12345.json
                                  │
                       claude --settings ...  ◀── 你的参数原样透传
                                  │
                            会话结束 → rm 临时文件
```

所以两条 `cla` 先后启动，各自锁定自己那一刻的模型；中途改全局配置，只影响之后新启动的会话。

### 安装时：往 rc 文件里插一段带标记的代码

`source install-claude-wrapper.sh` 做的三件事：

1. 识别 shell，算出要写哪个 rc 文件（不存在就创建）；
2. 如果里面已有 `# Claude Code 配置固化器` 到 `# END Claude Code 配置固化器` 这一段，先整段删掉——所以可以重复安装、换别名重装（旧版本 `快捷启动器` 的段也会被一并清理）；
3. 追加新的函数定义，并在末尾 `source` 对应的 rc 文件，让当前 shell 立刻可用。

它只动这一段，不碰你的 PATH、alias 和其它配置。

## 只锁定 env

只有 `settings.json` 的 `env` 会被固化；权限、hooks、MCP 等其它设置仍按全局配置生效，日常调整不用重装。

## 卸载

1. 删掉 rc 文件里 `# Claude Code 配置固化器` 到 `# END Claude Code 配置固化器` 之间的内容；
2. 让函数从当前 shell 消失：

```bash
# zsh
unfunction cla && source ~/.zshrc
# bash
unset -f cla && source ~/.bashrc
```

3. 可选：`rm -f "${TMPDIR:-/tmp}"/.claude-frozen-config-*.json`

## 常见问题

**`defining function based on alias`** —— 别名和已有 alias 冲突，先 `unalias cla`，再 `source ~/.zshrc`。

**`clang: error: no input files`** —— 别名取成了 `cc`，换成 `cla` 重装。

**装完提示 `cla: command not found`** —— 装的 rc 文件和当前 shell 不匹配。用 `echo $SHELL` 确认 shell，或用 `--rc=` 指定正确文件后重装。

**临时文件在哪** —— `${TMPDIR:-/tmp}/.claude-frozen-config-<PID>.json`，会话结束自动删除。

## English TL;DR

**Claude Code Config Freezer** — a shell function that freezes Claude Code's `settings.json` `env` into a temp file at launch, so several sessions can run different models side by side. Works on macOS/Linux with zsh or bash. Install with `source`, then run `cla`.
