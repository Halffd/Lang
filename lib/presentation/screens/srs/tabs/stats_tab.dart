import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/data/repositories/srs_service.dart';

class StatsTab extends StatelessWidget {
  final SRSService srsService;

  const StatsTab({required this.srsService, super.key});

  @override
  Widget build(BuildContext context) {
    final cards = srsService.allCards;
    final dueCount = srsService.dueCount;
    final totalCards = cards.length;
    final reviewed = cards.where((c) => c.reviewCount > 0).length;
    final suspended = cards.where((c) => c.type == CardType.suspended).length;

    final avgEase = cards.isNotEmpty
        ? (cards.map((c) => c.easeFactor).reduce((a, b) => a + b) / cards.length).toDouble()
        : 2.5;

    final intervals = cards.map((c) => c.interval).where((i) => i > 0).toList();
    final avgInterval = intervals.isNotEmpty
        ? (intervals.reduce((a, b) => a + b) / intervals.length).toDouble()
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverviewCards(totalCards, dueCount, reviewed, suspended),
        const SizedBox(height: 16),
        _buildProgressSection(cards),
        const SizedBox(height: 16),
        _EaseDistributionChart(cards: cards),
        const SizedBox(height: 16),
        _IntervalDistributionChart(cards: cards),
        const SizedBox(height: 16),
        _buildStatsSummary(totalCards, dueCount, reviewed, suspended, avgEase, avgInterval),
      ],
    );
  }

  Widget _buildOverviewCards(int total, int due, int reviewed, int suspended) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(label: 'Total Cards', value: '$total', color: Colors.blue),
        _StatCard(label: 'Due Now', value: '$due', color: Colors.orange),
        _StatCard(label: 'Reviewed', value: '$reviewed', color: Colors.green),
        _StatCard(label: 'Suspended', value: '$suspended', color: Colors.grey),
      ],
    );
  }

  Widget _buildProgressSection(List<SRSCard> cards) {
    final due = cards.where((c) => c.isDue && c.type != CardType.suspended).length;
    final learning = cards.where((c) => c.type == CardType.learning).length;
    final review = cards.where((c) => c.type == CardType.review).length;
    final mature = cards.where((c) => c.type == CardType.review && c.reviewCount > 8).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressRow('Due', due, cards.length, Colors.orange),
        _ProgressRow('Learning', learning, cards.length, Colors.blue),
        _ProgressRow('Review', review, cards.length, Colors.green),
        _ProgressRow('Mature', mature, cards.length, Colors.purple),
      ],
    );
  }

  Widget _buildStatsSummary(
    int total, int due, int reviewed, int suspended,
    double avgEase, double avgInterval,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _detailRow('Total Cards', '$total'),
            _detailRow('Due for Review', '$due'),
            _detailRow('Ever Reviewed', '$reviewed'),
            _detailRow('Suspended', '$suspended'),
            _detailRow('Avg Ease Factor', avgEase.toStringAsFixed(2)),
            _detailRow('Avg Interval', '${avgInterval.toStringAsFixed(1)} days'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressRow(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$pct% ($value)'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total > 0 ? value / total : 0,
          minHeight: 8,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}

class _EaseDistributionChart extends StatelessWidget {
  final List<SRSCard> cards;

  const _EaseDistributionChart({required this.cards});

  @override
  Widget build(BuildContext context) {
    final easeBuckets = <String, int>{
      'Hard (<2.0)': 0,
      'Normal (2.0-2.5)': 0,
      'Easy (2.5-3.0)': 0,
      'Very Easy (>3.0)': 0,
    };

    for (final card in cards) {
      if (card.easeFactor < 2.0) {
        easeBuckets['Hard (<2.0)'] = easeBuckets['Hard (<2.0)']! + 1;
      } else if (card.easeFactor < 2.5) {
        easeBuckets['Normal (2.0-2.5)'] = easeBuckets['Normal (2.0-2.5)']! + 1;
      } else if (card.easeFactor < 3.0) {
        easeBuckets['Easy (2.5-3.0)'] = easeBuckets['Easy (2.5-3.0)']! + 1;
      } else {
        easeBuckets['Very Easy (>3.0)'] = easeBuckets['Very Easy (>3.0)']! + 1;
      }
    }

    final maxVal = easeBuckets.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ease Factor Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal.toDouble() + 1 : 5,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final labels = ['Hard', 'Normal', 'Easy', 'Very Easy'];
                          return Text(val.toInt() < labels.length ? labels[val.toInt()] : '',
                              style: const TextStyle(fontSize: 9));
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (val, _) => Text(val.toInt() > 0 ? '${val.toInt()}' : '',
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: easeBuckets.entries.toList().asMap().entries.map((e) {
                    Color color;
                    switch (e.value.key) {
                      case 'Hard (<2.0)': color = Colors.red; break;
                      case 'Normal (2.0-2.5)': color = Colors.orange; break;
                      case 'Easy (2.5-3.0)': color = Colors.lightGreen; break;
                      default: color = Colors.green; break;
                    }
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value.toDouble(),
                          color: color,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalDistributionChart extends StatelessWidget {
  final List<SRSCard> cards;

  const _IntervalDistributionChart({required this.cards});

  @override
  Widget build(BuildContext context) {
    final intervals = cards.map((c) => c.interval).where((i) => i > 0).toList();

    if (intervals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No interval data yet'),
        ),
      );
    }

    final buckets = <String, int>{
      '1 day': 0,
      '2-3 days': 0,
      '4-7 days': 0,
      '1-2 weeks': 0,
      '2-4 weeks': 0,
      '1-3 months': 0,
      '3+ months': 0,
    };

    for (final interval in intervals) {
      if (interval <= 1) {
        buckets['1 day'] = buckets['1 day']! + 1;
      } else if (interval <= 3) {
        buckets['2-3 days'] = buckets['2-3 days']! + 1;
      } else if (interval <= 7) {
        buckets['4-7 days'] = buckets['4-7 days']! + 1;
      } else if (interval <= 14) {
        buckets['1-2 weeks'] = buckets['1-2 weeks']! + 1;
      } else if (interval <= 30) {
        buckets['2-4 weeks'] = buckets['2-4 weeks']! + 1;
      } else if (interval <= 90) {
        buckets['1-3 months'] = buckets['1-3 months']! + 1;
      } else {
        buckets['3+ months'] = buckets['3+ months']! + 1;
      }
    }

    final maxVal = buckets.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Interval Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal.toDouble() + 1 : 5,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final labels = ['1d', '2-3d', '4-7d', '1-2w', '2-4w', '1-3m', '3m+'];
                          return Text(val.toInt() < labels.length ? labels[val.toInt()] : '',
                              style: const TextStyle(fontSize: 9));
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (val, _) => Text(val.toInt() > 0 ? '${val.toInt()}' : '',
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: buckets.entries.toList().asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}