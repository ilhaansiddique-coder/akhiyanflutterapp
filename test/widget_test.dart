import 'package:akhiyan_admin/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots and shows the login screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AkhiyanAdminApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akhiyan Admin'), findsOneWidget);
    expect(find.text('Store Management'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });
}
