/// 趋势自定义时间段测试：TrendQuery 区间语义与 x 轴锚定（纯逻辑）。
library;

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
      final q = TrendQuery(days: 31, from: from, to: to);
      expect(q.isCustom, isTrue);
      expect(q.spanDays, 31);
      expect(q.endDate.year, 2026);
      expect(q.endDate.month, 8);
      expect(q.endDate.day, 31);
    });

    test('相同区间相等，不同区间不等', () {
      final a = TrendQuery(days: 31, from: _day(2026, 8, 1), to: _day(2026, 8, 31));
      final b = TrendQuery(days: 31, from: _day(2026, 8, 1), to: _day(2026, 8, 31));
      final c = TrendQuery(days: 31, from: _day(2026, 8, 2), to: _day(2026, 8, 31));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('单日区间：span=1', () {
      final q = TrendQuery(days: 1, from: _day(2026, 8, 1), to: _day(2026, 8, 1));
      expect(q.spanDays, 1);
    });
  });

  group('xOf 自定义区间锚定', () {
    test('区间末日为 x 轴最右端（不再锚定今天）', () {
      final q = TrendQuery(
        days: 3,
        from: _day(2026, 6, 1),
        to: _day(2026, 6, 3),
      );
      // 区间末日 → 最右
      expect(xOf(_day(2026, 6, 3), q), 2.0);
      // 区间首日 → 最左
      expect(xOf(_day(2026, 6, 1), q), 0.0);
      // 区间中间日
      expect(xOf(_day(2026, 6, 2), q), 1.0);
    });

    test('区间外的日期被钳制到轴范围内', () {
      final q = TrendQuery(
        days: 3,
        from: _day(2026, 6, 1),
        to: _day(2026, 6, 3),
      );
      expect(xOf(_day(2026, 5, 30), q), 0.0);
      expect(xOf(_day(2026, 6, 10), q), 2.0);
    });

    test('预设模式：仍以今天为末日', () {
      final q = TrendQuery(days: 7);
      final today = DateTime.now();
      expect(xOf(today, q), 6.0);
      expect(xOf(today.subtract(const Duration(days: 6)), q), 0.0);
    });
  });
}
