# Build Release 流程说明

本说明记录 `dart_simple_live` 本地 release 构建的标准流程，配套脚本为 `tools/build-release.ps1`。所有命令和文件读写都按 UTF-8 执行。

## 环境要求

- Flutter：`C:\softwares\flutter\bin\flutter.bat`
- NuGet：`C:\softwares\nuget\nuget.exe`
- Android SDK：`C:\softwares\Android_Sdk`
- GitHub CLI：`C:\softwares\GitHubCli\gh.exe`
- 代理兜底：`127.0.0.1:51888`

`C:\softwares\flutter\bin` 和 `C:\softwares\nuget` 需要在用户 PATH 中。若刚更新 PATH，建议重新打开终端后再构建。

## 常用命令

```powershell
# 主 App Windows
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Target Windows

# TV-Windows
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Target TVWindows

# 主 App 本地全量
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Target AllLocal
```

## Windows 构建流程

1. 执行 `flutter pub get`。
2. 检查并补齐 `media_kit_libs_windows_video` 的两个 Windows 原生依赖：
   - `mpv-dev-x86_64-20230924-git-652a1dd.7z`
   - `ANGLE.7z`
3. 对依赖包做 MD5 校验：
   - `mpv`：`a832ef24b3a6ff97cd2560b5b9d04cd8`
   - `ANGLE`：`e866f13e8d552348058afaafe869b1ed`
4. 执行 `flutter build windows --release`。
5. 从 `build\windows\x64\runner\Release` 或 `build\windows\x64\install` staging。
6. 如果 staging 中缺 `dart_quickjs.dll`，从 `.dart_tool\hooks_runner\shared\dart_quickjs\**\dart_quickjs.dll` 取最新副本补入。
7. 生成 zip，并校验关键文件。

## 必须校验的 Windows 文件

主 App Windows 包必须包含：

- `simple_live_app.exe`
- `flutter_windows.dll`
- `dart_quickjs.dll`
- `data\flutter_assets\AssetManifest.bin`
- `data\flutter_assets\NativeAssetsManifest.json`

TV-Windows 包必须包含：

- `simple_live_tv_app.exe`
- `flutter_windows.dll`
- `libmpv-2.dll`
- `dart_quickjs.dll`
- `data\app.so`
- `data\flutter_assets\AssetManifest.bin`
- `data\flutter_assets\NativeAssetsManifest.json`

## 常见问题

### NUGET-NOTFOUND

现象：`flutter_inappwebview_windows` 构建阶段报 `NUGET-NOTFOUND`。

处理：

1. 确认 `C:\softwares\nuget\nuget.exe` 存在。
2. 确认 `C:\softwares\nuget` 已在用户 PATH 中。
3. 删除对应项目下：
   - `build\windows\x64\CMakeCache.txt`
   - `build\windows\x64\CMakeFiles`
4. 重新执行 `flutter build windows --release` 或 release 脚本。

### mpv / ANGLE 依赖包校验失败

现象：CMake 报 `Integrity check failed`，或本地 `.7z` 为 0 字节。

处理：

1. 删除坏包。
2. 通过 `curl.exe --proxy socks5h://127.0.0.1:51888 -L` 重新下载。
3. 校验 MD5。
4. 重新构建。

`tools/build-release.ps1` 已内置这一步；如果仍失败，优先检查代理端口是否可用。

### dart_quickjs.dll 缺失

现象：运行时报 `JS_NewRuntime` 或 DLL load failure。

处理：

1. 检查最终 zip，而不是只检查 build 目录。
2. 确认 `dart_quickjs.dll` 在 zip 根目录。
3. 如缺失，从 `.dart_tool\hooks_runner\shared\dart_quickjs\**\dart_quickjs.dll` 复制最新副本。

## 发布目录

- 主 App：`C:\softwares\dart_simple_live\release\v<版本号>`
- TV：`C:\softwares\dart_simple_live\release\tv_v<版本号>`

完成构建后，必须记录并核对：

- 文件 `LastWriteTime`
- 文件大小
- SHA256
- `RELEASE_NOTES.md` UTF-8 回读无乱码
