import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('wanti'))));
    expect(find.text('wanti'), findsOneWidget);
  });
}
