import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ศูนย์กลางการจัดการวันที่แบบไทย/พุทธศักราชของทั้งแอป
///
/// แนวทางใช้งาน:
/// - ห้ามเรียก `showDatePicker` โดยตรงในหน้าต่างๆ
/// - ให้เรียก `ThaiDateUtils.showThaiDatePicker` เท่านั้น
/// - การแสดงผลวันที่ให้ใช้ formatter ในคลาสนี้เพื่อความสม่ำเสมอ
class ThaiDateUtils {
  static const Locale thaiLocale = Locale('th', 'TH');
  static const List<String> _thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  static String formatBuddhistDate(
    DateTime? date, {
    String emptyText = 'ไม่กำหนด',
  }) {
    if (date == null) return emptyText;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final buddhistYear = (date.year + 543).toString();
    return '$day/$month/$buddhistYear';
  }

  static Future<DateTime?> showThaiDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: thaiLocale,
      calendarDelegate: const BuddhistCalendarDelegate(),
    );
  }

  static String formatThaiMonthShort(DateTime date) {
    return _thaiMonthsShort[date.month - 1];
  }

  static String formatBuddhistDateTime(
    DateTime? date, {
    String emptyText = '-',
  }) {
    if (date == null) return emptyText;

    final datePart = formatBuddhistDate(date, emptyText: emptyText);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$datePart $hour:$minute';
  }

  static String formatThaiDateTimeShort(
    DateTime? date, {
    String emptyText = '-',
  }) {
    if (date == null) return emptyText;

    final day = date.day.toString().padLeft(2, '0');
    final month = formatThaiMonthShort(date);
    final shortBuddhistYear = ((date.year + 543) % 100).toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $shortBuddhistYear $hour:$minute น.';
  }
}

class BuddhistCalendarDelegate extends GregorianCalendarDelegate {
  const BuddhistCalendarDelegate();

  static const int _buddhistYearOffset = 543;

  @override
  String formatMonthYear(DateTime date, MaterialLocalizations localizations) {
    final month = DateFormat('MMMM', 'th_TH').format(date);
    return '$month ${date.year + _buddhistYearOffset}';
  }

  @override
  String formatYear(int year, MaterialLocalizations localizations) {
    return '${year + _buddhistYearOffset}';
  }

  @override
  String formatShortDate(DateTime date, MaterialLocalizations localizations) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year + _buddhistYearOffset).toString();
    return '$day/$month/$year';
  }

  @override
  String formatCompactDate(DateTime date, MaterialLocalizations localizations) {
    return formatShortDate(date, localizations);
  }

  @override
  String formatFullDate(DateTime date, MaterialLocalizations localizations) {
    final weekday = DateFormat('EEEE', 'th_TH').format(date);
    final month = DateFormat('MMMM', 'th_TH').format(date);
    return '$weekday ${date.day} $month ${date.year + _buddhistYearOffset}';
  }

  @override
  DateTime? parseCompactDate(String? inputString, MaterialLocalizations localizations) {
    if (inputString == null || inputString.trim().isEmpty) return null;

    final parts = RegExp(r'\d+')
        .allMatches(inputString)
        .map((m) => int.tryParse(m.group(0) ?? ''))
        .whereType<int>()
        .toList();

    if (parts.length < 3) {
      return super.parseCompactDate(inputString, localizations);
    }

    final day = parts[0];
    final month = parts[1];
    var year = parts[2];
    if (year > 2400) {
      year -= _buddhistYearOffset;
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  @override
  String dateHelpText(MaterialLocalizations localizations) {
    return 'วว/ดด/ปปปป (พ.ศ.)';
  }
}
