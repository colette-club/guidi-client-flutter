import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guidi_client/guidi_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const apiUrl = 'https://guidi.example.com/api/graphql';
  const apiKey = 'test-api-key';

  final sampleGuideState = {
    'guides': [
      {
        'guideId': 'welcome_v1',
        'completedSteps': 11,
        'totalSteps': 11,
        'skipped': false,
        'completedAt': '2026-04-04T12:00:00Z',
      },
    ],
  };

  MockClient mockClientWithResponse(String dataKey) {
    return MockClient((request) async {
      expect(request.url.toString(), apiUrl);
      expect(request.headers['Authorization'], 'Bearer $apiKey');
      expect(request.headers['Content-Type'], 'application/json');

      return http.Response(
        jsonEncode({'data': {dataKey: sampleGuideState}}),
        200,
      );
    });
  }

  group('GuidiClient', () {
    test('getGuideState returns parsed state', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: mockClientWithResponse('guideState'),
      );

      final state = await client.getGuideState('user-123');

      expect(state.guides, hasLength(1));
      expect(state.guides.first.guideId, 'welcome_v1');
      expect(state.guides.first.completedSteps, 11);
      expect(state.guides.first.totalSteps, 11);
      expect(state.guides.first.skipped, false);
      expect(state.hasSeen('welcome_v1'), true);
      expect(state.hasSeen('filters_v1'), false);
    });

    test('markGuideSeen sends correct variables', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final variables = body['variables'] as Map<String, dynamic>;
          expect(variables['userId'], 'user-123');
          expect(variables['guideId'], 'welcome_v1');
          expect(variables['completedSteps'], 5);
          expect(variables['totalSteps'], 11);
          expect(variables['skipped'], true);

          return http.Response(
            jsonEncode({'data': {'markGuideSeen': sampleGuideState}}),
            200,
          );
        }),
      );

      final state = await client.markGuideSeen(
        userId: 'user-123',
        guideId: 'welcome_v1',
        completedSteps: 5,
        totalSteps: 11,
        skipped: true,
      );

      expect(state.guides, hasLength(1));
    });

    test('resetGuide returns parsed state', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: mockClientWithResponse('resetGuide'),
      );

      final state = await client.resetGuide(userId: 'user-123', guideId: 'welcome_v1');

      expect(state.guides, hasLength(1));
    });

    test('resetAllGuides returns parsed state', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: mockClientWithResponse('resetAllGuides'),
      );

      final state = await client.resetAllGuides('user-123');

      expect(state.guides, hasLength(1));
    });

    test('throws GuidiException on HTTP error', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: MockClient((request) async {
          return http.Response('Unauthorized', 401);
        }),
      );

      expect(
        () => client.getGuideState('user-123'),
        throwsA(isA<GuidiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Unauthorized')),
      );
    });

    test('throws GuidiException on GraphQL error', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'errors': [
                {'message': 'User not found'}
              ]
            }),
            200,
          );
        }),
      );

      expect(
        () => client.getGuideState('user-123'),
        throwsA(isA<GuidiException>().having((e) => e.message, 'message', 'User not found')),
      );
    });

    test('throws GuidiException on network error', () async {
      final client = GuidiClient(
        url: apiUrl,
        apiKey: apiKey,
        httpClient: MockClient((request) async {
          throw Exception('Connection refused');
        }),
      );

      expect(
        () => client.getGuideState('user-123'),
        throwsA(isA<GuidiException>().having((e) => e.message, 'message', contains('Network error'))),
      );
    });
  });

  group('GuideState', () {
    test('hasSeen returns true for existing guide', () {
      final state = GuideState.fromJson(sampleGuideState);
      expect(state.hasSeen('welcome_v1'), true);
    });

    test('hasSeen returns false for unknown guide', () {
      final state = GuideState.fromJson(sampleGuideState);
      expect(state.hasSeen('unknown'), false);
    });

    test('empty state', () {
      final state = GuideState.fromJson({'guides': []});
      expect(state.guides, isEmpty);
      expect(state.hasSeen('welcome_v1'), false);
    });
  });
}
