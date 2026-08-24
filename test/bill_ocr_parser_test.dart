import 'package:flutter_test/flutter_test.dart';
import 'package:kar_upahar/src/ocr/bill_ocr.dart';

void main() {
  const parser = BillOcrParser();
  final now = DateTime(2026, 8, 24);

  BillOcrLine line(String text, double top) => BillOcrLine(
        text: text,
        left: 0,
        top: top,
        width: 300,
        height: 20,
      );

  test('extracts Latin PAN, AD date, and grand total', () {
    final result = parser.parse([
      line('Seller PAN/VAT: 123456789', 10),
      line('Invoice Date: 2026-08-18', 30),
      line('Sub Total Rs 1,100.00', 100),
      line('VAT Rs 143.00', 120),
      line('Grand Total Rs 1,243.00', 160),
    ], now: now);

    expect(result.panNumber, '123456789');
    expect(result.billDateAd, '2026-08-18');
    expect(result.totalAmount, '1243');
  });

  test('normalizes Devanagari digits and converts a BS date to AD', () {
    final result = parser.parse([
      line('प्यान: १२३४५६७८९', 10),
      line('बिल मिति: २०७६/०४/१८', 30),
      line('कुल जम्मा रु १,२५०.५०', 100),
    ], now: now);

    expect(result.panNumber, '123456789');
    expect(result.billDateAd, '2019-08-03');
    expect(result.totalAmount, '1250.50');
  });

  test('uses day-first parsing when the year is last', () {
    final result = parser.parse([
      line('Bill Date: 18/08/2026', 10),
    ], now: now);

    expect(result.billDateAd, '2026-08-18');
  });

  test('does not mistake a mobile number for PAN', () {
    final result = parser.parse([
      line('Phone: 9812345678', 10),
    ], now: now);

    expect(result.panNumber, isNull);
  });

  test('leaves equally plausible PAN values blank', () {
    final result = parser.parse([
      line('123456789', 10),
      line('987654321', 30),
    ], now: now);

    expect(result.panNumber, isNull);
  });

  test('rejects future and impossible dates', () {
    final future = parser.parse([
      line('Bill Date: 2026-08-25', 10),
    ], now: now);
    final impossible = parser.parse([
      line('Bill Date: 2026-02-31', 10),
    ], now: now);

    expect(future.billDateAd, isNull);
    expect(impossible.billDateAd, isNull);
  });

  test('returns partial results and leaves missing fields null', () {
    final result = parser.parse([
      line('PAN/VAT: 123456789', 10),
      line('Total: unreadable', 30),
    ], now: now);

    expect(result.detectedFieldCount, 1);
    expect(result.panNumber, '123456789');
    expect(result.billDateAd, isNull);
    expect(result.totalAmount, isNull);
  });
}
