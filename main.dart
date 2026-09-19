import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Text(
            'ERROR:\n\n${details.exceptionAsString()}\n\n${details.stack}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runZonedGuarded<void>(() async {
    await Firebase.initializeApp();

    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // Ads not critical — app still works without them.
    }

    runApp(const VibeRushApp());
  }, (Object error, StackTrace stack) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Text(
                  'CRASH:\n\n$error\n\n$stack',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
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
        onThemeChanged: changeTheme,
        isDark: themeMode == ThemeMode.dark,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final VoidCallback onThemeChanged;
  final bool isDark;

  const AuthGate({
    super.key,
    required this.onThemeChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return HomePage(
            onThemeChanged: onThemeChanged,
            isDark: isDark,
          );
        }

        return AuthScreen(onThemeChanged: onThemeChanged, isDark: isDark);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final bool isDark;

  const AuthScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDark,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLoginMode = true;
  bool isLoading = false;
  String? errorMessage;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();
    final String username = usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Email aur password bharo';
      });
      return;
    }

    if (!isLoginMode && username.isEmpty) {
      setState(() {
        errorMessage = 'Username bharo';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final String uid = cred.user!.uid;
        final String usernameLower = username.toLowerCase();

        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          <String, dynamic>{
            'uid': uid,
            'username': username,
            'usernameLower': usernameLower,
            'email': email,
            'points': 120,
            'streak': 3,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'Kuch galat ho gaya';
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFF7C4DFF),
                        Color(0xFFE040FB),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isLoginMode ? 'Welcome back' : 'Join VibeRush',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                if (!isLoginMode)
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
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading ? null : submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(isLoginMode ? 'Login' : 'Sign Up'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLoginMode = !isLoginMode;
                      errorMessage = null;
                    });
                  },
                  child: Text(
                    isLoginMode
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
  final VoidCallback onThemeChanged;
  final bool isDark;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.isDark,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  int points = 120;
  int streak = 3;

  String username = 'Vibe User';

  bool challengeDone = false;

  final List<String> challenges = <String>[
    'Post your best sunset photo 🌅',
    'Send a funny meme to a friend 😂',
    'Share your current favorite song 🎵',
    'Take a photo with your best friend 📸',
    'Write one positive thing about today ✨',
  ];

  int challengeIndex = 0;

  final List<int> pollVotes = <int>[42, 31, 27];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      points = prefs.getInt('points') ?? 120;
      streak = prefs.getInt('streak') ?? 3;
      challengeDone = prefs.getBool('challengeDone') ?? false;
      challengeIndex = prefs.getInt('challengeIndex') ?? 0;

      if (challengeIndex >= challenges.length) {
        challengeIndex = 0;
      }
    });

    await loadUsername();
  }

  Future<void> loadUsername() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) {
      return;
    }

    if (doc.exists) {
      setState(() {
        username = (doc.data()?['username'] as String?) ?? 'Vibe User';
      });
    }
  }

  Future<void> saveData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setInt('points', points);
    await prefs.setInt('streak', streak);
    await prefs.setBool('challengeDone', challengeDone);
    await prefs.setInt('challengeIndex', challengeIndex);

    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(<String, dynamic>{
        'points': points,
        'streak': streak,
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> completeChallenge() async {
    if (challengeDone) {
      showMessage('Today\'s challenge is already completed 🔥');
      return;
    }

    setState(() {
      challengeDone = true;
      points += 25;
      streak += 1;
    });

    await saveData();

    showMessage('+25 Vibe Points! 🔥');
  }

  Future<void> nextChallenge() async {
    setState(() {
      challengeIndex = (challengeIndex + 1) % challenges.length;
      challengeDone = false;
    });

    await saveData();
  }

  Future<void> vote(int option) async {
    setState(() {
      pollVotes[option] += 1;
      points += 5;
    });

    await saveData();

    showMessage('+5 Vibe Points! Your vote has been counted.');
  }

  Future<void> editProfile() async {
    final TextEditingController controller =
        TextEditingController(text: username);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: TextField(
            controller: controller,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'Enter your name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final String newName = controller.text.trim();

                if (newName.isNotEmpty) {
                  setState(() {
                    username = newName;
                  });

                  final User? user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update(<String, dynamic>{
                      'username': newName,
                      'usernameLower': newName.toLowerCase(),
                    });
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
  }

  Future<void> shareVibe() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '🔥 I am using VibeRush!\n\nMy Vibe Score: $points points\nStreak: $streak days\n\nJoin the vibe! ⚡',
        subject: 'VibeRush',
      ),
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void openCreate() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Create something',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_camera_rounded),
                  ),
                  title: const Text('Create a Vibe Post'),
                  subtitle: const Text('Share a moment with your friends'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showMessage('Vibe Post creator coming soon 📸');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.poll_rounded),
                  ),
                  title: const Text('Create a Poll'),
                  subtitle: const Text('Ask your friends a question'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showMessage('Poll creator opened 🗳️');
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
    final List<Widget> pages = <Widget>[
      buildHome(),
      buildChallengePage(),
      const FriendsPage(),
      buildProfile(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF7C4DFF),
                    Color(0xFFE040FB),
                  ],
                ),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'VibeRush',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share VibeRush',
            onPressed: shareVibe,
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: widget.onThemeChanged,
            icon: Icon(
              widget.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openCreate,
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt_rounded),
            label: 'Challenge',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
        children: <Widget>[
          buildGreetingCard(),
          const SizedBox(height: 18),
          buildStats(),
          const SizedBox(height: 18),
          buildDailyChallengeCard(),
          const SizedBox(height: 18),
          buildPollCard(),
          const SizedBox(height: 18),
          buildShareCard(),
          const SizedBox(height: 18),
          const AdBanner(),
        ],
      ),
    );
  }

  Widget buildGreetingCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF6C3BFF),
            Color(0xFFE03BFF),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Hey, $username 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to make today a little more fun?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6C3BFF),
            ),
            onPressed: () {
              setState(() {
                selectedIndex = 1;
              });
            },
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Take today\'s challenge'),
          ),
        ],
      ),
    );
  }

  Widget buildStats() {
    return Row(
      children: <Widget>[
        Expanded(
          child: statCard(
            icon: Icons.local_fire_department_rounded,
            value: '$streak',
            label: 'Day streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: statCard(
            icon: Icons.stars_rounded,
            value: '$points',
            label: 'Vibe points',
          ),
        ),
      ],
    );
  }

  Widget statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 30),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDailyChallengeCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.bolt_rounded),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'DAILY CHALLENGE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: nextChallenge,
                  child: const Text('Next'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              challenges[challengeIndex],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete it and earn 25 Vibe Points.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: completeChallenge,
                child: Text(
                  challengeDone ? 'Completed ✓' : 'Complete Challenge',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPollCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.poll_rounded),
                SizedBox(width: 8),
                Text(
                  'TODAY\'S POLL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'What makes a perfect weekend?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            pollButton(0, '🎮 Gaming with friends'),
            pollButton(1, '🍿 Movies + snacks'),
            pollButton(2, '🌄 Going somewhere'),
          ],
        ),
      ),
    );
  }

  Widget pollButton(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => vote(index),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(text)),
            Text('${pollVotes[index]}%'),
          ],
        ),
      ),
    );
  }

  Widget buildShareCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 28,
              child: Icon(Icons.share_rounded),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Share your Vibe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Invite your friends to VibeRush.'),
                ],
              ),
            ),
            IconButton(
              onPressed: shareVibe,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChallengePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      children: <Widget>[
        const Text(
          'Today\'s Vibe',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Do something fun and collect Vibe Points.',
        ),
        const SizedBox(height: 20),
        buildDailyChallengeCard(),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Your progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 15),
                LinearProgressIndicator(
                  value: (points % 100) / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 10),
                Text('${points % 100}/100 points until the next level'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildProfile() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 100),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 48,
            child: Text(
              username.isEmpty ? 'V' : username[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            username,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text('VibeRush member'),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit profile'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: editProfile,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share VibeRush'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: shareVibe,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  widget.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                title: Text(
                  widget.isDark ? 'Light mode' : 'Dark mode',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onThemeChanged,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: signOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const AdBanner(),
      ],
    );
  }
}

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Friends feature coming in the next update 👀',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? bannerAd;
  bool loaded = false;

  static const String bannerId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  @override
  void initState() {
    super.initState();
    loadAd();
  }

  void loadAd() {
    try {
      final BannerAd ad = BannerAd(
        adUnitId: bannerId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (!mounted) {
              return;
            }

            setState(() {
              bannerAd = ad as BannerAd;
              loaded = true;
            });
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            ad.dispose();

            if (!mounted) {
              return;
            }

            setState(() {
              loaded = false;
            });
          },
        ),
      );

      ad.load();
    } catch (_) {
      // If ads fail to initialize, just skip them silently.
    }
  }

  @override
  void dispose() {
    bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded || bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: bannerAd!.size.width.toDouble(),
        height: bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: bannerAd!),
      ),
    );
  }
}
