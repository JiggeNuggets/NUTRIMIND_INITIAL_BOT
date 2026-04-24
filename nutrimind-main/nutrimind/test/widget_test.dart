// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/models/report_model.dart';
import 'package:nutrimind/models/weekly_stats_model.dart';
import 'package:nutrimind/services/engagement_service.dart';

// This test is intentionally simple and does NOT touch Firebase/Database.
// It just verifies that a basic widget tree can build.

void main() {
  testWidgets('basic widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('NutriMind test')),
        ),
      ),
    );

    expect(find.text('NutriMind test'), findsOneWidget);
  });

  test('week id uses Monday as the week start', () {
    expect(EngagementService.weekIdFor(DateTime(2026, 4, 23)), '2026-04-20');
    expect(EngagementService.weekIdFor(DateTime(2026, 4, 20)), '2026-04-20');
    expect(EngagementService.weekIdFor(DateTime(2026, 4, 26)), '2026-04-20');
  });

  test('weekly stats model preserves real activity counters', () {
    final stats = WeeklyStatsModel(
      uid: 'uid-1',
      displayName: 'User One',
      weekId: '2026-04-20',
      mealsLogged: 2,
      scannedMeals: 1,
      postsCreated: 1,
      commentsCreated: 3,
      recipesSaved: 1,
      budgetFriendlyMeals: 2,
      points: 78,
      updatedAt: DateTime(2026, 4, 23),
    );

    final roundTrip = WeeklyStatsModel.fromMap(stats.toMap());

    expect(roundTrip.uid, 'uid-1');
    expect(roundTrip.weekId, '2026-04-20');
    expect(roundTrip.mealsLogged, 2);
    expect(roundTrip.scannedMeals, 1);
    expect(roundTrip.points, 78);
  });

  test('report model can use reporter id as report document id', () {
    final report = ReportModel(
      reportId: '',
      postId: 'post-1',
      postOwnerId: 'owner-1',
      reporterId: 'reporter-1',
      reporterName: 'Reporter',
      reason: 'Spam',
      createdAt: DateTime(2026, 4, 23),
    ).copyWith(reportId: 'reporter-1');

    expect(report.reportId, report.reporterId);
    expect(report.toMap()['status'], 'open');
  });
}
