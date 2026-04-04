import 'guide_progress.dart';

class GuideState {
  final List<GuideProgress> guides;

  const GuideState({required this.guides});

  factory GuideState.fromJson(Map<String, dynamic> json) {
    final guidesJson = json['guides'] as List<dynamic>;
    return GuideState(
      guides: guidesJson.map((g) => GuideProgress.fromJson(g as Map<String, dynamic>)).toList(),
    );
  }

  /// Check if a guide has been seen.
  bool hasSeen(String guideId) => guides.any((g) => g.guideId == guideId);

  @override
  String toString() => 'GuideState(guides: $guides)';
}
