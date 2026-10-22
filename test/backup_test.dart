import 'package:bijli_bachao/services/backup/backup_data.dart';
import 'package:bijli_bachao/services/backup/restore_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> meter(int id, String name, {String disco = 'LESCO'}) => {
      'id': id,
      'name': name,
      'disco': disco,
      'city': 'Lahore',
      'province': 'Punjab',
      'connection_type': 'home',
      'phase': 'single',
      'sanctioned_load_kw': 2.0,
      'protected_setting': 'auto',
      'reading_day': 10,
      'created_at': '2026-01-01T00:00:00.000',
    };

Map<String, Object?> reading(int meterId, String date, double value) => {
      'id': 1,
      'meter_id': meterId,
      'reading_date': date,
      'reading_value': value,
      'source': 'manual',
      'created_at': '${date}T20:00:00.000',
    };

Map<String, Object?> bill(int meterId, String month, int units) => {
      'id': 1,
      'meter_id': meterId,
      'bill_month': month,
      'units': units,
      'amount_rs': units * 40.0,
      'due_date': null,
      'present_reading': null,
      'source': 'manual',
      'created_at': '2026-10-01T00:00:00.000',
    };

BackupData sample() => BackupData(
      createdAt: DateTime(2026, 10, 22, 9),
      meters: [meter(1, 'Home'), meter(2, 'Shop', disco: 'IESCO')],
      readings: [reading(1, '2026-10-01', 12000), reading(1, '2026-10-10', 12080), reading(2, '2026-10-05', 500)],
      bills: [bill(1, '2026-09', 214), bill(2, '2026-09', 90)],
      appliances: [
        {'id': 1, 'meter_id': 1, 'name': 'Fan', 'category': 'cooling', 'watts': 80, 'quantity': 3, 'hours_per_day': 10.0, 'created_at': ''},
      ],
      settings: {'active_meter_id': 2, 'reminders_enabled': false},
    );

void main() {
  group('BackupData', () {
    test('round-trips through JSON', () {
      final back = BackupData.parse(sample().encode());
      expect(back.meters.length, 2);
      expect(back.readings.length, 3);
      expect(back.bills.length, 2);
      expect(back.appliances.single['name'], 'Fan');
      expect(back.settings['active_meter_id'], 2);
      expect(back.createdAt, DateTime(2026, 10, 22, 9));
    });

    test('rejects files that are not backups', () {
      expect(() => BackupData.parse('hello'), throwsA(isA<BackupFormatException>()));
      expect(() => BackupData.parse('{"app":"other"}'), throwsA(isA<BackupFormatException>()));
      expect(() => BackupData.parse('[1,2]'), throwsA(isA<BackupFormatException>()));
    });

    test('rejects backups from a newer format', () {
      final json = sample().encode().replaceFirst('"format": 1', '"format": 99');
      expect(
        () => BackupData.parse(json),
        throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains('newer'))),
      );
    });

    test('drops bad rows, orphans and unknown columns', () {
      final json = BackupData(
        createdAt: DateTime(2026, 10, 22),
        meters: [
          {...meter(1, 'Home'), 'future_column': 'x'},
        ],
        readings: [
          reading(1, '2026-10-01', 12000),
          reading(9, '2026-10-02', 12010), // meter 9 doesn't exist
          {...reading(1, 'not a date', 1)},
        ],
        bills: [bill(1, 'Sept', 10)],
        appliances: const [],
        settings: {'install_id': 'abc', 'reminders_enabled': true},
      ).encode();
      final b = BackupData.parse(json);
      expect(b.meters.single.containsKey('future_column'), isFalse);
      expect(b.readings.length, 1);
      expect(b.bills, isEmpty);
      expect(b.settings.containsKey('install_id'), isFalse, reason: 'never restore another phone\'s install id');
      expect(b.settings['reminders_enabled'], true);
    });

    test('handles a byte-order mark from file managers', () {
      expect(BackupData.parse('﻿${sample().encode()}').meters.length, 2);
    });
  });

  group('RestorePlan', () {
    test('replace inserts everything as new', () {
      final plan = RestorePlan.build(sample(), RestoreMode.replace, existing: sample());
      expect(plan.wipeFirst, isTrue);
      expect(plan.newMeters.length, 2);
      expect(plan.newMeters[1]!.containsKey('id'), isFalse);
      expect(plan.readings.length, 3);
      expect(plan.bills.length, 2);
      expect(plan.appliances.length, 1);
    });

    test('merge matches meters by name + company and skips what exists', () {
      // Phone: "home" (same meter, different id and case) with one reading and the Sept bill.
      final phone = BackupData(
        createdAt: DateTime(2026, 10, 22),
        meters: [meter(7, 'home')],
        readings: [reading(7, '2026-10-01', 12000)],
        bills: [bill(7, '2026-09', 214)],
        appliances: [
          {'id': 3, 'meter_id': 7, 'name': 'fan', 'watts': 80, 'hours_per_day': 8.0},
        ],
      );
      final plan = RestorePlan.build(sample(), RestoreMode.merge, existing: phone);
      expect(plan.wipeFirst, isFalse);
      expect(plan.existingMeterFor, {1: 7});
      expect(plan.newMeters.keys, [2], reason: 'Shop is new');
      // Home: only 10 Oct is new. Shop: its one reading.
      expect(plan.readings.map((r) => r['reading_date']), ['2026-10-10', '2026-10-05']);
      expect(plan.bills.map((b) => b['meter_id']), [2]);
      expect(plan.appliances, isEmpty);
    });

    test('merge of the same backup twice adds nothing', () {
      final once = sample();
      // After a replace, the phone holds the same data under new ids.
      final phone = BackupData(
        createdAt: DateTime(2026, 10, 22),
        meters: [meter(11, 'Home'), meter(12, 'Shop', disco: 'IESCO')],
        readings: [
          reading(11, '2026-10-01', 12000),
          reading(11, '2026-10-10', 12080),
          reading(12, '2026-10-05', 500),
        ],
        bills: [bill(11, '2026-09', 214), bill(12, '2026-09', 90)],
        appliances: [
          {'id': 1, 'meter_id': 11, 'name': 'Fan', 'watts': 80, 'hours_per_day': 10.0},
        ],
      );
      final plan = RestorePlan.build(once, RestoreMode.merge, existing: phone);
      expect(plan.addedCount, 0);
    });

    test('duplicate days inside a backup are kept once', () {
      final b = BackupData(
        createdAt: DateTime(2026, 10, 22),
        meters: [meter(1, 'Home')],
        readings: [reading(1, '2026-10-01', 12000), reading(1, '2026-10-01T18:00:00.000', 12004)],
        bills: const [],
        appliances: const [],
      );
      expect(RestorePlan.build(b, RestoreMode.replace).readings.length, 1);
    });
  });
}
