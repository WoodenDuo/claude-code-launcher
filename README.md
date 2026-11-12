# Claude Code 快捷启动器

一条命令启动 Claude Code，并且在**启动瞬间锁定当时的配置**：之后再改 `~/.claude/settings.json`，也不会影响已经在跑的会话。

- 同一目录可以同时开多个用不同模型的会话
- 临时配置文件随会话结束自动清理
- 别名随便取，可选免授权模式

> 适合经常切换模型 / API 地址 / key，又不想让新旧会话互相干扰的人。

## 它解决什么问题

Claude Code 默认所有会话共用一份 `~/.claude/settings.json`。你在会话 A 里换了模型，A 自己会跟着变，B 也跟着变，两个会话互相打架。

这个启动器在启动时把当前的 `env` 配置复制成一份临时文件，用 `--settings` 只喂给这一次会话：

| 步骤 | 操作 | 结果 |
| --- | --- | --- |
| 1 | 全局配置为 `glm-5`，执行 `cla` | 会话 1 锁定 `glm-5` |
| 2 | 把全局配置改成 `claude-sonnet-4-6` | 会话 1 不受影响 |
| 3 | 再次执行 `cla` | 会话 2 使用 `claude-sonnet-4-6` |

两个会话各跑各的模型，互不干扰。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/WoodenDuo/claude-code-launcher/main/install-claude-wrapper.sh -o /tmp/install-claude-wrapper.sh
source /tmp/install-claude-wrapper.sh
```

装完新开一个终端（或执行 `source ~/.zshrc`），验证一下：

```bash
type cla      # 输出 cla is a function 就成功了
```

> ⚠️ 必须用 `source` 执行。直接 `bash install-claude-wrapper.sh` 不会把函数写进你的 shell 配置。

### 安装参数

```bash
source /tmp/install-claude-wrapper.sh zz                      # 自定义别名 zz
source /tmp/install-claude-wrapper.sh cla --skip-permissions   # 免授权模式
```

| 参数 | 说明 | 默认 |
| --- | --- | --- |
| 别名 | 启动命令的名字，可以随便取 | `cla` |
| `--skip-permissions` | 跳过权限确认（谨慎使用） | 关闭 |

## 使用

```bash
cla                 # 用当前全局配置启动
cla --resume        # 其余参数原样透传给 claude，claude 支持的都能用
cla --help
```

## 只在启动时锁定 env

启动器只固化 `settings.json` 里的 `env` 字段（模型、API 地址、key 这类环境变量），其它设置仍按全局配置生效——这样升级、改权限、改 hook 不用重新装。

## 依赖

读取 JSON 需要以下任一命令，装一个就行：

- `python3`（推荐）
- `python`
- `jq`

三个都没有时，脚本会提示一句警告并直接启动 `claude`，不会报错中断。

## 卸载

1. 编辑 `~/.zshrc`，删除 `# Claude Code 快捷启动器` 到 `# END Claude Code 快捷启动器` 之间的内容；
2. 当前终端执行 `unfunction cla && source ~/.zshrc`。

临时文件都在 `/tmp/.claude-frozen-config-<PID>.json`，会话结束自动删除，也可以手动清理：

```bash
rm -f /tmp/.claude-frozen-config-*.json
```

## 常见问题

**提示 `defining function based on alias`**
别名和已有的 alias 冲突了。先 `unalias cla`，再重新 `source ~/.zshrc`。

**提示 `clang: error: no input files`**
你把别名取成了 `cc`，它是系统的 C 编译器。换一个别名重装，比如 `cla`。

**会不会污染现有配置？**
不会。安装只往 `~/.zshrc` 追加一段带起止标记的函数定义，重复安装会先删掉旧段再写新的。

## 文件

| 文件 | 说明 |
| --- | --- |
| `install-claude-wrapper.sh` | 安装脚本，负责写入 shell 函数 |
| `README.md` | 本文档 |

## English TL;DR

A tiny launcher for Claude Code that freezes your `settings.json` `env` at launch, so several sessions can run different models side by side.

```bash
curl -fsSL https://raw.githubusercontent.com/WoodenDuo/claude-code-launcher/main/install-claude-wrapper.sh -o /tmp/install-claude-wrapper.sh
source /tmp/install-claude-wrapper.sh        # then run: cla
```

Must be executed with `source`.
