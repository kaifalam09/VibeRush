class VibeRushApp extends StatefulWidget {
  const VibeRushApp({super.key});

  @override
  State<VibeRushApp> createState() => _VibeRushAppState();
}

class _VibeRushAppState extends State<VibeRushApp> {
  ThemeMode themeMode = ThemeMode.dark;

  bool firebaseReady = false;
  String? firebaseError;

  @override
  void initState() {
    super.initState();
    initializeServices();
  }

  Future<void> initializeServices() async {
    try {
      await Firebase.initializeApp();

      try {
        await MobileAds.instance.initialize();
      } catch (_) {
        // Ads fail hone par app band nahi hoga.
      }

      if (!mounted) return;

      setState(() {
        firebaseReady = true;
      });
    } catch (e, stack) {
      debugPrint('FIREBASE INITIALIZATION ERROR: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        firebaseError = '$e\n\n$stack';
      });
    }
  }

  void changeTheme() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeRush',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0B0B10),
      ),

      home: _startupScreen(),
    );
  }

  Widget _startupScreen() {
    if (firebaseError != null) {
      return Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firebase Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  firebaseError!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      firebaseError = null;
                      firebaseReady = false;
                    });

                    initializeServices();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!firebaseReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B10),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bolt_rounded,
                color: Colors.deepPurpleAccent,
                size: 70,
              ),
              SizedBox(height: 20),
              Text(
                'VibeRush',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text(
                'Starting VibeRush...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AuthGate(
      onThemeChanged: changeTheme,
      isDark: themeMode == ThemeMode.dark,
    );
  }
}
