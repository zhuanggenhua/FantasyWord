# MiniFantasy UV 迁移证据

## 现实含义

本目录保存的是 MiniFantasy UV / 装备换装链路迁移时产生的证据文件，用来追溯资源 GUID、来源路径、缺失项和历史构建日志。

这些文件不是框架本体，也不等于“临时系统”。当前框架候选仍在：

- `Assets/Scripts/test/EquipmentSystem`
- `Assets/GameData/EquipmentSystem`
- `Assets/ThirdParty/MiniFantasyUV`

## 文件说明

- `uv_guid_source_map.csv`：迁移时用来把 GUID 映射回来源资源路径的索引。
- `uv_data_guids.txt`：当时记录的数据资源 GUID 集合。
- `uv_missing_guids.txt`：当时记录的缺失 GUID 集合。
- `mini-fantasy-uv-create-scene-current.log`：历史场景构建尝试日志。

## 使用边界

- 需要追溯 MiniFantasy UV 资源来源、GUID 对齐或历史缺失项时读取。
- 不把这些文件当成当前任务入口。
- 不因它们位于归档目录就否定 `Assets/Scripts/test/EquipmentSystem` 的当前价值；框架是否进入正式链路要另行审查代码、资源引用和新游戏定位。
