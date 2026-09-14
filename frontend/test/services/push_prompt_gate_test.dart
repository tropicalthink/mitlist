import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/push_prompt_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StreamController<void> actions;
  late int prompts;
  bool household = true;
  bool decided = false;
  bool systemGranted = false;

  PushPromptGate build() {
    return PushPromptGate(
      firstActions: actions.stream,
      hasHousehold: () => household,
      isDecided: () async => decided,
      hasSystemPermission: () async => systemGranted,
      showPrompt: () async {
        prompts++;
        decided = true;
      },
    )..start();
  }

  Future<void> act() async {
    actions.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    actions = StreamController<void>.broadcast();
    prompts = 0;
    household = true;
    decided = false;
    systemGranted = false;
  });

  tearDown(() => actions.close());

  test('prompts once on the first action inside a household', () async {
    final gate = build();
    await act();
    await act();
    expect(prompts, 1);
    await gate.dispose();
  });

  test('never prompts without a household', () async {
    final gate = build();
    household = false;
    await act();
    expect(prompts, 0);
    household = true;
    await act();
    expect(prompts, 1, reason: 'still armed until a household is selected');
    await gate.dispose();
  });

  test('stays quiet once the offer was answered', () async {
    decided = true;
    final gate = build();
    await act();
    expect(prompts, 0);
    await gate.dispose();
  });

  test('stays quiet when the OS already allows notifications', () async {
    systemGranted = true;
    final gate = build();
    await act();
    expect(prompts, 0);
    await gate.dispose();
  });

  test('a burst of actions does not stack prompts', () async {
    final completer = Completer<void>();
    var count = 0;
    final gate = PushPromptGate(
      firstActions: actions.stream,
      hasHousehold: () => true,
      isDecided: () async => false,
      hasSystemPermission: () async => false,
      showPrompt: () {
        count++;
        return completer.future;
      },
    )..start();
    actions
      ..add(null)
      ..add(null)
      ..add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(count, 1);
    completer.complete();
    await gate.dispose();
  });

  test('the store persists the decision across launches', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await PushPromptStore.isDecided(), isFalse);
    await PushPromptStore.markDecided();
    expect(await PushPromptStore.isDecided(), isTrue);
  });
}
