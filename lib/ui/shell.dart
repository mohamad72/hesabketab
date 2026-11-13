import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/finance.dart';
import 'accounts.dart';
import 'monthly.dart';
import 'reports.dart';
import 'settings.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  final FinanceController controller;
  final bool demo;
  const AppShell({super.key, required this.controller, this.demo = false});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int page = 0;
  static const labels = ['ماهانه', 'حساب‌ها', 'گزارش‌ها', 'تنظیمات'];
  static const icons = [
    Icons.calendar_month_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.bar_chart_rounded,
    Icons.tune_rounded,
  ];
  FinanceController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.addListener(refresh);
  }

  @override
  void dispose() {
    c.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 1000;
      return Scaffold(
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (i) => setState(() => page = i),
                destinations: List.generate(
                  4,
                  (i) => NavigationDestination(
                    icon: Icon(icons[i]),
                    selectedIcon: Icon(icons[i], color: purple),
                    label: labels[i],
                  ),
                ),
              ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xfff8f2ff), Color(0xfffcf9fc), Color(0xfffff8f3)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  SizedBox(
                    width: 245,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .7),
                        border: const Border(left: BorderSide(color: lavender)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          brand(),
                          const SizedBox(height: 10),
                          const Text(
                            'حسابِ امروز، خیالِ فردا',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 50),
                          ...List.generate(
                            4,
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                selected: page == i,
                                selectedTileColor: lavender,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                leading: Icon(
                                  icons[i],
                                  color: page == i ? purple : muted,
                                ),
                                title: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: page == i ? purple : muted,
                                  ),
                                ),
                                onTap: () => setState(() => page = i),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Panel(
                            color: lavender.withValues(alpha: .5),
                            padding: const EdgeInsets.all(15),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.offline_bolt_outlined,
                                  color: purple,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'همراهت، حتی آفلاین',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'تغییرها اول روی دستگاه ذخیره می‌شوند.',
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 40 : 20,
                          wide ? 30 : 18,
                          wide ? 40 : 20,
                          28,
                        ),
                        children: [
                          Row(
                            children: [
                              if (!wide)
                                brand()
                              else
                                Text(
                                  labels[page],
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'وضعیت همگام‌سازی',
                                onPressed: () => setState(() => page = 3),
                                icon: Badge(
                                  isLabelVisible: c.pending > 0,
                                  label: Text(persian(c.pending)),
                                  backgroundColor: pink,
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final m = await pickMonth(
                                      context,
                                      Month.key(c.selectedMonth),
                                    );
                                    if (m != null && context.mounted) {
                                      await runAction(
                                        context,
                                        () => c.selectMonth(m.key),
                                      );
                                    }
                                  },
                                  child: Panel(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          color: purple,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            Month.key(c.selectedMonth).label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'ماه قبل',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => runAction(
                                            context,
                                            () => c.selectMonth(
                                              Month.key(
                                                c.selectedMonth,
                                              ).previous.key,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chevron_right,
                                            color: muted,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'ماه بعد',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => runAction(
                                            context,
                                            () => c.selectMonth(
                                              Month.key(
                                                c.selectedMonth,
                                              ).next.key,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chevron_left,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (wide) ...[
                                const SizedBox(width: 12),
                                Tag(
                                  widget.demo
                                      ? 'حالت آزمایشی'
                                      : 'ذخیره روی دستگاه',
                                ),
                              ],
                            ],
                          ),
                          if (widget.demo)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Tag(
                                'پیش‌نمایش آزمایشی · این اطلاعات واقعی نیستند',
                                color: peach,
                              ),
                            ),
                          if (!widget.demo)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: InkWell(
                                onTap: () => setState(() => page = 3),
                                child: Row(
                                  children: [
                                    Icon(
                                      c.syncing
                                          ? Icons.sync_rounded
                                          : Icons.cloud_off_outlined,
                                      size: 14,
                                      color: muted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        c.syncing
                                            ? c.syncMessage
                                            : c.lastSync == null
                                            ? 'آفلاین آماده‌ای؛ برای دریافت شیت، گوگل را متصل کن.'
                                            : '${persian(c.pending)} تغییر منتظر سینک · اطلاعات روی دستگاه ذخیره است',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                    if (c.syncing)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          KeyedSubtree(
                            key: ValueKey('$page-${c.selectedMonth}'),
                            child: switch (page) {
                              0 => MonthlyPage(controller: c),
                              1 => AccountsPage(controller: c),
                              2 => ReportsPage(controller: c),
                              _ => SettingsPage(
                                controller: c,
                                demo: widget.demo,
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget brand() => ShaderMask(
    shaderCallback: (r) => primaryGradient.createShader(r),
    child: const Text(
      'حساب حضرات',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );
}
