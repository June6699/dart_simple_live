import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class ProfileBackupService extends GetxService {
  static ProfileBackupService get instance => Get.find<ProfileBackupService>();

  static const schema = "simple_live_profile";
  static const schemaVersion = 2;

  static const Set<String> _excludedSettings = {
    LocalStorageService.kFirstRun,
    LocalStorageService.kLastLiveRoom,
    LocalStorageService.kLastLiveRoomResumePending,
    LocalStorageService.kWebDAVUri,
    LocalStorageService.kWebDAVUser,
    LocalStorageService.kWebDAVPassword,
    LocalStorageService.kWebDAVLastUploadTime,
    LocalStorageService.kWebDAVLastRecoverTime,
    LocalStorageService.kBilibiliCookie,
    LocalStorageService.kDouyinCookie,
  };

  Map<String, dynamic> exportProfileMap() {
    final shieldPayload = _exportShieldValues();
    final settingsPayload = _exportSettings();
    final followUsers = DBService.instance
        .getFollowList()
        .map((item) => item.toJson())
        .toList();
    final followUserTags = DBService.instance
        .getFollowTagList()
        .map((item) => item.toJson())
        .toList();
    final histories =
        DBService.instance.getHistores().map((item) => item.toJson()).toList();
    return {
      "schema": schema,
      "schemaVersion": schemaVersion,
      "appVersion": Utils.packageInfo.version,
      "platform": Platform.operatingSystem,
      "exportedAt": DateTime.now().toIso8601String(),
      "settings": settingsPayload,
      "danmuShield": shieldPayload,
      "shieldPresets": _exportShieldPresets(),
      "followUsers": followUsers,
      "followUserTags": followUserTags,
      "histories": histories,
      "summary": {
        "settingCount": settingsPayload.length,
        "keywordShieldCount": (shieldPayload["keywords"] as List).length,
        "userShieldCount": (shieldPayload["users"] as List).length,
        "followUserCount": followUsers.length,
        "followTagCount": followUserTags.length,
        "historyCount": histories.length,
      },
    };
  }

  String exportProfileJson() {
    return const JsonEncoder.withIndent("  ").convert(exportProfileMap());
  }

  Future<ProfileImportSummary> importProfileJson(
    String content, {
    bool overwrite = false,
  }) async {
    final decoded = jsonDecode(content);
    if (decoded is! Map || decoded["schema"] != schema) {
      throw const FormatException("不是 Simple Live 配置包");
    }
    if ((decoded["schemaVersion"] as num?)?.toInt() != schemaVersion) {
      throw const FormatException("暂不支持该配置包版本");
    }
    return importProfileMap(
      decoded.cast<String, dynamic>(),
      overwrite: overwrite,
    );
  }

  Future<ProfileImportSummary> importProfileMap(
    Map<String, dynamic> payload, {
    bool overwrite = false,
  }) async {
    final summary = ProfileImportSummary();
    await _importSettings(payload["settings"], summary, overwrite);
    await _importShields(payload["danmuShield"], summary, overwrite);
    await _importShieldPresets(payload["shieldPresets"], summary, overwrite);
    await _importFollowUsers(payload["followUsers"], summary, overwrite);
    await _importFollowTags(payload["followUserTags"], summary, overwrite);
    await _importHistories(payload["histories"], summary, overwrite);

    AppSettingsController.instance.reloadFromStorage();
    await LiveSubtitleService.instance.syncPreviewFromSettings();
    await FollowService.instance.loadData(updateStatus: false);
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
    EventBus.instance.emit(Constant.kUpdateHistory, 0);
    return summary;
  }

  Map<String, dynamic> _exportSettings() {
    final result = <String, dynamic>{};
    for (final entry
        in LocalStorageService.instance.settingsBox.toMap().entries) {
      final key = entry.key.toString();
      if (_excludedSettings.contains(key)) {
        continue;
      }
      result[key] = _safeJsonValue(entry.value);
    }
    return result;
  }

  Map<String, dynamic> _exportShieldValues() {
    final raw = LocalStorageService.instance.shieldBox.values
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    final keywords = AppSettingsControllerSafe.keywordValues()..sort();
    final userGroups = AppSettingsControllerSafe.userGroups();
    final users = userGroups.values.expand((e) => e).toSet().toList()..sort();
    return {
      "raw": raw,
      "keywords": keywords,
      "users": users,
      "userGroups": userGroups,
    };
  }

  List<Map<String, dynamic>> _exportShieldPresets() {
    final result = <Map<String, dynamic>>[];
    for (final entry
        in LocalStorageService.instance.shieldPresetBox.toMap().entries) {
      dynamic value = entry.value;
      try {
        value = jsonDecode(entry.value.toString());
      } catch (_) {}
      result.add({
        "name": entry.key.toString(),
        "value": _safeJsonValue(value),
      });
    }
    result.sort((a, b) => a["name"].toString().compareTo(b["name"].toString()));
    return result;
  }

  Future<void> _importSettings(
    dynamic rawSettings,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (rawSettings is! Map) {
      return;
    }
    if (overwrite) {
      await _clearImportableSettings();
    }
    final values = <dynamic, dynamic>{};
    for (final entry in rawSettings.entries) {
      final key = entry.key.toString();
      if (_excludedSettings.contains(key)) {
        continue;
      }
      values[key] = entry.value;
    }
    await LocalStorageService.instance.settingsBox.putAll(values);
    summary.settings = values.length;
  }

  Future<void> _clearImportableSettings() async {
    final keys = LocalStorageService.instance.settingsBox.keys
        .where((key) => !_excludedSettings.contains(key.toString()))
        .toList();
    if (keys.isNotEmpty) {
      await LocalStorageService.instance.settingsBox.deleteAll(keys);
    }
  }

  Future<void> _importShields(
    dynamic rawShield,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (overwrite) {
      await AppSettingsControllerSafe.clearShieldValues();
    }
    if (rawShield is Map) {
      final rawValues = rawShield["raw"];
      if (rawValues is List && rawValues.isNotEmpty) {
        for (final value in rawValues) {
          AppSettingsControllerSafe.importShieldValue(value.toString());
          summary.shields++;
        }
        return;
      }
      final keywords = rawShield["keywords"];
      if (keywords is List) {
        for (final keyword in keywords) {
          AppSettingsControllerSafe.addKeyword(keyword.toString());
          summary.shields++;
        }
      }
      final groups = rawShield["userGroups"];
      if (groups is Map) {
        for (final entry in groups.entries) {
          final users = entry.value;
          if (users is! List) {
            continue;
          }
          for (final user in users) {
            AppSettingsControllerSafe.addUser(
              user.toString(),
              siteId: entry.key.toString(),
            );
            summary.shields++;
          }
        }
      }
    }
  }

  Future<void> _importShieldPresets(
    dynamic rawPresets,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (overwrite) {
      await LocalStorageService.instance.shieldPresetBox.clear();
    }
    if (rawPresets is! List) {
      return;
    }
    for (final item in rawPresets) {
      if (item is! Map) {
        continue;
      }
      final name = item["name"]?.toString().trim() ?? "";
      if (name.isEmpty) {
        continue;
      }
      final value = item["value"];
      await LocalStorageService.instance.shieldPresetBox.put(
        name,
        value is String ? value : jsonEncode(value),
      );
      summary.shieldPresets++;
    }
    AppSettingsControllerSafe.reloadShields();
  }

  Future<void> _importFollowUsers(
    dynamic rawUsers,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (overwrite) {
      await DBService.instance.followBox.clear();
    }
    if (rawUsers is! List) {
      return;
    }
    for (final item in rawUsers) {
      if (item is! Map) {
        continue;
      }
      final user = FollowUser.fromJson(item.cast<String, dynamic>());
      await DBService.instance.followBox.put(user.id, user);
      summary.followUsers++;
    }
  }

  Future<void> _importFollowTags(
    dynamic rawTags,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (overwrite) {
      await DBService.instance.tagBox.clear();
    }
    if (rawTags is! List) {
      return;
    }
    for (final item in rawTags) {
      if (item is! Map) {
        continue;
      }
      final tag = FollowUserTag.fromJson(item.cast<String, dynamic>());
      await DBService.instance.tagBox.put(tag.id, tag);
      summary.followTags++;
    }
  }

  Future<void> _importHistories(
    dynamic rawHistories,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (overwrite) {
      await DBService.instance.historyBox.clear();
    }
    if (rawHistories is! List) {
      return;
    }
    for (final item in rawHistories) {
      if (item is! Map) {
        continue;
      }
      final history = History.fromJson(item.cast<String, dynamic>());
      final old = DBService.instance.historyBox.get(history.id);
      if (!overwrite &&
          old != null &&
          old.updateTime.isAfter(history.updateTime)) {
        continue;
      }
      await DBService.instance.addOrUpdateHistory(history);
      summary.histories++;
    }
  }

  dynamic _safeJsonValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Iterable) {
      return value.map(_safeJsonValue).toList();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _safeJsonValue(entry.value),
      };
    }
    return value.toString();
  }
}

class ProfileImportSummary {
  int settings = 0;
  int shields = 0;
  int shieldPresets = 0;
  int followUsers = 0;
  int followTags = 0;
  int histories = 0;

  String get message =>
      "设置 $settings 项，屏蔽 $shields 项，预设 $shieldPresets 个，关注 $followUsers 个，标签 $followTags 个，历史 $histories 条";
}

class AppSettingsControllerSafe {
  static List<String> keywordValues() {
    return AppSettingsController.instance.shieldList.toList();
  }

  static Map<String, List<String>> userGroups() {
    return AppSettingsController.instance.getUserShieldGroupSnapshot();
  }

  static void importShieldValue(String value) {
    AppSettingsController.instance.importShieldValue(value);
  }

  static void addKeyword(String value) {
    AppSettingsController.instance.addShieldList(value);
  }

  static void addUser(String value, {String? siteId}) {
    AppSettingsController.instance.addUserShieldList(value, siteId: siteId);
  }

  static Future<void> clearShieldValues() {
    return AppSettingsController.instance.clearShieldList();
  }

  static void reloadShields() {
    AppSettingsController.instance.refreshShieldData();
  }
}
