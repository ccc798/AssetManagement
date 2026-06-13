# 归档正确设计方案

## 问题

`isDeleted` 被复用为归档标记，导致：
1. 已归档物品无法再删除（`softDelete` 设置 `isDeleted=true` 已是归档标记，再次调用无效果）
2. 归档和删除概念混淆
3. 被迫引入 `hardDelete()` 永久删除来绕过，但永久删除丢数据

## 方案

### 数据模型
`AssetItem` 增加独立字段 `isArchived`
- `isArchived = true` → 已归档（首页不显示，归档分类可见）
- `isDeleted = true` → 已删除（所有地方不显示）

### 查询变更

| 场景 | 过滤条件 |
|------|----------|
| 首页全部 / 使用中 | `!isDeleted && !isArchived` |
| 已归档分类 | `isArchived && !isDeleted` |
| 搜索 | `!isDeleted && !isArchived` |
| 统计-全部 | 不过滤 |
| 统计-使用中 | `!isDeleted && !isArchived` |
| 统计-已归档 | `isArchived && !isDeleted` |

### 操作变更

| 操作 | 修改字段 |
|------|----------|
| 归档按钮 | `isArchived = true` |
| 删除按钮（任何界面） | `isDeleted = true`（原有 `softDelete`） |

### 移除

- `hardDelete()` 方法（永久删除是错误方向）
