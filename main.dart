import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const VibeRushApp());
}

class AppConfig {
  // Google test IDs. For real AdMob earnings, replace these with your own IDs
  // or pass them from GitHub Actions with --dart-define.
  static const bannerId = String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const interstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');
}

class Challenge {
  final String title, subtitle, emoji;
  final int points;
  const Challenge(this.title, this.subtitle, this.emoji, this.points);
}

const challenges = <Challenge>[
  Challenge('No-Look Selfie', 'Take a funny selfie without checking the camera first.', '📸', 50),
  Challenge('One-Word Vibe', 'Describe your mood today using exactly one word.', '⚡', 30),
  Challenge('Friend Roast', 'Write a harmless, funny compliment for your best friend.', '😂', 40),
  Challenge('Desk Flex', 'Show your study or gaming setup.', '🎮', 45),
  Challenge('Random Skill', 'Show one safe skill you can do surprisingly well.', '🔥', 60),
  Challenge('Old Photo', 'Share a favorite memory from your camera roll.', '🫶', 35),
  Challenge('Emoji Story', 'Tell a tiny story using only five emojis.', '😎', 25),
];

class PollModel {
  final String question;
  final List<String> options;
  final List<int> votes;
  PollModel(this.question, this.options, this.votes);
  Map<String, dynamic> toJson() => {'q': question, 'o': options, 'v': votes};
  factory PollModel.fromJson(Map<String, dynamic> j) => PollModel(j['q'], List<String>.from(j['o']), List<int>.from(j['v']));
}

final defaultPolls = <PollModel>[
  PollModel('Weekend plan?', ['Gaming 🎮', 'Out with friends 🧋', 'Movies 🍿', 'Sleep 😴'], [12, 19, 8, 15]),
  PollModel('Best vibe?', ['Chill 🌙', 'Hype 🔥', 'Funny 😂', 'Creative 🎨'], [14, 11, 23, 9]),
  PollModel('Choose one?', ['Pizza 🍕', 'Burger 🍔', 'Momos 🥟', 'Biryani 🍚'], [21, 17, 14, 26]),
];

class VibeRushApp extends StatefulWidget {
  const VibeRushApp({super.key});
  @override State<VibeRushApp> createState() => _VibeRushAppState();
}
class _VibeRushAppState extends State<VibeRushApp> {
  bool dark = true;
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'VibeRush',
    theme: ThemeData(useMaterial3: true, brightness: dark ? Brightness.dark : Brightness.light, colorSchemeSeed: const Color(0xFF8B5CF6), scaffoldBackgroundColor: dark ? const Color(0xFF09090B) : const Color(0xFFF7F7FB), fontFamily: 'sans'),
    home: MainShell(onTheme: () => setState(() => dark = !dark)),
  );
}

class AppStore extends ChangeNotifier {
  late SharedPreferences prefs;
  int score = 0, streak = 1;
  String name = 'Vibe Friend';
  Set<String> completed = {};
  List<PollModel> polls = defaultPolls.map((p) => PollModel(p.question, List.of(p.options), List.of(p.votes))).toList();
  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    score = prefs.getInt('score') ?? 0; streak = prefs.getInt('streak') ?? 1; name = prefs.getString('name') ?? 'Vibe Friend';
    completed = (prefs.getStringList('completed') ?? []).toSet();
    final raw = prefs.getString('polls');
    if (raw != null) polls = (jsonDecode(raw) as List).map((e) => PollModel.fromJson(e)).toList();
    notifyListeners();
  }
  Future<void> save() async {
    await prefs.setInt('score', score); await prefs.setInt('streak', streak); await prefs.setString('name', name);
    await prefs.setStringList('completed', completed.toList()); await prefs.setString('polls', jsonEncode(polls.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
  void addPoints(int p, String key) { if (completed.add(key)) { score += p; save(); } }
}

class MainShell extends StatefulWidget {
  final VoidCallback onTheme;
  const MainShell({super.key, required this.onTheme});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  final store = AppStore(); int tab = 0; bool loading = true; InterstitialAd? interstitial;
  @override void initState() { super.initState(); store.load().then((_) { setState(() => loading = false); _loadAd(); }); }
  void _loadAd() { InterstitialAd.load(adUnitId: AppConfig.interstitialId, request: const AdRequest(), adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (a) => interstitial = a, onAdFailedToLoad: (_) {})); }
  void showAd() { final a = interstitial; if (a != null) { a.fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadAd(); }); a.show(); interstitial = null; } }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [HomePage(store: store, onAd: showAd), ChallengePage(store: store, onAd: showAd), PollPage(store: store), LeaderboardPage(store: store), ProfilePage(store: store, onTheme: widget.onTheme)];
    return AnimatedBuilder(animation: store, builder: (_, __) => Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Challenges'), NavigationDestination(icon: Icon(Icons.poll_outlined), selectedIcon: Icon(Icons.poll), label: 'Polls'), NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Ranks'), NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'You')]),
    ));
  }
}

class AdBanner extends StatefulWidget { const AdBanner({super.key}); @override State<AdBanner> createState() => _AdBannerState(); }
class _AdBannerState extends State<AdBanner> { BannerAd? ad; @override void initState(){super.initState(); ad=BannerAd(adUnitId: AppConfig.bannerId, size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdFailedToLoad:(a,_)=>a.dispose()))..load();} @override void dispose(){ad?.dispose();super.dispose();} @override Widget build(BuildContext c)=>ad==null?const SizedBox(height:0):SizedBox(height:50,width:double.infinity,child:AdWidget(ad:ad!)); }

Widget header(BuildContext context, String title, String subtitle) => Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))])), Container(width: 44,height:44,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,color:Theme.of(context).colorScheme.primaryContainer),child:const Text('⚡',style:TextStyle(fontSize:22)))]));

class HomePage extends StatelessWidget { final AppStore store; final VoidCallback onAd; const HomePage({super.key,required this.store,required this.onAd}); @override Widget build(BuildContext c)=>ListView(children:[header(c,'VibeRush','Your daily dose of fun'), Padding(padding:const EdgeInsets.symmetric(horizontal:16),child: _HeroCard(store:store,onAd:onAd)), const SizedBox(height:16), const AdBanner(), const SizedBox(height:12), Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Text('Quick Vibes',style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))), const SizedBox(height:10), Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[Expanded(child:_StatCard(icon:'🔥',value:'${store.streak}',label:'Day streak')),const SizedBox(width:10),Expanded(child:_StatCard(icon:'⭐',value:'${store.score}',label:'Vibe points')),const SizedBox(width:10),Expanded(child:_StatCard(icon:'🎯',value:'${store.completed.length}',label:'Completed'))])), const SizedBox(height:20), Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Text('Today on VibeRush',style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))), const SizedBox(height:8), ...challenges.take(3).map((x)=>ListTile(leading:CircleAvatar(child:Text(x.emoji)),title:Text(x.title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(x.subtitle,maxLines:1,overflow:TextOverflow.ellipsis),trailing:Text('+${x.points}'))), const SizedBox(height:30)]); }
class _HeroCard extends StatelessWidget {final AppStore store;final VoidCallback onAd;const _HeroCard({required this.store,required this.onAd});@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(28),gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Theme.of(c).colorScheme.primary,Theme.of(c).colorScheme.tertiary])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('⚡ DAILY VIBE',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.5)),const SizedBox(height:8),Text(challenges[DateTime.now().day%challenges.length].title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(challenges[DateTime.now().day%challenges.length].subtitle),const SizedBox(height:16),FilledButton.tonal(onPressed:(){onAd();},child:const Text('Take the challenge'))]));}
class _StatCard extends StatelessWidget {final String icon,value,label;const _StatCard({required this.icon,required this.value,required this.label});@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(c).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(18)),child:Column(children:[Text(icon,style:const TextStyle(fontSize:24)),const SizedBox(height:5),Text(value,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18)),Text(label,style:TextStyle(fontSize:11,color:Theme.of(c).colorScheme.onSurfaceVariant),textAlign:TextAlign.center)]));}

class ChallengePage extends StatelessWidget { final AppStore store; final VoidCallback onAd; const ChallengePage({super.key,required this.store,required this.onAd}); @override Widget build(BuildContext c)=>ListView(children:[header(c,'Challenges','Complete safe challenges, earn points'),...challenges.asMap().entries.map((e){final x=e.value;final key='${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}-${e.key}';final done=store.completed.contains(key);return Padding(padding:const EdgeInsets.fromLTRB(16,6,16,6),child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[Container(width:54,height:54,alignment:Alignment.center,decoration:BoxDecoration(color:Theme.of(c).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(16)),child:Text(x.emoji,style:const TextStyle(fontSize:27))),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:4),Text(x.subtitle,maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:6),Text('+${x.points} points',style:TextStyle(color:Theme.of(c).colorScheme.primary,fontWeight:FontWeight.bold))])),const SizedBox(width:8),IconButton(onPressed:done?null:(){showDialog(context:c,builder:(_)=>AlertDialog(title:Text('${x.emoji} ${x.title}'),content:Text(x.subtitle),actions:[TextButton(onPressed:(){Navigator.pop(c);},child:const Text('Later')),FilledButton(onPressed:(){store.addPoints(x.points,key);Navigator.pop(c);onAd();},child:const Text('Done'))]));},icon:Icon(done?Icons.check_circle:Icons.arrow_forward_rounded,color:done?Colors.green:null))]))));}),const SizedBox(height:30)]); }

class PollPage extends StatefulWidget { final AppStore store; const PollPage({super.key,required this.store}); @override State<PollPage> createState()=>_PollPageState(); }
class _PollPageState extends State<PollPage> { final Set<int> voted={}; @override Widget build(BuildContext c)=>ListView(children:[header(c,'Poll Zone','Vote, see the vibe, share it'),...widget.store.polls.asMap().entries.map((entry){final i=entry.key,p=entry.value;final total=p.votes.fold<int>(0,(a,b)=>a+b);return Padding(padding:const EdgeInsets.fromLTRB(16,6,16,8),child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.question,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:14),...p.options.asMap().entries.map((o){final percent=total==0?0:p.votes[o.key]/total;return Padding(padding:const EdgeInsets.only(bottom:8),child:InkWell(borderRadius:BorderRadius.circular(14),onTap:voted.contains(i)?null:(){setState((){p.votes[o.key]++;voted.add(i);});widget.store.save();},child:Stack(alignment:Alignment.center,children:[Container(height:48,decoration:BoxDecoration(color:Theme.of(c).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(14))),if(voted.contains(i))Align(alignment:Alignment.centerLeft,child:FractionallySizedBox(width:percent,child:Container(height:48,decoration:BoxDecoration(color:Theme.of(c).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(14))))),Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Row(children:[Expanded(child:Text(o.value)),if(voted.contains(i))Text('${(percent*100).round()}%')]))])));})]))));}),const SizedBox(height:30)]); }

class LeaderboardPage extends StatelessWidget { final AppStore store; const LeaderboardPage({super.key,required this.store}); @override Widget build(BuildContext c){final people=[['Aarav',980],['Zoya',870],['Kabir',760],['Mira',690],['You',store.score]]..sort((a,b)=>(b[1] as int).compareTo(a[1] as int));return ListView(children:[header(c,'Leaderboard','Friendly competition only 🫶'),Padding(padding:const EdgeInsets.all(16),child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Text('🏆',style:TextStyle(fontSize:50)),const Text('Your Vibe Score',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('${store.score}',style:const TextStyle(fontSize:42,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Keep completing challenges to grow your score.',style:TextStyle(color:Theme.of(c).colorScheme.onSurfaceVariant))])))),...people.asMap().entries.map((e)=>ListTile(leading:CircleAvatar(child:Text('${e.key+1}')),title:Text(e.value[0].toString(),style:const TextStyle(fontWeight:FontWeight.w700)),trailing:Text('${e.value[1]} pts',style:const TextStyle(fontWeight:FontWeight.bold)))),const SizedBox(height:30)]);}}

class ProfilePage extends StatefulWidget { final AppStore store; final VoidCallback onTheme; const ProfilePage({super.key,required this.store,required this.onTheme}); @override State<ProfilePage> createState()=>_ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage>{final nameCtrl=TextEditingController();@override void initState(){super.initState();nameCtrl.text=widget.store.name;}@override void dispose(){nameCtrl.dispose();super.dispose();}@override Widget build(BuildContext c)=>ListView(children:[header(c,'Your Vibe','Make the app yours'),Center(child:Container(width:96,height:96,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,color:Theme.of(c).colorScheme.primaryContainer),child:const Text('😎',style:TextStyle(fontSize:50)))),const SizedBox(height:12),Center(child:Text(widget.store.name,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900))),const SizedBox(height:20),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:TextField(controller:nameCtrl,maxLength:24,decoration:const InputDecoration(labelText:'Display name',prefixIcon:Icon(Icons.badge_outlined),border:OutlineInputBorder()),onSubmitted:(v){if(v.trim().isNotEmpty){widget.store.name=v.trim();widget.store.save();setState((){});}})),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:FilledButton.icon(onPressed:(){final v=nameCtrl.text.trim();if(v.isNotEmpty){widget.store.name=v;widget.store.save();setState((){});FocusScope.of(c).unfocus();}},icon:const Icon(Icons.save),label:const Text('Save profile'))),const SizedBox(height:8),ListTile(leading:const Icon(Icons.dark_mode_outlined),title:const Text('Toggle theme'),subtitle:const Text('Switch between dark and light mode'),trailing:Switch(value:Theme.of(c).brightness==Brightness.dark,onChanged:(_)=>widget.onTheme())),ListTile(leading:const Icon(Icons.share_outlined),title:const Text('Share VibeRush'),subtitle:const Text('Invite your friends'),onTap:()async{await Share.share('⚡ I am using VibeRush! Join me for daily challenges, polls and fun.');}),ListTile(leading:const Icon(Icons.info_outline),title:const Text('About VibeRush'),subtitle:const Text('A fun social challenge app for friends.')),const SizedBox(height:30),const AdBanner()]);}
