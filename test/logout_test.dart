import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/data/auth_session.dart';
import 'package:stock/ui/screens/settings_screen.dart';
import 'package:stock/ui/theme/tokens.dart';

Future<void> _openSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              ),
              child: const Text('open settings'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logging out asks first, then ends the session', (tester) async {
    var loggedOut = 0;
    void listener() => loggedOut++;
    AuthSession.instance.addListener(listener);
    addTearDown(() => AuthSession.instance.removeListener(listener));

    await _openSettings(tester);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    // Confirmation first — nothing has happened yet.
    expect(find.text('Log out?'), findsOneWidget);
    expect(loggedOut, 0);

    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(loggedOut, 1);
    // Every screen above the root was closed, so the login screen the gate
    // switches to isn't hidden behind Settings.
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('open settings'), findsOneWidget);
  });

  testWidgets('cancelling the log-out prompt keeps the session', (
    tester,
  ) async {
    var loggedOut = 0;
    void listener() => loggedOut++;
    AuthSession.instance.addListener(listener);
    addTearDown(() => AuthSession.instance.removeListener(listener));

    await _openSettings(tester);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(loggedOut, 0);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
