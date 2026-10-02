import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/common/core_error.dart';
import 'package:simple_live_core/src/danmaku/douyu_danmaku.dart';
import 'package:simple_live_core/src/interface/live_danmaku.dart';
import 'package:simple_live_core/src/interface/live_site.dart';
import 'package:simple_live_core/src/model/live_anchor_item.dart';
import 'package:simple_live_core/src/model/live_category.dart';
import 'package:simple_live_core/src/model/live_message.dart';
import 'package:simple_live_core/src/model/live_play_url.dart';
import 'package:simple_live_core/src/model/live_contribution_rank.dart';
import 'package:simple_live_core/src/model/live_room_item.dart';
import 'package:simple_live_core/src/model/live_search_result.dart';
import 'package:simple_live_core/src/model/live_room_detail.dart';
import 'package:simple_live_core/src/model/live_play_quality.dart';
import 'package:simple_live_core/src/model/live_category_result.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:simple_live_core/src/scripts/douyu_sign.dart';

class DouyuSite implements LiveSite {
  /// Optional logged-in Cookie. Anonymous playback remains supported, but
  /// Douyu may cap anonymous high-quality streams after a short period.
  String cookie = "";

  /// 本设备持久化的匿名设备号（32 位 hex），由 App 层生成并注入。
  /// 作用：匿名请求不再共用写死的假 did（千万用户共享一个"设备"是风控
  /// 掐流的典型特征），签名与 dy_did/acf_did Cookie 保持一致。
  String deviceId = "";

  /// 进程内兜底设备号：App 层未注入时也保证同一进程内身份稳定。
  static final String _processFallbackDid = _generateHexDid(32);

  static String _generateHexDid(int length) {
    var random = Random.secure();
    return List.generate(
      length,
      (i) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  /// 从 cookie 字符串中解析指定键的值
  String _cookieValue(String key) {
    for (var part in cookie.split(';')) {
      var kv = part.trim().split('=');
      if (kv.length >= 2 && kv[0] == key) {
        return kv.sublist(1).join('=');
      }
    }
    return "";
  }

  /// 参与签名的设备号：优先登录 cookie 的 acf_did（与请求 Cookie 身份一致），
  /// 其次 App 注入的持久化 deviceId，最后进程内随机值。
  String get _deviceDid {
    final fromCookie = _cookieValue("acf_did");
    if (fromCookie.isNotEmpty) {
      return fromCookie;
    }
    if (deviceId.trim().isNotEmpty) {
      return deviceId.trim();
    }
    return _processFallbackDid;
  }

  /// 组装请求 Cookie：登录 cookie 原样保留；缺失 dy_did/acf_did 时补上
  /// 与签名一致的设备号，保证匿名请求也带稳定设备身份。
  String get _deviceCookieHeader {
    final trimmed = cookie.trim();
    final did = _deviceDid;
    var parts = <String>[];
    if (trimmed.isNotEmpty) {
      parts.add(trimmed);
    }
    if (_cookieValue("dy_did").isEmpty) {
      parts.add("dy_did=$did");
    }
    if (_cookieValue("acf_did").isEmpty) {
      parts.add("acf_did=$did");
    }
    return parts.join("; ");
  }

  Map<String, String> get _requestHeaders => {
    'referer': 'https://www.douyu.com/',
    'user-agent':
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    if (_deviceCookieHeader.isNotEmpty) 'Cookie': _deviceCookieHeader,
  };

  @override
  String id = "douyu";

  @override
  String name = "斗鱼直播";

  @override
  LiveDanmaku getDanmaku() => DouyuDanmaku();

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson(
      "https://m.douyu.com/api/cate/list",
    );
    var subCateList = result["data"]["cate2Info"] as List;
    for (var item in result["data"]["cate1Info"]) {
      var cate1Id = item["cate1Id"];
      var cate1Name = item["cate1Name"];
      List<LiveSubCategory> subCategories = [];
      subCateList.where((x) => x["cate1Id"] == cate1Id).forEach((element) {
        subCategories.add(
          LiveSubCategory(
            pic: element["icon"],
            id: element["cate2Id"].toString(),
            parentId: cate1Id.toString(),
            name: element["cate2Name"].toString(),
          ),
        );
      });
      categories.add(
        LiveCategory(
          id: cate1Id.toString(),
          name: cate1Name.toString(),
          children: subCategories,
        ),
      );
    }
    // 根据ID排序
    categories.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/gapi/rkc/directory/mixList/2_${category.id}/$page",
      queryParameters: {},
    );

    var items = <LiveRoomItem>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var roomItem = LiveRoomItem(
        cover: item['rs16'].toString(),
        online: item['ol'],
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        userName: item['nn'].toString(),
      );
      items.add(roomItem);
    }
    var hasMore = page < result['data']['pgcnt'];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) async {
    var data = await _getFreshPlayArgs(detail.roomId, fallback: detail.data);
    data += "&cdn=&rate=-1&ver=Douyu_223061205&iar=1&ive=1&hevc=0&fa=0";
    List<LivePlayQuality> qualities = [];
    var result = await HttpClient.instance.postJson(
      "https://www.douyu.com/lapi/live/getH5Play/${detail.roomId}",
      data: data,
      header: _requestHeaders,
      formUrlEncoded: true,
    );
    final errorCode = result is Map ? result["error"] : null;
    final payload = result is Map ? result["data"] : null;
    if (errorCode != null && errorCode.toString() != "0") {
      throw CoreError("斗鱼播放质量请求失败：${result["msg"] ?? errorCode}");
    }
    if (payload is! Map ||
        payload["cdnsWithName"] is! List ||
        payload["multirates"] is! List) {
      throw CoreError("斗鱼返回了无效的播放质量");
    }

    var cdns = <String>[];
    for (var item in payload["cdnsWithName"]) {
      cdns.add(item["cdn"].toString());
    }

    // 如果cdn以scdn开头，将其放到最后
    cdns.sort((a, b) {
      if (a.startsWith("scdn") && !b.startsWith("scdn")) {
        return 1;
      } else if (!a.startsWith("scdn") && b.startsWith("scdn")) {
        return -1;
      }
      return 0;
    });

    for (var item in payload["multirates"]) {
      qualities.add(
        LivePlayQuality(
          quality: item["name"].toString(),
          data: DouyuPlayData(item["rate"], cdns),
        ),
      );
    }
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    // The signed playback arguments expire while a room remains open.  A
    // retry must fetch a new server script and sign it again; reusing the
    // value captured by getRoomDetail causes Douyu to return a timestamp error
    // after roughly ten minutes for high-quality anonymous streams.
    var args = await _getFreshPlayArgs(detail.roomId, fallback: detail.data);
    var data = quality.data as DouyuPlayData;

    List<String> urls = [];
    for (var item in data.cdns) {
      var url = await getPlayUrl(detail.roomId, args, data.rate, item);
      if (url.isNotEmpty) {
        urls.add(url);
      }
    }
    return LivePlayUrl(urls: urls);
  }

  Future<String> getPlayUrl(
    String roomId,
    String args,
    int rate,
    String cdn,
  ) async {
    args += "&cdn=$cdn&rate=$rate";
    var result = await HttpClient.instance.postJson(
      "https://www.douyu.com/lapi/live/getH5Play/$roomId",
      data: args,
      header: {..._requestHeaders, 'referer': 'https://www.douyu.com/$roomId'},
      formUrlEncoded: true,
    );

    final errorCode = result is Map ? result["error"] : null;
    final data = result is Map ? result["data"] : null;
    if (errorCode != null && errorCode.toString() != "0") {
      throw CoreError("斗鱼播放地址请求失败：${result["msg"] ?? errorCode}");
    }
    if (data is! Map || data["rtmp_url"] == null || data["rtmp_live"] == null) {
      throw CoreError("斗鱼返回了无效的播放地址");
    }
    return "${data["rtmp_url"]}/${HtmlUnescape().convert(data["rtmp_live"].toString())}";
  }

  Future<String> _getFreshPlayArgs(String roomId, {Object? fallback}) async {
    try {
      final jsEncResult = await HttpClient.instance.getText(
        "https://www.douyu.com/swf_api/homeH5Enc?rids=$roomId",
        queryParameters: {},
        header: {
          ..._requestHeaders,
          'referer': 'https://www.douyu.com/$roomId',
        },
      );
      final decoded = json.decode(jsEncResult);
      final payload = decoded is Map ? decoded["data"] : null;
      final script = payload is Map ? payload["room$roomId"] : null;
      if (script is String && script.isNotEmpty) {
        final signed = DouyuSign.getSign(script, roomId, _deviceDid);
        if (signed.isNotEmpty) {
          return signed;
        }
      }
    } catch (_) {
      // Keep the original arguments as a compatibility fallback for transient
      // failures; the subsequent playback response is validated below.
    }
    final value = fallback?.toString() ?? "";
    if (value.isEmpty) {
      throw CoreError("斗鱼播放签名刷新失败");
    }
    return value;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/weblist/apinc/allpage/6/$page",
      queryParameters: {},
    );

    var items = <LiveRoomItem>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var roomItem = LiveRoomItem(
        cover: item['rs16'].toString(),
        online: item['ol'],
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        userName: item['nn'].toString(),
      );
      items.add(roomItem);
    }
    var hasMore = page < result['data']['pgcnt'];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    Map roomInfo = await _getRoomInfo(roomId);

    Map h5RoomInfo = await HttpClient.instance.getJson(
      "https://www.douyu.com/swf_api/h5room/$roomId",
      queryParameters: {},
      header: {..._requestHeaders, 'referer': 'https://www.douyu.com/$roomId'},
    );
    String? showTime = h5RoomInfo["data"]?["show_time"]?.toString();

    final playArgs = await _getFreshPlayArgs(roomInfo["room_id"].toString());

    return LiveRoomDetail(
      cover: roomInfo["room_pic"].toString(),
      online: int.tryParse(roomInfo["room_biz_all"]["hot"].toString()) ?? 0,
      roomId: roomInfo["room_id"].toString(),
      title: roomInfo["room_name"].toString(),
      userName: roomInfo["owner_name"].toString(),
      userAvatar: roomInfo["owner_avatar"].toString(),
      introduction: roomInfo["show_details"].toString(),
      notice: "",
      status: roomInfo["show_status"] == 1 && roomInfo["videoLoop"] != 1,
      danmakuData: roomInfo["room_id"].toString(),
      data: playArgs,
      url: "https://www.douyu.com/$roomId",
      isRecord: roomInfo["videoLoop"] == 1,
      showTime: showTime,
      categoryId:
          roomInfo["cate2Id"]?.toString() ??
          roomInfo["cate_id"]?.toString() ??
          roomInfo["cid1"]?.toString(),
      categoryName:
          roomInfo["cate2Name"]?.toString() ??
          roomInfo["game_name"]?.toString() ??
          roomInfo["cate_name"]?.toString(),
      categoryParentId:
          roomInfo["cate1Id"]?.toString() ?? roomInfo["cid2"]?.toString(),
      categoryParentName:
          roomInfo["cate1Name"]?.toString() ??
          roomInfo["parent_cate_name"]?.toString(),
      categoryPic:
          roomInfo["game_icon"]?.toString() ??
          roomInfo["game_icon_url"]?.toString(),
    );
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchShow",
      queryParameters: {"kw": keyword, "page": page, "pageSize": 20},
      header: {
        ..._requestHeaders,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
        'referer': 'https://www.douyu.com/search/',
      },
    );
    if (result['error'] != 0) {
      throw Exception(result['msg']);
    }
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["relateShow"]) {
      var roomItem = LiveRoomItem(
        roomId: item["rid"].toString(),
        title: item["roomName"].toString(),
        cover: item["roomSrc"].toString(),
        userName: item["nickName"].toString(),
        online: parseHotNum(item["hot"].toString()),
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["relateShow"].isNotEmpty;
    return LiveSearchRoomResult(hasMore: hasMore, items: items);
  }

  Future<Map> _getRoomInfo(String roomId) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/betard/$roomId",
      queryParameters: {},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
      },
    );
    Map roomInfo;
    if (result is String) {
      roomInfo = json.decode(result)["room"];
    } else {
      roomInfo = result["room"];
    }
    return roomInfo;
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchUser",
      queryParameters: {
        "kw": keyword,
        "page": page,
        "pageSize": 20,
        "filterType": 1,
      },
      header: {
        ..._requestHeaders,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
        'referer': 'https://www.douyu.com/search/',
      },
    );

    var items = <LiveAnchorItem>[];
    for (var item in result["data"]["relateUser"]) {
      var liveStatus =
          (int.tryParse(item["anchorInfo"]["isLive"].toString()) ?? 0) == 1;
      var roomType =
          (int.tryParse(item["anchorInfo"]["roomType"].toString()) ?? 0);
      var roomItem = LiveAnchorItem(
        roomId: item["anchorInfo"]["rid"].toString(),
        avatar: item["anchorInfo"]["avatar"].toString(),
        userName: item["anchorInfo"]["nickName"].toString(),
        liveStatus: liveStatus && roomType == 0,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["relateUser"].isNotEmpty;
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var roomInfo = await _getRoomInfo(roomId);
    return roomInfo["show_status"] == 1 && roomInfo["videoLoop"] != 1;
  }

  int parseHotNum(String hn) {
    try {
      var num = double.parse(hn.replaceAll("万", ""));
      if (hn.contains("万")) {
        num *= 10000;
      }
      return num.round();
    } catch (_) {
      return -999;
    }
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
    LiveRoomDetail? detail,
  }) {
    //尚不支持
    return Future.value([]);
  }

  @override
  Future<List<LiveContributionRankItem>> getContributionRank({
    required String roomId,
    LiveRoomDetail? detail,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/interact/comm/fanshome/rank/top10",
      queryParameters: {"rid": roomId},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    );
    final items = (result["data"]?["intimacyRank"] as List?) ?? const [];
    return items.map((item) {
      return LiveContributionRankItem(
        rank: int.tryParse(item["rank"].toString()) ?? 0,
        userName: item["nickname"]?.toString() ?? "",
        avatar: item["avatar"]?.toString() ?? "",
        scoreText: item["value"]?.toString() ?? "0",
        scoreDetail: "亲密度",
      );
    }).toList();
  }
}

class DouyuPlayData {
  final int rate;
  final List<String> cdns;
  DouyuPlayData(this.rate, this.cdns);
}
