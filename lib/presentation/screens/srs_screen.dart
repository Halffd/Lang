import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/data/repositories/anki_package_service.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/utils/screen_size.dart';
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