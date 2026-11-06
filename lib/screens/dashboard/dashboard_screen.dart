import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime now) {
    final weekday = now.weekday;
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    final firebase = FirebaseService();
    final settings = SettingsStore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _Reveal(
                child: _Header(
                  title: 'Dashboard',
                  subtitle: DateFormat('EEEE, MMM d', locale)
                      .format(DateTime.now()),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: uid == null
                          ? const Stream.empty()
                          : firebase.getOrdersStream(userId: uid, limit: 200),
                      builder: (context, orderSnap) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: uid == null
                              ? const Stream.empty()
                              : firebase.getCreditsStream(uid),
                          builder: (context, creditSnap) {
                            final now = DateTime.now();
                            final orders = (orderSnap.data?.docs ?? [])
                                .map((doc) => StoreOrder.fromFirestore(
                                      doc.id,
                                      doc.data() as Map<String, dynamic>,
                                    ))
                                .toList()
                              ..sort((a, b) {
                                final aTime = a.createdAt ??
                                    DateTime.fromMillisecondsSinceEpoch(0);
                                final bTime = b.createdAt ??
                                    DateTime.fromMillisecondsSinceEpoch(0);
                                return bTime.compareTo(aTime);
                              });

                            double salesToday = 0;
                            int txToday = 0;
                            for (final o in orders) {
                              final when = o.createdAt;
                              if (when != null && _isSameDay(when, now)) {
                                salesToday += o.total;
                                txToday++;
                              }
                            }

                            final estProfitToday = salesToday * 0.15;

                            final waiting = orderSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !orderSnap.hasData;

                            if (waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: scheme.primary,
                                ),
                              );
                            }

                            if (orderSnap.hasError) {
                              return Center(
                                child: Text(
                                  l10n.text(
                                    'couldNotLoadDashboard',
                                    values: {'error': '${orderSnap.error}'},
                                  ),
                                  style: GoogleFonts.outfit(
                                      color: sari.mutedText),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            double creditBalance = 0;
                            for (final doc
                                in creditSnap.data?.docs ?? const []) {
                              final data = doc.data();
                              if (data['isPaid'] == true) continue;
                              creditBalance +=
                                  (data['amount'] as num?)?.toDouble() ?? 0;
                            }

                            final weekStart = _startOfWeek(now);
                            final values = List<double>.filled(7, 0);
                            for (final o in orders) {
                              final when = o.createdAt;
                              if (when == null) continue;
                              final day =
                                  DateTime(when.year, when.month, when.day);
                              final diff = day.difference(weekStart).inDays;
                              if (diff >= 0 && diff < 7) {
                                values[diff] += o.total;
                              }
                            }
                            final maxY = values.fold<double>(
                                10, (m, v) => v > m ? v : m);
                            final weekTotal =
                                values.fold<double>(0, (s, v) => s + v);
                            final todayIndex = now.weekday - 1;

                            final soldByName = <String, int>{};
                            for (final o in orders) {
                              for (final item in o.items) {
                                final name =
                                    (item['name'] ?? l10n.text('itemName'))
                                        .toString();
                                final qty =
                                    (item['quantity'] as num?)?.toInt() ?? 0;
                                soldByName[name] =
                                    (soldByName[name] ?? 0) + qty;
                              }
                            }
                            final topSelling = soldByName.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value));
                            final top3 = topSelling.take(3).toList();

                            final labels = List<String>.generate(
                              7,
                              (index) => DateFormat('E', locale).format(
                                weekStart.add(Duration(days: index)),
                              ),
                            );

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 90),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Reveal(
                                    delay: const Duration(milliseconds: 80),
                                    child: _HeroSalesCard(
                                      label: 'Sales Today',
                                      profitLabel: 'Est. Profit Today',
                                      sales: salesToday,
                                      profit: estProfitToday,
                                      format: settings.formatMoney,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _Reveal(
                                    delay: const Duration(milliseconds: 180),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _CountUp(
                                            value: txToday.toDouble(),
                                            builder: (context, v) =>
                                                StatCard(
                                              label: 'Transactions',
                                              value: '${v.round()}',
                                              icon: Icons.receipt_long_outlined,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _CountUp(
                                            value: creditBalance,
                                            builder: (context, v) =>
                                                StatCard(
                                              label: 'Total Utang',
                                              value: settings.formatMoney(v),
                                              icon: Icons.credit_card_outlined,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _Reveal(
                                    delay: const Duration(milliseconds: 280),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionTitle(
                                          title: 'This Week',
                                          trailing: _CountUp(
                                            value: weekTotal,
                                            builder: (context, v) => Text(
                                              settings.formatMoney(v),
                                              style: GoogleFonts.outfit(
                                                color: sari.accentAmber,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          height: 210,
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 24, 16, 12),
                                          decoration: BoxDecoration(
                                            color: sari.cardSurface,
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            border: Border.all(
                                              color: sari.cardBorder,
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: sari.shadow,
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: const Duration(
                                                milliseconds: 1000),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, progress, _) {
                                              final chartMax = maxY <= 0
                                                  ? 10.0
                                                  : maxY * 1.2;
                                              return BarChart(
                                                swapAnimationDuration:
                                                    const Duration(
                                                        milliseconds: 400),
                                                BarChartData(
                                                  maxY: chartMax,
                                                  gridData: const FlGridData(
                                                      show: false),
                                                  borderData: FlBorderData(
                                                      show: false),
                                                  barTouchData: BarTouchData(
                                                    touchTooltipData:
                                                        BarTouchTooltipData(
                                                      getTooltipColor: (_) =>
                                                          scheme.primary,
                                                      getTooltipItem: (group,
                                                          gi, rod, ri) {
                                                        return BarTooltipItem(
                                                          settings.formatMoney(
                                                              values[gi]),
                                                          GoogleFonts.outfit(
                                                            color: scheme
                                                                .onPrimary,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  titlesData: FlTitlesData(
                                                    leftTitles:
                                                        const AxisTitles(
                                                      sideTitles: SideTitles(
                                                          showTitles: false),
                                                    ),
                                                    rightTitles:
                                                        const AxisTitles(
                                                      sideTitles: SideTitles(
                                                          showTitles: false),
                                                    ),
                                                    topTitles:
                                                        const AxisTitles(
                                                      sideTitles: SideTitles(
                                                          showTitles: false),
                                                    ),
                                                    bottomTitles: AxisTitles(
                                                      sideTitles: SideTitles(
                                                        showTitles: true,
                                                        getTitlesWidget:
                                                            (value, meta) {
                                                          final i =
                                                              value.toInt();
                                                          if (i < 0 ||
                                                              i >=
                                                                  labels
                                                                      .length) {
                                                            return const SizedBox
                                                                .shrink();
                                                          }
                                                          final isToday =
                                                              i == todayIndex;
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 8),
                                                            child: Text(
                                                              labels[i],
                                                              style:
                                                                  GoogleFonts
                                                                      .outfit(
                                                                color: isToday
                                                                    ? scheme
                                                                        .primary
                                                                    : sari
                                                                        .faintText,
                                                                fontSize: 11.5,
                                                                fontWeight: isToday
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  barGroups: List.generate(
                                                      values.length, (i) {
                                                    final isToday =
                                                        i == todayIndex;
                                                    return BarChartGroupData(
                                                      x: i,
                                                      barRods: [
                                                        BarChartRodData(
                                                          toY: values[i] *
                                                              progress,
                                                          width: 18,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          gradient:
                                                              LinearGradient(
                                                            begin: Alignment
                                                                .bottomCenter,
                                                            end: Alignment
                                                                .topCenter,
                                                            colors: [
                                                              scheme.primary
                                                                  .withValues(
                                                                      alpha: isToday
                                                                          ? 0.7
                                                                          : 0.35),
                                                              scheme.primary
                                                                  .withValues(
                                                                      alpha: isToday
                                                                          ? 1.0
                                                                          : 0.65),
                                                            ],
                                                          ),
                                                          backDrawRodData:
                                                              BackgroundBarChartRodData(
                                                            show: true,
                                                            toY: chartMax,
                                                            color: scheme
                                                                .onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.05),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _Reveal(
                                    delay: const Duration(milliseconds: 380),
                                    child: const _SectionTitle(
                                      title: 'Top Selling Products',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (top3.isEmpty)
                                    _Reveal(
                                      delay: const Duration(milliseconds: 440),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: sari.cardSurface,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border:
                                              Border.all(color: sari.cardBorder),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              color: sari.faintText,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'No sales recorded yet',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                color: sari.mutedText,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    ...List.generate(top3.length, (i) {
                                      final item = top3[i];
                                      final topValue = top3.first.value;
                                      return _Reveal(
                                        delay: Duration(
                                            milliseconds: 440 + i * 90),
                                        child: _TopItemTile(
                                          rank: i + 1,
                                          name: item.key,
                                          countLabel: '${item.value} pcs',
                                          ratio: topValue <= 0
                                              ? 0
                                              : item.value / topValue,
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    return Row(
      children: [
        if (canPop)
          Material(
            color: sari.fieldFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded,
                    color: scheme.onSurface, size: 20),
              ),
            ),
          )
        else
          const SizedBox(width: 4),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: sari.mutedText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: sari.accentAmber,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HeroSalesCard extends StatelessWidget {
  const _HeroSalesCard({
    required this.label,
    required this.profitLabel,
    required this.sales,
    required this.profit,
    required this.format,
  });

  final String label;
  final String profitLabel;
  final double sales;
  final double profit;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sari.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sari.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: sari.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sari.accentAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.trending_up_rounded,
                        color: sari.accentAmber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: sari.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CountUp(
                value: sales,
                builder: (context, v) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    format(v),
                    style: GoogleFonts.outfit(
                      color: scheme.onSurface,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sari.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: sari.success.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: _CountUp(
                  value: profit,
                  builder: (context, v) => Text(
                    '$profitLabel  •  ${format(v)}',
                    style: GoogleFonts.outfit(
                      color: sari.success,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopItemTile extends StatelessWidget {
  const _TopItemTile({
    required this.rank,
    required this.name,
    required this.countLabel,
    required this.ratio,
  });

  final int rank;
  final String name;
  final String countLabel;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    final scheme = Theme.of(context).colorScheme;

    final badgeColor = switch (rank) {
      1 => const Color(0xFFFFC145),
      2 => const Color(0xFFB8C2CC),
      _ => const Color(0xFFD08C5B),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: sari.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sari.cardBorder, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: Text(
                  '$rank',
                  style: GoogleFonts.outfit(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                countLabel,
                style: GoogleFonts.outfit(
                  color: sari.accentAmber,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(
                  scheme.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reveal extends StatefulWidget {
  const _Reveal({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _offset =
      Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(_curve);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.builder});

  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}