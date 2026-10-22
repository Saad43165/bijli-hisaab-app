import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/appliance_repository.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/meter_repository.dart';
import '../data/repositories/reading_repository.dart';

class ExportResult {
  const ExportResult({required this.files, required this.rowCounts});

  final List<File> files;
  final Map<String, int> rowCounts;
}

/// Writes anonymised CSV files that match docs/POWER_BI_DATA_SCHEMA.md.
class ExportService {
  ExportService({
    MeterRepository? meters,
    ReadingRepository? readings,
    BillRepository? bills,
    ApplianceRepository? appliances,
    EventRepository? events,
  })  : _meters = meters ?? MeterRepository(),
        _readings = readings ?? ReadingRepository(),
        _bills = bills ?? BillRepository(),
        _appliances = appliances ?? ApplianceRepository(),
        _events = events ?? EventRepository();

  final MeterRepository _meters;
  final ReadingRepository _readings;
  final BillRepository _bills;
  final ApplianceRepository _appliances;
  final EventRepository _events;

  Future<ExportResult> buildCsvFiles(String installId) async {
    final base = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final dir = Directory(p.join(base.path, 'powerbi_export_$stamp'));
    await dir.create(recursive: true);

    String key(int? meterId) => meterId == null ? '' : '$installId-$meterId';
    String ts(DateTime d) => d.toUtc().toIso8601String();

    final meters = await _meters.getAll();
    final readings = await _readings.all();
    final bills = await _bills.all();
    final appliances = await _appliances.all();
    final events = await _events.all();

    final files = <File>[
      await _write(dir, 'meters.csv', [
        'install_id', 'meter_id', 'meter_key', 'disco', 'city', 'province', 'connection_type',
        'phase', 'sanctioned_load_kw', 'protected_setting', 'reading_day', 'created_at',
      ], [
        for (final m in meters)
          [
            installId, m.id, key(m.id), m.disco, m.city.trim(), m.province, m.connectionType,
            m.phase, m.sanctionedLoadKw, m.protectedSetting.name, m.readingDay, ts(m.createdAt),
          ],
      ]),
      await _write(dir, 'readings.csv', [
        'install_id', 'meter_key', 'reading_date', 'reading_value', 'source', 'created_at',
      ], [
        for (final r in readings)
          [installId, key(r.meterId), Fmt.isoDate(r.date), r.value, r.source, ts(r.createdAt)],
      ]),
      await _write(dir, 'bills.csv', [
        'install_id', 'meter_key', 'bill_month', 'bill_month_date', 'units', 'amount_rs',
        'due_date', 'slab_band', 'source', 'created_at',
      ], [
        for (final b in bills)
          [
            installId, key(b.meterId), b.month, '${b.month}-01', b.units, b.amount,
            b.dueDate == null ? '' : Fmt.isoDate(b.dueDate!), AppConstants.slabBand(b.units),
            b.source, ts(b.createdAt),
          ],
      ]),
      await _write(dir, 'appliances.csv', [
        'install_id', 'meter_key', 'appliance', 'category', 'watts', 'quantity',
        'hours_per_day', 'est_units_month',
      ], [
        for (final a in appliances)
          [
            installId, key(a.meterId), a.name, a.category, a.watts, a.quantity,
            a.hoursPerDay, a.monthlyUnits.toStringAsFixed(1),
          ],
      ]),
      await _write(dir, 'events.csv', [
        'install_id', 'event_type', 'meter_key', 'value', 'detail', 'created_at',
      ], [
        for (final e in events)
          [installId, e.type, key(e.meterId), e.value ?? '', e.detail ?? '', ts(e.createdAt)],
      ]),
    ];

    return ExportResult(files: files, rowCounts: {
      'meters': meters.length,
      'readings': readings.length,
      'bills': bills.length,
      'appliances': appliances.length,
      'events': events.length,
    });
  }

  Future<ShareResult> share(ExportResult result) {
    return SharePlus.instance.share(
      ShareParams(
        files: [for (final f in result.files) XFile(f.path, mimeType: 'text/csv')],
        subject: 'Bijli Hisaab data export (Power BI)',
        text: 'Bijli Hisaab anonymised export — 5 CSV files for Power BI.',
      ),
    );
  }

  Future<File> _write(Directory dir, String name, List<String> header, List<List<Object?>> rows) async {
    final buffer = StringBuffer()..writeln(header.map(_cell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_cell).join(','));
    }
    final file = File(p.join(dir.path, name));
    return file.writeAsString(buffer.toString());
  }

  static String _cell(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.contains(RegExp(r'[",\n\r]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }
}
