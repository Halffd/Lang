// Widget tests for the screenshot manager: the filter/sort toolbar,
// the per-item action menu and the rename/edit flows.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/screenshot_manager.dart';
import 'package:lang/presentation/widgets/screenshot_ref_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ScreenshotService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('screenshot_manager_test');
    service = ScreenshotService();
    service.dirProvider = () async => tempDir;
    service.platformOverride = () async => ScreenshotPlatform.x11;
    service.runCommand = (executable, arguments) async {
      if (executable == 'which') {
        const tools = {'maim', 'slop', 'xdotool', 'xrandr'};
        return (tools.contains(arguments.first) ? 0 : 1, '', '');
      }
      if (executable == 'maim') {
        File(arguments.last).writeAsStringSync('png');
        return (0, '', '');
      }
      if (executable == 'slop') {
        return (0, '100x100+0+0', '');
      }
      if (executable == 'xrandr') {
        return (0, 'HDMI-1 connected primary 1920x1080+0+0', '');
      }
      return (1, '', '');
    };
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });


  /// The thumbnail shows a progress indicator while the bytes are read,
  /// and that indicator animates forever, so the frame pump has to be
  /// bounded instead of settling. The window is long enough for the
  /// popup menu route to finish animating.
  Future<void> pump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpManager(WidgetTester tester) async {
    final appState = AppState(StorageService());
    await appState.storageService.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ScreenshotManager(service: service)),
        ),
      ),
    );
    await pump(tester);
  }

  Future<void> captureOne(WidgetTester tester) async {
    final item = await service.capture(ScreenshotKind.fullscreen);
    expect(item, isNotNull);
    await pump(tester);
  }

  testWidgets('shows the empty state when nothing is stored', (
    tester,
  ) async {
    await pumpManager(tester);

    expect(find.text('No screenshots yet'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('lists a stored screenshot', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);

    expect(find.text('No screenshots yet'), findsNothing);
    expect(find.byType(ScreenshotRefImage), findsOneWidget);
  });

  testWidgets('the item menu offers the full action set', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Copy path'), findsOneWidget);
    expect(find.text('Copy relative path'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Edit text'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('rename stores the new name on the item', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Rename'));
    await pump(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'invoice',
    );
    await tester.tap(find.text('Save'));
    await pump(tester);
    // the dialog pops and the rename runs in the continuation
    await tester.pump(const Duration(milliseconds: 600));

    expect(service.items.first.name, 'invoice');
    expect(find.text('invoice'), findsOneWidget);
  });

  testWidgets('edit text replaces the recognized text', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);
    service.editOcrText(service.items.first.id, 'old text');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Edit text'));
    await pump(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'new text',
    );
    await tester.tap(find.text('Save'));
    await pump(tester);
    // the dialog pops and the rename runs in the continuation
    await tester.pump(const Duration(milliseconds: 600));

    expect(service.items.first.ocrText, 'new text');
  });

  testWidgets('hide removes the item from the visible list', (
    tester,
  ) async {
    await pumpManager(tester);
    await captureOne(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Hide'));
    await pump(tester);

    expect(service.items.first.hidden, isTrue);
    expect(find.byType(ScreenshotRefImage), findsNothing);
  });

  testWidgets('the hidden filter shows the hidden items', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);
    service.setHidden(service.items.first.id, true);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await pump(tester);
    await tester.tap(find.text('Hidden'));
    await pump(tester);

    expect(find.byType(ScreenshotRefImage), findsOneWidget);
  });

  testWidgets('delete removes the item from the service', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Delete'));
    await pump(tester);

    expect(service.items, isEmpty);
    expect(find.text('No screenshots yet'), findsOneWidget);
  });

  testWidgets('properties shows the stored metadata', (tester) async {
    await pumpManager(tester);
    await captureOne(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Properties'));
    await pump(tester);

    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Kind'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Path'), findsOneWidget);
  });
}
