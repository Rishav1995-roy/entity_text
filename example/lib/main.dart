import 'package:flutter/material.dart';

import 'screens/composer_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/playground_screen.dart';

void main() => runApp(const ExampleApp());

/// Root of the example app.
class ExampleApp extends StatelessWidget {
  const ExampleApp({
    super.key,
    this.initialTab = 0,
    this.dark = false,
    this.flatShadows = false,
  });

  final int initialTab;
  final bool dark;

  /// Removes shadows (used when rendering the doc images in the test engine).
  final bool flatShadows;

  ColorScheme _scheme(Brightness b) {
    final s = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B5BDB),
      brightness: b,
    );
    return flatShadows ? s.copyWith(shadow: Colors.transparent) : s;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'entity_text',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: _scheme(Brightness.light),
        shadowColor: flatShadows ? Colors.transparent : null,
      ),
      darkTheme: ThemeData(
        colorScheme: _scheme(Brightness.dark),
        shadowColor: flatShadows ? Colors.transparent : null,
      ),
      home: HomeShell(initialTab: initialTab),
    );
  }
}

/// Bottom navigation with the three demo screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    const titles = ['Feed', 'Composer', 'Playground'];
    return Scaffold(
      appBar: AppBar(title: Text('entity_text - ${titles[_index]}')),
      body: IndexedStack(
        index: _index,
        children: const [FeedScreen(), ComposerScreen(), PlaygroundScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.edit), label: 'Composer'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Playground'),
        ],
      ),
    );
  }
}
