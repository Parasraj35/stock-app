import 'package:flutter/material.dart';

import '../data/repos.dart';
import 'screens/brands_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/entry_list_screen.dart';
import 'widgets/bottom_tab_bar.dart';

/// Bottom-nav shell for the 4 main screens, shown after login.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(),
      EntryListScreen(title: 'Purchase', repository: Repos.instance.purchases),
      EntryListScreen(title: 'Sale', repository: Repos.instance.sales),
      BrandsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
