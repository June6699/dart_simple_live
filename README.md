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

更多社区反馈与赞助鸣谢见 [THANKS.md](/THANKS.md)。

<p align="center">
  <img width="360" src="/assets/support_wechat.png" alt="微信收款码">
</p>

## 用户群

扫码加入 SimpleLive 用户群，交流使用问题和反馈建议。

<p align="center">
  <img width="360" src="/assets/user_group_wechat.jpg" alt="SimpleLive 用户群二维码">
</p>

## Release 资产

Release 资产会在 Windows、Android 和 TV 模拟环境完成基础验证后发布。

当前提供这些正式资产：

- Android `apk`
- Android TV 拆分 `apk`
- Windows `zip`
- Linux `zip`
- Linux `deb`

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

## 实时字幕

当前版本暂时下线实时字幕入口，相关开关、样式和模型说明不再对外展示。

## 抖音搜索 Cookie

抖音播放可以使用内置 `ttwid` 兜底，但房间名 / 主播名搜索经常要求登录态。搜索不可用时，需要在 `账号管理 -> 抖音 -> Cookie登录` 粘贴桌面浏览器登录后的完整 Cookie，不要只粘贴单个 `ttwid`。

电脑端获取方式：

- 在浏览器打开 `www.douyin.com` 或 `live.douyin.com` 并登录。
- 按 `F12` 打开开发者工具，切到 `Network / 网络`。
- 刷新页面或随便点一次页面，让浏览器产生一个抖音域名请求。
- 点开任意 `douyin.com` 请求，在 `Request Headers / 请求标头` 找到 `cookie`。
- 复制 `cookie` 后面完整的一大串，粘贴到 SimpleLive 的抖音 Cookie 登录框。

应用也兼容直接粘贴 `Cookie: xxx`，或粘贴浏览器复制出来的整段请求头；会自动从其中提取 `cookie` 字段。Android / iOS 端只保留粘贴 Cookie 和文件导入，搜索 Cookie 建议仍从电脑浏览器获取后粘贴或同步。TV 端不内置浏览器，请从主 App 同步完整 Cookie。

抖音账号页会尝试从完整 Cookie 的 `sid_guard` 中解析预计剩余有效期；如果只配置了 `ttwid`，或请求头 Cookie 里没有可解析的过期信息，会提示有效期无法判断。Cookie 仍可能因退出登录、改密或平台风控提前失效。

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

## 版本重点 2026.6.4

主 App 版本为 `v1.12.5`，TV 端版本为 `tv_v1.7.6`；本地 release 目录对应 `release/v1.12.5` 和 `release/tv_v1.7.6`。完整更新记录见 [Update.md](/Update.md)。

### 主要变更

- `update:` 桌面端直播间非全屏状态新增右侧栏折叠功能，方便多开时让播放器占用更多窗口空间；移动端、全屏和小窗布局保持原有习惯。
- `fix:` 桌面端直播间非全屏去掉内部顶栏，改为浮层返回 / 更多按钮，避免 Windows 顶部灰色空白带挤占播放区域。
- `fix:` iOS 非全屏直播页使用明确 16:9 播放器尺寸的布局，规避 iPadOS 横屏白屏但有声音的问题。
- `update:` 重复弹幕过滤新增“刷屏严父”模式，忽略用户只按弹幕内容全局去重，主 App 全平台和 TV 端均生效。
- `update:` 切到“刷屏严父”会自动开启重复过滤、窗口重置为默认 10 条并隐藏过滤步长；窗口可在 5 到 100 条内调整，超过 20 条时提示弹幕可能明显变少。
- `update:` iOS 直播间普通状态支持左侧边缘滑动返回（issue [#39](https://github.com/June6699/dart_simple_live/issues/39)，感谢 @LakeWithOcean），并使用 Cupertino 风格路由转场；全屏状态仍保持返回时先退出全屏。
- `update:` 完善抖音直播弹幕本地表情显示，内置 141 个抖音平台表情资源，并支持本地 `asset://` 表情资源渲染；表情参考感谢 [EmojiAll 抖音平台表情](https://www.emojiall.com/zh-hans/platform-douyin)。
- `fix:` B 站弹幕表情改为富文本片段渲染，避免源码文本和表情图重复显示。
- `fix:` TV 端关注列表改为分页加载，关注刷新加入冷却和任务互斥，同步关注列表改为批量写入，降低大量关注场景下的闪退风险。
- `perf:` 大量关注导入 / 本地同步 / 房间同步 / WebDAV 恢复按数据规模分批处理，历史记录批量合并写入，关注状态刷新并发改为后台自动判断。
- `fix:` 删除关注页“读取中”分组，未知状态按未开播处理；关注页记住上次分组模式和选中分组。
- `fix:` 搜索页改为按平台 `siteId` 记忆，避免配置同步或平台排序变化后选错平台。
- `fix:` 排查 issue #37，1.12.4 Windows 白屏更像发布包 / 构建链或运行时依赖差异，源码侧未发现 Windows runner / `main.dart` 启动链路变更。
- `release:` 更新 JSON 与本地 release 说明切换为正式 `v1.12.5` / `tv_v1.7.6`，移除预发布下载链接与 prerelease 标记。

### 验证状态

- 主 App：`flutter analyze` 通过，`No issues found`。
- TV App：`flutter analyze` 通过，`No issues found`。
- Core：`dart test test/live_repeated_danmu_summary_test.dart` 通过。
- 本地 release 目录已准备：`release/v1.12.5`、`release/tv_v1.7.6`；macOS / iOS 按策略由 GitHub Actions 手动 workflow 构建。
- 待真实设备继续验证：桌面多开右侧栏折叠、严父模式高弹幕量误过滤、TV 端大量关注列表、抖音本地表情显示效果。

## 后续目标

- Android/iOS 真实设备验证特别关注开播提醒、自动小窗、静音、多开声音隔离，并继续收紧小窗预览恢复逻辑。
- 继续验证 WebDAV 恢复、局域网二维码/手动输入、远程房间同步在不同网络环境下的失败提示和可用性。
- 继续跟踪虎牙头条偶发不显示、视频卡住后刷新恢复、SC 高峰时播放器浮层稳定性。
- 继续完善抖音搜索登录引导；TV 端保持无浏览器方案，通过手机或桌面端登录后同步 Cookie。
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

[EmojiAll 抖音平台表情](https://www.emojiall.com/zh-hans/platform-douyin) `感谢提供抖音平台表情参考，项目内仅作为本地静态表情资源使用`

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

<a href="https://www.star-history.com/?repos=June6699%2Fdart_simple_live&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=June6699/dart_simple_live&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=June6699/dart_simple_live&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=June6699/dart_simple_live&type=date&legend=top-left" />
 </picture>
</a>



