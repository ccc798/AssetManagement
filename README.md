<<<<<<< HEAD

# Asset Management

声明：本项目使用reasonix+deepseek编写而成，项目图标使用豆包AI生产，如果有不符合代码规范或严重bug的地方，一定是本人对编码和reasonix使用不熟悉，并不代表reasonix和deepseek的真实水平。
本项目的创立之初只是没有找到好用的类似的软件，或者软件没有找到我，制作这个项目也只是为了个人使用，分享出来也只是给大家提供多一个选择。有意见可以提但是水平有限。

使用工具增加了trae，主要是reasonix不能很直观的看到代码本身，虽然也并不能看懂就是了。

> 个人资产管理系统 — 记录、追踪、分析每一笔资产的价值与成本
> Personal asset management system — track, analyze, and manage every item you own.

!\[Flutter]\(https\://img.shields.io/badge/Flutter-3.22+-blue)
!\[Platform]\(https\://img.shields.io/badge/Platform-Android%20|%20Windows%20|%20Linux%20|%20macOS%20|%20iOS-brightgreen)
!\[License]\(https\://img.shields.io/badge/License-GPLv3-blue)
!\[i18n]\(https\://img.shields.io/badge/i18n-zh%20|%20en-orange)

***

## 目录 / Table of Contents

- [功能特性 / Features](#功能特性--features)
- [截图预览 / Screenshots](#截图预览--screenshots)
- [项目结构 / Project Structure](#项目结构--project-structure)
- [快速开始 / Quick Start](#快速开始--quick-start)
- [多语言 / i18n](#多语言--i18n)
- [数据模型 / Data Model](#数据模型--data-model)
- [使用指南 / Usage Guide](#使用指南--usage-guide)
- [技术栈 / Tech Stack](#技术栈--tech-stack)
- [许可证 / License](#许可证--license)

***

## 功能特性 / Features

### 核心功能

| 功能             | 说明                               |
| -------------- | -------------------------------- |
| 🏷️ **物品管理**   | 手动添加或 AI 截图识别，记录名称、品牌、价格、购买日期、分类 |
| 💰 **日均成本**    | 自动计算每件物品从购买日至今的日均消耗              |
| 📅 **生命周期**    | 设置计划使用期限，自动追踪剩余价值和淘汰日期           |
| ⭐ **满意度评分**    | 5 星评分系统                          |
| 🛡️ **保修与保险**  | 可选的保修期限、到期日期、保险信息记录              |
| 📦 **归档/删除分离** | 归档隐藏，误删可恢复，支持彻底删除                |
| 📊 **统计分析**    | 总览仪表盘、分类占比、月度趋势图，支持范围和时间过滤       |
| 🔍 **全文搜索**    | 按名称、品牌、分类、备注搜索                   |
| 🏷️ **分类过滤**   | 12 个预设分类 + 自定义分类，按分类筛选物品列表       |

### AI 智能识别

- **截图识别** — 购物截图自动提取物品信息，支持一单多件逐件保存
- **AI 自动增强** — 添加后自动补充分类、标签和使用建议
- **连接检测** — 自动验证模型是否支持图片识别
- **兼容多供应商** — OpenAI / DeepSeek / 通义千问 / OneAPI 等通用接口

### 🎨 主题系统

- **明暗模式** — 浅色 / 深色 / 跟随系统
- **8 组配色** — 靛蓝（默认）、天蓝、青绿、翠绿、橙色、玫红、紫色、红色
- **实时预览** — 选择时即时生效，无需重启

### 🔒 数据安全

- **本地存储** — JSON 文件存储，不依赖云端，数据完全自主掌控
- **本地备份/恢复** — 备份到系统公开下载目录，可从本地文件恢复
- **WebDAV 远程备份** — 支持坚果云、Nextcloud 等，支持列表浏览和恢复
- **恢复策略** — 支持覆盖恢复或按 UUID 去重合并

### 📤 数据导出

- **CSV 导出** — UTF-8 BOM 格式，16 个字段，Excel/WPS 直接打开
- **多语言表头** — 表头语言跟随系统设置（中文/英文）
- **公开目录保存** — 保存到系统公开 Downloads 目录（非 Android/data/ 内部目录）

### 🌐 多语言 (i18n)

- 中文 / English
- 语言设置页自动列出所有可用语言
- 新语言只需添加一个 `.dart` 文件即可

### 🖥️ 多平台

Android · Windows · Linux · macOS · iOS

***

## 截图预览 / Screenshots

<img width="702" height="1248" alt="image" src="https://github.com/user-attachments/assets/c9ccef1a-ca25-4714-a9f5-dbacc7054687" />

***

## 项目结构 / Project Structure

```
asset_management/
├── lib/
│   ├── main.dart                          # 应用入口 + DB 初始化
│   ├── app.dart                           # MaterialApp 动态主题
│   │
│   ├── core/
│   │   ├── operations.dart                # ItemOp.archive / ItemOp.delete
│   │   ├── i18n/
│   │   │   ├── translations.dart          # t() 函数、语言检测、注册表
│   │   │   └── locales/
│   │   │       ├── zh.dart                # 中文翻译（305 键）
│   │   │       └── en.dart                # 英文翻译（305 键）
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # 版本号、预设分类、默认配置
│   │   │   └── app_colors.dart            # 调色板 + 颜色解析
│   │   ├── utils/
│   │   │   ├── csv_export.dart            # CSV 生成 + 公开目录导出
│   │   │   ├── date_utils.dart            # 日期格式化
│   │   │   └── money_utils.dart           # 金额格式化 + 日均类比
│   │   └── theme/
│   │       ├── app_theme.dart             # 主题工厂（seed → light/dark）
│   │       └── app_icons.dart             # CustomPainter 矢量图标
│   │
│   ├── data/
│   │   ├── models/
│   │   │   ├── asset_item.dart            # 资产物品模型（含计算属性）
│   │   │   ├── category.dart              # 分类模型
│   │   │   └── backup_config.dart         # AI/WebDAV/主题 配置模型
│   │   └── database/
│   │       ├── database_manager.dart      # JSON 文件数据库（单例）
│   │       ├── config_dao.dart            # 配置读写
│   │       ├── asset_dao.dart             # 物品数据访问
│   │       └── category_dao.dart          # 分类数据访问
│   │
│   ├── services/
│   │   ├── ai_service.dart                # AI 图片/文字识别 + 数据增强
│   │   ├── local_backup_service.dart      # 本地备份/恢复
│   │   └── webdav_service.dart            # WebDAV 备份/恢复
│   │
│   └── ui/
│       ├── providers/
│       │   ├── asset_provider.dart        # 物品列表/统计/版本号 providers
│       │   ├── category_provider.dart     # 分类 providers
│       │   ├── theme_provider.dart        # 主题模式 + 配色 providers
│       │   └── settings_provider.dart     # 配置 providers
│       ├── widgets/
│       │   ├── app_toast.dart             # 胶囊 Toast overlay
│       │   ├── asset_card.dart            # 物品卡片（滑动操作）
│       │   ├── category_chip.dart         # 分类 chip
│       │   └── empty_state.dart           # 空状态 + 加载状态
│       └── pages/
│           ├── home/
│           │   └── home_page.dart         # 首页：统计栏 + 分类过滤 + 搜索
│           ├── add_item/
│           │   └── add_item_page.dart     # 添加/编辑（支持 AI 批量）
│           ├── item_detail/
│           │   └── item_detail_page.dart  # 成本分析 + 生命周期
│           ├── statistics/
│           │   └── statistics_page.dart   # 统计 + 折线图
│           └── settings/
│               ├── settings_page.dart     # 设置入口
│               ├── backup_settings_page.dart
│               ├── webdav_settings_page.dart
│               ├── ai_settings_page.dart
│               ├── export_page.dart
│               ├── theme_settings_page.dart
│               ├── category_management_page.dart
│               └── language_settings_page.dart
│
├── android/
├── ios/
├── linux/
├── macos/
├── windows/
├── assets/icons/                          # 应用图标
├── test/                                  # 测试（.gitignore 排除）
├── version.txt                            # 版本号（自动管理）
├── pubspec.yaml                           # 依赖配置
├── build_all.ps1                          # 交互式多平台构建脚本
├── deploy_github.ps1                      # GitHub 部署脚本
├── .gitignore                             # Git 忽略规则
├── LICENSE                                # GPLv3
└── README.md
```

***

## 快速开始 / Quick Start

### 前置条件 / Prerequisites

- Flutter 3.22+ ([安装指南](https://docs.flutter.dev/get-started/install))
- 对应平台的构建工具链

### 运行 / Run

```bash
# 获取依赖
flutter pub get

# 运行（自动选择当前平台）
flutter run

# 调试模式（Android）
flutter run --debug
```

### 构建 / Build

交互式菜单：

```powershell
.\build_all.ps1
```

命令行模式：

```powershell
.\build_all.ps1 -Target android      # 仅 Android APK
.\build_all.ps1 -Target desktop      # 当前桌面平台
.\build_all.ps1 -Target all          # Android + 桌面
```

构建产物：

```
AssetManagement_vX.X.X.apk               # Android 安装包
AssetManagement_vX.X.X_win64.zip         # Windows 便携版
AssetManagement_vX.X.X_linux64.tar.gz    # Linux 包
AssetManagement_vX.X.X_macos.zip         # macOS 包
```

***

## 多语言 / i18n

系统默认支持 **中文** 和 **English**，语言设置自动跟随系统或手动选择。

### 添加新语言

只需 3 步：

1. **创建** **`lib/core/i18n/locales/ja.dart`：**

```dart
const Map<String, String> ja = <String, String>{
  'app.name': '資産管理',
  'home.title': 'ホーム',
  // ... 翻译所有 key
};
```

1. **在** **`translations.dart`** **注册：**

```dart
import 'locales/ja.dart';

final Map<String, Map<String, String>> _allLocales = {
  'zh': zh,
  'en': en,
  'ja': ja,   // ← 新增
};
```

1. **完成。** 语言设置页会自动列出新语言选项。

***

## 数据模型 / Data Model

### AssetItem

| 字段                    | 类型             | 说明              |
| --------------------- | -------------- | --------------- |
| `id`                  | `int`          | 自增 ID           |
| `uuid`                | `String`       | 全局唯一 ID（用于合并去重） |
| `name`                | `String`       | 物品名称            |
| `category`            | `String`       | 分类（预设或自定义）      |
| `brand`               | `String`       | 品牌              |
| `price`               | `double`       | 价格              |
| `purchaseDate`        | `DateTime?`    | 购买日期            |
| `plannedLifetimeDays` | `int`          | 计划使用天数（默认 365）  |
| `rating`              | `int`          | 满意度评分 1-5       |
| `notes`               | `String`       | 备注              |
| `tags`                | `List<String>` | 标签              |
| `warrantyPeriod`      | `String?`      | 保修期限            |
| `warrantyExpiry`      | `DateTime?`    | 保修到期            |
| `insuranceInfo`       | `String?`      | 保险信息            |
| `screenshotPath`      | `String`       | 截图文件路径          |
| `isArchived`          | `bool`         | 归档标记            |
| `isDeleted`           | `bool`         | 删除标记            |

**计算属性：**

| 属性                    | 类型          | 公式                                                       |
| --------------------- | ----------- | -------------------------------------------------------- |
| `daysUsed`            | `int`       | `DateTime.now() - purchaseDate`                          |
| `dailyCost`           | `double`    | `price / daysUsed`                                       |
| `remainingValueRatio` | `double`    | `(plannedLifetimeDays - daysUsed) / plannedLifetimeDays` |
| `estimatedEndDate`    | `DateTime?` | `purchaseDate + plannedLifetimeDays`                     |

***

## 使用指南 / Usage Guide

### 配置 AI

打开 **设置 → AI 智能识别**：

| 字段       | 推荐值                                 |
| -------- | ----------------------------------- |
| API 地址   | `https://api.openai.com/v1` 或其他兼容地址 |
| API Key  | 你的 API 密钥                           |
| 模型       | `gpt-4o-mini`（推荐，支持多模态）             |
| 最大 Token | 4096                                |

点击 **测试连接** 验证。截图识别在添加物品页使用。

### 备份与恢复

打开 **设置 → 备份与恢复**：

- **本地备份**：完整数据保存到系统公开 Downloads 目录
- **本地恢复**：选取备份文件，选择覆盖或合并
- **WebDAV**：配置远程服务器后手动备份、浏览和恢复

### CSV 导出

打开 **设置 → 导出数据**：

- 选择范围：全部 / 使用中 / 已归档
- 自动保存到系统公开 Downloads 目录
- 表头语言跟随系统语言设置
- UTF-8 BOM 格式，Excel/WPS 可直接打开

### 主题

打开 **设置 → 主题设置**：明暗模式 + 8 组配色方案，点击即时预览。

***

## 技术栈 / Tech Stack

| 技术             | 用途                   |
| -------------- | -------------------- |
| Flutter 3.22+  | 跨平台框架                |
| Riverpod 2.6   | 状态管理                 |
| Dio 5.4        | HTTP 客户端             |
| fl\_chart      | 统计图表                 |
| file\_picker   | 文件选择器                |
| path\_provider | 文件路径管理               |
| CustomPainter  | 自定义矢量图形              |
| xml            | WebDAV PROPFIND 响应解析 |

### 数据存储

| 数据     | 路径                                       | 说明             |
| ------ | ---------------------------------------- | -------------- |
| 物品数据   | `appDocDir/asset_management_data.json`   | 所有资产数据         |
| 配置数据   | `appDocDir/asset_management_config.json` | AI/WebDAV/主题配置 |
| 本地备份   | 公开 Downloads 目录                          | JSON 格式完整备份    |
| CSV 导出 | 公开 Downloads 目录                          | UTF-8 BOM CSV  |

***

## 许可证 / License

GNU General Public License v3.0

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# AssetManagement

> > > > > > > f5ef88f9cb9c068b6e446d784f4fd5945df8460b

