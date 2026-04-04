import 'package:flutter/widgets.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

enum GuideAudience { newUser, returningUser, all }

class GuideStep {
  final String screen;
  final GlobalKey targetKey;
  final String Function(dynamic l10n) titleResolver;
  final String Function(dynamic l10n) descResolver;
  final ContentAlign contentAlign;

  /// When true, the user can tap through the overlay onto the target widget.
  /// The guide pauses after this step so the caller can wait for the
  /// resulting interaction (e.g. a bottom sheet) to finish before resuming.
  final bool tapThrough;

  GuideStep({
    required this.screen,
    required this.targetKey,
    required this.titleResolver,
    required this.descResolver,
    this.contentAlign = ContentAlign.bottom,
    this.tapThrough = false,
  });
}

class Guide {
  final String id;
  final int priority;
  final String startScreen;
  final GuideAudience audience;
  final String Function(dynamic l10n) titleResolver;
  final String Function(dynamic l10n) descResolver;
  final IconData icon;
  final List<GuideStep> steps;

  Guide({
    required this.id,
    required this.priority,
    required this.startScreen,
    this.audience = GuideAudience.all,
    required this.titleResolver,
    required this.descResolver,
    required this.icon,
    required this.steps,
  });

  /// Groups consecutive steps by screen.
  /// e.g. [home, profile, profile, home, home] -> [[home], [profile, profile], [home, home]]
  List<List<GuideStep>> get stepGroups {
    if (steps.isEmpty) return [];
    final groups = <List<GuideStep>>[];
    var currentGroup = <GuideStep>[steps.first];
    for (var i = 1; i < steps.length; i++) {
      if (steps[i].screen == steps[i - 1].screen) {
        currentGroup.add(steps[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = [steps[i]];
      }
    }
    groups.add(currentGroup);
    return groups;
  }

  /// Returns the step offset for a given group index (number of steps before this group).
  int stepOffsetForGroup(int groupIndex) {
    final groups = stepGroups;
    var offset = 0;
    for (var i = 0; i < groupIndex && i < groups.length; i++) {
      offset += groups[i].length;
    }
    return offset;
  }
}
