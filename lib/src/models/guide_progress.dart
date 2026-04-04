class GuideProgress {
  final String guideId;
  final int completedSteps;
  final int totalSteps;
  final bool skipped;
  final bool notApplicable;
  final DateTime completedAt;

  const GuideProgress({
    required this.guideId,
    required this.completedSteps,
    required this.totalSteps,
    required this.skipped,
    this.notApplicable = false,
    required this.completedAt,
  });

  factory GuideProgress.fromJson(Map<String, dynamic> json) {
    return GuideProgress(
      guideId: json['guideId'] as String,
      completedSteps: json['completedSteps'] as int,
      totalSteps: json['totalSteps'] as int,
      skipped: json['skipped'] as bool,
      notApplicable: json['notApplicable'] as bool? ?? false,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  @override
  String toString() =>
      'GuideProgress(guideId: $guideId, completedSteps: $completedSteps, totalSteps: $totalSteps, skipped: $skipped, notApplicable: $notApplicable)';
}
