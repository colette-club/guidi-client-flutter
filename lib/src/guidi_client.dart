import 'dart:convert';

import 'package:http/http.dart' as http;

import 'guidi_exception.dart';
import 'models/guide_state.dart';

class GuidiClient {
  final String url;
  final String apiKey;
  final http.Client _httpClient;

  GuidiClient({
    required this.url,
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<GuideState> getGuideState(String userId) async {
    const query = '''
      query GuideState(\$userId: String!) {
        guideState(userId: \$userId) {
          guides {
            guideId
            completedSteps
            totalSteps
            skipped
            completedAt
          }
        }
      }
    ''';
    final data = await _request(query, {'userId': userId});
    return GuideState.fromJson(data['guideState'] as Map<String, dynamic>);
  }

  Future<GuideState> markGuideSeen({
    required String userId,
    required String guideId,
    required int completedSteps,
    required int totalSteps,
    required bool skipped,
  }) async {
    const query = '''
      mutation MarkGuideSeen(\$userId: String!, \$guideId: String!, \$completedSteps: Int!, \$totalSteps: Int!, \$skipped: Boolean!) {
        markGuideSeen(userId: \$userId, guideId: \$guideId, completedSteps: \$completedSteps, totalSteps: \$totalSteps, skipped: \$skipped) {
          guides {
            guideId
            completedSteps
            totalSteps
            skipped
            completedAt
          }
        }
      }
    ''';
    final data = await _request(query, {
      'userId': userId,
      'guideId': guideId,
      'completedSteps': completedSteps,
      'totalSteps': totalSteps,
      'skipped': skipped,
    });
    return GuideState.fromJson(data['markGuideSeen'] as Map<String, dynamic>);
  }

  Future<GuideState> resetGuide({
    required String userId,
    required String guideId,
  }) async {
    const query = '''
      mutation ResetGuide(\$userId: String!, \$guideId: String!) {
        resetGuide(userId: \$userId, guideId: \$guideId) {
          guides {
            guideId
            completedSteps
            totalSteps
            skipped
            completedAt
          }
        }
      }
    ''';
    final data = await _request(query, {'userId': userId, 'guideId': guideId});
    return GuideState.fromJson(data['resetGuide'] as Map<String, dynamic>);
  }

  Future<GuideState> resetAllGuides(String userId) async {
    const query = '''
      mutation ResetAllGuides(\$userId: String!) {
        resetAllGuides(userId: \$userId) {
          guides {
            guideId
            completedSteps
            totalSteps
            skipped
            completedAt
          }
        }
      }
    ''';
    final data = await _request(query, {'userId': userId});
    return GuideState.fromJson(data['resetAllGuides'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _request(String query, Map<String, dynamic> variables) async {
    final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      );
    } catch (e) {
      throw GuidiException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw GuidiException(response.body, statusCode: response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body.containsKey('errors')) {
      final errors = body['errors'] as List<dynamic>;
      final message = (errors.first as Map<String, dynamic>)['message'] as String;
      throw GuidiException(message);
    }

    return body['data'] as Map<String, dynamic>;
  }
}
