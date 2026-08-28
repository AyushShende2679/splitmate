import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget smoke', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('SplitMate'))));
    expect(find.text('SplitMate'), findsOneWidget);
  });
}
