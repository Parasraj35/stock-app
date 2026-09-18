import 'package:flutter_test/flutter_test.dart';
import 'package:stock/main.dart';
import 'package:stock/data/repos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('fresh install shows the create-account form', (tester) async {
    final repos = await Repos.init();
    await tester.pumpWidget(StockApp(repos: repos));
    await tester.pumpAndSettle();

    expect(find.text('Set up your account'), findsOneWidget);
  });
}
