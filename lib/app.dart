import 'package:flutter/material.dart';

import 'screens/account_screens.dart';
import 'screens/closet_screens.dart';
import 'screens/discover_screen.dart';
import 'state/closet_store.dart';
import 'state/session_store.dart';
import 'theme.dart';

class ClosetXApp extends StatefulWidget {
  const ClosetXApp({super.key});

  @override
  State<ClosetXApp> createState() => _ClosetXAppState();
}

class _ClosetXAppState extends State<ClosetXApp> {
  late final ClosetStore _store = ClosetStore(garments: const []);
  late final SessionStore _session = SessionStore();

  @override
  void dispose() {
    _store.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      store: _session,
      child: ClosetStoreScope(
        store: _store,
        child: MaterialApp(
          title: 'ClosetX',
          debugShowCheckedModeBanner: false,
          theme: buildClosetTheme(),
          home: AnimatedBuilder(
            animation: _session,
            builder: (context, _) {
              if (!_session.isSignedIn) {
                return LoginScreen(
                  onContinue: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClosetShell(),
                    ),
                  ),
                );
              }
              return _session.needsGoogleRoleSelection
                  ? const GoogleRoleSetupScreen()
                  : const ClosetShell();
            },
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
    final isDesigner = SessionScope.of(context).profile?.isDesigner == true;
    final pages = [
      const DiscoverScreen(),
      isDesigner ? const DesignerStudioScreen() : const SavedScreen(),
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
          NavigationDestination(
            icon: Icon(
              isDesigner
                  ? Icons.checkroom_outlined
                  : Icons.bookmark_border_rounded,
            ),
            label: isDesigner ? 'My Designs' : 'Saved',
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
