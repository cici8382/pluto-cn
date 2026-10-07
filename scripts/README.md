# scripts

两条线的部署脚本。**先读 [../README.md](../README.md)，再读对应的 docs。**

---

## 目录

```
lib/verify.ps1                共用：哈希校验、环境探测（CPU / 游戏目录 / KK 配置）
1161/                       星际争霸 1.16.1 线
  01-check-env.ps1             检查游戏、BWAPI、Pluto、IPXWrapper 是否齐全
  02-verify.ps1             校验 Pluto 三个文件的 SHA256
  03-setup-same-pc.ps1         同机双开：建账号 + 影子目录 + 1 字节改名
scr/                        重制版线
  01-check-env.ps1             检查客户端版本/架构、CPU、KK 是否指向 x86
  02-verify.ps1             校验 Pluto + 桥接的 SHA256
  launch-kk.ps1/.cmd    带联机环境变量启动 KK（STRADDLE）
  03-inject-kk.ps1             把 AI 注入到 KK 启动的游戏进程；-Watch 自动重注入
```

---

## ⚠️ 修改脚本前必读：编码

**本仓库所有 `.ps1` 和 `.cmd` 文件都是纯 ASCII，请保持这个约定。**

原因：Windows PowerShell 5.1 在读取**不带 BOM** 的 `.ps1` 时，会按系统 ANSI 代码页解码。如果文件里写了 UTF-8 的中文，在中文系统上会被按 GBK 解码 —— 中文会变成乱码，而乱码里可能恰好出现引号或反引号，**直接破坏脚本语法**，报出一堆莫名其妙的「缺少右花括号」之类的错误。

所以：

- 脚本里的注释和输出**一律用英文/ASCII**
- 所有中文说明放在 `/docs` 的 Markdown 里
- 如果你确实要在脚本里写中文，**必须另存为 UTF-8 with BOM**，否则在别的机器上会坏

`.cmd` 文件同理，而且更严格 —— cmd.exe 的代码页处理更原始，中文极易被拆成假命令。

---

## 常用命令

```powershell
# ---- 1.16.1 ----
.\scripts\1161\01-check-env.ps1
.\scripts\1161\02-verify.ps1 -Pluto "G:\starcraft_old\bwapi-data\AI\pluto.dll"
.\scripts\1161\03-setup-same-pc.ps1 -GameDir "G:\starcraft_old" -Password "<自定义密码>"
.\scripts\1161\03-setup-same-pc.ps1 -GameDir "G:\starcraft_old" -WhatIf   # 只看不改

# ---- 重制版 ----
.\scripts\scr\01-check-env.ps1
.\scripts\scr\02-verify.ps1 -Pluto "<pluto.dll>" -Bridge "<桥接目录>"
.\scripts\scr\launch-kk.cmd
.\scripts\scr\03-inject-kk.ps1 -Pluto "<pluto.dll>" -Bridge "<桥接目录>" -Watch
```

首次运行如果提示「禁止运行脚本」，用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\scr\01-check-env.ps1
```

或者对当前用户放开（一次性）：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

## 这些脚本会改什么

用之前心里有数：

| 脚本 | 改动 |
|---|---|
| `1161/03-setup-same-pc.ps1` | **创建 Windows 本地账号**；写入该账号的注册表（仅 `HKCU\Software\IPXWrapper`）；**新建**一个影子目录（目录联接 + 硬链接，不占额外空间）；**不修改**原游戏目录和原 `ipxwrapper.dll` |
| `scr/03-inject-kk.ps1` | 只注入内存；在桥接目录下写 `runtime-multiplier/` 日志；**不修改**游戏和 Pluto 文件 |
| `scr/launch-kk.ps1` | 只设置两个环境变量后启动 KK |

撤销：

- 删除 Windows 账号：`net user <账号名> /delete`
- 删除影子目录：直接删文件夹（**注意：删之前确认里面是联接/硬链接，不会连带删掉原文件**）
