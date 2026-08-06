import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  const workblocBody = '''
WorkBloc - Co-Working Space Payment Received - Invoice INV-00000112
PAID
workblocofficial@gmail.com
03294610000
Main Defence Road, Near Rainbow Store, Opposite Front Green Belt Block B Phase 1, DHA Rahbar, Lahore
NTN: J459878
STRN/PNTN: P459878
Sales Tax Invoice
INV-00000112
Issue Date: 01 August 2026
Due Date: 01 August 2026
Bill To
Muhammad Arham Babar
m.arham.babar.1625@gmail.com
0324-4200101
Ho# 125 TNT Aapbara Housing Society
NTN: 35202-7235133-3
Description Qty Rate Amount
Management Service Charges 1 PKR 190,000.00 PKR 190,000.00
Subtotal PKR 190,000.00
''';

  test('WorkBloc paid invoice is debit rent not income', () {
    final r = parser.parse(
      workblocBody,
      source: TransactionSource.notification,
      notificationTitle:
          'WorkBloc - Co-Working Sp. – WorkBloc - Co-Working Space Payment Received - Invoice INV-00000112',
      packageName: 'com.google.android.gm',
    );
    expect(r, isNotNull);
    expect(r!.amount, 190000.0);
    expect(r.type, TransactionType.debit);
    expect(r.merchant.toLowerCase(), contains('workbloc'));
    expect(r.merchant.toLowerCase(), contains('co-working'));
    expect(r.merchant.toLowerCase(), isNot(contains('arham')));
  });

  test('wallet Payment Received from person stays credit', () {
    final r = parser.parse(
      'Rs 5,000.00 received from SARA AHMED in your account via Raast. '
      'TID: 112233.',
      source: TransactionSource.notification,
      packageName: 'com.hbl.android.hblmobilebanking',
      notificationTitle: 'Payment Received',
    );
    expect(r, isNotNull);
    expect(r!.type, TransactionType.credit);
    expect(r.merchant.toUpperCase(), contains('SARA'));
  });
}
