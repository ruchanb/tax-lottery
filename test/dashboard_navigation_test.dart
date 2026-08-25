import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kar_upahar/src/app.dart';
import 'package:kar_upahar/src/data/local_store.dart';
import 'package:kar_upahar/src/models.dart';
import 'package:kar_upahar/src/services/firebase_service.dart';

class _EmptyLocalStore extends LocalStore {
  @override
  Future<List<BillEntry>> getBills() async => const [];
}

void main() {
  testWidgets('active coupons opens Bills with the Active filter selected',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          profile: const UserProfile(
            name: 'Test user',
            mobile: '9812345678',
            address: 'Kathmandu',
          ),
          language: AppLanguage.en,
          store: _EmptyLocalStore(),
          firebase: FirebaseService(enabled: false),
          onLanguageChanged: (_) {},
          onProfileChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    SegmentedButton<bool> filter = tester.widget(
      find.byWidgetPredicate((widget) => widget is SegmentedButton<bool>),
    );
    expect(filter.selected, {false});

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active coupons'));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 1);

    filter = tester.widget(
      find.byWidgetPredicate((widget) => widget is SegmentedButton<bool>),
    );
    expect(filter.selected, {true});
  });
}
