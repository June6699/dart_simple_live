# 预发布更新与数据同步说明

适用于 `v1.12.0-issue9-local-20260510-next` 及之后的预发布版本。

## 更新前先做备份

同平台更新时，Simple Live 通常会继续读取原来的本地数据目录，所以 Windows 覆盖升级后还能看到上一版设置是正常的。跨平台、跨版本或卸载重装时，仍建议先导出一份 JSON 备份。

Windows 用户可以在仓库目录运行：

```powershell
cd C:\softwares\dart_simple_live
.\tools\export_legacy_settings.ps1
```

如果自动找不到数据目录，手动指定：

```powershell
.\tools\export_legacy_settings.ps1 -DataDir "$env:APPDATA\com.xycz\simple_live_app" -OutFile "$env:USERPROFILE\Desktop\simple-live-settings.json"
```

release 包里也会放一个不依赖 Dart 环境的可执行文件：

```powershell
.\tools\export_legacy_settings_windows.exe --data-dir "%APPDATA%\com.xycz\simple_live_app" --out "%USERPROFILE%\Desktop\simple-live-settings.json"
```

导出的 JSON 包含设置参数、关注列表、关注标签、历史记录、屏蔽词、分平台屏蔽用户和屏蔽预设。当前版本已经支持应用内 WebDAV/局域网同步以及屏蔽预设导入导出；完整 JSON 主要作为升级前的离线备份和后续迁移依据。

## 推荐同步方案

### 方案 A：应用内 WebDAV 同步

1. 打开 Simple Live。
2. 进入 `我的` -> `数据同步` -> `WebDAV同步`。
3. 填入 WebDAV 地址、账号和密码。
4. 先在旧设备点上传，再在新设备点恢复。

这条路最适合关注、历史、屏蔽词、B 站账号和应用设置的日常跨设备同步。

### 方案 B：微力同步 / VerySync 保存迁移包

1. 在 Windows、Android、Linux 或 TV 设备上安装并注册微力同步 / VerySync。
2. 建一个同步目录，例如 `SimpleLiveSync`。
3. 更新前运行导出脚本，把 `simple-live-settings-*.json` 放进这个目录。
4. 把 release 包、导出 JSON、自己的补充说明都放在同一个同步目录里。
5. 新设备更新后，优先用应用内 WebDAV/局域网同步恢复；屏蔽预设可以在弹幕屏蔽设置里导入；完整 JSON 留作对照和后续迁移备份。

TV 端如果没有专门的 VerySync TV 版，可先使用 Android 版客户端或通过同一局域网从手机/电脑转入安装包。
