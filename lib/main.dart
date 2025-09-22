import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CW1App());

class CW1App extends StatefulWidget {
  const CW1App({super.key});
  @override
  State<CW1App> createState() => _CW1AppState();
}

class _CW1AppState extends State<CW1App> with SingleTickerProviderStateMixin {
  // -------- persisted state --------
  int _counter = 0;
  bool _showFirstImage = true;
  bool _isDark = false;

  // -------- animation --------
  late final AnimationController _controller;
  late final Animation<double> _fade;

  // Your images are in the PROJECT ROOT (next to pubspec.yaml)
  final AssetImage _imgA = const AssetImage('img1.jpeg');
  final AssetImage _imgB = const AssetImage('img2.jpeg');

  // Use a navigatorKey so the dialog always has a valid context
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.value = 1.0; // show first image immediately

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-cache images (avoid flicker)
      precacheImage(_imgA, context);
      precacheImage(_imgB, context);
    });

    _loadState();
  }

  // ---------- persistence ----------
  Future<void> _loadState() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _counter = p.getInt('counter') ?? 0;
      _showFirstImage = p.getBool('showFirstImage') ?? true;
      _isDark = p.getBool('isDark') ?? false;
    });
  }

  Future<void> _saveState() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('counter', _counter);
    await p.setBool('showFirstImage', _showFirstImage);
    await p.setBool('isDark', _isDark);
  }

  // ---------- actions ----------
  void _increment() {
    setState(() => _counter++);
    _saveState();
  }

  void _toggleImage() {
    setState(() => _showFirstImage = !_showFirstImage);
    _controller
      ..value = 0
      ..forward();
    _saveState();
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    _saveState();
  }

  // ---------- reset (robust) ----------
  Future<void> _resetAll() async {
    // Use the navigatorKey's context to avoid "no Navigator" issues
    final ctx = _navKey.currentContext ?? context;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Reset'),
        content: const Text(
          'Reset counter to 0 and image to the first one, and clear saved data?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    // Persist a clean baseline so relaunch also starts at zero
    final p = await SharedPreferences.getInstance();
    await p.setInt('counter', 0);
    await p.setBool('showFirstImage', true);
    await p.setBool('isDark', false);

    // Update the on-screen state immediately
    setState(() {
      _counter = 0;
      _showFirstImage = true;
      _isDark = false;
    });

    _controller.value = 1.0; // ensure image is visible right away

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reset complete')));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey, // <- important
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CW1 — Counter + Image + Reset'),
          centerTitle: true,
        ),
        body: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              // Counter
              Center(
                child: Text(
                  'Counter: $_counter',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Increment'),
                  onPressed: _increment,
                ),
              ),

              const SizedBox(height: 28),

              // Image + fade
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: Image(
                    image: _showFirstImage ? _imgA : _imgB,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Text(
                      'Image not found. Check filename & pubspec assets.',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Toggle Image'),
                  onPressed: _toggleImage,
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.brightness_6),
                  label: Text(
                    _isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  ),
                  onPressed: _toggleTheme,
                ),
              ),

              const SizedBox(height: 20),
              // Visually distinct reset
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () async => _resetAll(), // wrap async in a closure
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
