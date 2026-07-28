import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3trim/main.dart';

void main() {
  testWidgets('Audio Trimmer smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AudioTrimmerApp());
    expect(find.text('Audio Trimmer'), findsWidgets);
  });

  testWidgets('trim save control starts with prompt and no pencil icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AudioTrimmerApp());

    expect(find.text('Choose a file to trim.'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.byIcon(Icons.drive_file_rename_outline), findsNothing);
  });
}
