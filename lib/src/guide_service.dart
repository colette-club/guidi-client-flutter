import 'guidi_client.dart';
import 'models/guide.dart';
import 'models/guide_state.dart';

class GuideService {
  final GuidiClient _client;
  final List<Guide> _guides;
  String? _userId;
  GuideState? _cachedState;

  GuideService({required GuidiClient client, required List<Guide> guides})
      : _client = client,
        _guides = guides;

  /// All registered guides.
  List<Guide> get guides => _guides;

  void setUserId(String userId) {
    if (_userId != userId) {
      _cachedState = null;
    }
    _userId = userId;
    _ensureState();
  }

  Future<void> _ensureState() async {
    if (_cachedState != null || _userId == null) return;
    try {
      _cachedState = await _client.getGuideState(_userId!);
    } catch (_) {}
  }

  /// Whether the backend state has been successfully loaded.
  bool get isReady => _cachedState != null;

  Future<bool> hasSeenGuide(String guideId) async {
    await _ensureState();
    if (_cachedState == null) return true;
    return _cachedState!.hasSeen(guideId);
  }

  Future<void> markGuideSeen(String guideId, {required int completedSteps, required int totalSteps, required bool skipped}) async {
    if (_userId == null) return;
    try {
      _cachedState = await _client.markGuideSeen(
        userId: _userId!,
        guideId: guideId,
        completedSteps: completedSteps,
        totalSteps: totalSteps,
        skipped: skipped,
      );
    } catch (_) {}
  }

  Future<void> markGuideNotApplicable(String guideId) async {
    if (_userId == null) return;
    try {
      _cachedState = await _client.markGuideNotApplicable(userId: _userId!, guideId: guideId);
    } catch (_) {}
  }

  Future<void> resetGuide(String guideId) async {
    if (_userId == null) return;
    try {
      _cachedState = await _client.resetGuide(userId: _userId!, guideId: guideId);
    } catch (_) {}
  }

  /// Get guides that start on a given screen, sorted by priority.
  List<Guide> guidesForScreen(String screen) {
    return _guides.where((g) => g.startScreen == screen).toList()..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Find a guide by ID.
  Guide? findById(String id) {
    for (final g in _guides) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Get unseen guides that start on the given screen, sorted by priority.
  Future<List<Guide>> unseenForScreen(String screen) async {
    await _ensureState();
    final screenGuides = guidesForScreen(screen);
    final unseen = <Guide>[];
    for (final guide in screenGuides) {
      if (!await hasSeenGuide(guide.id)) {
        unseen.add(guide);
      }
    }
    return unseen;
  }

  Future<void> resetAllGuides() async {
    if (_userId == null) return;
    try {
      _cachedState = await _client.resetAllGuides(_userId!);
    } catch (_) {}
  }
}
