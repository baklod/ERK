import 'package:controller/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts on the boat controller', (tester) async {
    await tester.pumpWidget(const BoatApp());

    expect(find.text('ERK'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('CONVEYOR'), findsOneWidget);
    expect(find.text('E-STOP'), findsOneWidget);
    expect(find.text('Connect Wi-Fi'), findsNothing);
  });
}
