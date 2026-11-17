import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:guidi_client/guidi_client.dart";

const Size _phone = Size(400, 800);

/// Two targets 2,000 points apart on a scrolling screen that keeps both mounted, and a guide with one step on each.
class _Screen {
  final GlobalKey topKey = GlobalKey(debugLabel: "top");
  final GlobalKey bottomKey = GlobalKey(debugLabel: "bottom");
  final ScrollController scrollController = ScrollController();

  late final Guide guide = Guide(
    id: "demo_v1",
    priority: 0,
    startScreen: "demo",
    titleResolver: (_) => "Demo",
    descResolver: (_) => "A demo guide",
    icon: Icons.info,
    steps: [
      GuideStep(
          screen: "demo",
          targetKey: topKey,
          titleResolver: (_) => "Top title",
          descResolver: (_) => "Top description"),
      GuideStep(
          screen: "demo",
          targetKey: bottomKey,
          titleResolver: (_) => "Bottom title",
          descResolver: (_) => "Bottom description"),
    ],
  );

  Widget build() {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            children: [
              Container(key: topKey, height: 80, color: Colors.blue),
              const SizedBox(height: 2000),
              Container(key: bottomKey, height: 80, color: Colors.green),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );
  }
}

Future<_Screen> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final _Screen screen = _Screen();
  await tester.pumpWidget(screen.build());
  return screen;
}

/// Pumps discrete frames: the coach mark pulses forever, so pumpAndSettle never returns.
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  for (var elapsed = Duration.zero;
      elapsed < duration;
      elapsed += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The rectangle the coach mark lights up: where it measured the target when it focused the step.
Rect _highlightedRect(WidgetTester tester) {
  final CustomPaint light = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere(
          (paint) => paint.painter.runtimeType.toString() == "LightPaintRect");
  final TargetPosition target =
      (light.painter as dynamic).target as TargetPosition;
  return target.offset & target.size;
}

void _expectOnScreen(WidgetTester tester, Finder finder, String label) {
  expect(finder, findsOneWidget, reason: "$label is shown");
  final Rect rect = tester.getRect(finder);
  expect(rect.top >= 0 && rect.bottom <= _phone.height, isTrue,
      reason: "$label is on screen, not at $rect");
}

void main() {
  group("play", () {
    testWidgets(
        "scrolls the first step's target into view before highlighting it",
        (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      screen.scrollController.jumpTo(1500);
      await tester.pump();
      expect(tester.getRect(find.byKey(screen.topKey)).bottom, lessThan(0),
          reason: "the setup scrolls the first target out of view");

      GuidePlayer(
              context: tester.element(find.byType(SingleChildScrollView)),
              guide: screen.guide,
              groupIndex: 0,
              l10n: null)
          .play();
      await _pumpFor(tester, const Duration(milliseconds: 1500));

      _expectOnScreen(tester, find.byKey(screen.topKey), "the first target");
      _expectOnScreen(tester, find.text("Top title"), "the first tooltip");
      expect(_highlightedRect(tester).top,
          closeTo(tester.getRect(find.byKey(screen.topKey)).top, 1),
          reason: "the highlight sits on the first target");
    });

    testWidgets(
        "highlights the next target where it comes to rest after scrolling to it",
        (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      GuidePlayer(
              context: tester.element(find.byType(SingleChildScrollView)),
              guide: screen.guide,
              groupIndex: 0,
              l10n: null)
          .play();
      await _pumpFor(tester, const Duration(milliseconds: 1500));

      await tester.tap(find.text("Next"));
      await _pumpFor(tester, const Duration(milliseconds: 2000));

      _expectOnScreen(tester, find.byKey(screen.bottomKey), "the next target");
      expect(
        _highlightedRect(tester).top,
        closeTo(tester.getRect(find.byKey(screen.bottomKey)).top, 1),
        reason:
            "the highlight sits on the target where it came to rest, not where it was mid-scroll",
      );
    });

    testWidgets(
        "takes the guide down without finishing or skipping it once its screen is no longer visible",
        (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      var visible = true;
      var interrupted = 0;
      var finished = 0;
      var skipped = 0;

      GuidePlayer(
        context: tester.element(find.byType(SingleChildScrollView)),
        guide: screen.guide,
        groupIndex: 0,
        l10n: null,
        isScreenVisible: () => visible,
        onInterrupted: () => interrupted++,
        onGroupFinished: () => finished++,
        onSkip: (_) => skipped++,
      ).play();
      await _pumpFor(tester, const Duration(milliseconds: 1500));
      expect(find.text("Top title"), findsOneWidget,
          reason: "the guide shows first");

      visible = false;
      await _pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text("Top title"), findsNothing);
      expect(find.byKey(const Key("guide_skip_button")), findsNothing);
      expect(interrupted, 1);
      expect(finished, 0);
      expect(skipped, 0);
    });

    testWidgets(
        "takes the guide down cleanly while it still scrolls to its first target",
        (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      screen.scrollController.jumpTo(1500);
      await tester.pump();
      var visible = true;
      var interrupted = 0;

      GuidePlayer(
        context: tester.element(find.byType(SingleChildScrollView)),
        guide: screen.guide,
        groupIndex: 0,
        l10n: null,
        isScreenVisible: () => visible,
        onInterrupted: () => interrupted++,
      ).play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      visible = false;
      await _pumpFor(tester, const Duration(milliseconds: 1500));

      expect(tester.takeException(), isNull);
      expect(find.text("Top title"), findsNothing);
      expect(interrupted, 1);
    });
  });

  group("cancel", () {
    testWidgets(
        "takes the guide down without finishing or skipping it, and stops watching its screen",
        (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      var interrupted = 0;
      var finished = 0;
      var skipped = 0;
      final GuidePlayer player = GuidePlayer(
        context: tester.element(find.byType(SingleChildScrollView)),
        guide: screen.guide,
        groupIndex: 0,
        l10n: null,
        isScreenVisible: () => true,
        onInterrupted: () => interrupted++,
        onGroupFinished: () => finished++,
        onSkip: (_) => skipped++,
      );
      player.play();
      await _pumpFor(tester, const Duration(milliseconds: 1500));
      expect(find.text("Top title"), findsOneWidget,
          reason: "the guide shows first");

      player.cancel();
      await _pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text("Top title"), findsNothing);
      expect(interrupted, 0);
      expect(finished, 0);
      expect(skipped, 0);
    });

    testWidgets(
        "leaves the screen where it is once cancelled before the first step scrolled",
        (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      screen.scrollController.jumpTo(1500);
      await tester.pump();
      final GuidePlayer player = GuidePlayer(
        context: tester.element(find.byType(SingleChildScrollView)),
        guide: screen.guide,
        groupIndex: 0,
        l10n: null,
      );

      player.play();
      await tester.pump();
      player.cancel();
      await _pumpFor(tester, const Duration(milliseconds: 1000));

      expect(screen.scrollController.offset, 1500);
      expect(find.text("Top title"), findsNothing);
    });

    testWidgets("does nothing for a guide that never showed", (tester) async {
      final _Screen screen = await _pumpScreen(tester);
      final GuidePlayer player = GuidePlayer(
          context: tester.element(find.byType(SingleChildScrollView)),
          guide: screen.guide,
          groupIndex: 7,
          l10n: null);

      expect(player.play(), isFalse);
      player.cancel();

      expect(tester.takeException(), isNull);
    });
  });
}
