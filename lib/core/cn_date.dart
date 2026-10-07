/// 中文日期格式化工具集合。
///
/// 刻意不引入 intl：日记场景需要的格式很有限，自己实现更轻、
/// 也避免与 flutter_localizations 的 intl 版本产生耦合。
library;

class CnDate {
  CnDate._();

  static const List<String> _weekShort = <String>['一', '二', '三', '四', '五', '六', '日'];
  static const List<String> _weekFull = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  static String p2(int n) => n.toString().padLeft(2, '0');

  /// 数据库中使用的日期键：2026-10-06
  static String ymd(DateTime d) => '${d.year}-${p2(d.month)}-${p2(d.day)}';

  /// 月份键：2026-10
  static String monthKey(DateTime d) => '${d.year}-${p2(d.month)}';

  /// 解析 ymd，失败返回 null。
  static DateTime? tryParseYmd(String? s) {
    if (s == null) return null;
    final RegExpMatch? m =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final int y = int.parse(m.group(1)!);
    final int mo = int.parse(m.group(2)!);
    final int da = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || da < 1 || da > 31) return null;
    return DateTime(y, mo, da);
  }

  /// 2026年10月6日
  static String cnFull(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  /// 2026年10月
  static String cnMonth(DateTime d) => '${d.year}年${d.month}月';

  /// 星期三
  static String weekday(DateTime d) => _weekFull[d.weekday - 1];

  /// 周三
  static String weekdayShort(DateTime d) => '周${_weekShort[d.weekday - 1]}';

  /// 10月6日
  static String cnMonthDay(DateTime d) => '${d.month}月${d.day}日';

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// 今天 / 昨天 / 10月3日
  static String friendly(DateTime d, {DateTime? now}) {
    final DateTime n = dayOnly(now ?? DateTime.now());
    final DateTime t = dayOnly(d);
    final int diff = n.difference(t).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    if (diff == -1) return '明天';
    if (t.year == n.year) return cnMonthDay(t);
    return '${t.year}年${t.month}月${t.day}日';
  }
}