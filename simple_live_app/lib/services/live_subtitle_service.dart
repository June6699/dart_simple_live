import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

abstract class LiveSubtitleEngine {
  Future<void> start({
    required String modelPath,
    required String language,
  });

  Future<void> stop();

  Stream<String> get textStream;
}

class LiveSubtitleService extends GetxService {
  static LiveSubtitleService get instance => Get.find<LiveSubtitleService>();

  final RxString subtitleText = "".obs;
  final RxBool running = false.obs;
  LiveSubtitleEngine? engine;

  Timer? _previewTimer;
  StreamSubscription<String>? _engineSubscription;

  void setEngine(LiveSubtitleEngine value) {
    engine = value;
  }

  bool get isDesktopExperiment =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  String get platformStatusLabel => isDesktopExperiment ? "当前平台可实验" : "当前平台待验证";

  bool validateModelPathSync(String path) {
    final value = path.trim();
    if (value.isEmpty) {
      return false;
    }
    if (kIsWeb) {
      return false;
    }
    return File(value).existsSync() || Directory(value).existsSync();
  }

  Future<bool> validateModelPath(String path) async {
    final value = path.trim();
    if (value.isEmpty || kIsWeb) {
      return false;
    }
    return await File(value).exists() || await Directory(value).exists();
  }

  Future<bool> syncPreviewFromSettings() async {
    final settings = AppSettingsController.instance;
    if (!settings.liveSubtitleEnable.value) {
      stop();
      return true;
    }
    final modelPath = settings.liveSubtitleModelPath.value.trim();
    if (!await validateModelPath(modelPath)) {
      stop();
      return false;
    }
    if (engine != null) {
      await _startEngine(
        modelPath: modelPath,
        language: settings.liveSubtitleLanguage.value,
      );
      return true;
    }
    startPreview(
      language: settings.liveSubtitleLanguage.value,
      forceRestart: true,
    );
    return true;
  }

  void startPreview({String language = "auto", bool forceRestart = false}) {
    if (!forceRestart && running.value && subtitleText.value.isNotEmpty) {
      return;
    }
    _engineSubscription?.cancel();
    _previewTimer?.cancel();
    running.value = true;

    final labels = _previewLabels(language);
    var index = 0;
    subtitleText.value = labels[index];
    _previewTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      index = (index + 1) % labels.length;
      subtitleText.value = labels[index];
    });
  }

  Future<void> _startEngine({
    required String modelPath,
    required String language,
  }) async {
    _previewTimer?.cancel();
    _previewTimer = null;
    await _engineSubscription?.cancel();
    final currentEngine = engine!;
    await currentEngine.start(modelPath: modelPath, language: language);
    _engineSubscription = currentEngine.textStream.listen((text) {
      subtitleText.value = text;
    });
    running.value = true;
  }

  void stop() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _engineSubscription?.cancel();
    _engineSubscription = null;
    unawaited(engine?.stop());
    running.value = false;
    subtitleText.value = "";
  }

  List<String> _previewLabels(String language) {
    final languageLabel = switch (language) {
      "zh" => "中文",
      "en" => "English",
      "ja" => "日本語",
      "ko" => "한국어",
      _ => "自动语言",
    };
    return [
      "字幕预览：$languageLabel",
      "实时字幕框架已启用",
    ];
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
