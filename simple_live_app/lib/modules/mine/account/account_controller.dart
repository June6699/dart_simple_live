import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class AccountController extends GetxController {
  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyinTap() async {
    douyinLogin();
  }

  void douyinLogin() {
    Utils.showBottomSheet(
      title: "抖音账号",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text("网页登录/扫码登录"),
              subtitle: const Text("打开抖音网页登录，扫码后保存 Cookie"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kDouyinWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动粘贴完整抖音 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doDouyinCookieConfig();
            },
          ),
          if (DouyinAccountService.instance.hasCookie.value)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("清除 Cookie"),
              subtitle: const Text("清除后恢复默认 ttwid"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await clearDouyinCookie();
              },
            ),
        ],
      ),
    );
  }

  Future<void> clearDouyinCookie() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      var result =
          await Utils.showAlertDialog("确定要清除自定义抖音 Cookie 吗？", title: "清除配置");
      if (result) {
        DouyinAccountService.instance.clearCookie();
        SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
      }
    }
  }

  void doDouyinCookieConfig() {
    // 兼容旧版只保存 ttwid 的配置。
    var savedCookie = DouyinAccountService.instance.cookie;
    var displayText = savedCookie;
    if (savedCookie.startsWith('ttwid=') && !savedCookie.contains(";")) {
      displayText = savedCookie.substring(6);
    }
    var controller = TextEditingController(text: displayText);

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "默认内置 ttwid 可用于播放；搜索接口被要求登录时，建议粘贴完整 www.douyin.com Cookie。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "可粘贴完整 Cookie，也可只粘贴 ttwid 值",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  var defaultValue = DouyinSite.kDefaultCookie;
                  if (defaultValue.startsWith('ttwid=')) {
                    defaultValue = defaultValue.substring(6);
                  }
                  controller.text = defaultValue;
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 ttwid"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              Get.back();
              if (input.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                var cookie = input;
                if (!input.contains("=")) {
                  cookie = 'ttwid=$input';
                }
                DouyinAccountService.instance.setCookie(cookie);
                SmartDialog.showToast("抖音 Cookie 已保存");
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }
}
