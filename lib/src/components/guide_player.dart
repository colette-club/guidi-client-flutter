import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../models/guide.dart';

/// Theme configuration for the guide player UI.
class GuidePlayerTheme {
  final Color overlayColor;
  final double overlayOpacity;
  final Color tooltipBackground;
  final Color primaryColor;
  final Color primaryTextColor;
  final Color subtleTextColor;
  final String skipLabel;
  final String nextLabel;
  final String doneLabel;
  final double? tooltipMaxWidth;

  const GuidePlayerTheme({
    this.overlayColor = const Color(0xFF1B3A2D),
    this.overlayOpacity = 0.85,
    this.tooltipBackground = const Color(0xFFFAF6F1),
    this.primaryColor = const Color(0xFF1B3A2D),
    this.primaryTextColor = Colors.white,
    this.subtleTextColor = const Color(0xFF8C8C8C),
    this.skipLabel = 'Skip',
    this.nextLabel = 'Next',
    this.doneLabel = 'Done',
    this.tooltipMaxWidth,
  });
}

class GuidePlayer {
  final BuildContext context;
  final Guide guide;
  final int groupIndex;

  /// Offset into the group's step list — skip the first N visible steps.
  final int stepOffset;

  final VoidCallback? onGroupFinished;
  final void Function(int completedSteps)? onSkip;

  /// Called when the user taps Next on a step that has [GuideStep.tapThrough].
  /// The tutorial is dismissed; the caller should run the interactive action
  /// (e.g. open a bottom sheet) and then resume with an incremented [stepOffset].
  final void Function(int stepIndex)? onTapThrough;

  /// Asked while the guide shows. Once it returns false, for instance because another screen covers the
  /// guide's screen or another tab is selected, the guide is taken down without finishing or skipping it,
  /// and [onInterrupted] is called.
  final bool Function()? isScreenVisible;

  /// Called after [isScreenVisible] took the guide down, so the caller can play it again later.
  final VoidCallback? onInterrupted;

  /// Localization object passed to guide step resolvers.
  final dynamic l10n;

  /// Theme configuration for the tooltip UI.
  final GuidePlayerTheme theme;

  late TutorialCoachMark _tutorialCoachMark;
  bool _tapThroughFired = false;
  bool _skipFired = false;
  bool _shown = false;
  bool _interrupted = false;
  int _currentStepIndex = 0;
  Timer? _visibilityWatch;

  /// How often [isScreenVisible] is asked while the guide shows.
  static const Duration _visibilityCheckInterval = Duration(milliseconds: 100);

  GuidePlayer({
    required this.context,
    required this.guide,
    required this.groupIndex,
    required this.l10n,
    this.stepOffset = 0,
    this.onGroupFinished,
    this.onSkip,
    this.onTapThrough,
    this.isScreenVisible,
    this.onInterrupted,
    this.theme = const GuidePlayerTheme(),
  });

  /// Plays the guide group. Returns true if steps were shown, false if no visible targets found.
  bool play() {
    final groups = guide.stepGroups;
    if (groupIndex >= groups.length) return false;

    final currentGroup = groups[groupIndex];
    final isLastGroup = groupIndex == groups.length - 1;

    // Filter to only steps whose key is currently mounted and has a valid render box
    final visibleSteps = <MapEntry<int, GuideStep>>[];
    for (var i = 0; i < currentGroup.length; i++) {
      final ctx = currentGroup[i].targetKey.currentContext;
      if (ctx != null) {
        final renderObject = ctx.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            renderObject.size.isFinite) {
          final position = renderObject.localToGlobal(Offset.zero);
          if (position.dx.isFinite && position.dy.isFinite) {
            visibleSteps.add(MapEntry(i, currentGroup[i]));
          }
        }
      }
    }

    // Apply stepOffset — skip steps we've already shown
    final stepsToShow = visibleSteps.skip(stepOffset).toList();

    if (stepsToShow.isEmpty) {
      return false;
    }

    final groupStepOffset = guide.stepOffsetForGroup(groupIndex);
    _currentStepIndex = groupStepOffset + stepOffset;

    final screenHeight = MediaQuery.of(context).size.height;

    final targets = stepsToShow.asMap().entries.map((entry) {
      final visibleIndex = entry.key;
      final step = entry.value.value;
      final isLastStep = isLastGroup &&
          visibleIndex == stepsToShow.length - 1 &&
          !step.tapThrough;

      // If target takes more than 1/3 of the screen and content is top-aligned,
      // use custom positioning to guarantee tooltip gets enough space
      var contentAlign = step.contentAlign;
      CustomTargetContentPosition? customPosition;
      final targetCtx = step.targetKey.currentContext;
      if (contentAlign == ContentAlign.top && targetCtx != null) {
        final renderBox = targetCtx.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final targetHeight = renderBox.size.height;
          if (targetHeight > screenHeight / 3) {
            contentAlign = ContentAlign.custom;
            customPosition = CustomTargetContentPosition(top: 16);
          }
        }
      }

      return TargetFocus(
        identify: step.titleResolver(l10n),
        keyTarget: step.targetKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: contentAlign,
            customPosition: customPosition,
            child: _GuideTooltip(
              title: step.titleResolver(l10n),
              description: step.descResolver(l10n),
              isLast: isLastStep,
              theme: theme,
              onNext: () {
                if (step.tapThrough && onTapThrough != null) {
                  _tapThroughFired = true;
                  _tutorialCoachMark.finish();
                  onTapThrough!(stepOffset + visibleIndex);
                  return;
                }
                _currentStepIndex =
                    groupStepOffset + stepOffset + visibleIndex + 1;
                _tutorialCoachMark.next();
              },
            ),
          ),
        ],
      );
    }).toList();

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: theme.overlayColor,
      opacityShadow: theme.overlayOpacity,
      // A fixed "Skip" pill pinned to the top-right (safe-area aware), shown on
      // every step. It's the guaranteed escape hatch: even if a step's tooltip
      // ends up off-screen, the user can always cancel the guide from here
      // rather than being stuck and force-quitting the app.
      hideSkip: false,
      showSkipInLastTarget: true,
      alignSkip: Alignment.topRight,
      skipWidget: _PinnedSkip(theme: theme),
      beforeFocus: _scrollIntoView,
      onFinish: () {
        _visibilityWatch?.cancel();
        if (_tapThroughFired || _skipFired) return;
        final lastStep = stepsToShow.last.value;
        if (lastStep.tapThrough && onTapThrough != null) {
          onTapThrough!(stepOffset + stepsToShow.length - 1);
          return;
        }
        onGroupFinished?.call();
      },
      onSkip: () {
        _visibilityWatch?.cancel();
        _skipFired = true;
        onSkip?.call(_currentStepIndex);
        return true;
      },
    );

    _shown = true;
    _tutorialCoachMark.show(context: context, rootOverlay: true);
    _watchVisibility();
    return true;
  }

  /// Takes the guide down without finishing or skipping it, for instance when
  /// its screen goes away. Does nothing for a guide that never showed.
  void cancel() {
    _visibilityWatch?.cancel();
    if (!_shown || _interrupted) return;
    _interrupted = true;
    _tutorialCoachMark.removeOverlayEntry();
  }

  /// Scrolls a step's target into view and waits for the scroll to end, so the coach mark measures the
  /// target where it comes to rest. Runs before every step, the first one included.
  Future<void> _scrollIntoView(TargetFocus target) async {
    // A guide taken down leaves its screen where it is, and its coach mark's
    // focus, disposed by now, must never go on to measure and animate.
    if (_interrupted) return Completer<void>().future;

    final BuildContext? targetContext = target.keyTarget?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3,
      );
    }
    // Taken down while it scrolled.
    if (_interrupted) return Completer<void>().future;
  }

  void _watchVisibility() {
    final isScreenVisible = this.isScreenVisible;
    if (isScreenVisible == null) return;

    _visibilityWatch = Timer.periodic(_visibilityCheckInterval, (timer) {
      if (isScreenVisible()) return;
      cancel();
      onInterrupted?.call();
    });
  }
}

/// Tooltip widget shown during guide steps.
class _GuideTooltip extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final bool isLast;
  final GuidePlayerTheme theme;

  const _GuideTooltip({
    required this.title,
    required this.description,
    required this.onNext,
    required this.theme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: theme.tooltipMaxWidth != null
          ? BoxConstraints(maxWidth: theme.tooltipMaxWidth!)
          : null,
      decoration: BoxDecoration(
        color: theme.tooltipBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: theme.subtleTextColor, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.primaryTextColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  isLast ? theme.doneLabel : theme.nextLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: theme.primaryTextColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (theme.tooltipMaxWidth != null) {
      return Align(
        alignment: Alignment.center,
        child: tooltip,
      );
    }
    return tooltip;
  }
}

/// The always-visible skip control pinned to the guide overlay's top-right
/// corner — a small, unobtrusive close (X) icon so it stays out of the way of
/// the tooltip and the highlighted target. TutorialCoachMark wraps it in its
/// own tap handler (`onClickSkip` → `skip`), so this widget is purely visual.
/// It guarantees an escape hatch even if a step's tooltip lands off-screen.
/// Keyed for tests; carries a semantic label for accessibility.
class _PinnedSkip extends StatelessWidget {
  final GuidePlayerTheme theme;

  const _PinnedSkip({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        key: const Key('guide_skip_button'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: theme.tooltipBackground,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.close,
          size: 18,
          color: theme.primaryColor,
          semanticLabel: theme.skipLabel,
        ),
      ),
    );
  }
}
