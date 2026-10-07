# 第三方组件清单（许可证与获取方式）

本仓库**不随包分发**任何第三方二进制或游戏本体。下表是全部依赖项、它们的许可证，以及官方获取途径。

> ⚠️ **没有声明许可证 ≠ 可以自由分发。** 按伯尔尼公约和各国著作权法，未声明许可证的软件默认"保留所有权利"。所以下面标 `未声明` 的组件，**只能由使用者本人从上游获取，不能打包再分发**。

---

## 组件总表

| 组件 | 用途 | 许可证 | 获取途径 |
|---|---|---|---|
| **星际争霸：母巢之战 1.16.1** | 经典版游戏本体 | 暴雪版权 | 自备 |
| **星际争霸：重制版** | 重制版游戏本体 | 暴雪版权 | 自备（需 `1.23.10.13515`） |
| [tscmoo/pluto](https://github.com/tscmoo/pluto) | AI 本体 | **未声明** | Releases 页 |
| [bwapi/bwapi](https://github.com/bwapi/bwapi) | 1.16.1 的 AI 接口 | **LGPL-3.0** | GitHub Releases（需 4.4.0） |
| Chaoslauncher | 1.16.1 的注入器 | **未声明** | TeamLiquid 原帖 / 各星际社区 |
| [solemnwarning/ipxwrapper](https://github.com/solemnwarning/ipxwrapper) | 同机 / 局域网 IPX 联机 | **GPL-2.0** | GitHub Releases |
| Pluto 重制版桥接 | 把 Pluto 接到重制版 | **未声明** | 原仓库已下架，见下方镜像 |
| [hwkim3330/pluto-re](https://github.com/hwkim3330/pluto-re) | 逆向文档（**只读参考**） | 未声明 | GitHub |

---

## 重制版桥接的获取（重点）

**原仓库 `chan22222/Pluto-AI-Starcraft-Remaster` 已于 2026-10 前后下架**（访问返回 404）。

目前可用的镜像：

- https://github.com/lpflhh/Pluto-AI-Starcraft-Remaster

> 该镜像的 `bin/pluto-scr.dll` 与原仓库内容一致，SHA256 为 `beba6230b098c77579a281f592b83beea5d335b2105b7c4b2bf4fad069e74773`。

**如果这个镜像也失效了**，请自行在 GitHub 搜索同名仓库，或从社区网盘中寻找。本仓库不提供二进制镜像 —— 一是许可证不允许，二是上游消失后任何镜像都可能是被改动过的，**自己核对 SHA256 才是唯一可靠的办法**（见下方哈希表）。

> 注意：桥接本身是**实验性项目**，作者在 README 中明确写着"联机双端同步尚未验证完"。使用前请理解这一点。

---

## 版本哈希表（用于校验）

**本指南所有结论都基于下面这几个确切版本。** 版本不对，一切都不成立 —— 请务必核对。

### 游戏本体

| 文件 | SHA256 |
|---|---|
| 重制版 `x86\StarCraft.exe`（1.23.10.13515） | `32dbbdd001dd381cb1b3a719b7ad1fc918a9d4bc99661c675e00254efecca827` |

> 重制版**必须用 x86 那个**（`\x86\StarCraft.exe`），x64 的 `\x86_64\starcraft.exe` 不是桥接的目标。

### Pluto（`md07x02_cog2026_2578600_int8mv` 发布版）

| 文件 | SHA256 |
|---|---|
| `pluto.dll` | `7e360b643c8c0156c03fe0cad9972a3058138ccfe22f921c5b4e0cd0aaf0abef` |
| `pluto\pluto_infer.exe` | `ad880d8be52a6ef03893fa20644b6627e04fcd55e030178c6d52486b82340f2b` |
| `pluto\pluto_weights.bin` | `00b400eace6e4782202ebdcb3c30db76054aaa6a08c6a7dcb59575abc2d0a26e` |

### 重制版桥接

| 文件 | SHA256 |
|---|---|
| `bin\pluto-scr.dll` | `beba6230b098c77579a281f592b83beea5d335b2105b7c4b2bf4fad069e74773` |
| `bin\scr-loader.exe` | `5461b07d1d656fbedb86245da64ce3fb3d71a3ef4a81221d6a094a5c54f68e7e` |

> 桥接仓库里自带的 `validation/SHA256SUMS.txt` 记录的 `pluto-scr.dll` 是另一个构建（`89170b92…`），与 `bin/` 里的实际文件对不上 —— 这是上游的文件不一致，**以本表为准**。

### 校验方式

```powershell
# 单个文件
Get-FileHash .\pluto.dll -Algorithm SHA256

# 或用本仓库的脚本
.\scripts\scr\02-verify.ps1 -Pluto <pluto.dll 路径> -Bridge <桥接目录> -VerifyOnly
```

---

## 关于许可证的说明

- **LGPL-3.0（BWAPI）**、**GPL-2.0（IPXWrapper）** 是允许再分发的自由软件许可。本仓库不打包它们，但在脚本中提供了官方下载链接。
- **未声明许可证的组件**（Pluto、Chaoslauncher、重制版桥接）**不可再分发**。请每位使用者自行从上游获取。
- 本仓库自身的脚本与文档采用 **MIT** 许可（见 [LICENSE](LICENSE)），但**这不构成对上述第三方组件的任何授权**。
