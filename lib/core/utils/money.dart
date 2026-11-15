/// Decimal money from server JSON, represented in hundredths of a dong.
BigInt moneyMinor(String value) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) throw FormatException('Invalid decimal money');
  final amount =
      BigInt.parse(match[2]!) * BigInt.from(100) +
      BigInt.parse((match[3] ?? '').padRight(2, '0'));
  return match[1] == '-' ? -amount : amount;
}

String moneyDecimal(BigInt value) {
  final amount = value.abs();
  return '${value.isNegative ? '-' : ''}${amount ~/ BigInt.from(100)}.${(amount % BigInt.from(100)).toString().padLeft(2, '0')}';
}

String moneyDifference(String total, String deducted) =>
    moneyDecimal(moneyMinor(total) - moneyMinor(deducted));
