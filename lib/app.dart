import 'package:flutter/material.dart';

import 'data/garments.dart';
import 'screens/closet_screens.dart';
import 'screens/discover_screen.dart';
import 'state/closet_store.dart';
import 'supabase/supabase_config.dart';
import 'theme.dart';

class ClosetXApp extends StatefulWidget {
  const ClosetXApp({super.key});

  @override
  State<ClosetXApp> createState() => _ClosetXAppState();
}

class _ClosetXAppState extends State<ClosetXApp> {
  late final ClosetStore _store = ClosetStore(garments: sampleGarments);

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClosetStoreScope(
      store: _store,
      child: MaterialApp(
        title: 'ClosetX',
        debugShowCheckedModeBanner: false,
        theme: buildClosetTheme(),
        home: isSupabaseConfigured
            ? const ClosetShell()
            : Builder(
                builder: (context) => LoginScreen(
                  onContinue: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClosetShell(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class ClosetShell extends StatefulWidget {
  const ClosetShell({super.key});

  @override
  State<ClosetShell> createState() => _ClosetShellState();
}

class _ClosetShellState extends State<ClosetShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DiscoverScreen(),
      const SavedScreen(),
      const ImpactScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            label: 'Saved',
          ),
          const NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            label: 'Impact',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
