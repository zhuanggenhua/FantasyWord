# 旧 RPG 资产归档

## 归档原因

本目录保存从当前 Unity 导入入口移出的旧 RPG 数据库和 Prefab 资产。

静态脚本 GUID 对照显示，原 `Assets/Database` 与 `Assets/Prefabs` 中大量资产引用的项目侧脚本已经不存在：当前检查到 99 类脚本引用，其中 97 类没有对应脚本 `.meta`。这些资产不适合继续放在 `Assets` 正式导入目录里作为新游戏链路的一部分。

## 当前状态

- 原路径：`Assets/Database`
- 原路径：`Assets/Prefabs`
- 当前归档路径：`docs/archive/legacy-rpg-assets/Assets/Database`
- 当前归档路径：`docs/archive/legacy-rpg-assets/Assets/Prefabs`

文件和 `.meta` 已保留，用于后续追溯旧系统结构、UI 组织、数据命名或资源来源；这不是删除，也不是判定这些内容没有参考价值。

## 重启条件

只有当某个旧 RPG 模块被重新纳入当前俯视角开放世界正式范围时，才从本目录按模块恢复，并先补齐：

- 参考面和排除项。
- 依赖脚本或替代实现。
- 数据迁移规则。
- Unity 导入和编译验证。
- 当前项目正式目录落点。
