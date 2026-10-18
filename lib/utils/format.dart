import 'package:intl/intl.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _compact = NumberFormat.decimalPattern('id_ID');

String rp(num v) => _rp.format(v);

/// Shows "—" for unknown values instead of a false precise number.
String rpOrDash(num? v) => v == null ? '—' : rp(v);

String fmtQty(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String fmtNum(num v) => _compact.format(v);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const _monthsLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];
const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

bool get _englishDates => Intl.defaultLocale?.startsWith('en') == true;
const _enMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _enMonthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _enDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String fmtDate(DateTime d) =>
    '${d.day} ${(_englishDates ? _enMonths : _months)[d.month - 1]} ${d.year}';
String fmtDateLong(DateTime d) =>
    '${(_englishDates ? _enDays : _days)[d.weekday - 1]}, ${d.day} ${(_englishDates ? _enMonthsLong : _monthsLong)[d.month - 1]}';
String fmtMonth(DateTime d) =>
    '${(_englishDates ? _enMonthsLong : _monthsLong)[d.month - 1]} ${d.year}';
String fmtDayShort(DateTime d) =>
    (_englishDates ? _enDays : _days)[d.weekday - 1].substring(0, 3);
String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Parses "3.500", "3500", "3,5rb", "4rb" → number.
double? parseAmount(String s) {
  var t = s.trim().toLowerCase().replaceAll('rp', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  var mult = 1.0;
  if (t.endsWith('rb') || t.endsWith('k')) {
    mult = 1000;
    t = t.replaceAll(RegExp(r'(rb|k)$'), '').replaceAll(',', '.');
    return double.tryParse(t) == null ? null : double.parse(t) * mult;
  }
  t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}
