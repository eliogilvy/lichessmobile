import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/view/user/leaderboard_screen.dart';
import 'package:lichess_mobile/src/view/user/leaderboard_widget.dart';

import '../../test_app.dart';
import '../../test_utils.dart';

class FakeClientFactory implements LichessClientFactory {
  @override
  http.Client call() {
    return MockClient((request) {
      if (request.url.path == '/api/player/top/1/standard') {
        return mockResponse(top1Response, 200);
      }
      return mockResponse('', 404);
    });
  }
}

void main() {
  group('LeaderboardWidget', () {
    testWidgets(
      'accessibility and basic info showing test',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final app = await buildTestApp(
          tester,
          home: Column(children: [LeaderboardWidget()]),
          overrides: [
            lichessClientFactoryProvider.overrideWithValue(FakeClientFactory()),
          ],
        );

        await tester.pumpWidget(app);

        await tester.pump(const Duration(milliseconds: 50));

        for (final name in [
          'Svetlana',
          'Marcel',
          'Anthony',
          'Patoulatchi',
          'Cerdan',
        ]) {
          expect(
            find.widgetWithText(LeaderboardListTile, name),
            findsOneWidget,
          );
        }

        // await meetsTapTargetGuideline(tester);

        // await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        // if (debugDefaultTargetPlatformOverride == TargetPlatform.android) {
        //   await expectLater(tester, meetsGuideline(textContrastGuideline));
        // }
        handle.dispose();
      },
      variant: kPlatformVariant,
    );
  });
}

const top1Response = '''
{"bullet":{"id":"svetlana","username":"Svetlana","perfs":{"bullet":{"rating":2340,"progress":0}},"patron":true},"blitz":{"id":"marcel","username":"Marcel","perfs":{"blitz":{"rating":2520,"progress":0}}},"rapid":{"id":"anthony","username":"Anthony","perfs":{"rapid":{"rating":2413,"progress":0}}},"classical":{"id":"patoulatchi","username":"Patoulatchi","perfs":{"classical":{"rating":2521,"progress":0}}},"ultraBullet":{"id":"cerdan","username":"Cerdan","perfs":{"ultraBullet":{"rating":2648,"progress":0}}}}
      ''';
