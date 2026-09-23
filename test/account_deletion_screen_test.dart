import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/features/home/presentation/screens/account_deletion_screen.dart';

void main() {
  testWidgets('deletion requires loaded options, password and explicit confirmation', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: AccountDeletionScreen(
      loadOptions: () async => {'ministries': <dynamic>[]},
      submit: (password, successors) async { expect(password, 'test'); calls++; },
    )));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Excluir minha conta');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'test');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile)); await tester.pump();
    await tester.ensureVisible(button); await tester.tap(button); await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });
  testWidgets('small viewport, large text and loading failure remain recoverable', (tester) async {
    tester.view.physicalSize = const Size(320, 640); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var failed = true;
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)), child: child!),
      home: AccountDeletionScreen(loadOptions: () async {
        if (failed) throw StateError('offline');
        return {'ministries': <dynamic>[]};
      })));
    await tester.pumpAndSettle();
    final retry = find.text('Tentar novamente');
    await tester.scrollUntilVisible(retry, 250, scrollable: find.byType(Scrollable).first);
    failed = false; await tester.tap(retry); await tester.pumpAndSettle();
    expect(retry, findsNothing); expect(tester.takeException(), isNull);
  });
}
