const int kBottlePrice = 150;

const String kRegisteredPhone = '3018472910';
const String kRegisteredPin = '1234';

const String kPendingSyncLabel = 'Saved on phone — pending sync.';
const String kSyncedLabel = 'Synced with office.';

String formatRs(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return negative ? '-Rs. $buffer' : 'Rs. $buffer';
}

String formatEntryDate(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
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
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatEntryTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String bottleSummary(int full, int empty) {
  final fullLabel = full == 1 ? '1 full bottle' : '$full full bottles';
  final emptyLabel = empty == 1 ? '1 empty' : '$empty empties';
  return '$fullLabel · $emptyLabel';
}

String paymentLine({required PaymentMethod method, required int amount}) {
  return switch (method) {
    PaymentMethod.cash => 'Cash received: ${formatRs(amount)}',
    PaymentMethod.online => 'Online payment: ${formatRs(amount)}',
    PaymentMethod.unpaid => 'Payment not received',
  };
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

enum PaymentMethod { cash, online, unpaid }

enum PaymentProvider { jazzCash, easyPaisa, bank, other }

enum EntryFilter { all, cash, online, unpaid }

enum LoginFailure { unknownPhone, wrongPin }

extension PaymentMethodLabel on PaymentMethod {
  String get title => switch (this) {
    PaymentMethod.cash => 'Cash Received',
    PaymentMethod.online => 'Paid Online',
    PaymentMethod.unpaid => 'Payment Not Received',
  };

  String get urdu => switch (this) {
    PaymentMethod.cash => 'نقد رقم',
    PaymentMethod.online => 'آن لائن ادائیگی',
    PaymentMethod.unpaid => 'ادائیگی نہیں ہوئی',
  };
}

extension PaymentProviderLabel on PaymentProvider {
  String get label => switch (this) {
    PaymentProvider.jazzCash => 'JazzCash',
    PaymentProvider.easyPaisa => 'Easypaisa',
    PaymentProvider.bank => 'Bank Transfer',
    PaymentProvider.other => 'Other',
  };
}
