import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/scoring_banner.dart';

void main() {
  testWidgets('B3 muestra el sistema 5 / 3 / +1', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScoringBanner())),
    );
    expect(find.textContaining('5 pts'), findsOneWidget);
    expect(find.textContaining('3 pts'), findsOneWidget);
    expect(find.textContaining('+1 pt'), findsOneWidget);
  });
}
