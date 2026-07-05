# 好友与屏蔽共享 NB优化版V1.0

这是一个适用于《魔兽世界》WLK 3.3.5 客户端的好友与屏蔽名单同步插件，基于原版 Friend & Ignore Share 优化。

NB优化版主要增加了跨账号好友同步能力，并优化了好友变更提示和自有角色排除逻辑。

## 功能特性

- 同账号多角色好友列表同步
- 跨账号、同服务器、同阵营角色好友同步
- 添加好友时自动同步到已配置同步角色
- 删除好友时自动同步删除
- 登录角色时自动导入已保存的全局好友列表
- 避免把自己的角色、小号、同步角色加入好友列表
- 可选择是否自动移除好友列表里的小号
- 添加或删除好友时显示具体变更角色名
- 支持屏蔽名单同步
- 插件列表、聊天提示已汉化

## 安装方法

将 `FriendShare` 文件夹放入魔兽世界插件目录：

```text
World of Warcraft\Interface\AddOns\FriendShare
```

进入角色选择界面，点击左下角“插件”，确认“好友与屏蔽共享 NB优化版V1.0”已启用。

如果游戏已经打开，请在每个角色上输入：

```text
/reload
```

或者完全退出游戏后重新登录。

## 跨账号同步快速开始

跨账号同步需要两个账号的角色同时在线，并且双方都把对方添加为同步角色。

假设：

- 账号 1 角色：`Nbpala`
- 账号 2 角色：`Nbmagedad`

在 `Nbpala` 上输入：

```text
/fs peer add nbmagedad
```

在 `Nbmagedad` 上输入：

```text
/fs peer add nbpala
```

检查同步角色：

```text
/fs peers
```

首次同步或需要手动补同步时输入：

```text
/fs sync
```

完成首次同步后，日常添加或删除好友会在两个同步角色同时在线时自动同步。

## 常用命令

```text
/fs help
/fs peers
/fs peer add 角色名
/fs peer remove 角色名
/fs sync
/fs sync 角色名
/fs removealts
/fs removealts on
/fs removealts off
/fs import
/fs reset
```

屏蔽名单同步命令：

```text
/is help
/is import
/is reset
```

更详细的使用步骤请查看插件目录中的 [使用说明.txt](FriendShare/%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E.txt)。

## 注意事项

- 跨账号同步要求两个角色同时在线。
- 同步范围按“服务器-阵营”区分，不同服务器或不同阵营不会混用同一份好友列表。
- WLK 3.3.5 好友数量仍受客户端上限限制。
- 自己的角色、小号、同步角色会被记录用于排除，默认不会主动加入好友列表。
- 默认会自动移除好友列表里的小号；如果希望保留自己的小号好友，请输入 `/fs removealts off`。
- 如果聊天框出现 `FSHARE:` 开头的密语，这是插件的兼容同步消息，不影响功能。

## 项目结构

```text
FriendShare/
  FriendShare.lua
  FriendShare.toc
  FriendShare.xml
  IgnoreShare.lua
  IgnoreShare.xml
  使用说明.txt
```

## 作者信息

- 原作者：Vimrasha
- 优化版本：NB优化版V1.0

## 许可说明

本仓库保留原插件文件与改动记录，用于 WLK 3.3.5 插件使用与分享。
