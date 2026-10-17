import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
                      child: CircularProgressIndicator(color: sari.success),
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        l10n.text('dashboard'),
                        style: TextStyle(
                          color: sari.faintText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: l10n.text('salesToday'),
                                value: settings.formatMoney(metrics.salesToday),
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: l10n.text('afterTaxToday'),
                                value:
                                    settings.formatMoney(metrics.afterTaxToday),
                                valueColor: sari.success,
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: l10n.text('transactions'),
                                value: '${metrics.transactionsToday}',
                                icon: Icons.receipt_long_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              height: 108,
                              child: StatCard(
                                label: l10n.text('creditBalance'),
                                value: creditBalance == null
                                    ? l10n.text('unavailable')
                                    : settings.formatMoney(creditBalance),
                                valueColor:
                                    creditBalance == null ? sari.danger : null,
                                icon: Icons.credit_card_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, bottom: 10, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _period.label(l10n),
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _periodPicker(),
                        ],
                      ),
                    ),
                    _panel(
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            BarChart(
                              chart.dataFor(sari, scheme),
                              swapAnimationDuration:
                                  const Duration(milliseconds: 250),
                            ),
                            if (!chart.hasValues)
                              IgnorePointer(
                                child: Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: sari.onAccent,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(16),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        l10n.text('noSalesInPeriod'),
                                        style: TextStyle(
                                          color: sari.mutedText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        l10n.text('topSellingRecent'),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (metrics.topSellers.isEmpty)
                      _panel(
                        child: Text(
                          l10n.text('noSalesYet'),
                          style: TextStyle(
                            color: sari.mutedText,
                            fontSize: 13,
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
                              _sellerRow(metrics.topSellers[index], index + 1),
                              if (index < metrics.topSellers.length - 1)
                                Divider(
                                  height: 1,
                                  color: sari.success.withValues(alpha: 0.14),
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _periodPicker() {
    final l10n = context.l10n;
    return PopupMenuButton<_ChartPeriod>(
      initialValue: _period,
      onSelected: (value) => setState(() => _period = value),
      color: sari.cardSurfaceStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: sari.success.withValues(alpha: 0.25)),
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
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  if (period == _period)
                    Icon(Icons.check_rounded, color: sari.warning, size: 18),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
            color: sari.success.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _period.pickerLabel(l10n),
              style: TextStyle(
                color: sari.faintText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: sari.faintText, size: 18),
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
    );
  }

  Widget _messageCard(String message, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: _panel(
        child: Text(
          message,
          style: TextStyle(color: color, fontSize: 12),
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

  Widget _sellerRow(DashboardSeller seller, int rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sari.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: sari.success,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: sari.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: sari.warning,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              seller.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
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
            style: TextStyle(
              color: sari.warning,
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
  });

  final List<double> values;
  final List<String> labels;
  final bool hasValues;

  BarChartData dataFor(SariColors sari, ColorScheme scheme) {
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
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final index = group.x.toInt();
            if (index < 0 || index >= labels.length) return null;
            return BarTooltipItem(
              '${labels[index]}\n',
              TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: SettingsStore.instance.formatMoney(values[index]),
                  style: TextStyle(
                    color: sari.success,
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
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: sari.chartLabel,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(values.length, (index) {
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: values[index],
              width: values.length > 7 ? 10 : 16,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              color: sari.chartBar,
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMax,
                color: sari.cardSurface,
              ),
            ),
          ],
        );
      }),
    );
  }
}
