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

## Release 资产

在我的设备Windows+安卓+TV模拟设备上实际测试，release内的功能和bug修复均完成。

当前提供这些正式资产：

- Android `apk`
- Android TV 拆分 `apk`
- Windows `zip`
- Linux `zip`
- Linux `deb`
- source code zip

TV 版已在本地 `Android Emulator - Medium_Phone`（`Android 16 / API 36 / x86_64`）验证通过，虎牙、斗鱼、抖音直播均可正常出画面。当前这版 TV 播放建议保持 `硬件解码` 开启。

TV 下载建议：

- `SimpleLive-TV-arm64-v8a-release.apk`：适合大多数 64 位安卓电视 / 电视盒子，`NVIDIA SHIELD Android TV` 优先下载这个。
- `SimpleLive-TV-armeabi-v7a-release.apk`：适合较老的 32 位安卓电视设备。
- `SimpleLive-TV-x86_64-release.apk`：适合 Android Studio / AVD 模拟器等 `x86_64` 环境。
- 如果不确定设备架构，优先看系统信息里的 `arm64-v8a / armeabi-v7a / x86_64`，不要盲下“最新版”。

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

## 当前已完成的改动 2026.5.5

### 全平台通用

- `fix:` 修复聊天区用户名和内容的首尾空格问题，并修复用户名过长时单独换行的问题。
- `fix:` 修复虎牙头条 / SC 显示异常、重复刷新、价格异常和旧数据残留问题。
- `fix:` 修复虎牙 / B站直播间在没有头条或 SC 时无任何提示的问题，补上明确空状态。
- `fix:` 修复直播间内“正在连接弹幕服务器”“线路选择”“线路 N”等中文文案乱码，并继续统一按 `UTF-8` 维护中文文案与注释。
- `fix:` 修复直播间内通过推荐 / 历史再次进房时出现的页面套娃、返回黑屏和房间切换异常问题。
- `fix:` 修复直播间内关注列表只显示开播主播的问题，补齐“全部 / 直播中 / 未开播”筛选能力。
- `fix:` 修复 B站贡献榜重复更新、刷新异常的问题，并改进贡献榜按需刷新逻辑。
- `optimize:` 弹幕显示从“上下间距”调整为“显示几行”，并根据显示区域和字体大小动态计算。
- `optimize:` 弹幕延迟支持按平台单独微调。
- `optimize:` 贡献榜增加前十、粉丝牌、高贡献等筛选。
- `optimize:` 分类页在缺少原始图标时提供统一占位图标。
- `optimize:` 同类推荐、观看历史、用户快捷操作等直播间交互继续补强，并避免在直播间内部重复套娃导航。
- `update:` 弹幕屏蔽升级为分平台管理，并支持关键词 / 用户分别一键清空。
- `update:` 弹幕屏蔽预设支持导入、导出、编辑和保存覆盖。
- `update:` 直播间内点击用户名或整条弹幕都可进行屏蔽、临时禁言、备注、复制、批量恢复等操作，并支持复制弹幕内容。
- `update:` 新增 `B站 / 抖音 / 斗鱼` 贡献榜或亲密榜展示能力。

### Windows

- `fix:` 修复直播间标题居中逻辑被右侧操作栏影响的问题，改为按实际直播画面区域计算视觉中心。
- `fix:` 修复 Windows 小窗、全屏、窗口恢复、鼠标自动隐藏、悬浮控制区闪动等一系列桌面播放器问题。

### Android

- `fix:` 修复安卓后台恢复与直播间恢复逻辑，提升应用被系统回收后的可恢复性。
- `fix:` 修复安卓端全屏下从历史 / 关注 / 推荐打开右侧列表时一闪就消失的问题。
- `fix:` 修复“我的”里的直播设置、弹幕设置等长页面与安卓虚拟导航栏重叠的问题。

### Android TV

- `fix:` TV 播放已在本地 `Android Emulator - Medium_Phone`（`Android 16 / API 36 / x86_64`）验证通过，虎牙、斗鱼、抖音均正常出画面；当前建议保持 `硬件解码` 开启。
- `update:` TV 更新检查已切换到当前公开仓库的版本说明与下载页，不再继续指向上游仓库。
- `update:` TV 设置页补充黑屏排查提示，方便在没有设备的情况下给用户明确的兼容性操作建议。

### 发布与工程

- `optimize:` Windows / Android / TV 本地构建链统一收敛回单路径 Flutter，减少多套 SDK 混跑导致的路径污染问题。
- `update:` 发布链路已拆成 Android / Windows / Linux 三条独立工作流，macOS 改为手动入口，并补齐 Android TV 正式 release。
- `update:` Windows / Android / Android TV 本地 Flutter 已升级到 `3.41.9`，并保留 Linux WSL 独立 Flutter 构建路径。

## 下一步计划

### 全平台通用

- `fix`：弹幕展示行数改为跟随显示区域自适应分配，动态调整弹幕上下行间距；限制间距最小值避免弹幕重叠，限制间距最大值防止留白过大、界面观感不佳及内容溢出，实现弹幕行数自适应贴合显示区域。==（或者通过用户自定义弹幕上下间距以控制显示的行数，各有优劣）==
- `optimize`：关于功能`播放器中显示SC`，默认设为关闭。
- `optimize`：继续补完部分平台接口细节，例如分区字段、标签图标、推荐逻辑反查和直播间周边数据一致性。
- `optimize`：继续研究虎牙贡献榜的稳定方案，如果网页端不稳定，再评估 APP 侧接口或保底方案。
- `optimize`：继续优化聊天区自动滚动、推荐直播、观看历史和贡献榜筛选等直播间交互体验。
- `update`：新加每月功能讨论区，提供用户投票功能来更新下一阶段方案。

### Android

- `fix`：修复直播非全屏模式下，关注页面筛选标签乱跳问题；全屏长按进入关注页时，筛选标签功能正常。
- `optimize`：继续补强安卓直播间底部按钮与虚拟导航栏重叠、后台长时间挂起后的恢复细节。

### Android TV

- `optimize`：继续排查 Android TV 设备兼容性，重点关注黑屏、有声无画和硬件解码差异问题。

### MacOS 及 IOS

- `fix`：修补依赖的冲突，发布release。

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
