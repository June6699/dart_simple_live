import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/bulk_data_import_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncDeviceController extends BaseController {
  final SyncClinet client;
  final SyncClientInfoModel info;
  SyncDeviceController({required this.client, required this.info});
  SyncClientRequest request = SyncClientRequest();

  Future<void> _syncJsonChunks<T>({
    required List<T> items,
    required bool overlay,
    required String label,
    required Object? Function(T item) toJson,
    required Future<bool> Function(String body, bool overlay) send,
  }) async {
    final policy = BulkDataImportService.policyForCount(items.length);
    final chunkSize = policy.scale == BulkDataScale.normal
        ? items.length
        : policy.dbBatchSize;
    Log.i("本地发送$label：count=${items.length} scale=${policy.label}");
    if (items.isEmpty) {
      await send(json.encode(const []), overlay);
      return;
    }
    for (var start = 0; start < items.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, items.length).toInt();
      final chunk = items.sublist(start, end);
      final body = json.encode(chunk.map(toJson).toList());
      await send(body, overlay && start == 0);
      Log.i(
        "本地发送$label分段：${start + 1}-$end/${items.length} bytes=${body.length}",
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<bool> showOverlayDialog() async {
    var overlay = await Utils.showAlertDialog(
      "是否覆盖对方设备上的同类数据？选择“不覆盖”会合并同步。",
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  void syncFollowAndTag() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      var users = DBService.instance.getFollowList();
      var tags = DBService.instance.getFollowTagList();
      await _syncJsonChunks(
        items: users,
        overlay: overlay,
        label: "关注",
        toJson: (item) => item.toJson(),
        send: (body, chunkOverlay) {
          return request.syncFollow(client, body, overlay: chunkOverlay);
        },
      );
      // 标签和关注必须同时同步
      await _syncJsonChunks(
        items: tags,
        overlay: overlay,
        label: "标签",
        toJson: (item) => item.toJson(),
        send: (body, chunkOverlay) {
          return request.syncTag(client, body, overlay: chunkOverlay);
        },
      );
      SmartDialog.showToast("已同步关注列表和标签");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步关注和标签失败：$e", StackTrace.current);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncProfile() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      await request.syncProfile(
        client,
        ProfileBackupService.instance.exportProfileJson(),
        overlay: overlay,
      );
      SmartDialog.showToast("已同步配置包");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步配置包失败：$e", StackTrace.current);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncHistory() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      var histores = DBService.instance.getHistores();
      await _syncJsonChunks(
        items: histores,
        overlay: overlay,
        label: "历史",
        toJson: (item) => item.toJson(),
        send: (body, chunkOverlay) {
          return request.syncHistory(client, body, overlay: chunkOverlay);
        },
      );
      SmartDialog.showToast("已同步历史记录");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步历史记录失败：$e", StackTrace.current);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBlockedWord() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      var shieldList = AppSettingsController.instance.allShieldValues.toList();
      await _syncJsonChunks(
        items: shieldList,
        overlay: overlay,
        label: "屏蔽词",
        toJson: (item) => item,
        send: (body, chunkOverlay) {
          return request.syncBlockedWord(client, body, overlay: chunkOverlay);
        },
      );
      SmartDialog.showToast("已同步屏蔽词");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步屏蔽词失败：$e", StackTrace.current);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBiliAccount() async {
    try {
      if (!BiliBiliAccountService.instance.logined.value) {
        SmartDialog.showToast("未登录哔哩哔哩");
        return;
      }
      SmartDialog.showLoading(msg: "同步中...");

      await request.syncBiliAccount(
          client, BiliBiliAccountService.instance.cookie);
      SmartDialog.showToast("已同步哔哩哔哩账号");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步哔哩哔哩账号失败：$e", StackTrace.current);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncDouyinAccount() async {
    try {
      if (!DouyinAccountService.instance.hasCookie.value) {
        SmartDialog.showToast("未配置抖音 Cookie");
        return;
      }
      SmartDialog.showLoading(msg: "同步中...");

      await request.syncDouyinAccount(
          client, DouyinAccountService.instance.cookie);
      SmartDialog.showToast("已同步抖音账号");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步抖音账号失败：$e", StackTrace.current);
    } finally {
      SmartDialog.dismiss();
    }
  }
}
