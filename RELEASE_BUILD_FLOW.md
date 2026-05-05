# SimpleLive Release 预编译与发布流程

这份文档记录当前仓库在 `Windows / Android / Android TV / Linux` 四个平台上的实际可用预编译流程，也记录了这次本地多平台构建后确认过的注意事项。

目标很明确：

- 本地先验证 Windows 和 Android
- 本地同步验证 Android TV
- Linux 优先用 GitHub Actions 正式构建
- 如果确实需要本地重新打 Linux 包，只把 WSL 当 Linux 构建环境，不要求在 WSL 里运行图形界面
- 所有最终成品统一归档到 `C:\softwares\dart_simple_live\release`
- 日常开发以私有 `own` 仓库为准，公开 `fork` 仓库只做阶段性对外发布

`macOS` 当前只保留手动入口，不参与正式自动发布判断。

## 1. 适用范围

- 主应用：`simple_live_app`
- TV 应用：`simple_live_tv_app`
- 当前正式发布产物：
  - Android 单个 `apk`
  - Android TV 拆分 `apk`
  - Windows `zip`
  - Linux `zip`
  - Linux `deb`
  - source code zip
- 当前不再自动发布：
  - macOS
  - iOS
  - Windows `msix`

## 2. 本机默认路径

当前这台 Windows 机器默认使用这些目录：

- 仓库：`C:\softwares\dart_simple_live`
- Flutter：`C:\softwares\flutter`
- Git：`C:\softwares\Git`
- GitHub CLI：`C:\softwares\GitHubCli`
- NuGet：`C:\softwares\nuget`
- Android SDK：`C:\softwares\Android_Sdk`
- JDK 17：`C:\softwares\jdk-17`
- Windows 本机部署目录：`C:\softwares\SimpleLive`
- Android 本机输出目录：`C:\softwares\SimpleLiveAndroid`
- Android TV 本机输出目录：`C:\softwares\SimpleLiveAndroidTV`
- Release 汇总目录：`C:\softwares\dart_simple_live\release`

固定约定：

- `Windows / Android / Android TV` 只使用这一套本地 Flutter：`C:\softwares\flutter`
- `Linux` 只使用 WSL 里的独立 Flutter，不和 Windows 共用同一套 SDK
- 不要在 Windows 本地长期保留第二套 `flutter_clean / flutter_tmp / flutter_backup_for_build` 之类的并行 SDK
- 如果 `C:\softwares\flutter` 损坏，修复方式应是“用干净 SDK 替换回 `C:\softwares\flutter`”，而不是让项目长期改用第二个本地路径
- 不要在 `WSL flutter pub get` 和 `Windows flutter pub get` 之间对同一个工程目录来回混跑，否则 `.dart_tool/package_config.json` 很容易混入错误路径

如果这些路径改了，先同步修改对应脚本或命令。

## 3. 双仓库分工

当前建议固定为三套远程：

- `origin`
  - 指向私有仓库：`June6699/dart_simple_live_own`
  - 这是日常开发主仓，也是本地默认 push 目标
- `fork`
  - 指向公开仓库：`June6699/dart_simple_live`
  - 这个仓库保留 fork 标签，只在需要对外公开时更新
- `upstream`
  - 指向原作者仓库：`xiaoyaocz/dart_simple_live`
  - 只作为历史与参考上游，不直接往这里 push

推荐策略：

1. 所有日常开发都在本地仓库完成，然后先 push 到私有 `origin`
2. 私有 `origin` 可以比公开 `fork` 更新得更频繁
3. 公开 `fork` 不需要每次开发都同步，只在你准备阶段性公开或发 release 时再同步
4. 不要把公开 `fork` 当成日常开发主仓

你现在提出的节奏是可行的，而且是推荐做法：

- `own` 作为“持续更新的私有主仓”
- `public fork` 作为“隔一段时间发布一次的公开镜像”
- 私有 `own` 可以创建和保留 issue / 验证 / release 临时分支
- 公开 `fork` 远端不允许创建任何临时分支或功能分支，只允许维护 `master`、正式 tag 和 release
- 公开 `fork` 上已经存在、用于向上游作者仓库发起 Pull Request 的分支是保护对象，不能删除、改名、强推或覆盖
- 上游作者仓库里的 Pull Request 不能关闭、重开、改 base、改 head、删除来源分支或做任何会改变 PR 状态的操作，除非用户明确点名要求处理该 PR

唯一需要补的一条规则是：

- 从 `own` 同步到 `public fork` 时，不是直接原样推过去，而是先做一次“公开裁剪”

发布前先执行一次远程校验，避免把私有提交直接推到公开仓库：

```powershell
cd C:\softwares\dart_simple_live
git remote -v
```

当前期望结果：

- `origin -> https://github.com/June6699/dart_simple_live_own.git`
- `fork -> https://github.com/June6699/dart_simple_live.git`

当前公开仓库根目录不应包含这些文件：

- `build_android_apk.bat`
- `build_tv_apk.bat`
- `deploy_windows.bat`
- `UPDATE.md`
- `RELEASE_BUILD_FLOW.md`
- 除 `README.md` 之外的其他根目录 `.md` 文档
- 其他根目录 `.bat` 脚本

## 4. 当前 GitHub Actions 工作流

当前主应用与 TV 应用发布相关工作流拆成 6 个文件：

- [publish_app_release.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release.yml)
  - Android 自动发布
  - 触发方式：推送 `v*` tag
- [publish_app_release_windows.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_windows.yml)
  - Windows 自动发布
  - 触发方式：推送 `v*` tag
- [publish_app_release_linux.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_linux.yml)
  - Linux 自动发布
  - 触发方式：推送 `v*` tag
  - 当前使用 `ubuntu-22.04`
  - 当前 GitHub Actions Flutter 版本：`3.41.x`
  - 当前 Linux 打包方式：`flutter_distributor package --platform linux --targets deb,zip --skip-clean`
- [publish_app_release_macos_manual.yml](/C:/softwares/dart_simple_live/.github/workflows/publish_app_release_macos_manual.yml)
  - macOS 手动构建入口
  - 触发方式：`workflow_dispatch`
  - 默认不参与正式发布
- [publish_tv_app_dev.yaml](/C:/softwares/dart_simple_live/.github/workflows/publish_tv_app_dev.yaml)
  - Android TV 开发预发构建
  - 触发方式：推送 `dev_tv_v*` tag 或手动 `workflow_dispatch`
  - 产物上传到 GitHub Actions Artifacts
- [publish_tv_app_release.yaml](/C:/softwares/dart_simple_live/.github/workflows/publish_tv_app_release.yaml)
  - Android TV 正式 release
  - 触发方式：推送 `tv_v*` tag
  - 依赖 GitHub Secrets：`TV_KEYSTORE_BASE64`、`TV_STORE_PASSWORD`、`TV_KEY_PASSWORD`、`TV_KEY_ALIAS`
  - 使用 `flutter build apk --release --split-per-abi`
  - 会上传 `armeabi-v7a / arm64-v8a / x86_64` 三个 APK 到 Artifacts 和 GitHub Release

## 5. 发布前原则

1. 尽量不要用脏工作区直接打“最终正式包”。
2. 最稳的正式发版方式仍然是：
   - 本地先做功能验证
   - push 代码
   - 打 tag
   - 以 GitHub Actions 产物为正式 release
3. 四个平台要独立看待：
   - Android 只看 Android
   - Android TV 只看 Android TV
   - Windows 只看 Windows
   - Linux 只看 Linux
4. 不要再让 macOS 成败阻塞正式发版。
5. 本地 `debug`、临时预编译目录、解压目录不要混进正式 `release` 归档。
6. 私有 `origin` 和公开 `fork` 的 tag 可以同名，但允许指向不同提交。
7. 公开 `fork` 的源码和 source zip 必须基于“公开裁剪后的提交”生成，不能直接拿 `own` 的完整提交导出。

## 6. 版本号与 tag

主应用版本号在：

- [simple_live_app/pubspec.yaml](/C:/softwares/dart_simple_live/simple_live_app/pubspec.yaml)

例如：

```yaml
version: 1.12.0+11200
```

发布时要保证：

1. `pubspec.yaml` 的版本号已经改好
2. Git tag 使用 `v` 前缀

例如：

```powershell
cd C:\softwares\dart_simple_live
git tag -f v1.12.0
git push origin v1.12.0 --force
```

TV 版版本信息在：

- [simple_live_tv_app/pubspec.yaml](/C:/softwares/dart_simple_live/simple_live_tv_app/pubspec.yaml)
- [assets/tv_app_version.json](/C:/softwares/dart_simple_live/assets/tv_app_version.json)

例如：

```yaml
version: 1.6.5+10605
```

```json
{
  "version": "1.6.5",
  "version_num": 10605
}
```

TV 发版时要保证：

1. `simple_live_tv_app/pubspec.yaml` 的 `version` 已更新
2. `assets/tv_app_version.json` 的 `version`、`version_num`、`version_desc` 与本次发布一致
3. 正式 release 的 Git tag 使用 `tv_v` 前缀
4. 如果只是跑开发预发构建，使用 `dev_tv_v*` tag

例如正式 release：

```powershell
cd C:\softwares\dart_simple_live
git tag tv_v1.7.0
git push origin tv_v1.7.0
```

例如开发预发构建：

```powershell
cd C:\softwares\dart_simple_live
git tag dev_tv_v1.6.5
git push origin dev_tv_v1.6.5
```

## 7. 本地预验证

### 7.1 Android

仓库脚本：

- [build_android_apk.bat](/C:/softwares/dart_simple_live/build_android_apk.bat)

推荐命令：

```powershell
cd C:\softwares\dart_simple_live
.\build_android_apk.bat --no-pause C:\softwares\SimpleLiveAndroid
```

说明：

- 脚本会检查 `Flutter / Android SDK / JDK / keystore`
- Flutter 固定走 `C:\softwares\flutter`
- 原始构建产物先落在 `simple_live_app\build\...`
- 成功后会把 APK 复制到：
  - `C:\softwares\SimpleLiveAndroid\SimpleLive-release.apk`

### 7.2 Android TV

仓库脚本：

- [build_tv_apk.bat](/C:/softwares/dart_simple_live/build_tv_apk.bat)

推荐命令：

```powershell
cd C:\softwares\dart_simple_live
.\build_tv_apk.bat --no-pause C:\softwares\SimpleLiveAndroidTV
```

说明：

- 脚本会检查 `Flutter / Android SDK / JDK / keystore`
- Flutter 固定走 `C:\softwares\flutter`
- 会执行 `flutter pub get`
- 会执行 `flutter build apk --release --split-per-abi`
- 原始构建产物先落在 `simple_live_tv_app\build\...`
- 成功后会把 APK 复制到：
  - `C:\softwares\SimpleLiveAndroidTV\SimpleLive-TV-armeabi-v7a-release.apk`
  - `C:\softwares\SimpleLiveAndroidTV\SimpleLive-TV-arm64-v8a-release.apk`
  - `C:\softwares\SimpleLiveAndroidTV\SimpleLive-TV-x86_64-release.apk`
- TV 正式签名依赖：
  - `simple_live_tv_app/android/key.properties`
  - `simple_live_tv_app/android/release-keystore.jks`

### 7.3 Windows

仓库脚本：

- [deploy_windows.bat](/C:/softwares/dart_simple_live/deploy_windows.bat)

推荐命令：

```powershell
cd C:\softwares\dart_simple_live
.\deploy_windows.bat --no-pause C:\softwares\SimpleLive
```

说明：

- 会自动关闭正在运行的 `simple_live_app.exe`
- Flutter 固定走 `C:\softwares\flutter`
- 会执行 `flutter pub get`
- 会执行 `flutter build windows --release`
- 原始构建产物先落在 `simple_live_app\build\windows\...`
- 会把结果镜像部署到：
  - `C:\softwares\SimpleLive`

### 7.4 Linux

正式 release 优先依赖 GitHub Actions。

但如果满足下面任一情况，可以本地重新打 Linux 包：

- 需要在 push 前先验证 Linux 打包链没坏
- GitHub Release 上已有旧 Linux 包，但你明确不想复用旧包
- 需要在本地重新生成新的 `linux.zip` 和 `linux.deb`

注意：

- 本地 Linux 构建不要求在 WSL 里运行图形界面
- 只需要能在 WSL 里完成编译和打包即可
- `Windows 挂载目录 /mnt/c/...` 不适合直接做最终 `deb` 打包，因为权限会变成 `777`，`dpkg-deb` 可能报控制目录权限错误
- 正确做法是把仓库同步到 WSL 自己的 Linux 文件系统，再在那里打包

## 8. Linux 本地构建实战规则

这部分是这次实际构建后确认过的经验，后面再本地打 Linux 包，尽量按这个来。

### 7.1 WSL 的定位

WSL 在这里的作用只是：

- 提供 Linux 编译环境
- 安装 Linux 依赖
- 生成 `linux.zip` 和 `linux.deb`

不是为了在 WSL 里运行图形界面程序。

### 7.2 不要直接复用 Windows Flutter 缓存

不要直接拿 `C:\softwares\flutter` 的缓存去做 Linux 构建。

原因：

- Windows Flutter 缓存里带的是 Windows Dart/Engine
- 在 WSL 下直接复用，经常会出现平台不匹配问题

正确做法：

- 在 WSL 里单独准备一份 Linux Flutter 工具链
- 这次本地 Linux 打包验证可用的是 `Flutter 3.38.10`
- 当前 Windows / Android / Android TV 本地构建已切换到 `C:\softwares\flutter` 下的 `Flutter 3.41.9`

例如：

```bash
mkdir -p /root/tools
cd /root/tools
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.10-stable.tar.xz -o flutter_linux_3.38.10-stable.tar.xz
tar -xf flutter_linux_3.38.10-stable.tar.xz
mv flutter flutter_3.38.10
```

### 7.3 WSL 需要安装的 Linux 依赖

至少准备这些：

```bash
apt-get update
apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libasound2-dev libmpv-dev mpv curl git unzip xz-utils zip patchelf lld-14
```

说明：

- GitHub Actions 工作流里当前最关键的是：
  - `clang`
  - `cmake`
  - `ninja-build`
  - `pkg-config`
  - `libgtk-3-dev`
  - `liblzma-dev`
  - `libasound2-dev`
  - `libmpv-dev`
  - `mpv`
- 本地额外装了：
  - `curl`
  - `git`
  - `unzip`
  - `xz-utils`
  - `zip`
  - `patchelf`
  - `lld-14`

`lld-14` 很重要，因为这次实际遇到了：

- `Failed to find any of [ld.lld, ld] in LocalDirectory: '/usr/lib/llvm-14/bin'`

补完 `lld-14` 后才通过。

必要时还可以补一个链接：

```bash
ln -s /usr/bin/ld /usr/lib/llvm-14/bin/ld
```

### 7.4 不要在 `/mnt/c/...` 里直接打 `deb`

这次已经验证过，直接在：

- `/mnt/c/softwares/dart_simple_live/...`

里执行 `flutter_distributor package`，`flutter build linux` 可能成功，但 `deb` 打包会失败，典型报错是：

```text
dpkg-deb: error: control directory has bad permissions 777 (must be >=0755 and <=0775)
```

原因：

- Windows 挂载盘权限模型不适合 `deb` 控制目录权限检查

正确做法：

1. 用 `rsync` 或其他方式，把仓库同步到 WSL 原生目录
2. 在 WSL 原生目录里执行打包
3. 打包完成后，再把产物复制回 Windows 的 `release` 目录

例如：

```bash
rm -rf /root/build/dart_simple_live
mkdir -p /root/build
rsync -a --delete \
  --exclude .git \
  --exclude release \
  --exclude simple_live_app/build \
  --exclude simple_live_app/.dart_tool \
  /mnt/c/softwares/dart_simple_live/ /root/build/dart_simple_live/
```

### 7.5 Linux 本地打包命令

在 WSL 原生目录里执行：

```bash
export HOME=/root
export PATH=/root/tools/flutter_3.38.10/bin:/root/.pub-cache/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

cd /root/build/dart_simple_live/simple_live_app
flutter config --enable-linux-desktop
flutter pub get
dart pub global activate flutter_distributor
flutter_distributor package --platform linux --targets deb,zip --skip-clean
```

产物默认会出现在：

- `build/dist/<app_version>/simple_live_app-<app_version>-linux.deb`
- `build/dist/<app_version>/simple_live_app-<app_version>-linux.zip`

### 7.6 关于 root 警告

在 WSL 里如果用 `root` 跑 Flutter，会看到：

```text
Woah! You appear to be trying to run flutter as root.
```

这只是警告，不一定会导致构建失败。

当前这台机器上，这次 Linux 本地打包虽然出现了这个提示，但 `linux.deb` 和 `linux.zip` 最终都成功生成了。

### 7.7 关于 pub advisory 的异常提示

这次 WSL 里还看到了类似：

```text
Failed to decode advisories for archive from https://pub.dev.
FormatException: advisoriesUpdated must be a String
```

当前观察：

- 这类提示没有阻塞最终 Linux 构建
- `flutter pub get` 和 `flutter_distributor package` 最终仍能成功

因此目前把它视作“噪音警告”，不是正式阻塞项。

## 9. 日常开发与公开发布策略

推荐长期按下面这套来：

### 9.1 日常开发

日常开发默认流程：

1. 在本地仓库修改
2. 提交到本地 `master`
3. push 到私有 `origin`

示例：

```powershell
cd C:\softwares\dart_simple_live
git status
git add .
git commit -m "your commit"
git push origin master
```

这一步不会影响公开 `fork`。

### 9.2 阶段性公开

当你准备对外公开一版时，再把私有仓库的某个稳定点同步到 `fork`。

推荐规则：

1. 永远先在 `own` 上完成开发和验证
2. 只把“你愿意公开”的稳定版本同步到 `fork`
3. 同步前先移除公开仓库不该带的文件
4. 公开 release 的 source zip 也要基于公开裁剪后的版本生成

### 9.3 这套思路是否可行

可行，而且比较适合你：

- `own` 更频繁 push，作为私有开发真源
- `fork` 更低频更新，作为公开发布窗口

只要你坚持“公开同步前先裁剪”这条规则，就不会乱。

## 10. 私有仓库正式发布流程

私有 `own` 仓库的正式流程如下。

### 10.1 提交代码并推送

```powershell
cd C:\softwares\dart_simple_live
git status
git add .
git commit -m "Release v1.12.0"
git push origin master
```

### 10.2 打 tag 触发 3 条自动工作流

```powershell
cd C:\softwares\dart_simple_live
git tag -f v1.12.0
git push origin v1.12.0 --force
```

会触发：

- Android 工作流
- Windows 工作流
- Linux 工作流

不会自动触发 macOS。

### 10.3 查看工作流状态

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh run list --repo June6699/dart_simple_live --limit 20
```

建议分别确认这 3 条工作流成功：

- `app-build-android-release`
- `app-build-windows-release`
- `app-build-linux-release`

如果只想看某一条：

```powershell
gh run list --repo June6699/dart_simple_live --workflow publish_app_release.yml --limit 10
gh run list --repo June6699/dart_simple_live --workflow publish_app_release_windows.yml --limit 10
gh run list --repo June6699/dart_simple_live --workflow publish_app_release_linux.yml --limit 10
```

## 11. 公开 fork 发布流程

公开 `fork` 不建议直接拿私有 `master` 原样强推。

正确做法是：

1. 从私有稳定提交创建一个本地临时导出工作区或本地临时分支
2. 删除公开不该带的文件
3. 生成一个“公开裁剪提交”
4. 只把这个提交推到 `fork/master`，不要推任何临时分支到公开 `fork`
5. 如需公开源码随 release 更新，再强制更新 `fork` 的 `vX.Y.Z` tag
6. 用这个公开裁剪提交生成 source zip
7. 上传 Android / Windows / Linux / source 资产到 `fork` release

公开 `fork` 远端只允许存在：

- `master`
- 正式 tag
- release

例外与保护规则：

- 如果公开 `fork` 已经有用于向上游作者仓库提 PR 的历史分支，视为 PR 保护分支
- PR 保护分支不能删除、强推、改名、覆盖，也不能为了“清理 public 分支”而动它
- 不要执行 `gh pr close`、`gh pr reopen`、`gh pr edit`、删除 PR 来源分支、修改 PR base/head 等会改变 PR 状态的命令
- 只允许只读查看 PR 状态；任何 PR 变更都必须等用户明确说“处理这个 PR”
- 如果旧 PR 因来源分支被 force-push / recreated 导致 GitHub 拒绝 reopen，不要继续改旧 PR；确认用户授权后，用当前公开 `fork` 的对应分支重新创建一个新 PR，并在正文里引用旧 PR 编号

公开仓库根目录当前必须删除的文件：

- `build_android_apk.bat`
- `build_tv_apk.bat`
- `deploy_windows.bat`
- `UPDATE.md`
- `RELEASE_BUILD_FLOW.md`
- 除 `README.md` 之外的其他根目录 `.md` 文档
- 其他根目录 `.bat` 脚本

示意流程：

```powershell
cd C:\softwares\dart_simple_live
git switch -c public-export-v1.12.0
git rm build_android_apk.bat build_tv_apk.bat deploy_windows.bat UPDATE.md RELEASE_BUILD_FLOW.md
git commit -m "chore: prepare public fork release v1.12.0"
git push fork HEAD:master --force
git tag -f v1.12.0 HEAD
git push fork refs/tags/v1.12.0 --force
```

注意：`public-export-v1.12.0` 只能是本地临时分支或临时目录里的分支，不能推到公开 `fork`。然后再基于这个公开裁剪提交生成公开 source zip。

## 12. `release` 目录归档规则

每个版本都整理到：

- `C:\softwares\dart_simple_live\release\vX.Y.Z`

推荐结构：

```text
release\
  v1.12.0\
    android\
    tv\
    linux\
    windows\
    source\
```

其中：

- `android`：最终正式 APK
- `tv`：最终正式 Android TV APK
- `linux`：最终 `deb` 和 `zip`
- `windows`：最终 `zip`
- `source`：源码压缩包

原则：

1. `release` 里只放最终成品
2. 不要把 `debug` 输出混进去
3. 不要把旧版本覆盖到新版本目录
4. 不要把临时解压文件长期留在 `android / tv / linux / windows / source` 目录里

## 13. 当前正式资产命名

当前目标保留这些文件：

- `simple_live_app-<app_version>-android.apk`
- `simple_live_tv_app-<tv_app_version>-armeabi-v7a-release.apk`
- `simple_live_tv_app-<tv_app_version>-arm64-v8a-release.apk`
- `simple_live_tv_app-<tv_app_version>-x86_64-release.apk`
- `simple_live_app-<app_version>-windows.zip`
- `simple_live_app-<app_version>-linux.zip`
- `simple_live_app-<app_version>-linux.deb`
- `dart_simple_live-v<semver>-source.zip`

例如 `1.12.0+11200`：

- `simple_live_app-1.12.0+11200-android.apk`
- `simple_live_tv_app-1.7.0+10700-armeabi-v7a-release.apk`
- `simple_live_tv_app-1.7.0+10700-arm64-v8a-release.apk`
- `simple_live_tv_app-1.7.0+10700-x86_64-release.apk`
- `simple_live_app-1.12.0+11200-windows.zip`
- `simple_live_app-1.12.0+11200-linux.zip`
- `simple_live_app-1.12.0+11200-linux.deb`
- `dart_simple_live-v1.12.0-source.zip`

## 14. 本地归档命令示例

### 11.1 归档 Android

```powershell
Copy-Item -Force `
  C:\softwares\SimpleLiveAndroid\SimpleLive-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\android\simple_live_app-1.12.0+11200-android.apk
```

### 14.2 归档 Android TV

```powershell
Copy-Item -Force `
  C:\softwares\dart_simple_live\simple_live_tv_app\build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\tv\simple_live_tv_app-1.7.0+10700-armeabi-v7a-release.apk

Copy-Item -Force `
  C:\softwares\dart_simple_live\simple_live_tv_app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\tv\simple_live_tv_app-1.7.0+10700-arm64-v8a-release.apk

Copy-Item -Force `
  C:\softwares\dart_simple_live\simple_live_tv_app\build\app\outputs\flutter-apk\app-x86_64-release.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\tv\simple_live_tv_app-1.7.0+10700-x86_64-release.apk
```

### 14.3 归档 Windows

```powershell
Compress-Archive `
  -Path C:\softwares\SimpleLive\* `
  -DestinationPath C:\softwares\dart_simple_live\release\v1.12.0\windows\simple_live_app-1.12.0+11200-windows.zip `
  -Force
```

### 14.4 归档 Linux

如果是 GitHub Release 下载来的，直接放到：

- `release\v1.12.0\linux`

如果是本地 WSL 新构建的，可以从 WSL 复制回 Windows：

```bash
cp -f /root/build/dart_simple_live/simple_live_app/build/dist/1.12.0+11200/simple_live_app-1.12.0+11200-linux.deb /mnt/c/softwares/dart_simple_live/release/v1.12.0/linux/
cp -f /root/build/dart_simple_live/simple_live_app/build/dist/1.12.0+11200/simple_live_app-1.12.0+11200-linux.zip /mnt/c/softwares/dart_simple_live/release/v1.12.0/linux/
```

### 14.5 归档 source zip

如果当前 HEAD 就是你要归档的版本：

```powershell
cd C:\softwares\dart_simple_live
git archive --format=zip --output=C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip HEAD
```

如果要严格对应 tag：

```powershell
cd C:\softwares\dart_simple_live
git archive --format=zip --output=C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip v1.12.0
```

## 15. build 完成后的本地保留规则

构建过程中会同时出现三类目录：

1. 工程内 `build\...`
2. 本机临时预编译目录：
   - `C:\softwares\SimpleLive`
   - `C:\softwares\SimpleLiveAndroid`
   - `C:\softwares\SimpleLiveAndroidTV`
3. 最终归档目录：
   - `C:\softwares\dart_simple_live\release\...`

约定：

- `build\...` 只作为编译中间产物，不长期保留
- `C:\softwares\SimpleLive*` 只作为临时预编译/临时拷贝目录，不长期保留
- 真正长期保留的最终成品，只放在 `C:\softwares\dart_simple_live\release`

在 `push` 之前，增加一个固定收尾动作：

1. 确认需要保留的 APK / ZIP / DEB / source zip 都已经归档到 `release`
2. 清理工程内 `build` 目录
3. 清理 `C:\softwares\SimpleLive`
4. 清理 `C:\softwares\SimpleLiveAndroid`
5. 清理 `C:\softwares\SimpleLiveAndroidTV`
6. 最终只保留 `C:\softwares\dart_simple_live\release` 中的正式内容，避免重复占用空间

## 16. CI 成功后的常规收尾

如果 3 条自动工作流都成功，则通常只需要：

1. 检查 GitHub Release 资产是否完整
2. 下载 Windows 和 Linux 正式产物到本地 `release\vX.Y.Z`
3. 本地生成或核对 source zip
4. 用 Windows `zip` 刷新 `C:\softwares\SimpleLive`
5. 在 push 之前，按上一节规则清理 `build` 和 `C:\softwares\SimpleLive*`

示例：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release view v1.12.0 --repo June6699/dart_simple_live --json assets,url
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-windows.zip" -D C:\softwares\dart_simple_live\release\v1.12.0\windows
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-linux.zip" -D C:\softwares\dart_simple_live\release\v1.12.0\linux
gh release download v1.12.0 --repo June6699/dart_simple_live -p "simple_live_app-1.12.0+11200-linux.deb" -D C:\softwares\dart_simple_live\release\v1.12.0\linux
```

## 17. 兜底流程

如果某条工作流已经成功构建，但 release 上传阶段异常，可以补救。

### 17.1 下载某条工作流 artifact

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh run download <run_id> --repo June6699/dart_simple_live -n android -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\android_artifact
gh run download <run_id> --repo June6699/dart_simple_live -n windows -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\windows_artifact
gh run download <run_id> --repo June6699/dart_simple_live -n linux -D C:\softwares\dart_simple_live\release\v1.12.0\_tmp\linux_artifact
```

### 17.2 手动补传 Release

```powershell
$env:HTTP_PROXY='http://127.0.0.1:51888'
$env:HTTPS_PROXY='http://127.0.0.1:51888'
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH

gh release upload v1.12.0 --repo June6699/dart_simple_live --clobber `
  C:\softwares\dart_simple_live\release\v1.12.0\android\simple_live_app-1.12.0+11200-android.apk `
  C:\softwares\dart_simple_live\release\v1.12.0\windows\simple_live_app-1.12.0+11200-windows.zip `
  C:\softwares\dart_simple_live\release\v1.12.0\linux\simple_live_app-1.12.0+11200-linux.zip `
  C:\softwares\dart_simple_live\release\v1.12.0\linux\simple_live_app-1.12.0+11200-linux.deb `
  C:\softwares\dart_simple_live\release\v1.12.0\source\dart_simple_live-v1.12.0-source.zip
```

## 18. 上传失败时的代理处理

如果：

- `github.com` 能访问
- 但 `uploads.github.com` 上传超时

通常不是仓库权限问题，而是上传链路没走代理。

本机可用代理：

- `127.0.0.1:51888`

测试：

```powershell
Test-NetConnection 127.0.0.1 -Port 51888
curl.exe -I -m 20 --proxy http://127.0.0.1:51888 https://uploads.github.com
```

上传前建议：

```powershell
$env:HTTP_PROXY='http://127.0.0.1:51888'
$env:HTTPS_PROXY='http://127.0.0.1:51888'
```

这次实际踩到的坑：

1. `gh release upload` 很可能不是权限问题，而是 `uploads.github.com` 没走代理
2. 需要显式加上代理环境变量后重传
3. 重新上传已有资产时要带 `--clobber`
4. 公开仓库和私有仓库如果共用同名 tag，要分别确认 tag 指向的提交是不是你想要的那个
5. 公开仓库 release 的 source zip 不能直接复用私有仓库导出的版本
6. 公开仓库如果已经被错误推入了私有文件，需要通过新的公开裁剪提交重新覆盖

## 18. Release 页面清理规则

发版完成后应保证：

- 最终只保留一个正式 `vX.Y.Z` Release
- 不再混入 `msix`
- 不再混入 macOS 自动发布产物

检查：

```powershell
$env:PATH='C:\softwares\GitHubCli;C:\softwares\Git\cmd;'+$env:PATH
gh release list --repo June6699/dart_simple_live --limit 20
gh release view v1.12.0 --repo June6699/dart_simple_live --json assets,url
```

## 19. 最终核对清单

1. [simple_live_app/pubspec.yaml](/C:/softwares/dart_simple_live/simple_live_app/pubspec.yaml) 版本号正确
2. Git tag 正确，格式为 `vX.Y.Z`
3. 三条自动工作流分别成功：
   - Android
   - Windows
   - Linux
4. 正式 Release 至少包含：
   - Android `apk`
   - Windows `zip`
   - Linux `zip`
   - Linux `deb`
   - source code zip
5. 本地 `release\vX.Y.Z` 已归档完成
6. `C:\softwares\SimpleLive` 已刷新为该版本 Windows 预编译目录
7. `release` 目录里没有把 debug 输出、临时文件混进去
8. 如果这次要同步公开 `fork`，确认公开仓库根目录只保留 `README.md`，不含其他 `.md` 文档和任何 `.bat` 脚本
9. 如果这次要同步公开 `fork`，确认公开 source zip 是基于公开裁剪提交生成的
10. 如果这次要同步公开 `fork`，确认公开远端没有创建临时分支或功能分支
11. 如果公开 `fork` 有用于向上游作者仓库提 PR 的分支，确认没有删除、强推、改名、覆盖这些 PR 保护分支，也没有关闭或修改对应 PR
12. 如果 PR 因 head 分支被 force-push / recreated 而无法 reopen，确认新 PR 已创建并在正文中说明替代的旧 PR 编号

## 21. 建议的最短执行顺序

赶时间时，按这套顺序走：

1. 改 [simple_live_app/pubspec.yaml](/C:/softwares/dart_simple_live/simple_live_app/pubspec.yaml) 版本号
2. 本地验证：
   - `.\build_android_apk.bat --no-pause C:\softwares\SimpleLiveAndroid`
   - `.\deploy_windows.bat --no-pause C:\softwares\SimpleLive`
3. 提交并 push 到私有 `origin/master`
4. 私有仓库打 `vX.Y.Z` tag 并 push
5. 分别看 Android、Windows、Linux 三条工作流
6. 检查正式 Release 资产是否齐全
7. 本地归档到 `release\vX.Y.Z`
8. 清理工程内 `build` 和 `C:\softwares\SimpleLive*`，最终只保留 `release`
9. 如有需要，再临时从 `release` 刷新 `C:\softwares\SimpleLive`
10. 如果这次需要公开，再额外执行一次公开裁剪并同步到 `fork`

如果 Linux 这次不能复用旧 release，又不想等线上 release，也可以插入一个本地 Linux 构建步骤：

1. 在 WSL 里准备独立 Linux Flutter
2. 把仓库同步到 WSL 原生目录
3. 本地打出新的 `linux.zip` 和 `linux.deb`
4. 复制回 `release\vX.Y.Z\linux`

照这份流程执行，当前仓库已经可以稳定完成一轮 `Windows / Android / Android TV / Linux` 预编译与正式发版，同时也能把私有开发仓和公开 fork 仓库长期分开维护。
