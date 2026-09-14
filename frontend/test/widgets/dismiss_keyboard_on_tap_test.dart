import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/widgets/dismiss_keyboard_on_tap.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required FocusNode node,
    VoidCallback? onButton,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DismissKeyboardOnTap(
            child: Column(
              children: [
                TextField(
                  focusNode: node,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                TextButton(
                  onPressed: onButton,
                  child: const Text('Pin it'),
                ),
                // Empty space, like the cork between two notes on the hub.
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a tap on empty space drops focus from a multiline field',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpField(tester, node: node);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tapAt(tester.getCenter(find.byType(SizedBox).last));
    await tester.pump();
    expect(node.hasFocus, isFalse);
  });

  testWidgets('tappable children keep their own taps', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var pressed = 0;
    await pumpField(tester, node: node, onButton: () => pressed++);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tap(find.text('Pin it'));
    await tester.pump();
    expect(pressed, 1);
    // The button owned that tap: the wrapper did not also blur the field.
    expect(node.hasFocus, isTrue);
  });
}
