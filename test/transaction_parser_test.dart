import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('parses HDFC debit SMS', () {
    final result = parser.parse(
      'Rs 500 debited from A/c **4521 on 16-06-26 at SWIGGY. Info: UPI/12345',
      source: TransactionSource.sms,
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.debit);
    expect(result.merchant.toLowerCase(), contains('swiggy'));
  });

  test('parses credit alert', () {
    final result = parser.parse(
      'INR 85,000 credited to A/c **1234 on salary',
      source: TransactionSource.gmail,
    );
    expect(result, isNotNull);
    expect(result!.amount, 85000);
    expect(result.type, TransactionType.credit);
  });

  test('keeps a valid in-range date from the message', () {
    final result = parser.parse(
      'Rs 500 debited from A/c **4521 on 16-06-26 at SWIGGY',
      source: TransactionSource.sms,
      fallbackTime: DateTime(2026, 6, 20, 9, 30),
    );
    expect(result, isNotNull);
    expect(result!.occurredAt, DateTime(2026, 6, 16));
  });

  test('ignores reference numbers that look like dates', () {
    // "1234-56-7890" must not be misread as a date and file the transaction
    // into a bogus month — it should fall back to the message time.
    final fallback = DateTime(2026, 6, 16, 14, 0);
    final result = parser.parse(
      'Rs 200 spent at Cafe Ref 1234-56-7890',
      source: TransactionSource.notification,
      fallbackTime: fallback,
    );
    expect(result, isNotNull);
    expect(result!.occurredAt, fallback);
  });

  test('ignores future dates and falls back to the message time', () {
    final fallback = DateTime(2026, 6, 16, 14, 0);
    final result = parser.parse(
      'Rs 200 spent at Cafe on 16-06-40',
      source: TransactionSource.notification,
      fallbackTime: fallback,
    );
    expect(result, isNotNull);
    expect(result!.occurredAt, fallback);
  });

  test('parses UBL Digital PKR debit notification', () {
    final result = parser.parse(
      'UBL Digital — Dear Customer, PKR 2,500.00 has been debited from A/C ***1234 on 16-JUN-2026',
      source: TransactionSource.notification,
    );
    expect(result, isNotNull);
    expect(result!.amount, 2500);
    expect(result.type, TransactionType.debit);
  });

  test('builds stable fingerprint', () {
    final fp1 = TransactionParser.buildFingerprint(
      amount: 500,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'Swiggy',
      accountRef: '4521',
    );
    final fp2 = TransactionParser.buildFingerprint(
      amount: 500,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'swiggy',
      accountRef: '4521',
    );
    expect(fp1, fp2);
  });

  test('extracts from/to parties for self-transfer detection', () {
    final result = parser.parse(
      'PKR 5,000 transferred from Arham Babar to Arham Babar',
      source: TransactionSource.notification,
    );
    expect(result, isNotNull);
    expect(result!.senderName, 'Arham Babar');
    expect(result.receiverName, 'Arham Babar');
  });

  test('extracts receiver on paid-to messages', () {
    final result = parser.parse(
      'You paid PKR 1,200 to Ali Khan via wallet',
      source: TransactionSource.notification,
    );
    expect(result, isNotNull);
    expect(result!.receiverName, 'Ali Khan');
  });

  test('merchant name stops at sentence dot in notification title', () {
    final result = parser.parse(
      'Muhammad Ali. — You sent PKR 500 to Muhammad Ali. Trx ID 12345',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'Muhammad Ali');
    expect(result.receiverName, 'Muhammad Ali');
  });

  test('merchant name stops at dot after counterparty in body', () {
    final result = parser.parse(
      'You sent Rs. 1,500.00 to ABC Store. Trx ID 998877 via JazzCash',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'ABC Store');
    expect(result.receiverName, 'ABC Store');
  });

  test('parses JazzCash sent notification', () {
    final result = parser.parse(
      'You sent Rs. 1,500.00 to ABC Store via JazzCash',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1500);
    expect(result.type, TransactionType.debit);
  });

  test('parses EasyPaisa transfer successful notification', () {
    final result = parser.parse(
      'PKR 1,000.00 has been successfully transferred to 03331234567',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1000);
  });

  test('parses has been debited by PKR wording', () {
    final result = parser.parse(
      'Dear Customer, Your account has been debited by PKR 500.00 on 16-JUN-2026. Trx ID: 123456',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.occurredAt, DateTime(2026, 6, 16));
  });

  test('parses wallet capture with amount and trx id only', () {
    final result = parser.parse(
      'PKR 750.00 — Trx ID 998877 — A/C ***4521',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.amount, 750);
  });

  test('parses monitored wallet alert with amount only in body', () {
    final result = parser.parse(
      'Ahmed Khan — PKR 500.00',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
      notificationTitle: 'Ahmed Khan',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'Ahmed Khan');
  });

  test('classifies credit from money received title', () {
    final result = parser.parse(
      'Money Received — PKR 2,500.00',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
      notificationTitle: 'Money Received',
    );
    expect(result, isNotNull);
    expect(result!.type, TransactionType.credit);
    expect(result.amount, 2500);
  });

  test('credit merchant uses sender from received-from wording', () {
    final result = parser.parse(
      'You have received PKR 2,500.00 from Sara Ali via JazzCash',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.type, TransactionType.credit);
    expect(result.merchant, 'Sara Ali');
    expect(result.senderName, 'Sara Ali');
  });

  test('credit merchant uses title before sentence dot', () {
    final result = parser.parse(
      'Ahmed Khan. — PKR 1,000.00 has been credited to your account',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'Ahmed Khan');
    expect(result.senderName, 'Ahmed Khan');
  });

  test('uses notification title when body only has amount', () {
    final result = parser.parse(
      'PKR 750.00 — Trx ID 998877 — A/C ***4521',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
      notificationTitle: 'Fatima Noor',
    );
    expect(result, isNotNull);
    expect(result!.type, TransactionType.debit);
    expect(result.merchant, 'Fatima Noor');
  });

  test('parses NayaPay casual sent alert with Rs amount first', () {
    final result = parser.parse(
      "Rs. 190 sent to Inam Ullah. Your wallet's seen better days.",
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
      notificationTitle: 'Off it goes 💸',
    );
    expect(result, isNotNull);
    expect(result!.amount, 190);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'Inam Ullah');
    expect(result.receiverName, 'Inam Ullah');
  });

  test('parses JazzCash Raast incoming received-from alert', () {
    final result = parser.parse(
      'Rs 100.0 received from MUHAMMAD ARHAM BABAR AC ********244200101 in your '
      'JazzCash Mobile Account:03244200101 via Raast. TID: 715577471335',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
      notificationTitle: 'Raast Incoming Payment',
    );
    expect(result, isNotNull);
    expect(result!.amount, 100);
    expect(result.type, TransactionType.credit);
    expect(result.senderName, 'MUHAMMAD ARHAM BABAR');
  });

  test('parses NayaPay Rs 100 sent to account holder from screenshot', () {
    final result = parser.parse(
      "Rs. 100 sent to Muhammad Arham Babar. Your wallet's seen better days.",
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
      notificationTitle: 'Off it goes 💸',
    );
    expect(result, isNotNull);
    expect(result!.amount, 100);
    expect(result.type, TransactionType.debit);
    expect(result.receiverName, 'Muhammad Arham Babar');
  });

  test('parses truncated NayaPay body when title carries alert wording', () {
    final result = parser.parse(
      'Off it goes — Rs. 100 sent to',
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
      notificationTitle: 'Off it goes 💸',
    );
    expect(result, isNotNull);
    expect(result!.amount, 100);
    expect(result.type, TransactionType.debit);
  });

  test('parses Google Wallet PKR tap payment with merchant title', () {
    final result = parser.parse(
      'PKR330.00 with EP Digital Card Google Wallet ••8421',
      source: TransactionSource.notification,
      packageName: 'com.google.android.apps.walletnfcrel',
      notificationTitle: 'THE FAST MART',
    );
    expect(result, isNotNull);
    expect(result!.amount, 330);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'THE FAST MART');
  });

  test('parses EasyPaisa debit card SMS from short code', () {
    final result = parser.parse(
      'Txn ID 51695745211. Debit Card No. ***8421. You have paid Rs. 330.00 at '
      'THE FAST MART LAHORE PK on 2026-06-22. Transaction Fee: Rs. 0.00',
      source: TransactionSource.sms,
    );
    expect(result, isNotNull);
    expect(result!.amount, 330);
    expect(result.type, TransactionType.debit);
    expect(result.merchant.toUpperCase(), contains('FAST MART'));
  });

  test('parses NayaPay sent alert without PKR prefix', () {
    final result = parser.parse(
      'You sent — 1,500.00 — Transaction successful',
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
      notificationTitle: 'Ali Raza',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1500);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'Ali Raza');
  });

  test('parses canonical You sent Rs notification from NayaPay', () {
    final result = parser.parse(
      'You sent Rs. 500.00 to Sara Ali via NayaPay',
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'Sara Ali');
    expect(result.receiverName, 'Sara Ali');
  });

  test('You sent Rs in title alone is enough to parse', () {
    final result = parser.parse(
      'You sent Rs. 2,000.00',
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
    );
    expect(result, isNotNull);
    expect(result!.amount, 2000);
    expect(result.type, TransactionType.debit);
  });

  test('parses Raqami plain amount notification', () {
    final result = parser.parse(
      'Money Sent — 2,000.00',
      source: TransactionSource.notification,
      packageName: 'com.raqamidigital.cbt',
      notificationTitle: 'Hassan Shah',
    );
    expect(result, isNotNull);
    expect(result!.amount, 2000);
    expect(result.type, TransactionType.debit);
  });

  test('parses EasyPaisa amount without currency label', () {
    final result = parser.parse(
      '500.00 — Txn ID 445566',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
      notificationTitle: 'Transfer Successful',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.debit);
  });

  test('prefers person name over phone in transferred-to body', () {
    final result = parser.parse(
      'PKR 1,000.00 has been successfully transferred to 03331234567',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
      notificationTitle: 'Ali Raza',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'Ali Raza');
  });

  test('prefers name after from over generic amount title', () {
    final result = parser.parse(
      'Rs.500 received — You have received Rs.500 from Ahmed Khan via JazzCash',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
      notificationTitle: 'Rs.500 received',
    );
    expect(result, isNotNull);
    expect(result!.type, TransactionType.credit);
    expect(result.merchant, 'Ahmed Khan');
    expect(result.senderName, 'Ahmed Khan');
  });

  test('prefers name after from over money received title', () {
    final result = parser.parse(
      'Money Received — You have received PKR 2,500.00 from Sara Ali on 16-JUN-2026',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
      notificationTitle: 'Money Received',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'Sara Ali');
    expect(result.senderName, 'Sara Ali');
  });

  test('parses pkr amount from name wording', () {
    final result = parser.parse(
      'PKR 750.00 from Hassan Shah has been credited to your JazzCash account',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'Hassan Shah');
    expect(result.senderName, 'Hassan Shah');
  });

  test('parses you sent rs amount to merchant', () {
    final result = parser.parse(
      'You sent Rs. 2,500.00 to Hassan Shah via JazzCash',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.merchant, 'Hassan Shah');
    expect(result.receiverName, 'Hassan Shah');
  });

  test('parses Google Wallet USD payment', () {
    final result = parser.parse(
      r'You sent $25.00 to Coffee Shop — Google Wallet',
      source: TransactionSource.notification,
      packageName: 'com.google.android.apps.walletnfcrel',
    );
    expect(result, isNotNull);
    expect(result!.amount, 25);
    expect(result.type, TransactionType.debit);
  });

  test('parses unknown bank app with amount-only body', () {
    final result = parser.parse(
      'PKR 3,200.00 — Trx ID 112233',
      source: TransactionSource.notification,
      packageName: 'com.example.newbank.mobilebanking',
      notificationTitle: 'Sara Ali',
    );
    expect(result, isNotNull);
    expect(result!.amount, 3200);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'Sara Ali');
  });

  test('rejects system UI package even with amount-like text', () {
    final result = parser.parse(
      'PKR 500.00 debited from account',
      source: TransactionSource.notification,
      packageName: 'com.android.systemui',
    );
    expect(result, isNull);
  });

  test('parses payment of Rs from unknown wallet app', () {
    final result = parser.parse(
      'Payment of Rs. 2500 to Ahmed Khan was successful. Trx ID 998877.',
      source: TransactionSource.notification,
      packageName: 'com.newfintech.payapp',
    );
    expect(result, isNotNull);
    expect(result!.amount, 2500);
    expect(result.type, TransactionType.debit);
  });

  test('parses amount has been debited wording', () {
    final result = parser.parse(
      'PKR 500.00 has been debited from your account for bill payment.',
      source: TransactionSource.notification,
      packageName: 'com.unknown.bank.mobile',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.debit);
  });

  test('parses incoming transfer received', () {
    final result = parser.parse(
      'Incoming transfer: Rs 3000.00 received from Ali Raza via Raast.',
      source: TransactionSource.notification,
      packageName: 'com.random.wallet',
    );
    expect(result, isNotNull);
    expect(result!.amount, 3000);
    expect(result.type, TransactionType.credit);
  });

  test('parses you paid Rs from any wallet', () {
    final result = parser.parse(
      'You paid Rs. 750 to K-Electric. Reference 445566.',
      source: TransactionSource.notification,
      packageName: 'com.example.mypay',
    );
    expect(result, isNotNull);
    expect(result!.amount, 750);
    expect(result.type, TransactionType.debit);
  });

  test('parses UPI payment from unknown Indian wallet', () {
    final result = parser.parse(
      'UPI payment of INR 1200.00 to Swiggy was successful.',
      source: TransactionSource.notification,
      packageName: 'com.unknown.upi.app',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1200);
    expect(result.type, TransactionType.debit);
  });

  test('parses outgoing payment completed', () {
    final result = parser.parse(
      'Outgoing payment Rs 1800 completed to HBL account.',
      source: TransactionSource.notification,
      packageName: 'com.digitalbank.neo',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1800);
    expect(result.type, TransactionType.debit);
  });

  test('rejects JazzCash promotional maintain balance alert', () {
    final result = parser.parse(
      'Missed April & May? — Maintain Rs. 50K & Get a Chance to Win 1 CRORE! — '
      'android.app.Notification\$BigTextStyle — androidx.core.app.NotificationCompat\$BigTextStyle — '
      'com.techlogix.mobilinkcustomer — FCM-Notification:18884585',
      source: TransactionSource.notification,
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNull);
  });

  test('rejects backup upload progress with MB amounts', () {
    final result = parser.parse(
      'Backup in progress — Uploading: 165 MB of 302 MB (54%)',
      source: TransactionSource.notification,
      notificationTitle: 'Backup',
    );
    expect(result, isNull);
  });

  test('rejects shopping order without finance wording', () {
    final result = parser.parse(
      'Order confirmed! Your total is 1250. Enjoy your meal.',
      source: TransactionSource.notification,
      packageName: 'com.example.shop',
    );
    expect(result, isNull);
  });

  test('rejects social notification with numbers', () {
    final result = parser.parse(
      'You have 500 new followers this week. Keep posting!',
      source: TransactionSource.notification,
      packageName: 'com.example.social',
    );
    expect(result, isNull);
  });

  test('rejects OTP message with amount-like digits', () {
    final result = parser.parse(
      'Your OTP is 500123. Do not share this code with anyone.',
      source: TransactionSource.notification,
      packageName: 'com.example.bank.sms',
    );
    expect(result, isNull);
  });

  test('rejects generic successful message without currency', () {
    final result = parser.parse(
      'Payment successful! Thank you for using our app.',
      source: TransactionSource.notification,
      packageName: 'com.random.app',
    );
    expect(result, isNull);
  });

  test('rejects delivery tracking from food app package', () {
    final result = parser.parse(
      'Out for delivery — Rs 850 order from Burger Lab arriving in 12 min.',
      source: TransactionSource.notification,
      packageName: 'com.foodpanda.android',
    );
    expect(result, isNull);
  });

  test('rejects WhatsApp updating notification', () {
    final result = parser.parse(
      'WhatsApp is updating',
      source: TransactionSource.notification,
      packageName: 'com.whatsapp',
    );
    expect(result, isNull);
  });

  test('rejects WhatsApp update with version numbers', () {
    final result = parser.parse(
      'Update complete — WhatsApp 2.24.12.78',
      source: TransactionSource.notification,
      packageName: 'com.whatsapp',
    );
    expect(result, isNull);
  });

  test('rejects WhatsApp downloading update progress', () {
    final result = parser.parse(
      'Downloading update… 45% complete',
      source: TransactionSource.notification,
      packageName: 'com.whatsapp',
    );
    expect(result, isNull);
  });

  test('parses WhatsApp Pay UPI received notification', () {
    final result = parser.parse(
      'You received Rs. 500 from Amit Sharma via UPI.',
      source: TransactionSource.notification,
      packageName: 'com.whatsapp',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.credit);
  });

  test('parses UBL IBFT transfer to EasyPaisa', () {
    final result = parser.parse(
      'Dear Customer, your account **1234 has been debited by PKR 8,000.00 '
      'vide IBFT transfer to EASYPAISA Mobile Wallet on 18-JUN-2026.',
      source: TransactionSource.notification,
      packageName: 'app.com.brd',
    );
    expect(result, isNotNull);
    expect(result!.amount, 8000);
    expect(result.type, TransactionType.debit);
  });

  test('parses UBL transfer when amount is in notification title only', () {
    final result = parser.parse(
      'Fund transfer to EasyPaisa wallet successful.',
      source: TransactionSource.notification,
      packageName: 'app.com.brd',
      notificationTitle: 'PKR 8,000.00',
    );
    expect(result, isNotNull);
    expect(result!.amount, 8000);
    expect(result.type, TransactionType.debit);
  });

  test('parses UBL Rs amount with slash dash suffix', () {
    final result = parser.parse(
      'Transaction Alert: Rs. 8,000/- debited from A/C ***5678 for FT.',
      source: TransactionSource.notification,
      packageName: 'app.com.brd',
    );
    expect(result, isNotNull);
    expect(result!.amount, 8000);
    expect(result.type, TransactionType.debit);
  });

  test('parses easypaisa received Rs.1 in account via raast', () {
    final result = parser.parse(
      'Dear MUHAMMAD ARHAM BABAR, You have received Rs.1 in your Easypaisa account '
      '***********0101 from MUHAMMAD ARHAM BABAR PK**UNILPKKARTG****7613 via Raast Payment '
      'on 22-06-2026 at 04:18:31. Trx ID: 51649571871',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
      notificationTitle: 'easypaisa',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1);
    expect(result.type, TransactionType.credit);
    expect(result.senderName, 'MUHAMMAD ARHAM BABAR');
  });

  test('rejects easypaisa title only without transaction body', () {
    final result = parser.parse(
      'easypaisa',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
      notificationTitle: 'easypaisa',
    );
    expect(result, isNull);
  });
}
