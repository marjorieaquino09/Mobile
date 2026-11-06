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
import 'dashboard_metrics.dart';

enum _ChartPeriod { day, week, month, year }

extension on _ChartPeriod {
  String label(AppLocalizations l10n) {
    switch (this) {
      case _ChartPeriod.day:
        return l10n.text('todayPeriod');
      case _ChartPeriod.week:
        return l10n.text('thisWeek');
      case _ChartPeriod.month:
        return l10n.text('thisMonth');
      case _ChartPeriod.year:
        return l10n.text('thisYear');
    }
  }

  String pickerLabel(AppLocalizations l10n) {
    switch (this) {
      case _ChartPeriod.day:
        return l10n.text('periodDay');
      case _ChartPeriod.week:
        return l10n.text('periodWeek');
      case _ChartPeriod.month:
        return l10n.text('periodMonth');
      case _ChartPeriod.year:
        return l10n.text('periodYear');
    }
  }
}

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  _ChartPeriod _period = _ChartPeriod.week;

  @override
  Widget build(BuildContext context) {
    final firebase = FirebaseService();
    final settings = SettingsStore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return StreamBuilder<QuerySnapshot>(
          stream: userId == null
              ? const Stream.empty()
              : firebase.getOrdersStream(userId: userId, limit: 200),
          builder: (context, orderSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userId == null
                  ? const Stream.empty()
                  : firebase.getCreditsStream(userId),
              builder: (context, creditSnapshot) {
                if (orderSnapshot.connectionState == ConnectionState.waiting &&
                    !orderSnapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(color: scheme.primary),
                    ),
                  );
                }

                if (orderSnapshot.hasError) {
                  return _messageCard(
                    'Could not load dashboard: ${orderSnapshot.error}',
                    color: sari.danger,
                  );
                }

                final orders = (orderSnapshot.data?.docs
                        .map(
                          (doc) => StoreOrder.fromFirestore(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .toList() ??
                    <StoreOrder>[])
                  ..sort((a, b) {
                    final aTime =
                        a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime =
                        b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bTime.compareTo(aTime);
                  });
                final metrics = DashboardMetrics.fromOrders(
                  orders: orders,
                  taxRate: settings.taxRate,
                );
                final creditBalance = creditSnapshot.hasError
                    ? null
                    : DashboardMetrics.unpaidCredit(
                        creditSnapshot.data?.docs
                                .map((doc) => doc.data())
                                .toList() ??
                            const <Map<String, dynamic>>[],
                      );

                final chart = _chartFor(
                  _period,
                  orders,
                  metrics,
                  l10n,
                  locale,
                );
                final periodTotal =
                    chart.values.fold<double>(0, (sum, v) => sum + v);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    _Reveal(
                      child: _sectionLabel(l10n.text('dashboard')),
                    ),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _Reveal(
                              delay: const Duration(milliseconds: 60),
                              child: SizedBox(
                                width: cardWidth,
                                height: 108,
                                child: _CountUp(
                                  value: metrics.salesToday.toDouble(),
                                  builder: (context, v) => StatCard(
                                    label: l10n.text('salesToday'),
                                    value: settings.formatMoney(v),
                                    icon: Icons.payments_outlined,
                                  ),
                                ),
                              ),
                            ),
                            _Reveal(
                              delay: const Duration(milliseconds: 130),
                              child: SizedBox(
                                width: cardWidth,
                                height: 108,
                                child: _CountUp(
                                  value: metrics.afterTaxToday.toDouble(),
                                  builder: (context, v) => StatCard(
                                    label: l10n.text('afterTaxToday'),
                                    value: settings.formatMoney(v),
                                    valueColor: sari.success,
                                    icon:
                                        Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                              ),
                            ),
                            _Reveal(
                              delay: const Duration(milliseconds: 200),
                              child: SizedBox(
                                width: cardWidth,
                                height: 108,
                                child: _CountUp(
                                  value: metrics.transactionsToday.toDouble(),
                                  builder: (context, v) => StatCard(
                                    label: l10n.text('transactions'),
                                    value: '${v.round()}',
                                    icon: Icons.receipt_long_outlined,
                                  ),
                                ),
                              ),
                            ),
                            _Reveal(
                              delay: const Duration(milliseconds: 270),
                              child: SizedBox(
                                width: cardWidth,
                                height: 108,
                                child: creditBalance == null
                                    ? StatCard(
                                        label: l10n.text('creditBalance'),
                                        value: l10n.text('unavailable'),
                                        valueColor: sari.danger,
                                        icon: Icons.credit_card_outlined,
                                      )
                                    : _CountUp(
                                        value: creditBalance.toDouble(),
                                        builder: (context, v) => StatCard(
                                          label: l10n.text('creditBalance'),
                                          value: settings.formatMoney(v),
                                          icon: Icons.credit_card_outlined,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    _Reveal(
                      delay: const Duration(milliseconds: 340),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 4, bottom: 12, right: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 4,
                              height: 34,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _period.label(l10n),
                                    style: GoogleFonts.outfit(
                                      color: scheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  _CountUp(
                                    value: periodTotal,
                                    builder: (context, v) => Text(
                                      settings.formatMoney(v),
                                      style: GoogleFonts.outfit(
                                        color: sari.accentAmber,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _periodPicker(),
                          ],
                        ),
                      ),
                    ),

                    _Reveal(
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
                        decoration: BoxDecoration(
                          color: sari.cardSurface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: sari.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: sari.shadow,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 200,
                          child: Stack(
                            children: [
                              TweenAnimationBuilder<double>(
                                key: ValueKey(_period),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (context, progress, _) {
                                  return BarChart(
                                    chart.dataFor(sari, scheme, progress),
                                    swapAnimationDuration:
                                        const Duration(milliseconds: 350),
                                  );
                                },
                              ),
                              if (!chart.hasValues)
                                IgnorePointer(
                                  child: Center(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: sari.fieldFill,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(18),
                                        ),
                                        border: Border.all(
                                            color: sari.cardBorder),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 9,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bar_chart_rounded,
                                              color: sari.faintText,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.text('noSalesInPeriod'),
                                              style: GoogleFonts.outfit(
                                                color: sari.mutedText,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _Reveal(
                      delay: const Duration(milliseconds: 460),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                color: sari.accentAmber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.text('topSellingRecent'),
                              style: GoogleFonts.outfit(
                                color: scheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (metrics.topSellers.isEmpty)
                      _Reveal(
                        delay: const Duration(milliseconds: 520),
                        child: _panel(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  color: sari.faintText, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                l10n.text('noSalesYet'),
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
                      _panel(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < metrics.topSellers.length;
                                index++) ...[
                              _Reveal(
                                delay:
                                    Duration(milliseconds: 520 + index * 90),
                                child: _sellerRow(
                                  metrics.topSellers[index],
                                  index + 1,
                                  metrics.topSellers.first.quantity
                                      .toDouble(),
                                ),
                              ),
                              if (index < metrics.topSellers.length - 1)
                                Divider(
                                  height: 1,
                                  color: sari.cardBorder,
                                ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: sari.faintText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _periodPicker() {
    final l10n = context.l10n;
    return PopupMenuButton<_ChartPeriod>(
      initialValue: _period,
      onSelected: (value) => setState(() => _period = value),
      color: sari.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: sari.cardBorder),
      ),
      itemBuilder: (context) => _ChartPeriod.values
          .map(
            (period) => PopupMenuItem(
              value: period,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    period.pickerLabel(l10n),
                    style: GoogleFonts.outfit(color: scheme.onSurface),
                  ),
                  if (period == _period)
                    Icon(Icons.check_rounded, color: sari.accentAmber, size: 18),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sari.fieldFill,
          border: Border.all(
            color: sari.cardBorder,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _period.pickerLabel(l10n),
              style: GoogleFonts.outfit(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: sari.mutedText, size: 18),
          ],
        ),
      ),
    );
  }

  static _ChartResult _chartFor(
    _ChartPeriod period,
    List<StoreOrder> orders,
    DashboardMetrics metrics,
    AppLocalizations l10n,
    String locale,
  ) {
    switch (period) {
      case _ChartPeriod.day:
        return _buildDayChart(orders, locale);
      case _ChartPeriod.week:
        return _buildWeekChart(orders, locale);
      case _ChartPeriod.month:
        return _buildMonthChart(orders, locale, l10n);
      case _ChartPeriod.year:
        return _buildYearChart(orders, locale);
    }
  }

  static _ChartResult _buildDayChart(
    List<StoreOrder> orders,
    String locale,
  ) {
    final now = DateTime.now();
    final values = List<double>.filled(8, 0);
    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null ||
          createdAt.year != now.year ||
          createdAt.month != now.month ||
          createdAt.day != now.day) {
        continue;
      }
      values[createdAt.hour ~/ 3] += order.total;
    }
    final labels = List<String>.generate(
      8,
      (index) => DateFormat('ha', locale).format(
        DateTime(now.year, now.month, now.day, index * 3),
      ),
    );
    return _ChartResult(
      values: values,
      labels: labels,
      hasValues: values.any((value) => value > 0),
      currentIndex: now.hour ~/ 3,
    );
  }

  static _ChartResult _buildWeekChart(List<StoreOrder> orders, String locale) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final values = List<double>.filled(7, 0);
    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null) continue;
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final index = day.difference(monday).inDays;
      if (index >= 0 && index < values.length) values[index] += order.total;
    }
    return _ChartResult(
      values: values,
      labels: List<String>.generate(
        7,
        (index) =>
            DateFormat('E', locale).format(monday.add(Duration(days: index))),
      ),
      hasValues: values.any((value) => value > 0),
      currentIndex: now.weekday - 1,
    );
  }

  static _ChartResult _buildMonthChart(
    List<StoreOrder> orders,
    String locale,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final values = List<double>.filled(5, 0);
    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null) continue;
      if (createdAt.year != now.year || createdAt.month != now.month) continue;
      final weekIndex = ((createdAt.day - 1) ~/ 7).clamp(0, 4);
      values[weekIndex] += order.total;
    }
    final labels = List<String>.generate(
      5,
      (i) => l10n.text('chartWeekAbbr', values: {'week': '${i + 1}'}),
    );
    return _ChartResult(
      values: values,
      labels: labels,
      hasValues: values.any((v) => v > 0),
      currentIndex: ((now.day - 1) ~/ 7).clamp(0, 4),
    );
  }

  static _ChartResult _buildYearChart(List<StoreOrder> orders, String locale) {
    final now = DateTime.now();
    final values = List<double>.filled(12, 0);
    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null) continue;
      if (createdAt.year != now.year) continue;
      values[createdAt.month - 1] += order.total;
    }
    final labels = List<String>.generate(
      12,
      (i) => DateFormat('MMM', locale).format(DateTime(now.year, i + 1)),
    );
    return _ChartResult(
      values: values,
      labels: labels,
      hasValues: values.any((v) => v > 0),
      currentIndex: now.month - 1,
    );
  }

  Widget _messageCard(String message, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: _panel(
        child: Text(
          message,
          style: GoogleFonts.outfit(color: color, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: sari.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sari.cardBorder),
      ),
      child: child,
    );
  }

  Widget _sellerRow(DashboardSeller seller, int rank, double topQuantity) {
    final badgeColor = switch (rank) {
      1 => const Color(0xFFFFC145),
      2 => const Color(0xFFB8C2CC),
      _ => const Color(0xFFD08C5B),
    };
    final ratio =
        topQuantity <= 0 ? 0.0 : (seller.quantity.toDouble() / topQuantity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: Text(
                  '$rank',
                  style: GoogleFonts.outfit(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: sari.accentAmber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: sari.accentAmber,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  seller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.text(
                  'bestSellingPcs',
                  values: {'count': '${seller.quantity}'},
                ),
                style: GoogleFonts.outfit(
                  color: sari.accentAmber,
                  fontSize: 14,
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
                minHeight: 5,
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

class _ChartResult {
  const _ChartResult({
    required this.values,
    required this.labels,
    required this.hasValues,
    required this.currentIndex,
  });

  final List<double> values;
  final List<String> labels;
  final bool hasValues;
  final int currentIndex;

  BarChartData dataFor(
    SariColors sari,
    ColorScheme scheme,
    double progress,
  ) {
    final highestValue = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    final chartMax = highestValue <= 0 ? 10.0 : highestValue * 1.2;

    return BarChartData(
      maxY: chartMax,
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => sari.cardSurface,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final index = group.x.toInt();
            if (index < 0 || index >= labels.length) return null;
            return BarTooltipItem(
              '${labels[index]}\n',
              GoogleFonts.outfit(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: SettingsStore.instance.formatMoney(values[index]),
                  style: GoogleFonts.outfit(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= labels.length) {
                return const SizedBox.shrink();
              }
              final isCurrent = index == currentIndex;
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  labels[index],
                  style: GoogleFonts.outfit(
                    color: isCurrent ? scheme.primary : sari.faintText,
                    fontSize: 10.5,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(values.length, (index) {
        final isCurrent = index == currentIndex;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: values[index] * progress,
              width: values.length > 7 ? 10 : 16,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isCurrent
                    ? [
                        scheme.primary.withValues(alpha: 0.7),
                        scheme.primary,
                      ]
                    : [
                        scheme.primary.withValues(alpha: 0.35),
                        scheme.primary.withValues(alpha: 0.65),
                      ],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMax,
                color: scheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
          ],
        );
      }),
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