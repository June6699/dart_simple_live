import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';

void main() {
  group('ParseController.extractHttpUrl', () {
    test('extracts a Douyin short URL from share text', () {
      const shareText =
          '正在直播，复制链接打开抖音 https://v.douyin.com/GiurKu1HX_I/ 5@9.com';

      expect(
        ParseController.extractHttpUrl(shareText),
        'https://v.douyin.com/GiurKu1HX_I/',
      );
    });

    test('removes punctuation appended by prose', () {
      expect(
        ParseController.extractHttpUrl(
          '直播地址：https://live.douyin.com/123456，欢迎观看',
        ),
        'https://live.douyin.com/123456',
      );
    });

    test('returns empty text when no URL exists', () {
      expect(ParseController.extractHttpUrl('没有链接'), isEmpty);
    });
  });
}
