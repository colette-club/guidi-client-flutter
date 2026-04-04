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

  /// Localization object passed to guide step resolvers.
  final dynamic l10n;

  /// Theme configuration for the tooltip UI.
  final GuidePlayerTheme theme;

  late TutorialCoachMark _tutorialCoachMark;
  bool _tapThroughFired = false;
  bool _skipFired = false;
  int _currentStepIndex = 0;

  GuidePlayer({
    required this.context,
    required this.guide,
    required this.groupIndex,
    required this.l10n,
    this.stepOffset = 0,
    this.onGroupFinished,
    this.onSkip,
    this.onTapThrough,
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
        if (renderObject is RenderBox && renderObject.hasSize && renderObject.size.isFinite) {
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

    final targets = stepsToShow.asMap().entries.map((entry) {
      final visibleIndex = entry.key;
      final step = entry.value.value;
      final isLastStep = isLastGroup && visibleIndex == stepsToShow.length - 1 && !step.tapThrough;

      return TargetFocus(
        identify: step.titleResolver(l10n),
        keyTarget: step.targetKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: step.contentAlign,
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
                _currentStepIndex = groupStepOffset + stepOffset + visibleIndex + 1;
                _tutorialCoachMark.next();
                // Scroll to next target after overlay animation
                if (visibleIndex + 1 < stepsToShow.length) {
                  final nextStep = stepsToShow[visibleIndex + 1].value;
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (nextStep.targetKey.currentContext != null) {
                      Scrollable.ensureVisible(
                        nextStep.targetKey.currentContext!,
                        duration: const Duration(milliseconds: 300),
                        alignment: 0.3,
                      );
                    }
                  });
                }
              },
              onSkip: () {
                _tutorialCoachMark.skip();
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
      hideSkip: true,
      onFinish: () {
        if (_tapThroughFired || _skipFired) return;
        final lastStep = stepsToShow.last.value;
        if (lastStep.tapThrough && onTapThrough != null) {
          onTapThrough!(stepOffset + stepsToShow.length - 1);
          return;
        }
        onGroupFinished?.call();
      },
      onSkip: () {
        _skipFired = true;
        onSkip?.call(_currentStepIndex);
        return true;
      },
    );

    _tutorialCoachMark.show(context: context, rootOverlay: true);
    return true;
  }
}

/// Tooltip widget shown during guide steps.
class _GuideTooltip extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;
  final GuidePlayerTheme theme;

  const _GuideTooltip({
    required this.title,
    required this.description,
    required this.onNext,
    required this.onSkip,
    required this.theme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.subtleTextColor, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  theme.skipLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.subtleTextColor),
                ),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.primaryTextColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  isLast ? theme.doneLabel : theme.nextLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: theme.primaryTextColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
