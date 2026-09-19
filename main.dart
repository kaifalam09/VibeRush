import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade900,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            'UI ERROR\n\n${details.exceptionAsString()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  };

  try {
    await Firebase.initializeApp();

    runApp(const VibeRushApp());

    // Ads are not allowed to block app startup.
    Future<void>(() async {
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        debugPrint('AdMob initialization failed: $e');
      }
    });
  } catch (e, stack) {
    runApp(
      CrashApp(
        error: e.toString(),
        stack: stack.toString(),
      ),
    );
  }
}

class CrashApp extends StatelessWidget {
  final String error;
  final String stack;

  const CrashApp({
    super.key,
    required this.error,
    required this.stack,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'VibeRush Startup Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Firebase/App initialization failed:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'STACK TRACE:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  stack,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VibeRushApp extends StatefulWidget {
  const VibeRushApp({super.key});

  @override
  State<VibeRushApp> createState() => _VibeRushAppState();
}

class _VibeRushAppState extends State<VibeRushApp> {
  ThemeMode themeMode = ThemeMode.dark;

  void changeTheme() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
      home: AuthGate(
        isDark: themeMode == ThemeMode.dark,
        onThemeChanged: changeTheme,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final bool isDark;
  final VoidCallback onThemeChanged;

  const AuthGate({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return CrashApp(
            error: snapshot.error.toString(),
            stack: 'Firebase Auth state error',
          );
        }

        if (snapshot.hasData) {
          return HomePage(
            isDark: isDark,
            onThemeChanged: onThemeChanged,
          );
        }

        return AuthScreen(
          isDark: isDark,
          onThemeChanged: onThemeChanged,
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onThemeChanged;

  const AuthScreen({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool loginMode = true;
  bool loading = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();

  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        error = 'Email aur password bharo.';
      });
      return;
    }

    if (!loginMode && username.isEmpty) {
      setState(() {
        error = 'Username bharo.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (loginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'uid': user.uid,
            'username': username,
            'usernameLower': username.toLowerCase(),
            'email': email,
            'points': 120,
            'streak': 3,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? e.code;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7C4DFF),
                        Color(0xFFE040FB),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loginMode ? 'Welcome back' : 'Join VibeRush',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 30),
                if (!loginMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(loginMode ? 'Login' : 'Sign Up'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      loginMode = !loginMode;
                      error = null;
                    });
                  },
                  child: Text(
                    loginMode
                        ? 'Account nahi hai? Sign up karo'
                        : 'Pehle se account hai? Login karo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onThemeChanged;

  const HomePage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  String username = 'Vibe User';
  int points = 120;
  int streak = 3;

  bool challengeDone = false;
  int challengeIndex = 0;

  final challenges = [
    'Post your best sunset photo 🌅',
    'Send a funny meme to a friend 😂',
    'Share your favorite song 🎵',
    'Take a photo with your best friend 📸',
    'Write one positive thing about today ✨',
  ];

  final pollVotes = [42, 31, 27];

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        points = prefs.getInt('points') ?? 120;
        streak = prefs.getInt('streak') ?? 3;
        challengeDone = prefs.getBool('challengeDone') ?? false;
        challengeIndex = prefs.getInt('challengeIndex') ?? 0;

        if (challengeIndex >= challenges.length) {
          challengeIndex = 0;
        }
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            username =
                (doc.data()?['username'] as String?) ?? 'Vibe User';
          });
        }
      }
    } catch (e) {
      debugPrint('loadUser error: $e');
    }
  }

  Future<void> saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('points', points);
      await prefs.setInt('streak', streak);
      await prefs.setBool('challengeDone', challengeDone);
      await prefs.setInt('challengeIndex', challengeIndex);

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'points': points,
          'streak': streak,
        });
      }
    } catch (e) {
      debugPrint('saveData error: $e');
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> completeChallenge() async {
    if (challengeDone) {
      message('Today\'s challenge already completed 🔥');
      return;
    }

    setState(() {
      challengeDone = true;
      points += 25;
      streak += 1;
    });

    await saveData();

    message('+25 Vibe Points! ⚡');
  }

  Future<void> nextChallenge() async {
    setState(() {
      challengeIndex =
          (challengeIndex + 1) % challenges.length;
      challengeDone = false;
    });

    await saveData();
  }

  Future<void> vote(int index) async {
    setState(() {
      pollVotes[index]++;
      points += 5;
    });

    await saveData();

    message('+5 Vibe Points!');
  }

  Future<void> shareApp() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '🔥 I am using VibeRush!\n\n$points Vibe Points\n$streak day streak ⚡',
          subject: 'VibeRush',
        ),
      );
    } catch (e) {
      message('Share failed');
    }
  }

  Future<void> editProfile() async {
    final controller = TextEditingController(text: username);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: TextField(
            controller: controller,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Your name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();

                if (newName.isNotEmpty) {
                  setState(() {
                    username = newName;
                  });

                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'username': newName,
                        'usernameLower': newName.toLowerCase(),
                      });
                    } catch (e) {
                      debugPrint('profile update error: $e');
                    }
                  }
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void createMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create something',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_camera),
                  ),
                  title: const Text('Create a Vibe Post'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    message('Vibe Post coming soon 📸');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.poll),
                  ),
                  title: const Text('Create a Poll'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    message('Poll creator coming soon 🗳️');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHome(),
      buildChallenge(),
      const FriendsPage(),
      buildProfile(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF7C4DFF),
                    Color(0xFFE040FB),
                  ],
                ),
              ),
              child: const Icon(
                Icons.bolt,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'VibeRush',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: shareApp,
            icon: const Icon(Icons.share),
          ),
          IconButton(
            onPressed: widget.onThemeChanged,
            icon: Icon(
              widget.isDark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createMenu,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Challenge',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF7C4DFF),
                Color(0xFFE040FB),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey, $username 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ready to make today a little more fun?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF6A35C8),
                ),
                onPressed: () {
                  setState(() {
                    selectedIndex = 1;
                  });
                },
                icon: const Icon(Icons.bolt),
                label: const Text('Take today\'s challenge'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: statCard(
                Icons.local_fire_department,
                '$streak',
                'Day streak',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: statCard(
                Icons.star,
                '$points',
                'Vibe points',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        challengeCard(),
        const SizedBox(height: 18),
        pollCard(),
      ],
    );
  }

  Widget statCard(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget challengeCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt),
              SizedBox(width: 10),
              Text(
                'DAILY CHALLENGE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            challenges[challengeIndex],
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Complete it and earn 25 Vibe Points.'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: completeChallenge,
              child: Text(
                challengeDone
                    ? 'Completed ✓'
                    : 'Complete Challenge',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget pollCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.poll),
              SizedBox(width: 10),
              Text(
                'TODAY\'S POLL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'What makes a great day?',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          pollButton('Good friends', 0),
          pollButton('Good music', 1),
          pollButton('Good food', 2),
        ],
      ),
    );
  }

  Widget pollButton(String text, int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: () => vote(index),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text),
            Text('${pollVotes[index]}'),
          ],
        ),
      ),
    );
  }

  Widget buildChallenge() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Today\'s Vibe',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Do something fun and collect Vibe Points.',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 25),
        challengeCard(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your progress',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: (points % 100) / 100,
                minHeight: 12,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(height: 12),
              Text(
                '${points % 100}/100 points until the next level',
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: nextChallenge,
                child: const Text('Next Challenge'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 25),
        CircleAvatar(
          radius: 65,
          backgroundColor: Colors.deepPurple,
          child: Text(
            username.isNotEmpty
                ? username[0].toUpperCase()
                : 'V',
            style: const TextStyle(
              fontSize: 50,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            username,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Center(
          child: Text('VibeRush member'),
        ),
        const SizedBox(height: 30),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: editProfile,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share VibeRush'),
                trailing: const Icon(Icons.chevron_right),
                onTap: shareApp,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text(
                  widget.isDark ? 'Light mode' : 'Dark mode',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onThemeChanged,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final searchController = TextEditingController();

  bool searching = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> sendRequest(
    String uid,
    String username,
  ) async {
    final current = FirebaseAuth.instance.currentUser;

    if (current == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('friendRequests')
          .doc(current.uid)
          .set({
        'fromUid': current.uid,
        'fromUsername': await currentUsername(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $username'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: $e')),
        );
      }
    }
  }

  Future<String> currentUsername() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return 'Vibe User';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      return (doc.data()?['username'] as String?) ?? 'Vibe User';
    } catch (_) {
      return 'Vibe User';
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      searchUsers(String text) async {
    final query = text.trim().toLowerCase();

    if (query.isEmpty) return [];

    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: query)
        .where(
          'usernameLower',
          isLessThan: '$query\uf8ff',
        )
        .limit(20)
        .get();

    return result.docs;
  }

  void search() {
    setState(() {
      searching = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Friends',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Find friends and start chatting.',
          style: TextStyle(fontSize: 17),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => search(),
          decoration: InputDecoration(
            hintText: 'Search username',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: search,
              icon: const Icon(Icons.arrow_forward),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        if (searching)
          FutureBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: searchUsers(searchController.text),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  'Search error: ${snapshot.error}',
                );
              }

              final docs = snapshot.data ?? [];

              final filtered = docs.where(
                (doc) => doc.id != current?.uid,
              );

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No users found.'),
                  ),
                );
              }

              return Column(
                children: filtered.map((doc) {
                  final data = doc.data();
                  final name =
                      data['username'] as String? ?? 'User';

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : 'U',
                        ),
                      ),
                      title: Text(name),
                      subtitle: const Text('VibeRush member'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () {
                          sendRequest(doc.id, name);
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Messages'),
            subtitle: const Text(
              'Chat system will appear here.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessagesPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(25),
          child: Text(
            'Friend chat screen ready.\n\n'
            'Firestore chat rooms can be connected here.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
