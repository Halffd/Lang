import 'package:flutter_test/flutter_test.dart';

import 'package:lang/presentation/widgets/video/player_time.dart';

void main() {
  group('formatPlayerTime', () {
    test('drops the zero padding on the minutes', () {
      // YouTube writes chapter times as `0:00`, not `00:00`
      expect(formatPlayerTime(Duration.zero), '0:00');
      expect(formatPlayerTime(const Duration(seconds: 5)), '0:05');
      expect(formatPlayerTime(const Duration(minutes: 1)), '1:00');
    });

    test('pads the seconds', () {
      expect(formatPlayerTime(const Duration(seconds: 9)), '0:09');
      expect(formatPlayerTime(const Duration(minutes: 2, seconds: 3)), '2:03');
    });

    test('adds the hours past an hour', () {
      expect(formatPlayerTime(const Duration(hours: 1)), '1:00:00');
      expect(
        formatPlayerTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('keeps the minutes in range once the hours roll over', () {
      // 90 minutes is one hour and a half, not "90:00"
      expect(formatPlayerTime(const Duration(minutes: 90)), '1:30:00');
    });
  });
}
