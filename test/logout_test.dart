import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/password.dart';
import 'package:stock/data/auth_session.dart';
import 'package:stock/ui/screens/lock_screen.dart';
import 'package:stock/ui/screens/settings_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/logout_button.dart';

/// A root screen with a button that pushes [screen] on top of it, like the
/// real app opening Profile over the main shell.
Future<void> _openOverRoot(WidgetTester tester, Widget screen) async {
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
                MaterialPageRoute(builder: (context) => screen),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final _dialogConfirm = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('LOG OUT'),
);

void main() {
  group('log out button (on the Profile screen)', () {
    testWidgets('asks first, then ends the session', (tester) async {
      var loggedOut = 0;
      void listener() => loggedOut++;
      AuthSession.instance.addListener(listener);
      addTearDown(() => AuthSession.instance.removeListener(listener));

      await _openOverRoot(
        tester,
        Scaffold(
          body: Padding(padding: EdgeInsets.all(20), child: LogoutButton()),
        ),
      );
      await tester.tap(find.text('LOG OUT'));
      await tester.pumpAndSettle();

      // Confirmation first — nothing has happened yet.
      expect(find.text('Log out?'), findsOneWidget);
      expect(loggedOut, 0);

      await tester.tap(_dialogConfirm);
      await tester.pumpAndSettle();

      expect(loggedOut, 1);
      // Every screen above the root was closed, so the login screen the gate
      // switches to isn't hidden behind Profile.
      expect(find.byType(LogoutButton), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('cancelling keeps the session', (tester) async {
      var loggedOut = 0;
      void listener() => loggedOut++;
      AuthSession.instance.addListener(listener);
      addTearDown(() => AuthSession.instance.removeListener(listener));

      await _openOverRoot(
        tester,
        Scaffold(
          body: Padding(padding: EdgeInsets.all(20), child: LogoutButton()),
        ),
      );
      await tester.tap(find.text('LOG OUT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(loggedOut, 0);
      expect(find.byType(LogoutButton), findsOneWidget);
    });
  });

  testWidgets('Settings no longer has a Log out row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: SettingsScreen()),
    );
    expect(find.text('Profile'), findsOneWidget); // the row still there
    expect(find.textContaining('Log out', findRichText: true), findsNothing);
    expect(find.byType(LogoutButton), findsNothing);
  });

  group('PIN screen', () {
    AppUser user() => AppUser(
      username: '0300',
      passwordHash: hashPassword('Passw0rd'),
      pinHash: hashPassword('1234'),
    );

    Future<void> pump(
      WidgetTester tester,
      VoidCallback onUnlocked, {
      VoidCallback? onUseFullLogin,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LockScreen(
          user: user(),
          onUnlocked: onUnlocked,
          onUseFullLogin: onUseFullLogin ?? () {},
        ),
      ),
    );

    Future<void> wrongPin(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField), '0000');
      await tester.pump();
    }

    testWidgets('starts clean, with no Forgot link', (tester) async {
      await pump(tester, () {});
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(find.textContaining('Forgot'), findsNothing);
    });

    testWidgets('after 5 wrong PINs it offers the password login', (
      tester,
    ) async {
      var fullLogin = 0;
      await pump(tester, () {}, onUseFullLogin: () => fullLogin++);

      for (var i = 0; i < 4; i++) {
        await wrongPin(tester);
      }
      expect(find.textContaining('Forgot'), findsNothing); // 4 — not yet

      await wrongPin(tester); // the 5th
      expect(find.text('Forgot PIN? Log in with password'), findsOneWidget);

      await tester.tap(find.text('Forgot PIN? Log in with password'));
      await tester.pump();
      expect(fullLogin, 1);
    });

    testWidgets('the right PIN still unlocks once the link is showing', (
      tester,
    ) async {
      var unlocked = 0;
      await pump(tester, () => unlocked++);
      for (var i = 0; i < 5; i++) {
        await wrongPin(tester);
      }
      await tester.enterText(find.byType(TextFormField), '1234');
      await tester.pump();
      expect(unlocked, 1);
    });

    testWidgets('the right PIN unlocks, a wrong one does not', (tester) async {
      var unlocked = 0;
      await pump(tester, () => unlocked++);

      await tester.enterText(find.byType(TextFormField), '0000');
      await tester.pump();
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(unlocked, 0);

      await tester.enterText(find.byType(TextFormField), '1234');
      await tester.pump();
      expect(unlocked, 1);
    });
  });
}
