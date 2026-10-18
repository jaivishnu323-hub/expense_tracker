import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────── Theme constants ─────────────────────────
const kBg = Color(0xFF0A1122);
const kCard = Color(0xFF121C33);
const kCard2 = Color(0xFF18243F);
const kBorder = Color(0xFF222F4D);
const kBlue = Color(0xFF1677FF);
const kGreen = Color(0xFF22C55E);
const kRed = Color(0xFFEF3F5F);
const kMuted = Color(0xFF8C9AB5);

const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const expenseCats = ['Food', 'Travel', 'Shopping', 'Bills', 'Grocery', 'Other'];
const incomeCats = ['Salary', 'Freelance', 'Gift', 'Other'];

final navKey = GlobalKey<NavigatorState>();

// ───────────────────────── Helpers ─────────────────────────
String inr(num v) {
  final n = v.abs();
  final s = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  final parts = s.split('.');
  parts[0] = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '₹ ${parts.join('.')}';
}

String fmtDate(DateTime d) => '${d.day} ${monthsShort[d.month - 1]} ${d.year}';

String fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '${h.toString().padLeft(2, '0')}:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

IconData catIcon(String c) {
  switch (c) {
    case 'Food':
      return Icons.restaurant;
    case 'Travel':
      return Icons.flight_takeoff;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Bills':
      return Icons.receipt_long;
    case 'Grocery':
      return Icons.shopping_cart;
    case 'Salary':
      return Icons.account_balance_wallet;
    case 'Freelance':
      return Icons.work;
    case 'Gift':
      return Icons.card_giftcard;
    default:
      return Icons.category;
  }
}

Color catColor(String c) {
  switch (c) {
    case 'Food':
      return const Color(0xFF8B5CF6);
    case 'Travel':
      return const Color(0xFFF97316);
    case 'Shopping':
      return const Color(0xFF3B82F6);
    case 'Bills':
      return const Color(0xFFEAB308);
    case 'Grocery':
      return const Color(0xFFEF4444);
    case 'Salary':
    case 'Freelance':
      return kGreen;
    case 'Gift':
      return const Color(0xFFEC4899);
    default:
      return const Color(0xFFE5E7EB);
  }
}

Widget bigBtn(String text, VoidCallback onTap, {Color color = kBlue}) => SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );

Widget cardBox({required Widget child, EdgeInsets? padding, Color? color}) => Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color ?? kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
      child: child,
    );

Widget labeled(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
            child: child,
          ),
        ],
      ),
    );

Widget dropdown(String value, List<String> items, ValueChanged<String> onChanged) =>
    DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: kCard2,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );

Widget segmented(List<String> labels, int sel, ValueChanged<int> onTap, {List<Color>? colors}) =>
    Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == sel ? (colors?[i] ?? kGreen) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(labels[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }),
      ),
    );

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

final chipStyle = OutlinedButton.styleFrom(
  backgroundColor: kCard,
  foregroundColor: Colors.white,
  side: const BorderSide(color: kBorder),
  padding: const EdgeInsets.symmetric(vertical: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

// ───────────────────────── Model + State ─────────────────────────
class Txn {
  final String id;
  final String title;
  final String category;
  final double amount;
  final bool income;
  final DateTime date;
  final String note;
  Txn(this.id, this.title, this.category, this.amount, this.income, this.date, {this.note = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'income': income,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        j['id'] as String,
        j['title'] as String,
        j['category'] as String,
        (j['amount'] as num).toDouble(),
        j['income'] as bool,
        DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
      );
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class AppState extends ChangeNotifier {
  final List<Txn> txns = [];
  final List<Txn> outing = [];
  double outingBudget = 2000;

  bool lockEnabled = false;
  String lockMethod = 'Pattern';
  List<int>? pattern;
  String? pin;
  bool lockOnClose = true;
  int timeoutMin = 1;
  bool unlocking = false;

  TimeOfDay alarmTime = const TimeOfDay(hour: 7, minute: 0);
  Set<int> alarmDays = {1, 2, 3, 4, 5};
  String alarmSound = 'Default Alarm';
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);

  final ValueNotifier<String> status = ValueNotifier('Nothing saved yet');

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('app_data');
      if (raw == null) {
        status.value = 'No saved data found at start';
        return;
      }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      txns
        ..clear()
        ..addAll(((m['txns'] as List?) ?? []).map((e) => Txn.fromJson(Map<String, dynamic>.from(e as Map))));
      outing
        ..clear()
        ..addAll(((m['outing'] as List?) ?? []).map((e) => Txn.fromJson(Map<String, dynamic>.from(e as Map))));
      outingBudget = (m['outingBudget'] as num?)?.toDouble() ?? outingBudget;
      lockEnabled = (m['lockEnabled'] as bool?) ?? false;
      lockMethod = (m['lockMethod'] as String?) ?? 'Pattern';
      pattern = (m['pattern'] as List?)?.map((e) => e as int).toList();
      pin = m['pin'] as String?;
      lockOnClose = (m['lockOnClose'] as bool?) ?? true;
      timeoutMin = (m['timeoutMin'] as int?) ?? 1;
      alarmTime = TimeOfDay(hour: (m['alarmH'] as int?) ?? 7, minute: (m['alarmM'] as int?) ?? 0);
      alarmDays = ((m['alarmDays'] as List?)?.map((e) => e as int).toSet()) ?? {1, 2, 3, 4, 5};
      alarmSound = (m['alarmSound'] as String?) ?? 'Default Alarm';
      reminderTime = TimeOfDay(hour: (m['remH'] as int?) ?? 21, minute: (m['remM'] as int?) ?? 0);
      status.value = 'Loaded ${txns.length} entries at start';
    } catch (e) {
      status.value = 'Load error: $e';
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ok = await p.setString(
        'app_data',
        jsonEncode({
          'txns': txns.map((t) => t.toJson()).toList(),
          'outing': outing.map((t) => t.toJson()).toList(),
          'outingBudget': outingBudget,
          'lockEnabled': lockEnabled,
          'lockMethod': lockMethod,
          'pattern': pattern,
          'pin': pin,
          'lockOnClose': lockOnClose,
          'timeoutMin': timeoutMin,
          'alarmH': alarmTime.hour,
          'alarmM': alarmTime.minute,
          'alarmDays': alarmDays.toList(),
          'alarmSound': alarmSound,
          'remH': reminderTime.hour,
          'remM': reminderTime.minute,
        }),
      );
      status.value = ok ? 'Saved OK (${txns.length} entries)' : 'Save failed';
    } catch (e) {
      status.value = 'Save error: $e';
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _save();
  }

  double get income => txns.where((t) => t.income).fold(0.0, (s, t) => s + t.amount);
  double get expense => txns.where((t) => !t.income).fold(0.0, (s, t) => s + t.amount);
  double get balance => income - expense;
  double get outingSpent => outing.fold(0.0, (s, t) => s + t.amount);

  void refresh() => notifyListeners();
}

final app = AppState();

// ───────────────────────── App root ─────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});
  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> with WidgetsBindingObserver {
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed &&
        app.lockEnabled &&
        app.lockOnClose &&
        !app.unlocking &&
        pausedAt != null &&
        DateTime.now().difference(pausedAt!).inSeconds >= app.timeoutMin * 60) {
      app.unlocking = true;
      navKey.currentState?.push(MaterialPageRoute(builder: (_) => const UnlockScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      title: 'ExpenseTracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kBlue, surface: kBg),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kCard,
          indicatorColor: kBlue.withAlpha(70),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ───────────────────────── Main shell (bottom nav) ─────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    if (app.lockEnabled && !app.unlocking) {
      app.unlocking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navKey.currentState?.push(MaterialPageRoute(builder: (_) => const UnlockScreen()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(goTab: (i) => setState(() => index = i)),
      const HistoryScreen(),
      const ReportsScreen(),
      const SettingsTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ───────────────────────── 6. Dashboard ─────────────────────────
class HomeTab extends StatefulWidget {
  final void Function(int) goTab;
  const HomeTab({super.key, required this.goTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool hide = false;

  String get greet {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning!' : (h < 17 ? 'Good afternoon!' : 'Good evening!');
  }

  Widget stat(String label, double value, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.35)!],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16),
                ),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Text(hide ? '₹ ••••' : inr(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

  Widget quick(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(14), border: Border.all(color: color)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kMuted)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final pct = app.outingBudget == 0 ? 0.0 : (app.outingSpent / app.outingBudget).clamp(0.0, 1.0).toDouble();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hello, User 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(greet, style: const TextStyle(color: kMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => snack(context, 'No new notifications'),
                    icon: const Icon(Icons.notifications_none),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              cardBox(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Balance', style: TextStyle(color: kMuted, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(hide ? '₹ ••••••' : inr(app.balance),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => hide = !hide),
                      icon: Icon(hide ? Icons.visibility_off : Icons.visibility, color: kMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                stat('Income', app.income, Icons.arrow_downward, const Color(0xFF1FA84F)),
                const SizedBox(width: 12),
                stat('Expenses', app.expense, Icons.arrow_upward, const Color(0xFFD62A4B)),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutingScreen())),
                child: cardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kBlue.withAlpha(50), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.luggage, color: kBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Outing Budget', style: TextStyle(fontWeight: FontWeight.w600))),
                        Text(inr(app.outingBudget), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: kCard2,
                          color: kGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${inr((app.outingBudget - app.outingSpent).clamp(0, double.infinity))} left',
                              style: const TextStyle(color: kMuted, fontSize: 12)),
                          Text('${(pct * 100).round()}%', style: const TextStyle(color: kMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  quick(Icons.add, 'Add Income', kGreen, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen(income: true)));
                  }),
                  quick(Icons.remove, 'Add Expense', kRed, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen(income: false)));
                  }),
                  quick(Icons.luggage, 'Outing Budget', kBlue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OutingScreen()));
                  }),
                  quick(Icons.bar_chart, 'Reports', const Color(0xFF60A5FA), () => widget.goTab(2)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => widget.goTab(1), child: const Text('See all')),
                ],
              ),
              if (app.txns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No transactions yet.', style: TextStyle(color: kMuted))),
                ),
              ...app.txns.take(3).map((t) => TxnTile(t: t)),
            ],
          );
        },
      ),
    );
  }
}

class TxnTile extends StatelessWidget {
  final Txn t;
  const TxnTile({super.key, required this.t});
  @override
  Widget build(BuildContext context) {
    final color = t.income ? kGreen : kRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(catIcon(t.category), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(t.income ? 'Income' : 'Expense', style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${t.income ? '+' : '-'} ${inr(t.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              Text(fmtDate(t.date), style: const TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: kMuted),
        ],
      ),
    );
  }
}

// ───────────────────────── 7. Add Transaction ─────────────────────────
class AddTransactionScreen extends StatefulWidget {
  final bool income;
  const AddTransactionScreen({super.key, this.income = true});
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late bool income = widget.income;
  final amount = TextEditingController();
  final note = TextEditingController();
  late String category = income ? incomeCats.first : expenseCats.first;
  DateTime date = DateTime.now();

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => date = d);
  }

  void save() {
    final a = double.tryParse(amount.text.trim());
    if (a == null || a <= 0) {
      snack(context, 'Enter a valid amount');
      return;
    }
    app.txns.insert(0, Txn(newId(), category, category, a, income, date, note: note.text.trim()));
    app.txns.sort((x, y) => y.date.compareTo(x.date));
    app.refresh();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = income ? incomeCats : expenseCats;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction'), leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              segmented(['Income', 'Expense'], income ? 0 : 1, (i) {
                setState(() {
                  income = i == 0;
                  category = (income ? incomeCats : expenseCats).first;
                });
              }, colors: const [kGreen, kRed]),
              const SizedBox(height: 20),
              labeled(
                'Amount',
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: InputBorder.none, prefixText: '₹ ', hintText: '0'),
                ),
              ),
              labeled('Category', dropdown(category, cats, (v) => setState(() => category = v))),
              labeled(
                'Date',
                InkWell(
                  onTap: pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      Expanded(child: Text(fmtDate(date))),
                      const Icon(Icons.calendar_today, size: 18, color: kMuted),
                    ]),
                  ),
                ),
              ),
              labeled(
                'Notes (optional)',
                TextField(
                  controller: note,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Monthly salary'),
                ),
              ),
              const SizedBox(height: 8),
              bigBtn('Save', save, color: income ? kGreen : kRed),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 8. Outing Budget ─────────────────────────
class OutingScreen extends StatelessWidget {
  const OutingScreen({super.key});

  Future<void> editBudget(BuildContext context) async {
    final c = TextEditingController(text: app.outingBudget.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Total Budget'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final v = double.tryParse(c.text.trim());
    if (ok == true && v != null && v > 0) {
      app.outingBudget = v;
      app.refresh();
    }
  }

  Future<void> addExpense(BuildContext context) async {
    final name = TextEditingController();
    final amt = TextEditingController();
    String cat = 'Food';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kCard,
          title: const Text('Add Outing Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amt, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const SizedBox(height: 12),
              dropdown(cat, expenseCats, (v) => setS(() => cat = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final a = double.tryParse(amt.text.trim());
    if (ok == true && a != null && a > 0) {
      app.outing.insert(0, Txn(newId(), cat, cat, a, false, DateTime.now(), note: name.text.trim()));
      app.refresh();
    } else if (ok == true && context.mounted) {
      snack(context, 'Enter a valid amount');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outing Budget'), leading: const BackButton()),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final pct = app.outingBudget == 0 ? 0.0 : (app.outingSpent / app.outingBudget).clamp(0.0, 1.0).toDouble();
            final remaining = app.outingBudget - app.outingSpent;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                cardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Budget', style: TextStyle(color: kMuted, fontSize: 13)),
                              Text(inr(app.outingBudget), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => editBudget(context), icon: const Icon(Icons.edit, size: 20, color: kMuted)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                cardBox(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 84,
                              height: 84,
                              child: CircularProgressIndicator(
                                value: pct,
                                strokeWidth: 8,
                                backgroundColor: kCard2,
                                color: pct >= 1 ? kRed : kGreen,
                              ),
                            ),
                            Text('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Spent', style: TextStyle(color: kMuted, fontSize: 12)),
                          Text(inr(app.outingSpent), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Remaining', style: TextStyle(color: kMuted, fontSize: 12)),
                          Text(inr(remaining < 0 ? 0 : remaining),
                              style: TextStyle(fontWeight: FontWeight.bold, color: remaining < 0 ? kRed : null)),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                bigBtn('Add Outing Expense', () => addExpense(context)),
                const SizedBox(height: 20),
                const Text('Recent Outing Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (app.outing.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No outing expenses yet.', style: TextStyle(color: kMuted))),
                  ),
                ...app.outing.map(
                  (t) => Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      app.outing.removeWhere((e) => e.id == t.id);
                      app.refresh();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)),
                          child: Icon(catIcon(t.category), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(t.note.isEmpty ? fmtDate(t.date) : '${t.note} • ${fmtDate(t.date)}',
                                  style: const TextStyle(color: kMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(inr(t.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── 9. Transaction History ─────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History'), automaticallyImplyLeading: false),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.txns.where((t) => filter == 0 || (filter == 1 ? t.income : !t.income)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: segmented(['All', 'Income', 'Expense'], filter, (i) => setState(() => filter = i),
                    colors: const [Color(0xFF2B3C63), Color(0xFF2B3C63), Color(0xFF2B3C63)]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No transactions found.', style: TextStyle(color: kMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final t = list[i];
                          return Dismissible(
                            key: ValueKey(t.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              app.txns.removeWhere((e) => e.id == t.id);
                              app.refresh();
                            },
                            child: TxnTile(t: t),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── 10. Reports & Charts ─────────────────────────
class DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  DonutPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    final rect = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28;
    if (total == 0) {
      p.color = kCard2;
      canvas.drawArc(rect, 0, 2 * math.pi, false, p);
      return;
    }
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      p.color = colors[i];
      canvas.drawArc(rect, start, math.max(0.0, sweep - (values.length > 1 ? 0.04 : 0)), false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) => true;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int tab = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canNext = month.isBefore(DateTime(now.year, now.month));
    return Scaffold(
      appBar: AppBar(title: const Text('Reports'), automaticallyImplyLeading: false),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final inMonth = app.txns.where((t) => !t.income && t.date.year == month.year && t.date.month == month.month);
          final byCat = <String, double>{};
          for (final t in inMonth) {
            byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
          }
          final entries = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final total = entries.fold(0.0, (s, e) => s + e.value);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              segmented(['Monthly', 'Category'], tab, (i) => setState(() => tab = i)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${monthsFull[month.month - 1]} ${month.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      onPressed: canNext ? () => setState(() => month = DateTime(month.year, month.month + 1)) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (tab == 0)
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(220, 220),
                          painter: DonutPainter(
                            entries.map((e) => e.value).toList(),
                            entries.map((e) => catColor(e.key)).toList(),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total', style: TextStyle(color: kMuted)),
                            Text(inr(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (entries.isEmpty)
                const Center(child: Text('No expenses in this month.', style: TextStyle(color: kMuted)))
              else
                ...entries.map((e) {
                  final pct = total == 0 ? 0.0 : e.value / total;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: catColor(e.key), shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.key)),
                          Text('${(pct * 100).round()}%', style: const TextStyle(color: kMuted)),
                          const SizedBox(width: 20),
                          SizedBox(width: 90, child: Text(inr(e.value), textAlign: TextAlign.right)),
                        ]),
                        if (tab == 1) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: kCard2, color: catColor(e.key)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Settings tab ─────────────────────────
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget tile(IconData icon, String title, String sub, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: Icon(icon, color: kBlue),
          title: Text(title),
          subtitle: Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tile(Icons.lock_outline, 'App Lock', 'PIN or pattern protection', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AppLockScreen()));
          }),
          tile(Icons.alarm, 'Alarm & Reminder', 'Alarm and daily expense reminder', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmScreen()));
          }),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: app.status,
            builder: (context, v, _) => cardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Data storage', style: TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(v),
                  const SizedBox(height: 4),
                  const Text('Build: save-v6', style: TextStyle(color: kMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 4. App Lock Settings ─────────────────────────
Future<String?> showPinDialog(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('Set 4 digit PIN'),
      content: TextField(
        controller: c,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text.length == 4 ? c.text : null),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool> setupLock(BuildContext context) async {
  if (app.lockMethod == 'PIN') {
    final pin = await showPinDialog(context);
    if (pin != null) {
      app.pin = pin;
      return true;
    }
    return false;
  }
  final r = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const SetPatternScreen()));
  return r == true;
}

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  Widget methodTile(BuildContext context, String method, IconData icon, String sub) {
    final selected = app.lockMethod == method;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kBlue.withAlpha(50), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: kBlue),
      ),
      title: Text(method),
      subtitle: Text(sub, style: const TextStyle(color: kMuted, fontSize: 11)),
      trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? kBlue : kMuted),
      onTap: () async {
        if (selected) return;
        final old = app.lockMethod;
        app.lockMethod = method;
        if (app.lockEnabled) {
          final ok = await setupLock(context);
          if (!ok) app.lockMethod = old;
        }
        app.refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Lock'), leading: const BackButton()),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            cardBox(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable App Lock'),
                value: app.lockEnabled,
                activeThumbColor: kGreen,
                onChanged: (v) async {
                  if (!v) {
                    app.lockEnabled = false;
                    app.refresh();
                    return;
                  }
                  final ok = await setupLock(context);
                  if (ok) {
                    app.lockEnabled = true;
                    app.refresh();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Lock Method', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            cardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                methodTile(context, 'PIN', Icons.dialpad, 'Use 4 digit PIN'),
                methodTile(context, 'Pattern', Icons.pattern, 'Draw pattern to unlock'),
              ]),
            ),
            const SizedBox(height: 16),
            cardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  title: const Text('Change Lock'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final ok = await setupLock(context);
                    if (ok) app.refresh();
                    if (ok && context.mounted) snack(context, 'Lock updated');
                  },
                ),
                SwitchListTile(
                  title: const Text('Lock when app is closed'),
                  value: app.lockOnClose,
                  activeThumbColor: kGreen,
                  onChanged: (v) {
                    app.lockOnClose = v;
                    app.refresh();
                  },
                ),
                ListTile(
                  title: const Text('Timeout'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${app.timeoutMin} minute${app.timeoutMin == 1 ? '' : 's'}', style: const TextStyle(color: kMuted)),
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: () async {
                    final v = await showDialog<int>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        backgroundColor: kCard,
                        title: const Text('Timeout'),
                        children: [1, 5, 15]
                            .map((m) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(ctx, m),
                                  child: Text('$m minute${m == 1 ? '' : 's'}'),
                                ))
                            .toList(),
                      ),
                    );
                    if (v != null) {
                      app.timeoutMin = v;
                      app.refresh();
                    }
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Pattern pad (used by 5 & 15) ─────────────────────────
class PatternPainter extends CustomPainter {
  final List<int> sel;
  final Offset? cur;
  final Color active;
  final double side;
  PatternPainter(this.sel, this.cur, this.active, this.side);

  Offset center(int i) {
    final cell = side / 3;
    return Offset((i % 3) * cell + cell / 2, (i ~/ 3) * cell + cell / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = active
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < sel.length - 1; i++) {
      canvas.drawLine(center(sel[i]), center(sel[i + 1]), line);
    }
    if (sel.isNotEmpty && cur != null) canvas.drawLine(center(sel.last), cur!, line);
    for (int i = 0; i < 9; i++) {
      final on = sel.contains(i);
      canvas.drawCircle(center(i), on ? 10 : 7, Paint()..color = on ? active : Colors.white38);
      if (on) {
        canvas.drawCircle(
          center(i),
          20,
          Paint()
            ..color = active
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter old) => true;
}

class PatternPad extends StatefulWidget {
  final void Function(List<int>) onComplete;
  final bool error;
  const PatternPad({super.key, required this.onComplete, this.error = false});
  @override
  State<PatternPad> createState() => _PatternPadState();
}

class _PatternPadState extends State<PatternPad> {
  static const double side = 300;
  final List<int> sel = [];
  Offset? cur;

  Offset center(int i) {
    final cell = side / 3;
    return Offset((i % 3) * cell + cell / 2, (i ~/ 3) * cell + cell / 2);
  }

  void hit(Offset p) {
    cur = p;
    for (int i = 0; i < 9; i++) {
      if (!sel.contains(i) && (center(i) - p).distance < 30) {
        sel.add(i);
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: side,
      height: side,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => setState(() {
          sel.clear();
          hit(d.localPosition);
        }),
        onPanUpdate: (d) => setState(() => hit(d.localPosition)),
        onPanEnd: (_) {
          final result = List<int>.from(sel);
          setState(() => cur = null);
          widget.onComplete(result);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(sel.clear);
          });
        },
        child: CustomPaint(painter: PatternPainter(sel, cur, widget.error ? kRed : kGreen, side)),
      ),
    );
  }
}

// ───────────────────────── 5. Set Pattern ─────────────────────────
class SetPatternScreen extends StatefulWidget {
  const SetPatternScreen({super.key});
  @override
  State<SetPatternScreen> createState() => _SetPatternScreenState();
}

class _SetPatternScreenState extends State<SetPatternScreen> {
  List<int>? first;
  String msg = 'Draw your pattern';
  bool error = false;

  void done(List<int> p) {
    if (p.length < 4) {
      setState(() {
        error = true;
        msg = 'Connect at least 4 dots';
      });
      return;
    }
    if (first == null) {
      setState(() {
        first = p;
        error = false;
        msg = 'Draw again to confirm';
      });
    } else if (listEquals(first, p)) {
      app.pattern = p;
      Navigator.pop(context, true);
    } else {
      setState(() {
        first = null;
        error = true;
        msg = 'Patterns did not match. Try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Pattern'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(msg, style: TextStyle(color: error ? kRed : kMuted)),
            const Spacer(),
            Center(child: PatternPad(onComplete: done, error: error)),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Text('Release to confirm', style: TextStyle(color: kBlue)),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 15. App Unlock ─────────────────────────
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});
  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool wrong = false;
  bool correct = false;
  final pinCtrl = TextEditingController();

  @override
  void dispose() {
    app.unlocking = false;
    pinCtrl.dispose();
    super.dispose();
  }

  void unlockOk() {
    setState(() {
      correct = true;
      wrong = false;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void failed() {
    setState(() => wrong = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => wrong = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPin = app.lockMethod == 'PIN';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(isPin ? 'Enter PIN to Unlock' : 'Draw Pattern to Unlock',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (isPin)
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: pinCtrl,
                    autofocus: true,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(fontSize: 28, letterSpacing: 12),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (v) {
                      if (v.length == 4) {
                        if (v == app.pin) {
                          unlockOk();
                        } else {
                          pinCtrl.clear();
                          failed();
                        }
                      }
                    },
                  ),
                )
              else
                PatternPad(
                  error: wrong,
                  onComplete: (p) {
                    if (listEquals(p, app.pattern)) {
                      unlockOk();
                    } else {
                      failed();
                    }
                  },
                ),
              const Spacer(),
              SizedBox(
                height: 60,
                child: correct
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle, color: kGreen, size: 18),
                        const SizedBox(width: 6),
                        Text(isPin ? 'PIN is correct' : 'Pattern is correct', style: const TextStyle(color: kGreen)),
                      ])
                    : Text(wrong ? (isPin ? 'Wrong PIN. Try again' : 'Wrong pattern. Try again') : '',
                        style: const TextStyle(color: kRed)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 11. Alarm Settings (+ 14 reminder) ─────────────────────────
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});
  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  int tab = 0;
  late TimeOfDay alarmTime = app.alarmTime;
  late TimeOfDay reminderTime = app.reminderTime;
  late Set<int> days = {...app.alarmDays};
  late String sound = app.alarmSound;

  Future<void> pickTime() async {
    final t = await showTimePicker(context: context, initialTime: tab == 0 ? alarmTime : reminderTime);
    if (t != null) setState(() => tab == 0 ? alarmTime = t : reminderTime = t);
  }

  Future<void> pickSound() async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: kCard,
        title: const Text('Sound'),
        children: ['Default Alarm', 'Gentle Wake', 'Classic Beep']
            .map((s) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s), child: Text(s)))
            .toList(),
      ),
    );
    if (v != null) setState(() => sound = v);
  }

  void save() {
    app.alarmTime = alarmTime;
    app.reminderTime = reminderTime;
    app.alarmDays = {...days};
    app.alarmSound = sound;
    app.refresh();
    snack(context, tab == 0 ? 'Alarm set for ${fmtTime(alarmTime)}' : 'Daily reminder set for ${fmtTime(reminderTime)}');
  }

  void previewNotification() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.account_balance_wallet, color: kBlue, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('ExpenseTracker', style: TextStyle(fontSize: 12))),
                Text('now', style: TextStyle(color: kMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              const Text('🔔 Daily Expense Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Don\'t forget to add your today\'s expenses!', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kBlue),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen(income: false)));
                    },
                    child: const Text('Open App'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kCard2),
                    onPressed: () {
                      Navigator.pop(ctx);
                      snack(context, 'Reminder snoozed for 10 minutes');
                    },
                    child: const Text('Snooze 10 min'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = tab == 0 ? alarmTime : reminderTime;
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm'), leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              segmented(['Normal Alarm', 'Expense Reminder'], tab, (i) => setState(() => tab = i)),
              const SizedBox(height: 20),
              labeled(
                tab == 0 ? 'Alarm Time' : 'Reminder Time',
                InkWell(
                  onTap: pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      const Icon(Icons.access_time, size: 18, color: kMuted),
                      const SizedBox(width: 10),
                      Text(fmtTime(time)),
                    ]),
                  ),
                ),
              ),
              if (tab == 0) ...[
                const Text('Repeat', style: TextStyle(color: kMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final d = i + 1;
                    final on = days.contains(d);
                    return GestureDetector(
                      onTap: () => setState(() => on ? days.remove(d) : days.add(d)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? kGreen : kCard2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(weekDays[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                labeled(
                  'Sound',
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sound),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: pickSound,
                  ),
                ),
              ] else ...[
                cardBox(
                  child: const Text('Every day at the chosen time you will get: "Don\'t forget to add your today\'s expenses!"',
                      style: TextStyle(color: kMuted)),
                ),
                const SizedBox(height: 16),
              ],
              bigBtn(tab == 0 ? 'Save Alarm' : 'Save Reminder', save, color: kGreen),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: tab == 0
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmRingingScreen()))
                      : previewNotification,
                  child: Text(tab == 0 ? 'Preview ringing screen' : 'Preview notification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 12. Alarm Ringing ─────────────────────────
Widget ringBtn(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final back = Path()
      ..moveTo(0, s.height * 0.62)
      ..lineTo(s.width * 0.18, s.height * 0.50)
      ..lineTo(s.width * 0.35, s.height * 0.60)
      ..lineTo(s.width * 0.55, s.height * 0.44)
      ..lineTo(s.width * 0.80, s.height * 0.60)
      ..lineTo(s.width, s.height * 0.52)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF16233F));
    final front = Path()
      ..moveTo(0, s.height * 0.75)
      ..lineTo(s.width * 0.25, s.height * 0.64)
      ..lineTo(s.width * 0.5, s.height * 0.74)
      ..lineTo(s.width * 0.75, s.height * 0.62)
      ..lineTo(s.width, s.height * 0.72)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF0F1A31));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({super.key});
  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => HapticFeedback.heavyImpact());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2A4A), Color(0xFF0A1122)],
          ),
        ),
        child: CustomPaint(
          painter: MountainPainter(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.alarm, size: 80, color: Colors.white70),
                  const SizedBox(height: 16),
                  const Text('Alarm Ringing!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(fmtTime(app.alarmTime), style: const TextStyle(fontSize: 22, color: Colors.white70)),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(child: ringBtn(Icons.close, 'Stop', kRed, () => Navigator.pop(context))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ringBtn(Icons.access_time, 'Snooze\n10 min', kBlue, () {
                          Navigator.pushReplacement(
                              context, MaterialPageRoute(builder: (_) => const SnoozedScreen()));
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 13. Snoozed ─────────────────────────
class SnoozedScreen extends StatelessWidget {
  const SnoozedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(color: kBlue.withAlpha(50), shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_bottom, size: 44, color: kBlue),
              ),
              const SizedBox(height: 24),
              const Text('Snoozed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Alarm will ring again in', style: TextStyle(color: kMuted)),
              const Text('10 minutes', style: TextStyle(color: kBlue)),
              const SizedBox(height: 32),
              bigBtn('OK', () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
