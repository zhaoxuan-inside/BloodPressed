/// 趋势自定义时间段测试：TrendQuery 区间语义与 x 轴锚定（纯逻辑）。
library;

import 'package:blood_pressed/features/stats/domain/trend_timeline.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/stats/presentation/controllers/trend_providers.dart';

DateTime _day(int y, int m, int d) => DateTime(y, m, d);

void main() {
  group('TrendQuery 自定义时间段', () {
    test('预设模式：isCustom=false，endDate 为当前时刻', () {
      final q = TrendQuery(days: 30);
      expect(q.isCustom, isFalse);
      expect(q.endDate, isNotNull);
    });

    test('自定义模式：span 为首尾闭区间天数，endDate 为结束日', () {
      final from = _day(2026, 8, 1);
      final to = _day(2026, 8, 31);
      final q = TrendQuery.custom(from, to);
      expect(q.isCustom, isTrue);
      expect(q.days, 31);
      expect(q.endDate.year, 2026);
      expect(q.endDate.month, 8);
      expect(q.endDate.day, 31);
      expect(
        q.to,
        DateTime(2026, 9, 1).subtract(const Duration(microseconds: 1)),
      );
    });

    test('相同区间相等，不同区间不等', () {
      final a = TrendQuery(
        days: 31,
        from: _day(2026, 8, 1),
        to: _day(2026, 8, 31),
      );
      final b = TrendQuery(
        days: 31,
        from: _day(2026, 8, 1),
        to: _day(2026, 8, 31),
      );
      final c = TrendQuery(
        days: 31,
        from: _day(2026, 8, 2),
        to: _day(2026, 8, 31),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('单日区间：span=1', () {
      final q = TrendQuery.custom(_day(2026, 8, 1), _day(2026, 8, 1));
      expect(q.days, 1);
    });
  });

  test('原始测量横轴保留实际时刻及日期间隔', () {
    expect(
      TrendTimeline.xOf(DateTime(2026, 6, 1, 6), DateTime(2026, 6, 1)),
      0.25,
    );
    expect(
      TrendTimeline.xOf(DateTime(2026, 6, 3, 18), DateTime(2026, 6, 1)),
      2.75,
    );
  });
}
