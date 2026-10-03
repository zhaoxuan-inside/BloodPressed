import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late OutboxDao outbox;
  late RecordsRepository repo;

  BpRecord record({
    String? id,
    int sys = 120,
    int dia = 80,
    int? pulse,
    DateTime? at,
    MeasureArm arm = MeasureArm.left,
  }) {
    final now = DateTime.now();
    return BpRecord(
      id: id ?? 'id-$sys-$dia-${now.microsecondsSinceEpoch}',
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      measuredAt: at ?? now,
      arm: arm,
      source: RecordSource.manual,
      deviceId: 'test-device',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    AppDatabase.resetInstanceForTest();
    db = await AppDatabase.openForTest(
        await databaseFactory.openDatabase(inMemoryDatabasePath));
    outbox = OutboxDao(db);
    repo = RecordsRepository(db, outbox);
  });

  tearDown(() async {
    await db.db.close();
  });

  group('记录仓库', () {
    test('创建后可查询，outbox 生成 upsert', () async {
      await repo.create(record(sys: 128, dia: 84));
      final list = await repo.list();
      expect(list, hasLength(1));
      expect(list.first.systolic, 128);
      expect(await outbox.count(), 1);
      final entry = (await outbox.take(1)).first;
      expect(entry.op, 'upsert');
      expect(entry.entityType, 'bp_record');
    });

    test('软删除不物理移除，outbox 生成 delete', () async {
      final r = record();
      await repo.create(r);
      await repo.softDelete(r.id, deviceId: 'test-device');

      expect(await repo.list(), isEmpty);
      final all = await repo.list(includeDeleted: true);
      expect(all, hasLength(1));
      expect(all.first.isDeleted, isTrue);

      final entries = await outbox.take(10);
      expect(entries.last.op, 'delete');
    });

    test('update 覆盖原值', () async {
      final r = await repo.create(record(sys: 120, dia: 80));
      await repo.update(r.copyWith(systolic: 130, updatedAt: DateTime.now()));
      final list = await repo.list();
      expect(list.first.systolic, 130);
    });

    test('按测量时间倒序与范围过滤', () async {
      final base = DateTime(2026, 9, 1, 8);
      await repo.create(record(sys: 110, dia: 70,
          at: base.add(const Duration(days: 1))));
      await repo.create(record(sys: 120, dia: 80, at: base));
      await repo.create(record(sys: 130, dia: 85,
          at: base.add(const Duration(days: 2))));

      final all = await repo.list();
      expect(all.first.systolic, 130); // 最新在前

      final onlyFirstDay =
          await repo.list(from: base, to: base.add(const Duration(hours: 23)));
      expect(onlyFirstDay.map((r) => r.systolic), [120]);
    });

    test('左右臂筛选', () async {
      await repo.create(record(sys: 120, dia: 80, arm: MeasureArm.left));
      await repo.create(record(sys: 122, dia: 82, arm: MeasureArm.right));
      final left = await repo.list(arm: MeasureArm.left);
      expect(left, hasLength(1));
      expect(left.first.systolic, 120);
    });

    test('stats 达标率', () async {
      await repo.create(record(sys: 120, dia: 80));
      await repo.create(record(sys: 140, dia: 90));
      final s = await repo.stats();
      expect(s.count, 2);
      expect(s.normalRate, closeTo(0.5, 0.001));
    });
  });
}
