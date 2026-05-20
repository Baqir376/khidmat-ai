class DateFormatter {
  static String formatScheduledDateTime(dynamic dateVal, dynamic timeVal) {
    if (dateVal == null) return 'ASAP';
    
    String dateStr = dateVal.toString();
    if (dateStr.isEmpty || dateStr.toLowerCase() == 'asap') {
      return 'ASAP';
    }
    
    String formattedDate = dateStr;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final dateTime = DateTime(year, month, day);
        final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        formattedDate = "${weekdays[dateTime.weekday % 7]}, ${months[dateTime.month - 1]} $day, $year";
      }
    } catch (_) {}
    
    if (timeVal == null) return formattedDate;
    
    String timeStr = timeVal.toString().trim();
    if (timeStr.toLowerCase() == 'asap' || timeStr.isEmpty) {
      return "$formattedDate at ASAP";
    }
    
    String formattedTime = timeStr;
    try {
      final cleanTime = timeStr.toLowerCase();
      if (cleanTime.contains('am') || cleanTime.contains('pm')) {
        final isPm = cleanTime.contains('pm');
        final digits = cleanTime.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = digits.split(':');
        if (parts.isNotEmpty) {
          int hour = int.parse(parts[0]);
          int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
          if (hour == 0) hour = 12;
          if (hour > 12) hour = hour % 12;
          formattedTime = "$hour:${minute.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}";
        }
      } else {
        final timeParts = timeStr.split(':');
        if (timeParts.isNotEmpty) {
          int hour = int.parse(timeParts[0]);
          int minute = timeParts.length > 1 ? int.parse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '')) : 0;
          final ampm = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;
          formattedTime = "$hour12:${minute.toString().padLeft(2, '0')} $ampm";
        }
      }
    } catch (_) {}
    
    return "$formattedDate at $formattedTime";
  }
}
