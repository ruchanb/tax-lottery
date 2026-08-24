String? validateName(String? value) {
  if (value == null || value.trim().length < 2) {
    return 'Enter your full name';
  }
  return null;
}

String? validateNepalMobile(String? value) {
  final normalized = normalizeNepalMobile(value ?? '');
  if (!RegExp(r'^(97|98)\d{8}$').hasMatch(normalized)) {
    return 'Enter a valid 10-digit Nepal mobile number';
  }
  return null;
}

String normalizeNepalMobile(String value) {
  var normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.startsWith('977') && normalized.length == 13) {
    normalized = normalized.substring(3);
  }
  return normalized;
}

String? validatePan(String? value) {
  if (!RegExp(r'^\d{9}$').hasMatch((value ?? '').trim())) {
    return 'PAN/VAT number must contain 9 digits';
  }
  return null;
}

String? validateAmount(String? value) {
  final amount = double.tryParse((value ?? '').replaceAll(',', '').trim());
  if (amount == null || amount <= 100) {
    return 'Eligible bill amount must be more than Rs 100';
  }
  return null;
}

String normalizeCoupon(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

DateTime nextDrawDate(DateTime billDate) {
  if (billDate.day <= 15) return DateTime(billDate.year, billDate.month, 16);
  return DateTime(billDate.year, billDate.month + 1, 1);
}
