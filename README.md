> ### Release
>
> 本仓库提供阶段性 `Release` 安装包与压缩包，见 [GitHub Releases](https://github.com/June6699/dart_simple_live/releases) 页面。
>
> 私有开发主仓会更频繁更新；公开仓库只在阶段性整理后同步。

<p align="center">
    <img width="128" src="/assets/logo.png" alt="Simple Live logo">
</p>
<h2 align="center">Simple Live</h2>

<p align="center">
简简单单的看直播
</p>

![浅色模式](/assets/screenshot_light.jpg)

![深色模式](/assets/screenshot_dark.jpg)

## 仓库说明

- fork 来源：[原作者仓库 xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live)
- 当前公开仓库：`June6699/dart_simple_live`

## 支持项目

Simple Live 会继续保持开源和免费使用。赞助费用主要用于同步服务、域名和构建测试等维护开销。

<p align="center">
  <img width="360" src="/assets/support_wechat.png" alt="微信收款码">
</p>

## Release 资产

Release 资产会在 Windows、Android 和 TV 模拟环境完成基础验证后发布。

当前提供这些正式资产：

- Android `apk`
- Android TV 拆分 `apk`
- Windows `zip`
- Linux `zip`
- Linux `deb`
- source code zip

## 远程同步服务

当前远程同步使用自建 Cloudflare Workers 临时房间服务：

- 服务状态页：`https://simple-live-sync.3439394104.workers.dev`
- App 内 WebSocket 地址：`wss://simple-live-sync.3439394104.workers.dev/sync`

普通用户不需要自己配置服务器；创建房间、扫码或输入房间号即可同步。浏览器直接打开 `/sync` 显示 `websocket upgrade required` 是正常的，因为 `/sync` 只给 App 的 WebSocket 使用。

已知限制：

- 房间 600 秒后自动过期。
- 创建者退出或断开后，房间会销毁。
- 单房间最多 8 个连接。
- 单条同步消息最大 1 MB。
- 服务只做临时转发，不保存关注、历史、Cookie、屏蔽词等内容。
- 这不是账号云同步；不会跨天、跨设备持续自动同步。
- 如果用户所在网络无法访问 `workers.dev` 或拦截 WebSocket，远程同步可能连接失败，可改用局域网同步、WebDAV，或在设置里填写自建同步服务地址。后续建议绑定自定义域名，减少 `workers.dev` 在部分网络下不可达的问题。

可配置项：

- 主 App：`其他设置 -> 同步服务地址` 可以填写自建 `ws://` 或 `wss://` 地址，留空则使用内置默认服务。
- 主 App：`其他设置 -> 同步代理地址` 可以填写代理地址，例如 `127.0.0.1:51888` 或 `http://127.0.0.1:51888`；留空会在桌面端自动检测本机 `127.0.0.1:51888`，填写 `direct` 表示强制直连。
- 代理端口不是固定值，请在自己的代理软件里查看本机 HTTP 代理端口。比如 v2rayN、Clash、Mihomo 等软件一般会在设置或端口页面显示 `HTTP Port` / `Mixed Port`。
- TV App：设置页“关于”里显示当前同步服务地址；默认使用内置服务。

## 配置导入

新版配置包会导出设置、关注、标签、历史、弹幕屏蔽词和屏蔽词预设；Cookie、WebDAV 密码等敏感内容默认不会写入配置包。

兼容说明：

- 支持导入新版 `simple_live_profile.json`。
- 支持导入旧版 `simple_live_config.json`，但旧版“其他设置导出”本身通常只包含设置和弹幕屏蔽词，不一定包含关注列表。
- 支持兼容旧 WebDAV/同步备份里的关注、标签、历史数组格式。
- 如果旧备份文件仍然提示格式错误，或关注列表没有恢复，可以提交备份文件样例和报错信息用于补充兼容。

TV 版已在 `Android Emulator - Medium_Phone`（`Android 16 / API 36 / x86_64`）完成基础验证，虎牙、斗鱼、抖音直播可正常播放。TV 播放建议保持 `硬件解码` 开启。

TV 下载建议：

- `SimpleLive-TV-arm64-v8a-release.apk`：适合大多数 64 位安卓电视 / 电视盒子，`NVIDIA SHIELD Android TV` 优先下载这个。
- `SimpleLive-TV-armeabi-v7a-release.apk`：适合较老的 32 位安卓电视设备。
- `SimpleLive-TV-x86_64-release.apk`：适合 Android Studio / AVD 模拟器等 `x86_64` 环境。
- 如果不确定设备架构，优先看系统信息里的 `arm64-v8a / armeabi-v7a / x86_64`，不要盲下“最新版”。

## 实时字幕模型

实时字幕不内置模型，需要用户自行下载后在 App 里选择本地模型路径。HuggingFace 下载慢或打不开时，可以用下面的百度网盘镜像。

百度网盘镜像：[点击下载字幕模型](https://pan.baidu.com/s/17ToLCOaK71zkl1s6c8ZKpg?pwd=6699)，提取码：`6699`。网盘里包含 `advanced-whisper-large-v3-int8` 等 3 个模型文件夹，下载自己需要的档位即可。

使用方式：选一个档位，下载该档位列出的全部文件，放到同一个文件夹；App 里选择这个文件夹。不要下载 `.weights`、无 `int8` 的 `.onnx`、`test_wavs` 测试音频。

- 甜点级（先试这个）：Streaming Zipformer bilingual zh-en int8，体积较小。下载 `encoder-epoch-99-avg-1.int8.onnx`、`decoder-epoch-99-avg-1.int8.onnx`、`joiner-epoch-99-avg-1.int8.onnx`、`tokens.txt`、`bpe.model`、`bpe.vocab`。
- 中级（中文直播优先）：Paraformer zh int8。下载 `model.int8.onnx`、`tokens.txt`、`config.yaml`、`am.mvn`。
- 高级（高性能桌面）：Whisper large-v3 int8，文件很大。下载 `large-v3-encoder.int8.onnx`、`large-v3-decoder.int8.onnx`、`large-v3-tokens.txt`。

## 支持直播平台

- 虎牙直播
- 斗鱼直播
- 哔哩哔哩直播
- 抖音直播

## APP 支持平台

- [x] Android
- [x] iOS
- [x] Windows `BETA`
- [x] MacOS `BETA`
- [x] Linux `BETA`
- [x] Android TV `BETA`

## 环境

- Windows / Android / Android TV 本地 Flutter：`3.41.9`
- Linux 本地 WSL Flutter：`3.38.10`

## 版本重点 2026.5.29

主 App 版本为 `v1.12.4`，TV 端版本为 `tv_1.7.5`；本地 release 目录对应 `release/v1.12.4` 和 `release/tv_1.7.5`。完整更新记录见 [Update.md](/Update.md)。

### 主要变更

- `update:` 关注页支持按开播状态或平台分组，特别关注星标持久化并在全部列表和所属分组置顶；主 App 和 TV 关注刷新并发默认改为 `8`，仍支持 `0 = 自动`。
- `update:` issue #21：特别关注支持移动端开播提醒；桌面端和 TV 端暂不做通知。
- `fix:` 主 App / TV App 版本号、更新 JSON 和本地 release tag 统一到 `v1.12.4` / `tv_1.7.5`，避免新包仍显示旧版本。
- `fix:` WebDAV 和局域网同步恢复失败时不再一直转圈，连接失败会收起 loading 并给出明确原因；跨网络局域网同步会提示改用远程房间同步、WebDAV、VPN 或内网穿透。
- `update:` 抖音房间名 / 主播名搜索接入账号 Cookie；Android/iOS/Windows/macOS 支持抖音网页登录，Linux 支持浏览器登录后手动粘贴 Cookie，TV 端不打开浏览器，通过手机或电脑端同步 Cookie。
- `update:` 播放器新增当前房间临时静音、房间内一次性定时关闭、Android 退后台自动小窗开关；应用内返回只回主页，Home 键或系统手势退后台才触发自动小窗。
- `fix:` 手动刷新直播间时同步刷新视频、弹幕、SC/头条和贡献榜；全平台热度增加 10 秒详情刷新兜底；聊天区在全屏/小窗返回后主动回到底部。
- `fix:` 虎牙头条 pid 候选和日志增强，SC/头条按结束时间排序；修复 issue #22 中播放器浮层多条 SC 倒计时卡 1 秒不消失的问题。
- `update:` issue #24：弹幕表情支持 B 站和抖音消息里的图片字段，主 App 聊天区、主 App 播放器浮层和 TV 播放器弹幕均可显示；小窗返回时尽量保留当前弹幕层，不再整层清空重刷。
- `update:` 实时字幕设置补到直播间设置和右上角更多菜单，并提供高级/中级/甜点级模型推荐下载入口。
- `fix:` 其他设置里的同步服务地址在窄屏上改为短标签显示，完整地址保留在说明和编辑弹窗中。
- `update:` 抖音表情解析按富文本片段处理，网页登录改为调用系统浏览器后粘贴 Cookie；TV 端继续通过手机或电脑同步 Cookie。
- `update:` 播放页支持聊天 / SC 或头条 / 关注 / 设置自定义顺序，SC/头条支持按消失时间正序或倒序。
- `update:` 重复弹幕过滤支持全端配置，默认关闭；同一用户在最近 N 条内重复发送相同内容时只显示一次。
- `fix:` Android 非全屏播放页恢复竖屏布局，右上角更多菜单避开虚拟导航栏，小窗返回全屏时不主动清空弹幕层。
- `update:` 实时字幕模型下载说明改为“选择一个模型文件夹”，补充百度网盘镜像、每个档位需要下载的文件清单，并在 App 内优先选择模型文件夹。
- `fix:` 抖音聊天表情按富文本顺序显示，避免只把图片追加到末尾；表情图片无法解析时保留文字占位，减少消息内容丢失。
- `update:` TV 端也支持重复弹幕过滤和过滤窗口设置，默认关闭，逻辑与主 App 一致。

### 验证状态

- 主 App：`flutter pub get` 通过，`flutter analyze` 通过，`No issues found`。
- TV App：`flutter pub get` 通过，`flutter analyze` 通过，`No issues found`。
- `pubspec.lock` 无改动。
- 待真实设备继续验证：Android 自动小窗的 Home/返回键边界、关闭小窗后的预览保留、移动端开播提醒、WebDAV 恢复、跨设备 Cookie 同步、虎牙 SC/头条高频直播间表现、TV 弹幕表情显示效果。

## 后续目标

- Android/iOS 真实设备验证特别关注开播提醒、自动小窗、静音、多开声音隔离，并继续收紧小窗预览恢复逻辑。
- 继续验证 WebDAV 恢复、局域网二维码/手动输入、远程房间同步在不同网络环境下的失败提示和可用性。
- 继续跟踪虎牙头条偶发不显示、视频卡住后刷新恢复、SC 高峰时播放器浮层稳定性。
- 继续完善抖音搜索登录引导；TV 端保持无浏览器方案，通过手机或桌面端登录后同步 Cookie。
- 补充实时字幕模型的蓝奏云镜像链接，减少用户到 HuggingFace 手动找文件的成本。
- 评估 TV 端超大关注备份恢复的稳定性。

## 参考及引用

[AllLive](https://github.com/xiaoyaocz/AllLive) `本项目的 C# 版，有兴趣可以看看`

[xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live) `当前公开仓库的上游 fork 来源`

[dart_tars_protocol](https://github.com/xiaoyaocz/dart_tars_protocol.git)

[wbt5/real-url](https://github.com/wbt5/real-url)

[lovelyyoshino/Bilibili-Live-API](https://github.com/lovelyyoshino/Bilibili-Live-API/blob/master/API.WebSocket.md)

[IsoaSFlus/danmaku](https://github.com/IsoaSFlus/danmaku)

[BacooTang/huya-danmu](https://github.com/BacooTang/huya-danmu)

[TarsCloud/Tars](https://github.com/TarsCloud/Tars)

[YunzhiYike/douyin-live](https://github.com/YunzhiYike/douyin-live)

[5ime/Tiktok_Signature](https://github.com/5ime/Tiktok_Signature)

## 声明

本项目的功能基于互联网上公开资料整理与开发，无任何破解、逆向工程等行为。

本项目仅用于学习交流编程技术，严禁用于商业目的。如有任何商业行为，均与本项目无关。

如果本项目存在侵犯您合法权益的情况，请及时联系开发者，开发者会及时处理相关内容。

## 绝对禁止更新的一些功能

> [!WARNING]
>
> 不碰账号，不碰钱，不碰写操作，不碰官方活动。

- 官方账号登录、注册、找回密码、实名、绑定手机、未成年人模式。
- 官方账号维度的关注、取关、拉黑、消息已读、历史同步、收藏同步。
- 任何充值相关功能：钱包、余额、B币、银瓜子、金瓜子、虎牙币、电池、礼物背包、订单、退款、兑换码、优惠券。
- 任何付费互动：送礼物、上头条、上舰、续费大航海、开贵族、点亮粉丝牌、付费表情、充电、打赏。
- 任何“发出去”的直播互动：发送弹幕、评论、点赞、分享任务、投票、PK 助力、上麦申请、连麦申请。
- 任何社交功能：点赞、私信、群聊、应援团消息、用户聊天、主播私信。
- 任何治理功能：举报、申诉、房管、禁言、踢人、拉黑官方账号关系。
- 任何官方活动：抽奖、福袋、红包、竞猜、宝箱、签到、任务中心、经验成长、勋章升级、直播间成就。
- 任何主播后台：开播、改标题、改分区、公告、商品橱窗、收益、数据后台、粉丝管理。
- 任何电商闭环：直播间购物、商品跳转下单、会员购、店铺、带货组件。
- 离线缓存、录播下载、源流下载、批量导出。
- 完整首页推荐流、热榜、官方消息中心、Push 通知中心。
- 动态发布、评论发布、社区互动、投稿。
- 官方账号体系下的“我的”页面复刻，比如钱包、勋章、等级、任务、资产全量展示。
- 过于完整的录播 / 回放 / 追更体系，尤其是能替代用户回到官方 App 的那种。



## Star History

<a href="https://www.star-history.com/#xiaoyaocz/dart_simple_live&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date" />
 </picture>
</a>
