# 日记本 · date_write

Windows + Android 双端个人日记应用。数据全部存在本地，不联网、不上传。

---

## 打包与分发

产物都在 `dist/`：

| 文件 | 大小 | 说明 |
|---|---|---|
| `Diary-win-v1.0.0-setup.exe` | 19.5 MB | **Windows 安装程序**，推荐给自己和别人用 |
| `Diary-win-v1.0.0-portable.zip` | 23.9 MB | 便携版，解压即用，不写注册表 |
| `Diary-android-v1.0.0.apk` | 74.9 MB | Android 安装包 |

### Windows 安装程序

```powershell
flutter build windows --release          # 约 60 秒
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" tool\diary.iss
```

安装程序的特点：
- 装到 `%LOCALAPPDATA%\Programs\Diary`，**不需要管理员权限**，不弹 UAC
- 自动创建桌面和开始菜单快捷方式
- 自带卸载程序，卸载时**不会删除日记数据**（数据在 `%APPDATA%`，与安装目录分离）
- 向导文案已汉化（Inno 6.7.3 没附简体中文包，脚本里用 `[Messages]` 覆盖了主要文案）

### Android 签名

发布签名配置在 `android/key.properties` + `android/keystore/date_write.p12`。

> ⚠️ **这两样请务必备份到安全的地方。**
> keystore 是这个 app 的唯一身份，一旦发布，以后所有升级包都必须用同一个密钥签名；
> 换密钥系统会拒绝覆盖安装，只能卸载重装，日记会丢。

```powershell
flutter build apk --release
```

签名已验证：`CN=Diary`，SHA-256 `b1568a75...68ca11`（不是 debug key）。

### 换版本号

1. 改 `pubspec.yaml` 的 `version: 1.0.1+2`
2. 改 `tool/diary.iss` 顶部的 `#define AppVersion "1.0.1"`
3. 重新跑上面两条打包命令

---

## 环境

| 项 | 版本 / 路径 |
|---|---|
| Flutter SDK | 3.47.6 (stable)，装在 `C:\dev\flutter` |
| Dart | 3.13.5 |
| JDK | Temurin 17，`C:\dev\jdk` |
| Android SDK | `C:\dev\android-sdk`（platform-36 / build-tools 36.0.0） |
| Visual Studio | 生成工具 2022 17.14.41（MSVC 14.44 + Windows SDK 10.0.26100） |

`flutter`、JDK、Android SDK 都已加入用户 PATH，`JAVA_HOME` / `ANDROID_HOME` 也已写入用户环境变量。
新开一个终端即可直接用。

> **一个例外**：当前已经开着的终端/程序不会继承新写入的环境变量。
> 老终端里 `flutter doctor` 会误报 Android toolchain 为 ✗，重开一个终端即可。

## 运行

```powershell
# Windows 桌面
flutter run -d windows

# Android（需接上手机并开启 USB 调试）
flutter run -d android
```

## 打包

```powershell
flutter build windows --release     # build\windows\x64\runner\Release\  约 48MB
flutter build apk --release         # build\app\outputs\flutter-apk\app-release.apk
```

### Windows 打包的两个前置条件

1. **开发人员模式必须开启**。Flutter 在 Windows 上构建带原生插件的应用时要创建符号链接，
   没有这个权限会直接报 `Building with plugins requires symlink support`。
   开启方式：设置 → 系统 → 开发者选项 → 开发人员模式。
   注意 Windows PowerShell 的 `New-Item -ItemType SymbolicLink` 即使在开发人员模式下也会
   自查提权并失败，但 Win32 API 路径（`mklink`、Dart 的 `Link.create`）是正常的，不用担心。
2. Visual Studio 2022 的「使用 C++ 的桌面开发」工作负载。

### Android 构建踩过的坑

`android/gradle.properties` 里加了 `kotlin.incremental=false`。
原因是 Kotlin 增量编译缓存出现过损坏：

```
Could not close incremental caches in .../caches-jvm/jvm/kotlin
```

一旦触发就必须手动删掉 `build/` 才能恢复，关掉增量编译换取构建稳定性（代价是全量编译慢一点）。

---

## 功能

### 日记
- 时间线列表，按月份切换，月份可点击跳转到任意年月
- 新建 / 编辑 / 阅读；正文保留原始换行，词数实时统计
- **左滑删除 + 30 天回收站**，误删可恢复，也可在回收站里彻底删除
- 全文搜索（标题 + 正文 + 标签），搜索时跨全部月份
- 按标签筛选

### 元信息
- 心情 5 档（😞😕😐🙂😄）、天气 8 种、标签（逗号分隔，带历史标签快捷补全）
- **标签有颜色**：首次出现自动分配一个未被占用的暖色并持久化，同一标签在任何设备上颜色一致；
  可在「我的 → 标签管理」里改色、改名（改名会同步更新所有引用它的日记）、清理未使用标签
- `entry_date` 与 `created_at` 分离，支持补记往日和预写未来

### 正文
- **支持 Markdown**：阅读页按 Markdown 渲染，`#` 标题、`-` 列表、`>` 引用、`**加粗**` 都生效；
  完全不写语法也能正常显示为纯文本

### 导出（全部日记）
- **TXT** — 带 BOM，Windows 记事本直接正确显示中文
- **Word (.docx)** — 日期为标题层级，标签在文末
- **PDF** — A4，可选封面页 / 目录页，每篇单独起页，带页眉日期和页脚页码
- **JSON** — 整库备份，用于换机迁移
- 导出选项可控制是否输出心情 / 天气 / 标签

### 恢复备份
「我的 → 数据 → 从备份恢复」：

1. 选择之前导出的 JSON 文件
2. 先展示篇数与时间范围，确认无误
3. 选**合并**（只补充本地没有的日期）或**覆盖**（清空后写入，不可撤销）

解析层会校验 `app` 标识，非本应用的备份直接拒绝；单条记录缺 `entry_date` 会被跳过而不是让整份备份失败。

### 概览
「我的」页顶部卡片：总篇数、总字数、连续记录天数、记录天数。

### 外观
- 浅色 / 深色 / 跟随系统
- 正文字号缩放 85%–135%，设置页带实时预览

---

## 布局

窗口宽度自适应，无需手动切换：

| 宽度 | 布局 |
|---|---|
| < 1000px | 手机式：底部双 Tab + FAB，列表满屏 |
| ≥ 1000px | 桌面式：左侧导航栏 + 中间 340px 列表 + 右侧阅读区（选中即读，不跳页） |
| ≥ 1320px | 导航栏展开为带文字 |

---

## 工程结构

```
lib/
├── main.dart                  # 启动：加载设置 → 清理过期回收站 → 跑 App
├── core/
│   ├── cn_date.dart           # 中文日期格式化（刻意不引 intl）
│   └── theme.dart            # 纸感暖白主题 + 深色模式
├── data/
│   ├── db.dart                # 数据库入口，Android/Windows 双端适配，schema v2
│   ├── entry_repo.dart        # 增删改查 + 备份导入 + 概览聚合
│   ├── tag_repo.dart          # 标签与颜色分配
│   ├── tag_scope.dart         # 标签配色注入 widget 树
│   ├── app_settings.dart      # 设置（存在数据库 app_setting 表）
│   └── models/entry.dart      # Entry 模型 + 心情/天气取值
├── features/
│   ├── home_page.dart         # 主壳：窄屏 Tab / 宽屏双栏
│   ├── diary/                 # 列表 · 编辑 · 阅读 · 回收站 · 总览
│   └── settings/              # 我的 · 标签管理 · 导出 · 恢复
├── services/
│   ├── export_service.dart    # txt / docx / pdf / json 生成
│   └── backup_service.dart    # 备份文件解析与校验
└── widgets/entry_tile.dart    # 时间线条目 + 空状态
```

### 双端数据库适配

`lib/data/db.dart` 统一了两端差异，UI 层完全无感知：

| 平台 | 实现 | 数据库位置 |
|---|---|---|
| Android | `sqflite`（系统 SQLite） | 应用私有目录 |
| Windows | `sqflite_common_ffi`（进程内 SQLite） | `%APPDATA%\com.datewrite\date_write\` |

> **注意**：`sqflite_common_ffi` 的默认路径是**当前工作目录**下的 `.dart_tool/`，
> 对打包后的桌面应用来说这意味着「换个目录启动 exe 就看不到日记」。
> 所以桌面端这里显式指定了应用支持目录，不依赖启动时的 CWD。

**换机请走 JSON 备份/恢复，不要直接拷数据库文件。**

---

## 两个关键实现细节

### 1. PDF 中文必须内嵌字体

PDF 标准 14 字体不含中文字形，不内嵌字体导出来是一片方框。
本项目把字体打进 `assets/fonts/NotoSansSC-Regular.ttf`，在 `export_service.dart` 里通过
`pw.Font.ttf()` 加载，并在 `ThemeData.withFont()` 中把 base/bold/italic 全部指向同一份字体。

字体用的是**霞鹜文楷**（楷体风格，很适合日记）。原始文件 23.6MB，已用 fonttools 裁剪到 **15.77MB**：

```powershell
py -m fontTools.subset assets\fonts\NotoSansSC-Regular.ttf `
  --unicodes="U+0020-007E,U+00A0-00FF,U+2000-206F,U+2190-21FF,U+2460-24FF,U+25A0-25FF,U+2600-27BF,U+3000-303F,U+3400-4DBF,U+4E00-9FFF,U+FF00-FFEF" `
  --layout-features="*" --output-file=out.ttf
```

裁剪前确认过原字体覆盖全部 **20992** 个常用汉字和 **6592** 个扩展 A 字，所以汉字**不会缺字**。
如果还嫌大，去掉 `U+3400-4DBF`（扩展 A，生僻字）能再省约 4MB。

### 2. `docx` 包已下架，Word 导出改用 `docx_creator`

原方案里的 `docx` 包在 pub.dev 上已 404（被同名后继包取代），
实际用的是 `docx_creator ^1.4.0`，API 是 fluent builder：

```dart
DocxDocumentBuilder()
  ..h1('我的日记')
  ..h2('2026年10月6日　星期一')
  ..p('正文…')
  ..hr();
DocxExporter().exportToBytes(builder.build());
```

---

## 已知取舍

- **PDF 页脚只显示「第 N 页」**：pdf 包的 `context.pagesCount` 是「已生成页数」，
  边生成边显示总数会得到错误的 "1/1"，所以不显示总页数。
- **每篇日记一个 `MultiPage`**：pdf 3.x 移除了 `PageBreak`，
  改用「一篇一个 MultiPage」实现单独起页，单篇超过一页时它内部自己会续页。
  顺带一提，pdf 包写文件时还会把内嵌字体二次裁剪成只含实际用到的字形，
  所以导出的 PDF 只有几十 KB，不会因为 App 打包了 15MB 字体就产出巨型 PDF。
- **正文宽度上限 42 汉字**：超过后阅读时换行回扫会很难受。
- **搜索用 `LIKE` 而非 FTS5**：日记量级 <10 万条，`LIKE` 足够，省掉一个依赖和跨端兼容坑。
- **Android 未签名**：`flutter build apk --release` 目前出的是 debug 签名包，
  自用直接安装没问题；若要长期保留，务必固定用同一个 keystore 签名，
  否则换了签名系统会拒绝覆盖安装。

## 测试

```powershell
flutter analyze   # No issues found
flutter test      # 14 tests passed
```

导出测试会真正跑一遍三种格式的生成，验证 TXT 的 BOM 字节头、DOCX 的 ZIP 魔数、
PDF 的 `%PDF-` 头和 `FontFile` 流（字体有没有真的内嵌进去）。
这样「中文 PDF 显示方框」这类问题会在测试阶段就被拦下，而不是等导出时才发现。