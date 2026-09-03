import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_tracker/models/transaction.dart';
import 'package:spend_tracker/providers/category_catalog.dart';
import 'package:spend_tracker/widgets/home_sections.dart';
import 'package:spend_tracker/widgets/transaction_tile.dart';

Transaction _tx({
  required String merchant,
  required TransactionStatus status,
  double amount = 18337,
}) {
  return Transaction(
    id: '1',
    amount: amount,
    type: TransactionType.debit,
    merchant: merchant,
    categoryId: SpendingCategory.other.storageKey,
    occurredAt: DateTime(2026, 9, 3, 15, 25),
    source: TransactionSource.notification,
    status: status,
    fingerprint: 'fp-$merchant',
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) {
    return ChangeNotifierProvider<CategoryCatalog>.value(
      value: CategoryCatalog.instance,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('home list dims a failed payment instead of a red amount',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        HomeRecentActivity(
          transactions: [
            _tx(merchant: 'CURSOR', status: TransactionStatus.failed),
            _tx(
              merchant: 'Foodpanda',
              status: TransactionStatus.confirmed,
              amount: 4794,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Failed payment'), findsOneWidget);
    expect(find.text('−Rs 18,337'), findsNothing);
    expect(find.text('CURSOR'), findsOneWidget);
    expect(find.text('Foodpanda'), findsOneWidget);
    expect(find.text('−Rs 4,794'), findsOneWidget);
  });

  testWidgets('transaction tile labels a failed payment as Failed',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        TransactionTile(
          transaction: _tx(
            merchant: 'CURSOR',
            status: TransactionStatus.failed,
          ),
        ),
      ),
    );

    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Failed payment'), findsOneWidget);
    expect(find.text('−Rs 18,337'), findsNothing);
  });
}
