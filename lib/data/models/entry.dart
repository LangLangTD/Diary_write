import '../../core/cn_date.dart';

/// 一篇日记。
///
/// [date]（entry_date）与 createdAt 刻意分离：前者是「这篇日记属于哪一天」，
/// 后者是「什么时候创建的」。这样才能支持补记往日和预写未来。
class Entry {
  const Entry({
    this.id,
    this.title = '',
    this.content = '',
    required this.date,
    this.mood,
    this.weather,
    this.tags = const <String>[],
    this.wordCount = 0,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String content;

  /// 日记归属日期（已归一到零点）
  final DateTime date;

  /// 心情 1~5，null 表示未记录
  final int? mood;

  /// 天气，null 表示未记录
  final String? weather;

  final List<String> tags;
  final int wordCount;

  /// 回收站软删除标记
  final bool isDeleted;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory Entry.draft({DateTime? date}) {
    final DateTime now = DateTime.now();
    return Entry(
      date: CnDate.dayOnly(date ?? now),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Entry.fromMap(Map<String, Object?> m) {
    final int createdMs = (m['created_at'] as int?) ?? 0;
    return Entry(
      id: m['id'] as int?,
      title: (m['title'] as String?) ?? '',
      content: (m['content'] as String?) ?? '',
      date: CnDate.tryParseYmd(m['entry_date'] as String?) ??
          CnDate.dayOnly(DateTime.fromMillisecondsSinceEpoch(createdMs)),
      mood: m['mood'] as int?,
      weather: m['weather'] as String?,
      tags: parseTags(m['tags'] as String?),
      wordCount: (m['word_count'] as int?) ?? 0,
      isDeleted: ((m['is_deleted'] as int?) ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as int?) ?? createdMs),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'content': content,
        'entry_date': CnDate.ymd(date),
        'mood': mood,
        'weather': weather,
        'tags': tags.join(','),
        'word_count': wordCount,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  Entry copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? date,
    int? mood,
    bool clearMood = false,
    String? weather,
    bool clearWeather = false,
    List<String>? tags,
    int? wordCount,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: clearMood ? null : (mood ?? this.mood),
      weather: clearWeather ? null : (weather ?? this.weather),
      tags: tags ?? this.tags,
      wordCount: wordCount ?? this.wordCount,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayTitle {
    final String t = title.trim();
    return t.isEmpty ? '无标题' : t;
  }

  /// 标题是否存在
  bool get hasTitle => title.trim().isNotEmpty;

  /// 列表卡片用的单行摘要
  String get summary {
    final String s = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '还没有写正文';
    return s.length <= 90 ? s : '${s.substring(0, 90)}…';
  }

  /// 标题和正文都为空 → 没有实际内容
  bool get isBlank => !hasTitle && content.trim().isEmpty;

  static List<String> parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    return raw
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  /// 中日韩字符按字计，其余按空白分词计。
  static int countWords(String text) {
    if (text.isEmpty) return 0;
    final int cjk = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]').allMatches(text).length;
    final int latin = RegExp(r'[A-Za-z0-9]+').allMatches(text).length;
    return cjk + latin;
  }
}

/// 心情取值，供选择器与展示复用。
class Moods {
  Moods._();

  static const List<String> faces = <String>['😞', '😕', '😐', '🙂', '😄'];
  static const List<String> labels = <String>['很差', '一般', '平静', '不错', '很好'];

  static String? face(int? mood) {
    if (mood == null || mood < 1 || mood > 5) return null;
    return faces[mood - 1];
  }

  static String? label(int? mood) {
    if (mood == null || mood < 1 || mood > 5) return null;
    return labels[mood - 1];
  }
}

/// 天气取值。
class Weathers {
  Weathers._();

  static const List<String> icons = <String>['☀️', '⛅', '☁️', '🌧', '⛈', '🌨', '🌫', '🌪'];
  static const List<String> names = <String>['晴', '多云', '阴', '雨', '雷阵雨', '雪', '雾', '大风'];
}