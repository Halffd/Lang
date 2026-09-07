import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/presentation/screens/srs/tabs/study_tab.dart';
import 'package:lang/presentation/screens/srs/tabs/cards_tab.dart';
import 'package:lang/presentation/screens/srs/tabs/stats_tab.dart';
import 'package:lang/presentation/screens/srs/tabs/settings_tab.dart';

class SRSScreen extends StatefulWidget {
  const SRSScreen({super.key});

  @override
  State<SRSScreen> createState() => _SRSScreenState();
}

class _SRSScreenState extends State<SRSScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final srsService = context.watch<SRSService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SRS', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: srsService.dueCount > 0,
                label: Text('${srsService.dueCount}'),
                child: const Icon(Icons.school),
              ),
              text: 'Study',
            ),
            Tab(icon: const Icon(Icons.list), text: 'Cards'),
            Tab(icon: const Icon(Icons.bar_chart), text: 'Stats'),
            Tab(icon: const Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StudyTab(srsService: srsService),
          CardsTab(srsService: srsService),
          StatsTab(srsService: srsService),
          SettingsTab(srsService: srsService),
        ],
      ),
    );
  }
}