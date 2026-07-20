import 'package:flutter_test/flutter_test.dart';
import 'package:mp3trim/main.dart';

void main() {
  testWidgets('Audio Trimmer smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AudioTrimmerApp());
    expect(find.text('Audio Trimmer'), findsWidgets);
  });
}
