# 好友与屏蔽共享 NB优化版V1.1

适用于《魔兽世界》WLK 3.3.5 的好友/屏蔽名单同步插件，基于原版 Friend & Ignore Share 优化。

## 主要功能

- 同账号多角色自动同步好友列表。
- 支持跨账号、同服务器、同阵营角色同步好友。
- 添加/删除好友时自动同步，并显示变更的角色名。
- 可自动排除自己的小号、同步角色，节省好友栏位。
- 支持屏蔽名单同步。
- 插件信息和聊天提示已汉化。

## 安装

把 `FriendShare` 文件夹放到：

```text
World of Warcraft\Interface\AddOns\FriendShare
```

角色选择界面点击“插件”，启用“好友与屏蔽共享 NB优化版V1.1”。游戏已打开时，请 `/reload` 或重新登录。

## 快速开始

同账号角色无需配置，依次登录各角色即可自动合并好友数据。

跨账号同步需要两个角色同时在线，并互相添加为同步角色。例：`Nbpala` 和 `Nbmagedad`。

```text
# Nbpala 输入
/fs peer add nbmagedad

# Nbmagedad 输入
/fs peer add nbpala

# 任意一边检查
/fs peers

# 首次同步或补同步
/fs sync
```

之后两个同步角色同时在线时，添加/删除好友会自动同步；离线错过同步时，双方在线后再输入 `/fs sync`。

## 常用命令

```text
/fs help                 显示帮助
/fs peers                查看同步角色
/fs peer add 角色名      添加跨账号同步角色
/fs peer remove 角色名   移除跨账号同步角色
/fs sync                 与全部同步角色交换数据
/fs sync 角色名          与指定角色交换数据
/fs removealts           切换是否自动删除小号
/fs removealts on        开启自动删除小号
/fs removealts off       关闭自动删除小号
/fs import               手动导入已保存好友
/fs reset                用当前好友列表重置全局好友
```

屏蔽名单：

```text
/is help
/is import
/is reset
```

## 小号删除开关

默认会自动移除好友列表里的小号/同步角色。朋友希望保留自己的小号时，输入：

```text
/fs removealts off
```

想重新开启时输入：

```text
/fs removealts on
```

这个开关会同步给同账号角色和在线的跨账号同步角色；离线的跨账号角色之后可通过 `/fs sync` 同步到较新的状态。

## 注意事项

- 跨账号同步只支持同服务器、同阵营，并要求双方安装同版本插件。
- 首次跨账号同步前，双方都要执行一次 `/fs peer add 对方角色名`。
- WLK 3.3.5 好友列表有数量上限，满员时无法继续导入。
- `reset` 会覆盖当前服务器、当前阵营的全局好友记录，请谨慎使用。

## 作者信息

- 原作者：Vimrasha
- 优化版本：NB优化版V1.1
