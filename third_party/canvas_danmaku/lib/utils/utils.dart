import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/models/danmaku_content_item.dart';

class Utils {
  static String normalizeImageUrl(String url) {
    final value = url.trim();
    if (value.startsWith("//")) {
      return "https:$value";
    }
    return value;
  }

  static Size measureContent(
    DanmakuContentItem content,
    double fontSize,
    int fontWeight,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: content.text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.values[fontWeight],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final imageCount = (content.imageUrls ?? const <String>[])
        .where((url) => url.trim().isNotEmpty)
        .length;
    final imageSize = fontSize * 1.25;
    return Size(
      textPainter.width + imageCount * imageSize,
      textPainter.height > imageSize ? textPainter.height : imageSize,
    );
  }

  static ui.Paragraph generateParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
        fontWeight: FontWeight.values[fontWeight],
        textDirection: TextDirection.ltr,
      ),
    )..pushStyle(ui.TextStyle(color: content.color));
    _appendContent(builder, content, fontSize);
    return builder.build()
      ..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static ui.Paragraph generateStrokeParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
  ) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    final ui.ParagraphBuilder strokeBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
        fontWeight: FontWeight.values[fontWeight],
        textDirection: TextDirection.ltr,
      ),
    )..pushStyle(ui.TextStyle(foreground: strokePaint));
    _appendContent(strokeBuilder, content, fontSize);

    return strokeBuilder.build()
      ..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static void drawEmojiImages(
    Canvas canvas,
    ui.Paragraph paragraph,
    DanmakuContentItem content,
    Offset offset,
    Map<String, ui.Image> imageCache,
  ) {
    final imageUrls = (content.imageUrls ?? const <String>[])
        .map(normalizeImageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
    if (imageUrls.isEmpty) {
      return;
    }
    final boxes = paragraph.getBoxesForPlaceholders();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var i = 0; i < imageUrls.length && i < boxes.length; i++) {
      final image = imageCache[imageUrls[i]];
      if (image == null) {
        continue;
      }
      final box = boxes[i];
      final dst = Rect.fromLTRB(
        offset.dx + box.left,
        offset.dy + box.top,
        offset.dx + box.right,
        offset.dy + box.bottom,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        paint,
      );
    }
  }

  static void _appendContent(
    ui.ParagraphBuilder builder,
    DanmakuContentItem content,
    double fontSize,
  ) {
    builder.addText(content.text);
    final imageSize = fontSize * 1.25;
    for (final url in content.imageUrls ?? const <String>[]) {
      if (url.trim().isEmpty) {
        continue;
      }
      builder.addPlaceholder(
        imageSize,
        imageSize,
        ui.PlaceholderAlignment.middle,
      );
    }
  }
}
