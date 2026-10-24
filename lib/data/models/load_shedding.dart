import 'dart:convert';

/// One daily load-shedding slot, e.g. 2:00 pm – 4:00 pm. Times are minutes
/// after midnight; [end] before [start] means it runs past midnight.
class LoadSheddingSlot {
  const LoadSheddingSlot({required this.start, required this.end});

  final int start;
  final int end;

  /// Length in minutes.
  int get minutes => (end - start) % (24 * 60) == 0 ? 24 * 60 : (end - start) % (24 * 60);

  Map<String, Object?> toJson() => {'start': start, 'end': end};

  factory LoadSheddingSlot.fromJson(Map<String, Object?> j) => LoadSheddingSlot(
        start: (j['start'] as num).toInt() % (24 * 60),
        end: (j['end'] as num).toInt() % (24 * 60),
      );

  /// Slots saved in settings, sorted by start time. Bad data gives [].
  static List<LoadSheddingSlot> decode(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = (jsonDecode(json) as List).cast<Map<String, Object?>>();
      return [for (final j in list) LoadSheddingSlot.fromJson(j)]..sort((a, b) => a.start.compareTo(b.start));
    } catch (_) {
      return const [];
    }
  }

  static String encode(List<LoadSheddingSlot> slots) => jsonEncode([for (final s in slots) s.toJson()]);

  @override
  bool operator ==(Object other) => other is LoadSheddingSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
