import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/export/data/csv_exporter.dart';
import 'package:blood_pressed/features/stats/domain/bp_analyzer.dart';
import 'package:blood_pressed/features/stats/domain/daily_measurements.dart';
import 'package:blood_pressed/features/stats/domain/trend_timeline.dart';

import 'daily_measurements_test.dart' show reading;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('允许单项血压，仍拒绝两项均空或非法已填值', () {
    expect(validateBpValues(systolic: 120, diastolic: null), isNull);
    expect(validateBpValues(systolic: null, diastolic: 80), isNull);
    expect(
      validateBpValues(systolic: null, diastolic: null),
      BpValidationError.needSysDia,
    );
    expect(
      validateBpValues(systolic: 0, diastolic: null),
      BpValidationError.sysRange,
    );
    expect(
      validateBpValues(systolic: null, diastolic: 0),
      BpValidationError.diaRange,
    );
    expect(
      validateBpValues(systolic: 120, diastolic: 130),
      BpValidationError.sysGreater,
    );
  });

  test('copyWith 显式清空与序列化保留空值，压差只使用同次合法读数', () {
    final full = reading(8, 120, 80);
    final partial = full.copyWith(diastolic: null);
    expect(partial.systolic, 120);
    expect(partial.diastolic, isNull);
    expect(partial.pulsePressure, isNull);
    expect(BpRecord.fromMap(partial.toMap()).diastolic, isNull);
    expect(partial.copyWith().diastolic, isNull);
    expect(full.pulsePressure, 40);
    expect(full.copyWith(systolic: 70).pulsePressure, isNull);
    expect(BpCategory.fromValues(120, null), BpCategory.incomplete);
  });

  test('各指标分开计数与均值；达标率和规律分析仅用完整有效记录', () {
    final readings = [
      reading(8, 120, null),
      reading(10, null, 90),
      reading(12, 140, 80, pulse: 70),
    ];
    final stats = BpStats.compute(readings);
    expect(stats.count, 3);
    expect(stats.systolicCount, 2);
    expect(stats.diastolicCount, 2);
    expect(stats.avgSystolic, 130);
    expect(stats.avgDiastolic, 85);
    expect(stats.avgPulse, 70);
    expect(stats.completeCount, 1);
    expect(stats.normalRate, 0);
    expect(BpAnalyzer.analyze(readings).totalCount, 1);
    final onlySys = BpStats.compute([readings.first]);
    expect(onlySys.avgDiastolic, isNull);
    expect(onlySys.maxDiastolic, isNull);
    expect(onlySys.normalRate, isNull);
    final empty = BpStats.compute([]);
    expect(empty.avgSystolic, isNull);
    expect(empty.normalRate, isNull);
  });

  test('缺日断线，完整时间精度及独立每日首末值保留', () {
    final days = DailyMeasurements.aggregate([
      reading(8, 120, null),
      reading(10, null, 85),
      reading(20, 130, 80),
      reading(8, 140, 90, day: 17),
    ]);
    expect(days.first.systolic!.count, 2);
    expect(days.first.diastolic!.first, 85);
    expect(days.first.diastolic!.count, 2);
    final timeline = TrendTimeline(days);
    expect(timeline.entries, hasLength(5));
    expect(timeline.entries[3], isNull);
    expect(
      TrendTimeline.xOf(DateTime(2026, 10, 17, 6), DateTime(2026, 10, 15)),
      2.25,
    );
    expect(
      TrendTimeline.xOf(
        DateTime(2026, 10, 15, 0, 0, 0, 500),
        DateTime(2026, 10, 15),
      ),
      closeTo(0.5 / 86400, 1e-12),
    );
  });

  test('CSV 缺失值为空单元格而非零或 null', () {
    final csv = const CsvExporter().buildCsv([reading(8, 120, null)]);
    expect(csv.split('\n')[1], contains(',120,,,'));
    expect(csv, isNot(contains('null')));
  });

  test('v1 数据库升级保留原记录、outbox、其他表及索引，并允许保存和清空单项', () async {
    final dir = await Directory.systemTemp.createTemp('bp_partial_migration_');
    final path = '${dir.path}/upgrade.db';
    final factory = databaseFactoryFfiNoIsolate;
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          await AppDatabase.openForTest(d);
          final schema =
              (await d.rawQuery(
                    "SELECT sql FROM sqlite_master WHERE name = 'bp_records'",
                  )).single['sql']
                  as String;
          await d.execute('DROP TABLE bp_records');
          await d.execute(
            schema
                .replaceAll('systolic INTEGER,', 'systolic INTEGER NOT NULL,')
                .replaceAll(
                  'diastolic INTEGER,',
                  'diastolic INTEGER NOT NULL,',
                ),
          );
          await d.execute(
            'CREATE INDEX idx_records_measured_at ON bp_records (measured_at DESC)',
          );
          await d.execute(
            'CREATE INDEX idx_records_sync_state ON bp_records (sync_state)',
          );
        },
      ),
    );
    final original = reading(8, 120, 80, pulse: 72).toMap();
    await old.insert('bp_records', original);
    await old.insert('sync_outbox', {
      'entity_type': 'bp_record',
      'entity_id': original['id'],
      'op': 'upsert',
      'payload': '{}',
      'created_at': 1,
    });
    await old.insert('chat_messages', {
      'id': 'chat',
      'role': 'user',
      'content': 'kept',
      'created_at': 1,
    });
    await old.close();
    final upgraded = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    try {
      expect((await upgraded.query('bp_records')).single, original);
      expect(await upgraded.query('sync_outbox'), hasLength(1));
      expect((await upgraded.query('chat_messages')).single['content'], 'kept');
      expect(
        (await upgraded.rawQuery('PRAGMA index_list(bp_records)'))
            .map((r) => r['name']),
        containsAll(['idx_records_measured_at', 'idx_records_sync_state']),
      );
      final partial = reading(10, 130, null, id: 'partial');
      await upgraded.insert('bp_records', partial.toMap());
      await upgraded.update(
        'bp_records',
        {'systolic': null, 'diastolic': 85},
        where: 'id = ?',
        whereArgs: ['partial'],
      );
      final result = BpRecord.fromMap(
        (await upgraded.query(
          'bp_records',
          where: 'id = ?',
          whereArgs: ['partial'],
        )).single,
      );
      expect(result.systolic, isNull);
      expect(result.diastolic, 85);
    } finally {
      await upgraded.close();
      AppDatabase.resetInstanceForTest();
      if (dir.absolute.path.startsWith(Directory.systemTemp.absolute.path)) {
        await dir.delete(recursive: true);
      }
    }
  });

  test('真实仓库保存和编辑单项血压，outbox 也携带 null', () async {
    final db = await AppDatabase.openForTest(
      await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath),
    );
    try {
      final outbox = OutboxDao(db);
      final repo = RecordsRepository(db, outbox);
      final partial = reading(8, 120, null);
      await repo.create(partial);
      expect((await repo.byId(partial.id))!.diastolic, isNull);
      await repo.update(partial.copyWith(systolic: null, diastolic: 85));
      final result = (await repo.byId(partial.id))!;
      expect(result.systolic, isNull);
      expect(result.diastolic, 85);
      expect(await outbox.count(), 2);
      expect((await outbox.take(2)).last.payload, contains('"systolic":null'));
    } finally {
      await db.db.close();
      AppDatabase.resetInstanceForTest();
    }
  });
}
