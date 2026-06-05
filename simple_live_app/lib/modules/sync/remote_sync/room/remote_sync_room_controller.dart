import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/bulk_data_import_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/signalr_service.dart';

class RemoteSyncRoomController extends BaseController {
  final String roomId;
  final SignalRService signalR = SignalRService();
  RemoteSyncRoomController(this.roomId) {
    if (roomId.isNotEmpty) {
      currentRoomId.value = roomId;
    }
  }
  StreamSubscription? _roomDestroyedSubscription;
  StreamSubscription? _roomUserUpdatedSubscription;
  StreamSubscription? _onFavoriteSubscription;
  StreamSubscription? _onHistorySubscription;
  StreamSubscription? _onShieldWordSubscription;
  StreamSubscription? _onBiliAccountSubscription;
  var currentRoomId = "--".obs;
  RxList<RoomUser> roomUsers = <RoomUser>[].obs;
  bool get hasValidRoomId =>
      currentRoomId.value.trim().length == SignalRService.kRoomIdLength;

  Timer? _timer;

  Future<Resp> _sendJsonChunks<T>({
    required List<T> items,
    required bool overlay,
    required String label,
    required String action,
    required Object? Function(T item) toJson,
  }) async {
    final policy = BulkDataImportService.policyForCount(items.length);
    final chunkSize = policy.scale == BulkDataScale.normal
        ? items.length
        : policy.dbBatchSize;
    Log.i("房间发送$label：count=${items.length} scale=${policy.label}");
    if (items.isEmpty) {
      return signalR.sendContent(
        roomName: currentRoomId.value,
        action: action,
        overlay: overlay,
        content: json.encode(const []),
      );
    }
    Resp? lastResp;
    for (var start = 0; start < items.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, items.length).toInt();
      final chunk = items.sublist(start, end);
      final content = json.encode(chunk.map(toJson).toList());
      lastResp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: action,
        overlay: overlay && start == 0,
        content: content,
      );
      Log.i(
        "房间发送$label分段：${start + 1}-$end/${items.length} bytes=${content.length}",
      );
      if (!lastResp.isSuccess) {
        return lastResp;
      }
      await Future<void>.delayed(Duration.zero);
    }
    return lastResp ?? Resp(false, "没有可同步的数据", null);
  }

  var countDown = 600.obs;

  @override
  void onInit() {
    connect();
    super.onInit();
  }

  void connect() async {
    try {
      listenSignalR();
      await signalR.connect();
      if (signalR.state == SignalRConnectionState.connected) {
        if (roomId.isEmpty) {
          createRoom();
        } else {
          joinRoom(roomId);
        }
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("连接同步服务失败：${_formatSyncError(e)}");
      Get.back();
    }
  }

  void createRoom() async {
    try {
      var resp = await signalR.createRoom();
      if (resp.isSuccess && (resp.data?.trim().isNotEmpty ?? false)) {
        currentRoomId.value = resp.data!.trim();
        _startTimer();
      } else {
        SmartDialog.showToast(
          resp.message.isEmpty
              ? "创建房间失败：服务未返回房间号"
              : "创建房间失败：${_formatSyncError(resp.message)}",
        );
        Get.back();
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("创建房间失败：${_formatSyncError(e)}");
      Get.back();
    }
  }

  void _startTimer() {
    // 倒计时5分钟，自动关闭页面
    countDown.value = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countDown--;
      if (countDown <= 0) {
        timer.cancel();
        Get.back();
      }
    });
  }

  void joinRoom(String roomId) async {
    try {
      var resp = await signalR.joinRoom(roomId);
      if (!resp.isSuccess) {
        SmartDialog.showToast(resp.message);
        Get.back();
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("加入房间失败：${_formatSyncError(e)}");
      Get.back();
    }
  }

  String _formatSyncError(Object e) {
    final text =
        e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (text.isEmpty) {
      return "未知错误";
    }
    return text;
  }

  void listenSignalR() {
    _roomDestroyedSubscription = signalR.onRoomDestroyedStream.listen((roomId) {
      SmartDialog.showToast("房间已被销毁");
      Get.back();
    });
    _roomUserUpdatedSubscription = signalR.onRoomUserUpdatedStream.listen(
      (roomUsers) {
        this.roomUsers.assignAll(roomUsers);
      },
    );
    _onFavoriteSubscription = signalR.onFavoriteStream.listen((data) {
      onReceiveFavorite(data.$1, data.$2);
    });
    _onHistorySubscription = signalR.onHistoryStream.listen((data) {
      onReceiveHistory(data.$1, data.$2);
    });
    _onShieldWordSubscription = signalR.onShieldWordStream.listen((data) {
      onReceiveShieldWord(data.$1, data.$2);
    });
    _onBiliAccountSubscription = signalR.onBiliAccountStream.listen((data) {
      onReceiveBiliAccount(data.$1, data.$2);
    });
  }

  void onReceiveFavorite(bool overlay, String data) async {
    try {
      final stopwatch = Stopwatch()..start();
      var jsonBody = json.decode(data);
      if (jsonBody is! List) {
        throw const FormatException("关注列表格式不是数组");
      }
      final result = await BulkDataImportService.importFollowUsers(
        jsonBody,
        overwrite: overlay,
      );
      stopwatch.stop();
      Log.i(
        "房间同步关注完成：${result.logSummary} bytes=${data.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      SmartDialog.showToast("已同步关注列表（${result.imported} 条）");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveHistory(bool overlay, String data) async {
    try {
      final stopwatch = Stopwatch()..start();
      var jsonBody = json.decode(data);
      if (jsonBody is! List) {
        throw const FormatException("历史记录格式不是数组");
      }
      final result = await BulkDataImportService.importHistories(
        jsonBody,
        overwrite: overlay,
      );
      stopwatch.stop();
      Log.i(
        "房间同步历史完成：${result.logSummary} bytes=${data.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );
      SmartDialog.showToast('已同步历史记录（${result.imported} 条）');
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveShieldWord(bool overlay, String data) async {
    try {
      final stopwatch = Stopwatch()..start();
      var jsonBody = json.decode(data);
      if (jsonBody is! List) {
        throw const FormatException("屏蔽词格式不是数组");
      }
      final result = await BulkDataImportService.importShieldValues(
        jsonBody,
        overwrite: overlay,
      );
      stopwatch.stop();
      Log.i(
        "房间同步屏蔽词完成：${result.logSummary} bytes=${data.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );
      SmartDialog.showToast('已同步屏蔽词（${result.imported} 条）');
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveBiliAccount(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      if (jsonBody is! Map) {
        throw const FormatException("账号数据格式不是对象");
      }
      var cookie = jsonBody['cookie']?.toString() ?? "";
      if (cookie.isEmpty) {
        throw const FormatException("账号 Cookie 为空");
      }
      BiliBiliAccountService.instance.setCookie(cookie);
      BiliBiliAccountService.instance.loadUserInfo();
      SmartDialog.showToast('已同步哔哩哔哩账号');
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  Future<bool> showOverlayDialog() async {
    var overlay = await Utils.showAlertDialog(
      "是否覆盖远端数据？",
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  void syncFollow() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }

      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "发送中...");
      var users = DBService.instance.getFollowList();
      var resp = await _sendJsonChunks(
        items: users,
        label: "关注",
        action: "SendFavorite",
        overlay: overlay,
        toJson: (item) => item.toJson(),
      );
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送关注列表");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      SmartDialog.showToast("发送失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncHistory() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "发送中...");
      var histores = DBService.instance.getHistores();
      var resp = await _sendJsonChunks(
        items: histores,
        label: "历史",
        action: "SendHistory",
        overlay: overlay,
        toJson: (item) => item.toJson(),
      );
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送历史记录");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      SmartDialog.showToast("发送失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBlockedWord() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "发送中...");
      var shieldList = AppSettingsController.instance.allShieldValues.toList();
      var resp = await _sendJsonChunks(
        items: shieldList,
        label: "屏蔽词",
        action: "SendShieldWord",
        overlay: overlay,
        toJson: (item) => item,
      );
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送屏蔽词");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      SmartDialog.showToast("发送失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBiliAccount() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }
      if (!BiliBiliAccountService.instance.logined.value) {
        SmartDialog.showToast("未登录哔哩哔哩");
        return;
      }
      SmartDialog.showLoading(msg: "发送中...");

      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendBiliAccount",
        overlay: true,
        content: json.encode({
          "cookie": BiliBiliAccountService.instance.cookie,
        }),
      );
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送哔哩哔哩账号");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void showQRInfo() {
    if (!hasValidRoomId) {
      SmartDialog.showToast("房间号还未创建完成");
      return;
    }
    Utils.showBottomSheet(
      title: "房间信息",
      child: Column(
        children: [
          QrImageView(
            data: currentRoomId.value,
            version: QrVersions.auto,
            backgroundColor: Colors.white,
            padding: AppStyle.edgeInsetsA12,
            size: 200,
          ),
          AppStyle.vGap24,
          Text(
            currentRoomId.value,
            textAlign: TextAlign.center,
            style: Get.textTheme.titleLarge,
          ),
          const Text(
            "请使用其他Simple Live客户端扫描上方二维码\n建立连接后可选择需要同步的数据",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    _timer?.cancel();
    _roomDestroyedSubscription?.cancel();
    _roomUserUpdatedSubscription?.cancel();
    _onFavoriteSubscription?.cancel();
    _onHistorySubscription?.cancel();
    _onShieldWordSubscription?.cancel();
    _onBiliAccountSubscription?.cancel();
    signalR.dispose();
    super.onClose();
  }
}
