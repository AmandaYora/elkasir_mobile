import 'package:intl/intl.dart';

final _idr = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
final _time = DateFormat('HH:mm', 'id_ID');

String formatIDR(num value) => _idr.format(value);

String formatDateTime(DateTime value) => _dateTime.format(value);

String formatTime(DateTime value) => _time.format(value);
