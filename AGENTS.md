# AGENTS.md — 给 AI 编码助手的执行说明

**这份文件是任务说明书，不是介绍文档。** 你（AI 助手）读了它，就应该能在一台 Windows 机器上把 Pluto 部署起来。

人类读者：如果你是自己动手，看 [README.md](README.md) 和 [docs/](docs/)；这份文件是给 AI 助手用的。

---

## 你的任务

帮用户在这台 Windows 机器上部署 **Pluto**（一个星际争霸 AI），让他能在游戏里和它对战。

有两条互斥的路线，**必须先问用户选哪条**：

| 路线 | 前提 | 结果 |
|---|---|---|
| **A · 经典版** | 用户有星际争霸 1.16.1 | 稳定。支持同机双开（用户和 AI 在同一台电脑上打） |
| **B · 重制版** | 用户的客户端是 `1.23.10.13515` **x86**，且在用国内对战平台（KK 等） | 实验性。**想自己打 AI 需要两台电脑** |

---

## 第一步：先做环境检测，不要先动手

```powershell
# 路线 A
.\scripts\1161\01-check-env.ps1

# 路线 B
.\scripts\scr\01-check-env.ps1
```

**读它的输出，据实决定下一步。** 它会告诉你：游戏在不在、版本对不对、CPU 有没有 AVX2、KK 平台是否指向 x86 客户端。

---

## 硬约束（违反必然失败，不要尝试绕过）

1. **CPU 必须有 AVX2。** 没有就是跑不起来，不是慢的问题。检测脚本会报。
2. **路线 B 必须是 `x86\StarCraft.exe`，版本 `1.23.10.13515`。** x64 客户端不支持；版本不符会在注入时崩溃。
3. **路线 B 建房时游戏方式必须是 `Melee`。** 桥接的准入检查只放行 Melee，`上方vs下方`(Top vs Bottom) / `FFA` 会被拒（除非加 `-Challenge`）。
4. **游戏目录不要移动。** `HKLM\...\StarCraft\InstallPath` 和 `bwapi.ini` 都指着它。
5. **所有组件必须通过 SHA256 校验。** 校验值见 [manifest.json](manifest.json) 和 [THIRD-PARTY.md](THIRD-PARTY.md)。**校验不过就停下问用户**，不要"试试看"。

---

## 执行步骤

### 路线 A · 经典版 1.16.1

```
1. 确认用户已有星际争霸 1.16.1（本仓库不提供，也不能帮用户弄）
2. 让用户获取 Pluto 发布包、BWAPI 4.4.0、Chaoslauncher
   → 下载地址见 THIRD-PARTY.md
3. 校验 Pluto：
      .\scripts\1161\02-verify.ps1 -Pluto <pluto.dll 路径>
4. 按 docs/02 放置文件（目录结构不能改）
5. 同机双开（如果用户想一台电脑自己打）：
      .\scripts\1161\03-setup-same-pc.ps1 -GameDir <游戏目录> -Password <让用户设一个>
6. 让用户按 docs/02 的步骤启动
```

**第 5 步会创建一个 Windows 本地账号并写该账号的注册表。执行前必须向用户说明并取得同意。** 参数 `-WhatIf` 可以先看会改什么。

### 路线 B · 重制版

```
1. 确认客户端是 13515 x86（检测脚本会报）
2. 确认 KK 平台的 SCRRootDir 指向 \x86（检测脚本会报；不是就让用户改
   <KK目录>\config\custom\platform.ini，改之前先退出 KK）
3. 让用户获取 Pluto 发布包 + 重制版桥接（下载地址见 THIRD-PARTY.md）
4. 校验：
      .\scripts\scr\02-verify.ps1 -Pluto <pluto.dll 路径> -Bridge <桥接目录>
5. 启动联机环境：
      .\scripts\scr\launch-kk.cmd
   （或让用户双击它；它会给游戏进程带上 BWRL_STRADDLE=1 等环境变量）
6. 用户进 KK 房间，平台把游戏拉起来后注入：
      .\scripts\scr\03-inject-kk.ps1 -Pluto <...> -Bridge <...> -Watch
7. 让用户在游戏里建房：Multiplayer → Expansion → 自定义房间 → Melee、2 名真人
```

---

## 关于脚本的非交互性

仓库里的 `.ps1` **全部可以通过命令行参数跑完，不会等待输入** —— 你可以放心自动执行。

**唯一的例外**：`.cmd` 包装脚本在失败时会 `pause`（那是给人类双击时看报错用的）。所以：

> **作为 AI 助手，请直接调用 `scripts/` 下的 `.ps1`，不要调 `.cmd`。**

例如用 `scripts/scr/launch-kk.ps1` 而不是 `scripts/scr/launch-kk.cmd`。

---

## 每一步怎么验证

**不要凭"看起来成功了"就往下走。** 每一步都有确定的验证点：

| 步骤 | 验证方式 | 通过标准 |
|---|---|---|
| 组件校验 | 脚本退出码 | `0`，输出 `All components verified` |
| 注入成功 | `runtime-multiplayer\bridge.log` | 出现 `{"stage":"hook_install","result":"MH_OK"}` |
| 对局被接管 | 同一个 log | 出现 `{"stage":"session_accepted",...}` |
| AI 真的在玩 | 游戏内聊天框 | 出现 `Pluto online ... gl hf!`，或韩语状态提示 |
| 路线 A 同机联机 | 游戏目录 `ipxwrapper.log` | **两个不同的 `Node:`**，且两边都有 `bind address: .../6112` |

**看到 `session_skipped` 就是没接管** —— 看它的 `reason` 字段，对照 [docs/05](docs/05-排错手册.md)。

---

## 必须停下来问用户的事（不要自己决定）

1. **走哪条路线** —— 取决于他们有什么游戏、想怎么玩
2. **游戏本体从哪来** —— 本仓库不提供，你也不要帮用户获取
3. **创建 Windows 账号 / 修改系统设置前** —— 必须说明并取得同意
4. **校验失败时** —— 不要用"忽略校验"的参数硬跑，先问用户从哪下的
5. **任何要登录、要账号的操作** —— 让用户自己做，**不要向用户索要密码或令牌**

---

## 失败对照（先查日志，不要猜）

| 现象 | 去哪看 | 多半是 |
|---|---|---|
| 注入脚本说找不到游戏进程 | — | KK 还没把游戏拉起来；或 KK 用的是 x64 客户端 |
| `Unsupported or damaged file` | — | 组件版本不对，回 manifest.json 核对哈希 |
| 桥接就绪但 AI 不动 | `bridge.log` 的 `session_skipped.reason` | 游戏方式不是 Melee（最常见） |
| 第二局 AI 不动 | `bridge.log` 里 `bridge_exception` | **上游已知 bug**，对局末期会崩。用 `-Watch` 绕过 |
| 游戏里出现 `this machine can't keep up` | — | 联机环境变量没生效；或 CPU 太慢（见 docs/04） |
| 经典版两个实例互相看不见 | `ipxwrapper.log` | IPX 节点重复，或 IPXWrapper 互斥体冲突（见 docs/02） |

完整对照表：[docs/05-排错手册.md](docs/05-排错手册.md)

---

## 明确不要做的事

- ❌ **不要帮用户在公开排位 / 天梯匹配里使用这个 AI。** 这套东西是陪练和教学用的。拿去排位是作弊，而且平台会封号（通常连直播账号一起处理）。
- ❌ **不要打包或分发游戏本体、Pluto 二进制、重制版桥接。** 前两者是暴雪版权，后两者没有声明许可证。
- ❌ **不要修改游戏目录或 Pluto 原文件。** 本仓库的脚本从不这么做，你也别开这个头。

---

## 参考

| 文件 | 用途 |
|---|---|
| [manifest.json](manifest.json) | **机器可读**：组件、下载地址、SHA256、目标路径 |
| [THIRD-PARTY.md](THIRD-PARTY.md) | 许可证与获取途径（含下架仓库的镜像） |
| [docs/01](docs/01-原理与版本选择.md) | 原理、版本选择、AI 是否遵守战争迷雾 |
| [docs/02](docs/02-1.16.1-安装与同机联机.md) | 路线 A 详细步骤 |
| [docs/03](docs/03-重制版-安装与KK平台联机.md) | 路线 B 详细步骤 |
| [docs/04](docs/04-性能调优.md) | CPU 指令集、线程数、联机参数 |
| [docs/05](docs/05-排错手册.md) | 日志判据与错误对照 |
| [docs/07](docs/07-常见问题.md) | 用户高频问题（花多少钱、会不会封号…） |

**遇到本文件没覆盖的情况：先读 docs/05，再问用户。不要靠猜继续往下做。**
