# Build Release 流程说明

本文档记录 `dart_simple_live` 本地 release 构建、手工替换、打包校验和常见故障处理流程。所有命令、文件读写、日志和说明均使用 UTF-8。

## 基本原则

- 对外 `release\<tag>\RELEASE_NOTES.md` 写用户可读的发布说明，风格参考 `release\v1.12.6\RELEASE_NOTES.md`；不要写本地构建时间、路径、SHA256、打包过程或排错记录。
- 本地构建记录、哈希、踩坑和排错过程写入项目经验、构建日志或私有追踪文件，不写入对外 release notes。
- 修改会影响包内容的源码、runner、资源或依赖后，必须重新构建对应平台 release；不要用旧 debug 产物覆盖正式 release。
- 替换 release 目录后必须同时校验解压目录和 zip。只更新 `dart_quickjs.dll` 或 manifest 不能证明 exe 已更新。
- Windows 构建可能长时间停在 `Building Windows application...`；只要 `cmake.exe` / `cl.exe` / `link.exe` 等仍在工作，就继续等待，不要误判卡死。
- PowerShell 涉及递归删除或覆盖前，先解析绝对路径并确认目标在 `C:\softwares\dart_simple_live` 内。

## 环境要求

- Flutter：`C:\softwares\flutter\bin\flutter.bat`
- NuGet：`C:\softwares\nuget\nuget.exe`
- Android SDK：`C:\softwares\Android_Sdk`
- GitHub CLI：`C:\softwares\GitHubCli\gh.exe`
- 代理兜底：`127.0.0.1:51888`

`C:\softwares\flutter\bin` 和 `C:\softwares\nuget` 需要在用户 PATH 中。若刚更新 PATH，重新打开终端后再构建。

## 常用命令

```powershell
# 主 App Windows
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Target Windows

# TV-Windows
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Target TVWindows

# 主 App 本地全量
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Target AllLocal

# 手工构建主 App Windows release
cd C:\softwares\dart_simple_live\simple_live_app
flutter build windows --release
```

## 发布目录

- 主 App：`C:\softwares\dart_simple_live\release\v<版本号>`
- TV：`C:\softwares\dart_simple_live\release\tv_v<版本号>`
- 主 App Windows 解压目录：`release\v<版本号>\SimpleLive-Windows-v<版本号>`
- 主 App Windows zip：`release\v<版本号>\SimpleLive-Windows-v<版本号>.zip`
- TV-Windows 解压目录：`release\tv_v<版本号>\SimpleLive-TV-Windows-v<版本号>`
- TV-Windows zip：`release\tv_v<版本号>\SimpleLive-TV-Windows-v<版本号>.zip`

临时 combined staging 目录只能作为中转。最终产物必须复制到对应正式目录，不能把最终包留在临时目录。

## Windows 构建流程

1. 在对应项目目录执行 `flutter pub get`。
2. 检查并补齐 `media_kit_libs_windows_video` 的两个 Windows 原生依赖：
   - `mpv-dev-x86_64-20230924-git-652a1dd.7z`
   - `ANGLE.7z`
3. 对依赖包做 MD5 校验：
   - `mpv`：`a832ef24b3a6ff97cd2560b5b9d04cd8`
   - `ANGLE`：`e866f13e8d552348058afaafe869b1ed`
4. 执行 `flutter build windows --release`。
5. 从 `build\windows\x64\runner\Release` 或脚本生成的 staging 目录取最终文件。
6. 如果 staging 中缺 `dart_quickjs.dll`，优先从 `build\native_assets\windows\dart_quickjs.dll` 补入；如果该目录为空，再从 `.dart_tool\hooks_runner\shared\dart_quickjs\**\dart_quickjs.dll` 取最新副本。
7. 生成 zip，并校验关键文件、文件数量、大小、时间戳和 SHA256。

## 手工替换 Windows release 目录

手工替换适用于已完成 `flutter build windows --release`，只需要把新产物覆盖进现有 release 目录的情况。不要使用 debug 构建目录。

```powershell
$workspace = [System.IO.Path]::GetFullPath('C:\softwares\dart_simple_live')
$src = [System.IO.Path]::GetFullPath('C:\softwares\dart_simple_live\simple_live_app\build\windows\x64\runner\Release')
$dst = [System.IO.Path]::GetFullPath('C:\softwares\dart_simple_live\release\v<版本号>\SimpleLive-Windows-v<版本号>')
$zip = [System.IO.Path]::GetFullPath('C:\softwares\dart_simple_live\release\v<版本号>\SimpleLive-Windows-v<版本号>.zip')
$quickjs = [System.IO.Path]::GetFullPath('C:\softwares\dart_simple_live\simple_live_app\build\native_assets\windows\dart_quickjs.dll')

foreach ($path in @($src, $dst, $zip, $quickjs)) {
  if (-not $path.StartsWith($workspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path outside workspace: $path"
  }
}

if (Test-Path -LiteralPath $dst) {
  Remove-Item -LiteralPath $dst -Recurse -Force
}
New-Item -ItemType Directory -Path $dst -Force | Out-Null

Get-ChildItem -LiteralPath $src -Force |
  Copy-Item -Destination $dst -Recurse -Force

if (Test-Path -LiteralPath $quickjs) {
  Copy-Item -LiteralPath $quickjs -Destination $dst -Force
}

foreach ($required in @('simple_live_app.exe', 'dart_quickjs.dll', 'data\flutter_assets\NativeAssetsManifest.json')) {
  $path = Join-Path $dst $required
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing after copy: $path"
  }
}

if (Test-Path -LiteralPath $zip) {
  Remove-Item -LiteralPath $zip -Force
}
Compress-Archive -LiteralPath $dst -DestinationPath $zip -Force
```

PowerShell 复制注意事项：

- 不要用 `Copy-Item -LiteralPath (Join-Path $src '*')` 复制目录内容；`-LiteralPath` 不展开 `*`，容易生成只有少量文件的坏包。
- 可用 `Get-ChildItem -LiteralPath $src -Force | Copy-Item ...`，或在确实需要通配符时使用 `-Path` 而不是 `-LiteralPath`。
- 压缩后如果 zip 只有几百 KB，而预期约几十 MB，应立即视为坏包并重新复制/压缩。

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

完成构建或手工替换后，必须记录并核对：

- 解压目录 `LastWriteTime`
- zip `LastWriteTime`
- 关键文件 `Length`
- 关键文件 SHA256
- zip SHA256
- zip 内关键文件是否存在
- `RELEASE_NOTES.md` UTF-8 回读无乱码

示例校验命令：

```powershell
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression.FileSystem

$releaseRoot = 'C:\softwares\dart_simple_live\release\v<版本号>'
$dir = Join-Path $releaseRoot 'SimpleLive-Windows-v<版本号>'
$zip = Join-Path $releaseRoot 'SimpleLive-Windows-v<版本号>.zip'
$required = @('simple_live_app.exe', 'dart_quickjs.dll', 'data\flutter_assets\NativeAssetsManifest.json')

foreach ($file in $required) {
  $path = Join-Path $dir $file
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing file: $path"
  }
  Get-Item -LiteralPath $path | Select-Object FullName, Length, LastWriteTime
  Get-FileHash -Algorithm SHA256 -LiteralPath $path
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
  $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
  foreach ($name in @('simple_live_app.exe', 'dart_quickjs.dll', 'NativeAssetsManifest.json')) {
    $matches = $entryNames | Where-Object { $_ -like "*$name" }
    if (!$matches) {
      throw "Missing zip entry matching: $name"
    }
    $matches
  }
  $archive.Entries.Count
}
finally {
  $archive.Dispose()
}

Get-Item -LiteralPath $zip | Select-Object FullName, Length, LastWriteTime
Get-FileHash -Algorithm SHA256 -LiteralPath $zip
Get-Content -LiteralPath (Join-Path $releaseRoot 'RELEASE_NOTES.md') -Encoding UTF8 | Select-Object -First 20
```

## Android 构建与校验

- 主 App Android 使用 `tools/build-release.ps1 -Target Android` 或 `AllLocal` 生成 ABI 拆分包。
- Android APK 要包含对应 ABI 的 `libdart_quickjs.so`。
- 如果 split ABI 构建报 `Duplicate resources`，检查 `build/native_assets/android/jniLibs` 与 `android/app/build/generated/dart_quickjs/jniLibs` 是否重复注入同一 ABI。
- 失败后不要直接清空全部上下文；保留日志，优先看 `release\<tag>\logs` 中对应 target 的 log。

## Linux 构建与校验

- Linux 本地构建优先使用 WSL Flutter：`/root/tools/flutter_3.38.10/bin/flutter`。
- 如 `mimalloc-2.1.2.tar.gz` 校验失败，删除 0 字节坏包后走 `127.0.0.1:51888` 代理补包。
- `mimalloc-2.1.2.tar.gz` MD5 必须是 `5179c8f5cf1237d2300e2d8559a7bc55`。
- 如果 `flutter_distributor` 在 `/mnt/c` 打 deb 遇到 777 权限或 bundle 路径问题，可先用 Flutter 生成 `build/linux/x64/release/bundle`，再手工打 zip/deb。
- deb 的 `DEBIAN` 目录权限必须在 0755 到 0775 之间。

## macOS / iOS 构建与校验

- macOS / iOS 走 GitHub Actions 手动 workflow。
- 推送包含 release 修复的临时分支后，触发：
  - `publish_app_release_macos_manual.yml`
  - `publish_app_release_ios_manual.yml`
- 参数使用 `upload_release=false`，下载 artifact 后复制到主 App release 根目录。
- 不要在没有 June 明确要求时自动上传 GitHub Release 或删除远端 release assets。

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
2. 确认 `dart_quickjs.dll` 在 zip 根目录或应用解压目录根目录。
3. 如缺失，先查 `build\native_assets\windows\dart_quickjs.dll`，再查 `.dart_tool\hooks_runner\shared\dart_quickjs\**\dart_quickjs.dll`。
4. 补齐后重新生成 zip，并重新校验 zip 内关键文件。

### Windows 构建长时间无输出

现象：`flutter build windows --release` 输出停在 `Building Windows application...`，几分钟内没有新日志。

处理：

1. 不要只凭终端无输出判断卡死。Windows Release 编译可能在 C++ 阶段长时间静默。
2. 用进程确认是否还在编译，重点看 `flutter.bat`、`dart.exe`、`cmake.exe`、`cl.exe`、`link.exe` 是否仍在运行。
3. 如果能看到 `cmake.exe` / `cl.exe` 仍在当前项目的 `build\windows\x64` 下工作，继续等待。
4. 只有进程消失、日志报错，或同一个编译进程长时间无 CPU/IO 活动时，才按失败处理。

示例检查命令：

```powershell
Get-CimInstance Win32_Process |
  Where-Object {
    $_.CommandLine -like '*dart_simple_live*' -or
    $_.CommandLine -like '*flutter*build windows*' -or
    $_.CommandLine -like '*cmake*' -or
    $_.CommandLine -like '*cl.exe*' -or
    $_.CommandLine -like '*link.exe*'
  } |
  Select-Object ProcessId, Name, CommandLine |
  Format-List
```

### 产物时间戳与 zip 路径误判

现象：构建后 release 目录仍显示旧 zip，或手工校验 zip 时关键文件显示 `MISSING`。

处理：

1. 构建脚本结束前，release 目录里的 zip 可能仍是旧包；必须等脚本打印构建完成或手工命令退出码为 0 后再认定最终产物。
2. 构建结束后核对 `LastWriteTime`。如果 zip 或 exe 时间早于本次源码修改时间，视为旧包，必须重新构建。
3. 不同压缩方式可能让 zip 内路径使用 `/` 或 `\`，也可能有或没有顶层目录；校验关键文件时优先按文件名搜索，不要强行假设固定前缀。
4. 如果 zip 大小明显异常，先检查解压目录文件数量和复制命令，而不是直接发布。

### Windows runner 快捷键改动

`simple_live_app\windows\runner\flutter_window.cpp` 中桌面快捷键逻辑用于解决中文输入法下字母快捷键不触发的问题。原生层在 `WM_KEYDOWN` / `WM_SYSKEYDOWN` 阶段按物理键提前发送 MethodChannel 事件，但不消费按键消息；Dart 层仍负责在 `EditableText` 焦点内屏蔽播放器快捷键。修改该文件后必须重新构建 Windows release 并刷新 zip。