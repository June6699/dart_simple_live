import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/danmaku/douyin_emoji_assets.dart';
import 'package:simple_live_core/src/scripts/douyin_sign.dart';

import 'proto/douyin.pb.dart';

class DouyinDanmakuArgs {
  final String webRid;
  final String roomId;
  final String userId;
  final String cookie;
  DouyinDanmakuArgs({
    required this.webRid,
    required this.roomId,
    required this.userId,
    required this.cookie,
  });
  @override
  String toString() {
    return json.encode({
      "webRid": webRid,
      "roomId": roomId,
      "userId": userId,
      "cookie": cookie,
    });
  }
}

class DouyinDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 10 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://webcast3-ws-web-lq.douyin.com/webcast/im/push/v2/";
  late DouyinDanmakuArgs danmakuArgs;
  WebScoketUtils? webScoketUtils;
  final List<LiveMessage> _pendingChatMessages = <LiveMessage>[];
  Timer? _flushChatTimer;
  static const int _maxChatFlushBatch = 50;
  static const Duration _chatFlushInterval = Duration(milliseconds: 80);

  @override
  Future start(dynamic args) async {
    final startStopwatch = Stopwatch()..start();
    danmakuArgs = args as DouyinDanmakuArgs;
    var ts = DateTime.now().millisecondsSinceEpoch;
    var uri = Uri.parse(serverUrl).replace(
      scheme: "wss",
      queryParameters: {
        "app_name": "douyin_web",
        "version_code": "180800",
        "webcast_sdk_version": "1.3.0",
        "update_version_code": "1.3.0",
        "compress": "gzip",
        // "internal_ext":
        //     "internal_src:dim|wss_push_room_id:${danmakuArgs.roomId}|wss_push_did:${danmakuArgs.userId}|dim_log_id:20230626152702E8F63662383A350588E1|fetch_time:1687764422114|seq:1|wss_info:0-1687764422114-0-0|wrds_kvs:WebcastRoomRankMessage-1687764036509597990_InputPanelComponentSyncData-1687736682345173033_WebcastRoomStatsMessage-1687764414427812578",
        "cursor": "h-1_t-${ts}_r-1_d-1_u-1",
        "host": "https://live.douyin.com",
        "aid": "6383",
        "live_id": "1",
        "did_rule": "3",
        "debug": "false",
        "maxCacheMessageNumber": "20",
        "endpoint": "live_pc",
        "support_wrds": "1",
        "im_path": "/webcast/im/fetch/",
        "user_unique_id": danmakuArgs.userId,
        "device_platform": "web",
        "cookie_enabled": "true",
        "screen_width": "1920",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Mozilla",
        "browser_version": DouyinSite.kDefaultUserAgent.replaceAll(
          "Mozilla/",
          "",
        ),
        "browser_online": "true",
        "tz_name": "Asia/Shanghai",
        "identity": "audience",
        "room_id": danmakuArgs.roomId,
        "heartbeatDuration": "0",
        //"signature": "00000000"
      },
    );

    final signStopwatch = Stopwatch()..start();
    var sign = DouyinSign.getSignature(danmakuArgs.roomId, danmakuArgs.userId);
    signStopwatch.stop();
    CoreLog.i(
      "[DouyinDanmaku] getSignature 耗时 ${signStopwatch.elapsedMilliseconds}ms",
    );

    var url = "$uri&signature=$sign";
    var backupUrl = url.replaceAll("webcast3-ws-web-lq", "webcast5-ws-web-lf");
    var backupUrls = [
      url.replaceAll("webcast3-ws-web-lq", "webcast5-ws-web-hl"),
      url.replaceAll("webcast3-ws-web-lq", "webcast3-ws-web-hl"),
      url.replaceAll("webcast3-ws-web-lq", "webcast3-ws-web-lf"),
    ];
    CoreLog.d("[DouyinDanmaku] 连接弹幕服务器: ${danmakuArgs.webRid}");
    webScoketUtils = WebScoketUtils(
      url: url,
      backupUrl: backupUrl,
      backupUrls: backupUrls,
      headers: {
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "User-Agent": DouyinSite.kDefaultUserAgent,
        "Cookie": danmakuArgs.cookie,
        "Origin": "https://live.douyin.com",
        "Referer": "https://live.douyin.com/${danmakuArgs.webRid}",
      },
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
    startStopwatch.stop();
    CoreLog.i(
      "[DouyinDanmaku] start(${danmakuArgs.webRid}) 耗时 ${startStopwatch.elapsedMilliseconds}ms",
    );
  }

  @override
  void heartbeat() {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void decodeMessage(args) {
    // CoreLog.i(args.toString());
    final stopwatch = Stopwatch()..start();
    var messageCount = 0;
    var chatCount = 0;

    var wssPackage = PushFrame.fromBuffer(args);

    var logId = wssPackage.logId;
    var decompressed = gzip.decode(wssPackage.payload);
    var payloadPackage = Response.fromBuffer(decompressed);
    if (payloadPackage.needAck) {
      sendAck(logId, payloadPackage.internalExt);
      //return;
    }
    for (var msg in payloadPackage.messagesList) {
      messageCount++;
      if (msg.method == 'WebcastChatMessage') {
        final liveMessage = unPackWebcastChatMessage(msg.payload);
        if (liveMessage != null) {
          chatCount++;
          _enqueueChatMessage(liveMessage);
        }
      } else if (msg.method == 'WebcastRoomUserSeqMessage') {
        unPackWebcastRoomUserSeqMessage(msg.payload);
      }
    }
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds >= 16 || chatCount >= 20) {
      CoreLog.i(
        "[DouyinDanmaku] decodeMessage 耗时 ${stopwatch.elapsedMilliseconds}ms messages=$messageCount chats=$chatCount",
      );
    }
  }

  LiveMessage? unPackWebcastChatMessage(List<int> payload) {
    var chatMessage = ChatMessage.fromBuffer(payload);
    final spans = _extractRtfSpans(chatMessage);
    if (spans.isEmpty) {
      _appendTextWithEmojiFallback(spans, chatMessage.content);
    }
    final imageUrls = spans
        .where((item) => item.isImage)
        .map((item) => item.imageUrl!.trim())
        .toList();
    final message = _buildChatMessageText(chatMessage, spans);
    return LiveMessage(
      type: LiveMessageType.chat,
      color: LiveMessageColor.white,
      //暂不知道具体怎么转换颜色
      // color: chatMessage.common.fullScreenTextColor.
      //     ? LiveMessageColor.white
      //     : LiveMessageColor.numberToColor(color),
      message: message,
      userName: chatMessage.user.nickName,
      imageUrls: imageUrls.isEmpty ? null : imageUrls,
      spans: spans.isEmpty ? null : spans,
    );
  }

  void _enqueueChatMessage(LiveMessage message) {
    _pendingChatMessages.add(message);
    if (_pendingChatMessages.length >= _maxChatFlushBatch) {
      _flushChatTimer ??= Timer(Duration.zero, _flushChatMessages);
      return;
    }
    _flushChatTimer ??= Timer(_chatFlushInterval, _flushChatMessages);
  }

  void _flushChatMessages() {
    _flushChatTimer?.cancel();
    _flushChatTimer = null;
    if (_pendingChatMessages.isEmpty) {
      return;
    }
    final batchSize = _pendingChatMessages.length > _maxChatFlushBatch
        ? _maxChatFlushBatch
        : _pendingChatMessages.length;
    final batch = _pendingChatMessages.sublist(0, batchSize);
    _pendingChatMessages.removeRange(0, batchSize);
    for (final message in batch) {
      onMessage?.call(message);
    }
    if (_pendingChatMessages.isNotEmpty) {
      _flushChatTimer = Timer(_chatFlushInterval, _flushChatMessages);
    }
  }

  String _buildChatMessageText(
    ChatMessage chatMessage,
    List<LiveMessageSpan> spans,
  ) {
    if (spans.isEmpty) {
      return chatMessage.content;
    }
    final buffer = StringBuffer();
    for (final span in spans) {
      if (span.isText) {
        buffer.write(span.text);
      }
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? chatMessage.content : text;
  }

  List<LiveMessageSpan> _extractRtfSpans(ChatMessage chatMessage) {
    final spans = <LiveMessageSpan>[];
    if (!chatMessage.hasRtfContent()) {
      return spans;
    }
    for (final piece in chatMessage.rtfContent.piecesList) {
      if (piece.stringValue.trim().isNotEmpty) {
        _appendTextWithEmojiFallback(spans, piece.stringValue);
      }
      if (piece.hasPatternRefValue()) {
        final pattern = piece.patternRefValue.defaultPattern.trim();
        if (pattern.isNotEmpty) {
          _appendTextWithEmojiFallback(spans, pattern);
        }
      }
      if (piece.hasImageValue() && piece.imageValue.hasImage()) {
        final imageUrl = _extractImageUrl(piece.imageValue.image);
        if (imageUrl != null) {
          spans.add(LiveMessageSpan.image(imageUrl));
          continue;
        }
        final fallback = _extractImageFallbackText(piece.imageValue.image);
        if (fallback != null) {
          _appendTextWithEmojiFallback(spans, fallback);
        }
      }
    }
    return spans;
  }

  void _appendTextWithEmojiFallback(List<LiveMessageSpan> spans, String text) {
    if (text.isEmpty) {
      return;
    }
    var start = 0;
    for (final match in RegExp(r'\[[^\[\]]{1,16}\]').allMatches(text)) {
      final token = match.group(0);
      if (token == null) {
        continue;
      }
      final asset = douyinEmojiAssets[token];
      if (asset == null) {
        continue;
      }
      if (match.start > start) {
        spans.add(LiveMessageSpan.text(text.substring(start, match.start)));
      }
      spans.add(LiveMessageSpan.image(asset));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(LiveMessageSpan.text(text.substring(start)));
    }
  }

  String? _extractImageUrl(Image image) {
    for (final url in image.urlListList) {
      final value = url.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }
    final openWebUrl = image.openWebUrl.trim();
    if (openWebUrl.startsWith('http://') || openWebUrl.startsWith('https://')) {
      return openWebUrl;
    }
    final uri = image.uri.trim();
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return uri;
    }
    return null;
  }

  String? _extractImageFallbackText(Image image) {
    final alternativeText = image.content.alternativeText.trim();
    if (alternativeText.isNotEmpty) {
      return alternativeText;
    }
    final name = image.content.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final uri = image.uri.trim();
    if (uri.isNotEmpty) {
      return '[$uri]';
    }
    return null;
  }

  void unPackWebcastRoomUserSeqMessage(List<int> payload) {
    var roomUserSeqMessage = RoomUserSeqMessage.fromBuffer(payload);

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.online,
        data: roomUserSeqMessage.totalUser.toInt(),
        color: LiveMessageColor.white,
        message: "",
        userName: "",
      ),
    );
  }

  void sendAck(var logId, String internalExt) {
    var obj = PushFrame();
    obj.payloadType = 'ack';
    obj.logId = logId;
    obj.payload = utf8.encode(internalExt);
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void joinRoom(args) {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  @override
  Future stop() async {
    _flushChatTimer?.cancel();
    _flushChatTimer = null;
    _pendingChatMessages.clear();
    onMessage = null;
    onClose = null;
    onReady = null;
    webScoketUtils?.close();
  }
}
