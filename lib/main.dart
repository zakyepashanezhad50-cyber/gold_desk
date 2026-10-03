import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// آدرس رله بک‌اند شما که دیتای Databento (GC) را به WebSocket تبدیل می‌کند.
// خالی بگذارید تا حالت دمو اجرا شود.  مثال: wss://your-server.com/gc-depth
const String kDepthRelayUrl = '';

const ink = Color(0xFF0D1520);
const panel = Color(0xFF152233);
const line = Color(0xFF22344A);
const gold = Color(0xFFD9AE4E);
const up = Color(0xFF34C398);
const down = Color(0xFFEA5459);
const mute = Color(0xFF8B9BB0);

void main() => runApp(const GoldDeskApp());

class GoldDeskApp extends StatelessWidget {
  const GoldDeskApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gold Desk',
        locale: const Locale('fa'),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: const ColorScheme.dark(primary: gold, surface: panel),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: panel,
            indicatorColor: gold.withOpacity(.18),
          ),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  final depth = DepthService();
  @override
  void initState() {
    super.initState();
    depth.start(kDepthRelayUrl);
  }

  @override
  void dispose() {
    depth.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const JournalTab(), const SessionsTab(), DepthTab(svc: depth), const NewsTab()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: i, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'ژورنال'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'سشن‌ها'),
          NavigationDestination(icon: Icon(Icons.stacked_bar_chart), label: 'عمق GC'),
          NavigationDestination(icon: Icon(Icons.notifications_active_outlined), label: 'اخبار'),
        ],
      ),
    );
  }
}

Widget titleBar(String t, [Widget? trailing]) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(children: [
        Expanded(child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        if (trailing != null) trailing,
      ]),
    );

// ───────────── ژورنال ─────────────
class Trade {
  final String sym, side, session, reason;
  final double pnl, rr;
  const Trade(this.sym, this.side, this.pnl, this.rr, this.session, this.reason);
}

const demoTrades = [
  Trade('XAUUSD', 'خرید', 182.5, 2.1, 'لندن', 'برگشت از حمایت ۳۳۴۰ و شکست ساختار'),
  Trade('XAUUSD', 'فروش', -64.0, -1.0, 'نیویورک', 'ورود زودهنگام قبل از خبر CPI'),
  Trade('XAUUSD', 'خرید', 241.0, 3.0, 'هم‌پوشانی لندن/نیویورک', 'جمع‌آوری نقدینگی زیر سقف آسیا'),
  Trade('XAUUSD', 'فروش', 97.2, 1.4, 'توکیو', 'رد مقاومت ۳۳۶۵'),
];

class JournalTab extends StatelessWidget {
  const JournalTab({super.key});
  @override
  Widget build(BuildContext context) {
    final total = demoTrades.fold<double>(0, (a, t) => a + t.pnl);
    final wins = demoTrades.where((t) => t.pnl > 0).length;
    return ListView(children: [
      titleBar('ژورنال معاملات'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('سود خالص', style: TextStyle(color: mute)),
                const SizedBox(height: 4),
                Text('${total >= 0 ? '+' : ''}${total.toStringAsFixed(1)}\$',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: total >= 0 ? up : down)),
              ]),
            ),
            _stat('وین‌ریت', '${(wins / demoTrades.length * 100).round()}٪'),
            const SizedBox(width: 18),
            _stat('معاملات', '${demoTrades.length}'),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      for (final t in demoTrades) _tradeCard(t),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Text('داده‌ها نمونه‌اند. اتصال MetaApi برای کشیدن معاملات واقعی در مرحله بعد اضافه می‌شود.',
            style: TextStyle(color: mute.withOpacity(.8), fontSize: 12)),
      ),
    ]);
  }

  Widget _stat(String l, String v) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        Text(l, style: const TextStyle(color: mute, fontSize: 12)),
      ]);

  Widget _tradeCard(Trade t) {
    final win = t.pnl > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
        border: Border(right: BorderSide(color: win ? up : down, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${t.sym} · ${t.side}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${win ? '+' : ''}${t.pnl}\$', style: TextStyle(color: win ? up : down, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text(t.reason, style: const TextStyle(color: mute)),
        const SizedBox(height: 6),
        Text('سشن: ${t.session}  |  R:R ${t.rr}', style: const TextStyle(fontSize: 12, color: gold)),
      ]),
    );
  }
}

// ───────────── سشن‌ها (ساعت UTC، زنده) ─────────────
class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key});
  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Timer t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    t.cancel();
    super.dispose();
  }

  static const sessions = [
    ['سیدنی', 21, 6, Color(0xFF6C8EBF)],
    ['توکیو', 0, 9, Color(0xFFB07CC6)],
    ['لندن', 7, 16, Color(0xFF34C398)],
    ['نیویورک', 12, 21, Color(0xFFD9AE4E)],
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final h = now.hour + now.minute / 60;
    bool active(int s, int e) => s < e ? (h >= s && h < e) : (h >= s || h < e);
    final on = sessions.where((s) => active(s[1] as int, s[2] as int)).map((s) => s[0]).join(' + ');
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
      titleBar('سشن‌های بازار'),
      Text('هم‌اکنون: ${on.isEmpty ? 'بازار کم‌نقدینگی' : on}',
          style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w600)),
      Text('ساعت UTC  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: mute)),
      const SizedBox(height: 20),
      for (final s in sessions) ...[
        Text(s[0] as String),
        const SizedBox(height: 6),
        _bar(s[1] as int, s[2] as int, s[3] as Color, h),
        const SizedBox(height: 16),
      ],
    ]);
  }

  Widget _bar(int s, int e, Color c, double h) {
    final segs = s < e ? [[s, e]] : [[s, 24], [0, e]];
    return LayoutBuilder(builder: (ctx, bc) {
      final w = bc.maxWidth;
      return SizedBox(
        height: 26,
        child: Stack(textDirection: TextDirection.ltr, children: [
          Container(decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(6))),
          for (final g in segs)
            Positioned(
              left: w * g[0] / 24,
              width: w * (g[1] - g[0]) / 24,
              top: 0,
              bottom: 0,
              child: Container(decoration: BoxDecoration(color: c.withOpacity(.75), borderRadius: BorderRadius.circular(6))),
            ),
          Positioned(left: w * h / 24, top: -3, bottom: -3, child: Container(width: 2, color: Colors.white)),
        ]),
      );
    });
  }
}

// ───────────── عمق بازار GC ─────────────
class Level {
  final double p, s;
  Level(this.p, this.s);
}

class Book {
  final List<Level> bids, asks;
  Book(this.bids, this.asks);
}

class DepthService {
  final book = ValueNotifier<Book>(Book([], []));
  final live = ValueNotifier<bool>(false);
  WebSocketChannel? _ch;
  Timer? _demo;
  final _r = Random();
  double _mid = 3350.0;

  List<Level> _parse(dynamic l) =>
      (l as List).map((e) => Level((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();

  void start(String url) {
    stop();
    if (url.isEmpty) return _startDemo();
    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _ch = ch;
      ch.stream.listen((m) {
        live.value = true;
        final j = jsonDecode(m as String);
        book.value = Book(_parse(j['bids']), _parse(j['asks']));
      }, onError: (_) {
        if (_ch == ch) _startDemo();
      }, onDone: () {
        if (_ch == ch) _startDemo();
      });
    } catch (_) {
      _startDemo();
    }
  }

  void _startDemo() {
    live.value = false;
    _demo?.cancel();
    _demo = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _mid += (_r.nextDouble() - .5) * .4;
      Level mk(double p) => Level(p, (5 + _r.nextInt(60)).toDouble() + (_r.nextInt(12) == 0 ? 120 : 0));
      book.value = Book(
        List.generate(10, (i) => mk(_mid - .1 * (i + 1))),
        List.generate(10, (i) => mk(_mid + .1 * (i + 1))),
      );
    });
  }

  void stop() {
    _demo?.cancel();
    final c = _ch;
    _ch = null;
    c?.sink.close();
  }
}

class DepthTab extends StatelessWidget {
  final DepthService svc;
  const DepthTab({super.key, required this.svc});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      titleBar(
        'عمق بازار · فیوچرز GC',
        ValueListenableBuilder<bool>(
          valueListenable: svc.live,
          builder: (_, v, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: (v ? up : gold).withOpacity(.18), borderRadius: BorderRadius.circular(20)),
            child: Text(v ? 'زنده' : 'دمو', style: TextStyle(color: v ? up : gold, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('دیتای CME، نه اسپات. قیمت با XAUUSD بروکر چند دلار تفاوت دارد؛ به دیوارهای سفارش نگاه کنید.',
            style: TextStyle(color: mute, fontSize: 12)),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: ValueListenableBuilder<Book>(
          valueListenable: svc.book,
          builder: (_, b, __) {
            if (b.bids.isEmpty) return const Center(child: CircularProgressIndicator());
            final all = [...b.bids, ...b.asks];
            final mx = all.map((e) => e.s).reduce(max);
            final asks = b.asks.reversed.toList();
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final l in asks) _row(l, mx, down),
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('اسپرد ${(b.asks.first.p - b.bids.first.p).toStringAsFixed(2)}',
                      style: const TextStyle(color: gold, fontWeight: FontWeight.w700)),
                ),
                for (final l in b.bids) _row(l, mx, up),
              ],
            );
          },
        ),
      ),
    ]);
  }

  Widget _row(Level l, double mx, Color c) {
    final wall = l.s >= mx * .8;
    return Container(
      height: 30,
      margin: const EdgeInsets.only(bottom: 2),
      child: Stack(textDirection: TextDirection.ltr, children: [
        FractionallySizedBox(
          widthFactor: (l.s / mx).clamp(.02, 1),
          child: Container(decoration: BoxDecoration(color: c.withOpacity(wall ? .55 : .25), borderRadius: BorderRadius.circular(4))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(textDirection: TextDirection.ltr, children: [
            Text(l.p.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (wall) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.shield, size: 14, color: gold)),
            Text(l.s.toInt().toString()),
          ]),
        ),
      ]),
    );
  }
}

// ───────────── اخبار و آلارم ─────────────
class NewsTab extends StatefulWidget {
  const NewsTab({super.key});
  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  final items = <List<dynamic>>[
    ['NFP آمریکا', 'امشب ۱۵:۳۰ UTC', 'تأثیر بالا', true],
    ['سخنرانی رئیس فد', 'فردا ۱۸:۰۰ UTC', 'تأثیر بالا', true],
    ['CPI آمریکا', 'چهارشنبه ۱۲:۳۰ UTC', 'تأثیر بالا', false],
    ['موجودی نفت خام', 'چهارشنبه ۱۴:۳۰ UTC', 'تأثیر متوسط', false],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      titleBar('اخبار مؤثر بر طلا'),
      for (final it in items)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it[0], style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${it[1]}  ·  ${it[2]}', style: TextStyle(color: it[2] == 'تأثیر بالا' ? gold : mute, fontSize: 12)),
              ]),
            ),
            Switch(value: it[3] as bool, activeColor: gold, onChanged: (v) => setState(() => it[3] = v)),
          ]),
        ),
      const Padding(
        padding: EdgeInsets.all(20),
        child: Text('سوییچ یعنی ۱۵ دقیقه قبل از خبر آلارم بده. فید زنده و ارسال نوتیفیکیشن در مرحله بعد وصل می‌شود.',
            style: TextStyle(color: mute, fontSize: 12)),
      ),
    ]);
  }
}
