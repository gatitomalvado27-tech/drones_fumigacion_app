import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drones_fumigacion_app/main.dart';

void main() {
  testWidgets('ProIcaro smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(estaAutorizado: false));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
