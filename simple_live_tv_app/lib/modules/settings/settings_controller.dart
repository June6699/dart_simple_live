import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';

class SettingsController extends BaseController
    with GetTickerProviderStateMixin {
  late TabController tabController;
  var tabIndex = 0.obs;

  SettingsController() {
    tabController = TabController(length: 5, vsync: this);
    tabController.animation?.addListener(() {
      var currentIndex = (tabController.animation?.value ?? 0).round();
      if (tabIndex.value == currentIndex) {
        return;
      }
      tabIndex.value = currentIndex;
      if (tabIndex.value == 0) {
        hardwareDecodeFocusNode.requestFocus();
      }
      if (tabIndex.value == 1) {
        danmakuFoucsNode.requestFocus();
      }
      if (tabIndex.value == 2) {
        autoUpdateFollowEnableFocusNode.requestFocus();
      }
      if (tabIndex.value == 3) {
        bilibiliFoucsNode.requestFocus();
      }
      if (tabIndex.value == 4) {
        versionFocusNode.requestFocus();
      }
    });
  }
  var hardwareDecodeFocusNode = AppFocusNode()..isFoucsed.value = true;
  var compatibleModeFocusNode = AppFocusNode();
  var mpvProfileFocusNode = AppFocusNode();
  var scaleFoucsNode = AppFocusNode();
  var defaultQualityFocusNode = AppFocusNode();
  var danmakuFoucsNode = AppFocusNode();
  var danmakuSizeFoucsNode = AppFocusNode();
  var danmakuEmojiFoucsNode = AppFocusNode();
  var danmakuSpeedFoucsNode = AppFocusNode();
  var danmakuAreaFoucsNode = AppFocusNode();
  var danmakuOpacityFoucsNode = AppFocusNode();
  var danmakuStorkeFoucsNode = AppFocusNode();
  var liveEventFlowFoucsNode = AppFocusNode();
  var liveEventFlowOverlayFoucsNode = AppFocusNode();
  var liveEventFlowWindowFoucsNode = AppFocusNode();
  var liveEventFlowDisplayFoucsNode = AppFocusNode();
  var liveEventFlowMinCountFoucsNode = AppFocusNode();
  var danmakuDedupeFoucsNode = AppFocusNode();
  var danmakuDedupeModeFoucsNode = AppFocusNode();
  var danmakuDedupeWindowFoucsNode = AppFocusNode();
  var danmakuDedupeStepFoucsNode = AppFocusNode();

  var autoUpdateFollowEnableFocusNode = AppFocusNode();
  var autoUpdateFollowDurationFocusNode = AppFocusNode();
  var updateFollowThreadFocusNode = AppFocusNode();
  var followPageSizeFocusNode = AppFocusNode();
  var bilibiliFoucsNode = AppFocusNode();
  var versionFocusNode = AppFocusNode();

  void editSyncServerUrl() async {
    var value = await Utils.showEditTextDialog(
      SignalRService.configuredUrl,
      title: "同步服务地址",
      hintText: SignalRService.kDefaultUrl,
      validate: (text) {
        final url = text.trim();
        if (url.isEmpty) {
          return true;
        }
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !(uri.scheme == "wss" || uri.scheme == "ws") ||
            uri.host.isEmpty) {
          SmartDialog.showToast("请输入 ws:// 或 wss:// 开头的同步服务地址");
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return;
    }
    await SignalRService.setConfiguredUrl(value);
    SmartDialog.showToast(value.trim().isEmpty ? "已恢复默认同步服务" : "已保存");
    update();
  }

  void editSyncProxyUrl() async {
    var value = await Utils.showEditTextDialog(
      SignalRService.configuredProxyUrl,
      title: "同步代理地址",
      hintText: "TV 端请填局域网代理，例如 192.168.1.2:51888",
      validate: (text) {
        final value = text.trim();
        if (!SignalRService.isValidProxyConfig(value)) {
          SmartDialog.showToast(
            "请输入 host:port、http://host:port，或 direct 直连",
          );
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return;
    }
    await SignalRService.setConfiguredProxyUrl(value);
    SmartDialog.showToast(value.trim().isEmpty ? "已恢复自动检测代理" : "已保存");
    update();
  }

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      AppNavigator.toBiliBiliLogin();
    }
  }

  void douyinTap() async {
    final hasCookie = DouyinAccountService.instance.hasCookie.value;
    final action = await Utils.showOptionDialog<String>(
      [
        "编辑或导入 Cookie",
        if (hasCookie) "查看当前 Cookie",
        if (hasCookie) "导出到剪贴板",
        if (hasCookie) "清除 Cookie",
      ],
      "编辑或导入 Cookie",
      title: "抖音账号",
    );
    switch (action) {
      case "编辑或导入 Cookie":
        await _editDouyinCookie();
        break;
      case "查看当前 Cookie":
        await _showCurrentDouyinCookie();
        break;
      case "导出到剪贴板":
        await _exportDouyinCookieToClipboard();
        break;
      case "清除 Cookie":
        await _clearDouyinCookie();
        break;
      default:
        break;
    }
  }

  Future<void> _editDouyinCookie() async {
    final current = DouyinAccountService.instance.cookie;
    final value = await Utils.showEditTextDialog(
      current,
      title: "抖音 Cookie",
      hintText: "粘贴完整 Cookie，留空则恢复默认 ttwid",
    );
    if (value == null) {
      return;
    }
    final input = value.trim();
    if (input.isEmpty) {
      DouyinAccountService.instance.clearCookie();
      SmartDialog.showToast("已清除自定义抖音 Cookie");
      update();
      return;
    }
    final cookie = DouyinCookieHelper.normalizeInput(input);
    DouyinAccountService.instance.setCookie(cookie);
    SmartDialog.showToast(
      DouyinCookieHelper.hasFullCookie(cookie) ? "抖音 Cookie 已保存" : "已保存 ttwid",
    );
    update();
  }

  Future<void> _showCurrentDouyinCookie() async {
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义抖音 Cookie");
      return;
    }
    await Utils.showMessageDialog(
      cookie,
      title: "当前抖音 Cookie",
      selectable: true,
    );
  }

  Future<void> _exportDouyinCookieToClipboard() async {
    final cookie = DouyinAccountService.instance.cookie;
    if (cookie.isEmpty) {
      SmartDialog.showToast("当前没有自定义抖音 Cookie");
      return;
    }
    await Clipboard.setData(ClipboardData(text: cookie));
    SmartDialog.showToast("已复制当前抖音 Cookie");
  }

  Future<void> _clearDouyinCookie() async {
    final confirmed = await Utils.showAlertDialog(
      "确定要清除自定义抖音 Cookie 吗？",
      title: "清除配置",
    );
    if (!confirmed) {
      return;
    }
    DouyinAccountService.instance.clearCookie();
    SmartDialog.showToast("已清除自定义抖音 Cookie");
    update();
  }
}
