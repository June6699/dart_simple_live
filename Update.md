# Update Log

## 2026-05-10 22:35 Asia/Shanghai

### 本次已处理

- 按 issue #9 的预更新方向处理了抖音直播间打开失败相关防护：`444` 返回可读提示、HTML/数据结构保护、抖音请求节流，以及直播间快速重复进入防抖。
- 直播间关闭/切房时补充了播放器停止、弹幕定时器清理、贡献榜状态清理和已关闭页面的失效判断，降低退出后继续拉流或继续播放的概率。
- `SC` 显示默认值改为关闭。
- 弹幕屏蔽新增关键词编辑、用户编辑、分平台屏蔽用户、屏蔽预设导入/导出。
- 新增旧版本外部导出工具：
  - `tools/export_legacy_settings.ps1`
  - `simple_live_app/tool/export_legacy_settings.dart`
  - 本地 release 目录内另附 `export_legacy_settings_windows.exe`
- 导出内容包括：
  - `LocalStorage` 全量设置参数；
  - 当前屏蔽词；
  - 当前屏蔽用户，并按平台分组；
  - 屏蔽预设；
  - 关注列表；
  - 关注标签；
  - 历史记录。
- GitHub Actions 改为按需构建：
  - `publish_app_dev.yaml` 的 `dev_v*` tag 自动触发时，只默认跑 iOS/macOS；
  - Android/Windows/Linux/TV release workflow 去掉 tag push 自动构建，改为 `workflow_dispatch` 手动勾选；
  - 新增 `publish_app_release_ios_manual.yml`，用于手动构建 iOS unsigned IPA；
  - Android/Windows/Linux/TV 手动 workflow 均带 `ref` 与 `upload_release`，需要 GitHub 构建时再勾选并选择 tag/分支。
- 本地 release 新目录：
  - `release/v1.12.0-issue9-local-20260510`
  - 未覆盖旧 `release/v1.12.0` 和 `release/tv_v1.7.1`。
  - 已删除临时备份 `release - 副本`。

### 本次验证

- `dart analyze tool/export_legacy_settings.dart` 通过。
- `flutter analyze` 主 App 通过。
- `flutter analyze` TV App 通过。
- `tools/export_legacy_settings.ps1` 已用本机数据目录导出 JSON，通过。
- `release/.../tools/export_legacy_settings_windows.exe` 已用本机数据目录导出 JSON，通过。
- 已确认本地构建产物存在并复制到新 release 目录：
  - Windows: `windows-x64/Release/simple_live_app.exe`
  - Android: `android/simple_live_app-1.12.0+11200-issue9-local-20260510.apk`
  - Linux: `linux-x64/bundle/simple_live_app`
  - Android TV: `android-tv/SimpleLive-TV-*-issue9-local-20260510.apk`

### 下一步待修

- 自动化测试债务：`simple_live_app` 默认 widget test 仍需要补 GetX/服务初始化；`simple_live_core` 直播 API 测试依赖真实平台接口，后续要分离为 mock/集成测试。
- 自省：本轮优先做了迁移保护和发版流程止损，贡献榜和 Windows 全屏属于可复现性更强的下一批修复；后续每次构建前应固定新 release 子目录名，避免任何旧版本目录被覆盖。

## 2026-05-11 00:20 Asia/Shanghai

### 本次已处理

- 修复直播间右侧 `关注列表` 筛选后自动跳回 `全部`：筛选状态从构建函数局部变量挪到 `LiveRoomController`，避免关注列表刷新或弹窗重建时重置。
- 再次处理 Windows 最大化后双击全屏显示异常：进入全屏前只做最大化状态恢复和等待，不再在进入全屏路径里做窗口尺寸微调，避免全屏后被后续窗口 bounds 消息拉偏。
- 修复抖音贡献榜排名全为 `1` 的兜底逻辑：抖音接口返回的 `rank` 如果异常重复为 `1`，使用列表顺序生成展示名次。B 站、斗鱼贡献榜仍使用各自接口字段；虎牙当前未实现贡献榜。
- B4 弹幕行数自适应继续补强：引入本地 `canvas_danmaku` patch，给 `DanmakuOption` 增加 `lineHeight`，弹幕轨道高度随显示区域和用户设置动态计算，并在主 App 的有效区域与实际行数计算里使用同一套行距公式。
- 预发布迁移文档新增到 `docs/pre-release-update-and-sync.md`，说明旧版本导出脚本、WebDAV 同步和微力同步 / VerySync 迁移目录的推荐用法。
- GitHub Actions 继续改为按需构建：Android/Windows/Linux/TV release workflow 使用 `workflow_dispatch` 勾选；iOS/macOS 保留手动入口；release 上传显式指定 `tag_name`，避免手动 workflow 上传到错误 ref。

### 本次准备发布

- 本地新 release 目录固定为 `release/v1.12.0-issue9-local-20260510-next`。
- 主应用预发布 tag：`v1.12.0-issue9-local-20260510-next`。
- TV 预发布 tag：`tv_v1.7.1-issue9-local-20260510-next`。
- release 说明只写本次修复和更新前迁移教程，不写下一步 TODO。

### 本次验证

- `dart analyze tool/export_legacy_settings.dart` 通过。
- `flutter analyze` 主 App 通过。
- `flutter analyze` TV App 通过。
- Windows release 构建通过：`build/windows/x64/runner/Release/simple_live_app.exe`。
- Android release APK 构建通过：`build/app/outputs/flutter-apk/app-release.apk`。构建链因 `screen_brightness_android 2.1.4` 拉取 Kotlin 2.3 元数据，已同步升级主 App Android Kotlin 插件到 `2.3.21` 并改用新的 `compilerOptions` DSL。
- Android TV release split APK 构建通过：`armeabi-v7a / arm64-v8a / x86_64`。
- Linux WSL 原生目录构建通过，生成 `deb` 与 `zip`，并复制回 release 目录。
- `export_legacy_settings_windows.exe` 已用本机数据目录导出 JSON 通过；测试输出只用于本机验证，不进入 release。

### 后续待修

- 自动化测试债务：`simple_live_app` 默认 widget test 仍需要补 GetX/服务初始化；`simple_live_core` 直播 API 测试依赖真实平台接口，后续要分离为 mock/集成测试。
- 自省：本轮 Windows 全屏修复是基于窗口状态逻辑的二次收紧，仍建议用户在真实 Windows 最大化场景再复测；若仍异常，下一步应加 Windows 专用全屏状态探针，记录 `isMaximized/isFullScreen/bounds/titlebar` 的时间序列。
