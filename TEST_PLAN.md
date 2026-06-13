# AssetManagement 测试计划

## 一、测试策略

### 1.1 测试金字塔
```
        ┌─────────────┐
        │   E2E 测试   │  ← 少量核心流程
        ├─────────────┤
        │  集成测试   │  ← 关键业务流程
        ├─────────────┤
        │  Widget 测试 │  ← UI 组件
        ├─────────────┤
        │  单元测试   │  ← 核心逻辑（DAO、Service）
        └─────────────┘
```

### 1.2 测试覆盖率目标

| 模块 | 目标覆盖率 | 优先级 |
|-----|----------|-------|
| DatabaseManager | 80%+ | P0 |
| AssetDao | 80%+ | P0 |
| AiService | 70%+ | P1 |
| WebDavService | 70%+ | P1 |
| Repository | 80%+ | P1 |
| Widget 组件 | 60%+ | P2 |

## 二、测试用例清单

### 2.1 DatabaseManager 单元测试

| 测试用例 | 描述 | 预期结果 |
|---------|------|---------|
| `test_init_loads_existing_data` | 初始化时加载已有数据 | 数据正确加载 |
| `test_init_creates_new_file_if_not_exists` | 文件不存在时创建新文件 | 新文件创建成功 |
| `test_getAll_filters_deleted_items` | getAll 正确过滤已删除项 | 只返回未删除项 |
| `test_getAll_includeDeleted` | includeDeleted=true 时返回全部 | 包含已删除项 |
| `test_getPaged_returns_correct_page` | 分页返回正确页面数据 | 数据与页码匹配 |
| `test_getPaged_returns_empty_for_invalid_page` | 无效页码返回空列表 | 返回空列表 |
| `test_getCount_returns_correct_number` | 计数返回正确数量 | 数量准确 |
| `test_add_increments_id` | 添加物品后 ID 自增 | ID 正确递增 |
| `test_update_modifies_item` | 更新物品信息 | 修改生效 |
| `test_softDelete_sets_isDeleted_flag` | 软删除设置标志 | 标志正确设置 |
| `test_search_finds_matching_items` | 搜索找到匹配项 | 返回正确结果 |
| `test_getByCategory_filters_correctly` | 按分类过滤 | 只返回该分类 |
| `test_statistics_calculates_correctly` | 统计计算正确 | 统计数据准确 |

### 2.2 AssetDao 单元测试

| 测试用例 | 描述 |
|---------|------|
| `test_getAll_delegates_to_database_manager` | 正确委托给 DatabaseManager |
| `test_add_creates_item_with_id` | 添加并返回带 ID 的物品 |
| `test_update_modifies_existing_item` | 更新现有物品 |
| `test_softDelete_calls_database_manager` | 正确调用软删除 |

### 2.3 AiService 单元测试

| 测试用例 | 描述 |
|---------|------|
| `test_normalize_base_url_handles_common_cases` | URL 标准化处理常见情况 |
| `test_build_url_appends_v1_if_missing` | 缺少 v1 时自动添加 |
| `test_extract_json_from_plain_text` | 从纯文本提取 JSON |
| `test_extract_json_from_code_block` | 从代码块提取 JSON |
| `test_recognition_cache_hits` | 缓存命中时跳过 API 调用 |
| `test_recognition_cache_misses` | 缓存未命中时调用 API |
| `test_cache_clears_on_demand` | 支持手动清除缓存 |

### 2.4 WebDavService 单元测试

| 测试用例 | 描述 |
|---------|------|
| `test_auth_dio_adds_basic_auth` | 正确添加 Basic 认证 |
| `test_file_url_handles_path_correctly` | 文件路径处理正确 |
| `test_try_propfind_returns_null_on_success` | 成功时返回 null |
| `test_try_propfind_returns_error_on_401` | 401 时返回认证错误 |
| `test_handle_options_response_parses_correctly` | OPTIONS 响应解析正确 |

### 2.5 Widget 测试

| 测试用例 | 描述 |
|---------|------|
| `test_category_selector_renders_all_categories` | 渲染所有分类 |
| `test_category_selector_calls_onSelected` | 选择时触发回调 |
| `test_lifetime_selector_shows_presets` | 显示预设选项 |
| `test_rating_selector_displays_correct_stars` | 显示正确数量星星 |
| `test_warranty_section_expands_on_tap` | 点击展开保修区域 |

## 三、执行计划

### Phase 1: 单元测试（2-3天）
1. DatabaseManager 测试
2. AssetDao 测试
3. AiService 测试
4. WebDavService 测试

### Phase 2: Widget 测试（1-2天）
1. AddItemPage 子组件测试
2. 表单组件测试

### Phase 3: 集成测试（1天）
1. 数据流程测试
2. 备份恢复流程测试

## 四、测试环境要求

- Flutter SDK: >=3.2.0
- Dart SDK: >=3.2.0
- 必需依赖: flutter_test, mockito, build_runner

## 五、成功标准

- 所有 P0 测试用例通过
- 测试覆盖率达标
- 无 regression（回归）问题