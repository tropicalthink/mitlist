import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/widgets/app_button.dart';
import 'package:mitlist/widgets/app_card.dart';
import 'package:mitlist/widgets/app_dialog.dart';
import 'package:mitlist/widgets/app_input.dart';
import 'package:mitlist/widgets/app_bottom_sheet.dart';
import 'package:mitlist/widgets/animated_strikethrough.dart';
import 'package:mitlist/widgets/chip.dart';
import 'package:mitlist/widgets/app_icon.dart';
import 'package:mitlist/widgets/odometer.dart';

void main() {
  setUpAll(() {});

  // ── AppButton ──────────────────────────────────────────────────────────

  group('AppButton', () {
    testWidgets('renders with text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Tap me', onPressed: () {}),
      ));
      expect(find.text('TAP ME'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Tap', onPressed: () => tapped = true),
      ));
      await tester.tap(find.text('TAP'));
      expect(tapped, isTrue);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Disabled'),
      ));
      await tester.tap(find.text('DISABLED'));
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Loading', isLoading: true, onPressed: () {}),
      ));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders with icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(
          text: 'With icon',
          icon: const Icon(Icons.add),
          onPressed: () {},
        ),
      ));
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('WITH ICON'), findsOneWidget);
    });

    testWidgets('renders all size variants', (tester) async {
      for (final size in AppButtonSize.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppButton(text: size.name, size: size, onPressed: () {}),
        ));
        expect(find.text(size.name.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('renders with tooltip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(
          text: 'Info',
          tooltip: 'Useful tip',
          onPressed: () {},
        ),
      ));
      expect(find.text('INFO'), findsOneWidget);
    });

    testWidgets('renders all color variants', (tester) async {
      for (final color in AppButtonColor.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppButton(
            text: color.name,
            color: color,
            onPressed: () {},
          ),
        ));
        expect(find.text(color.name.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('renders all variant types', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppButton(
            text: variant.name,
            variant: variant,
            onPressed: () {},
          ),
        ));
        final expectedText = variant == AppButtonVariant.solid ||
                variant == AppButtonVariant.outline
            ? variant.name.toUpperCase()
            : variant.name;
        expect(find.text(expectedText), findsOneWidget);
      }
    });
  });

  // ── AppCard ────────────────────────────────────────────────────────────

  group('AppCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppCard(
          child: const Text('Card content'),
        ),
      ));
      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('fires onTap when interactive', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: AppCard(
          interactive: true,
          onTap: () => tapped = true,
          child: const Text('Tap card'),
        ),
      ));
      await tester.tap(find.text('Tap card'));
      expect(tapped, isTrue);
    });

    testWidgets('renders all card variants', (tester) async {
      for (final variant in AppCardVariant.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppCard(
            variant: variant,
            child: Text('$variant card'),
          ),
        ));
        expect(find.text('$variant card'), findsOneWidget);
      }
    });

    testWidgets('renders all tints', (tester) async {
      for (final tint in AppCardTint.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppCard(
            tint: tint,
            child: Text('$tint tint'),
          ),
        ));
        expect(find.text('$tint tint'), findsOneWidget);
      }
    });

    testWidgets('renders all padding presets', (tester) async {
      for (final padding in AppCardPadding.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppCard(
            padding: padding,
            child: Text('$padding padding'),
          ),
        ));
        expect(find.text('$padding padding'), findsOneWidget);
      }
    });

    testWidgets('renders animated card', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppCard(
          animated: true,
          child: const Text('Animated'),
        ),
      ));
      expect(find.text('Animated'), findsOneWidget);
    });
  });

  // ── AppDialog / showAppDialog ──────────────────────────────────────────

  group('showAppDialog', () {
    testWidgets('shows dialog with title and body', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppDialog(
                context: context,
                title: 'Test Dialog',
                body: const Text('Dialog body'),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();

      expect(find.text('TEST DIALOG'), findsOneWidget);
      expect(find.text('Dialog body'), findsOneWidget);
    });

    testWidgets('shows dialog with custom actions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppDialog<bool>(
                context: context,
                title: 'Confirm',
                body: const Text('Are you sure?'),
                actions: [
                  AppButton(
                    text: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  AppButton(
                    text: 'Delete',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();

      expect(find.text('CONFIRM'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('DELETE'), findsOneWidget);
    });

    testWidgets('Cancel action pops with false', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAppDialog<bool>(
                  context: context,
                  title: 'Confirm',
                  body: const Text('Body'),
                  actions: [
                    AppButton(
                      text: 'Cancel',
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.tap(find.text('CANCEL'));
      await tester.pump();

      expect(result, isFalse);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppDialog(
                context: context,
                title: 'Dismiss',
                body: const Text('Body'),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('DISMISS'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('DISMISS'), findsNothing);
    });
  });

  // ── AppInput ───────────────────────────────────────────────────────────

  group('AppInput', () {
    Widget buildAppInput(AppInput input) {
      return MaterialApp(
        home: Scaffold(
          body: input,
        ),
      );
    }

    testWidgets('renders with label and hint', (tester) async {
      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Name',
          hint: 'Enter your name',
        ),
      ));
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('Enter your name'), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Name',
          controller: controller,
        ),
      ));

      await tester.enterText(find.byType(AppInput), 'Test user');
      expect(controller.text, 'Test user');
    });

    testWidgets('shows error text', (tester) async {
      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Name',
          errorText: 'Required field',
        ),
      ));
      expect(find.text('Required field'), findsOneWidget);
    });

    testWidgets('obscures password text when obscureText is true',
        (tester) async {
      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Password',
          obscureText: true,
        ),
      ));
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('shows clear button when clearable', (tester) async {
      final controller = TextEditingController(text: 'some text');
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Search',
          clearable: true,
          controller: controller,
        ),
      ));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('respects maxLength', (tester) async {
      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Bio',
          maxLength: 100,
          showCharCount: true,
        ),
      ));
      expect(find.text('0/100'), findsOneWidget);
    });

    testWidgets('renders helper text', (tester) async {
      await tester.pumpWidget(buildAppInput(
        AppInput(
          label: 'Email',
          helperText: 'We will never share your email',
        ),
      ));
      expect(find.text('We will never share your email'), findsOneWidget);
    });
  });

  // ── AppBottomSheet / showAppBottomSheet ────────────────────────────────

  group('showAppBottomSheet', () {
    testWidgets('renders with title and body', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppBottomSheet(
                context: context,
                title: 'Sheet Title',
                body: const Text('Sheet body'),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();

      expect(find.text('Sheet Title'), findsOneWidget);
      expect(find.text('Sheet body'), findsOneWidget);
    });
  });

  // ── AppIcon ────────────────────────────────────────────────────────────

  group('AppIcon', () {
    testWidgets('renders known icon name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppIcon(name: 'home'),
      ));
      expect(find.byIcon(Icons.home), findsOneWidget);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppIcon(name: 'plus', size: 32),
      ));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders without crashing for unknown name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppIcon(name: 'nonexistent'),
      ));
      expect(find.byType(AppIcon), findsOneWidget);
    });

    testWidgets('renders with custom color', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppIcon(name: 'trash', color: Colors.red),
      ));
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });

  // ── AppChip ────────────────────────────────────────────────────────────

  group('AppChip', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppChip(label: 'Filter', selected: false, onSelected: (_) {}),
      ));
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('fires onSelected when tapped', (tester) async {
      var selectedValue = false;
      await tester.pumpWidget(MaterialApp(
        home: AppChip(
          label: 'Tap me',
          selected: false,
          onSelected: (v) => selectedValue = v,
        ),
      ));
      await tester.tap(find.text('Tap me'));
      expect(selectedValue, isTrue);
    });

    testWidgets('toggles selected state', (tester) async {
      var selectedValue = false;
      await tester.pumpWidget(MaterialApp(
        home: AppChip(
          label: 'Toggle',
          selected: true,
          onSelected: (v) => selectedValue = v,
        ),
      ));
      await tester.tap(find.text('Toggle'));
      expect(selectedValue, isFalse);
    });

    testWidgets('renders with leading icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppChip(
          label: 'With icon',
          selected: false,
          leading: const Icon(Icons.star),
          onSelected: (_) {},
        ),
      ));
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  // ── AnimatedStrikethrough ─────────────────────────────────────────────

  group('AnimatedStrikethrough', () {
    testWidgets('renders the text', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AnimatedStrikethrough(
            text: 'Buy milk',
            struck: false,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ));
      expect(find.text('Buy milk'), findsOneWidget);
    });

    testWidgets('paints the strike when struck flips on', (tester) async {
      var struck = false;
      late StateSetter setOuterState;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return AnimatedStrikethrough(
                text: 'Buy milk',
                struck: struck,
                style: const TextStyle(fontSize: 16),
              );
            },
          ),
        ),
      ));
      CustomPaint paintOf() => tester.widget<CustomPaint>(find.ancestor(
            of: find.text('Buy milk'),
            matching: find.byType(CustomPaint),
          ).first);
      expect(paintOf().foregroundPainter, isNull);

      setOuterState(() => struck = true);
      await tester.pumpAndSettle();
      expect(paintOf().foregroundPainter, isNotNull);
    });

    testWidgets('strikes instantly with reduced motion', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AnimatedStrikethrough(
              text: 'Buy milk',
              struck: true,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ));
      await tester.pump();
      final paint = tester.widget<CustomPaint>(find.ancestor(
        of: find.text('Buy milk'),
        matching: find.byType(CustomPaint),
      ).first);
      expect(paint.foregroundPainter, isNotNull);
    });
  });

  // ── MitlistOdometer ───────────────────────────────────────────────────

  group('MitlistOdometer', () {
    testWidgets('renders every digit of the value without overflow errors',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MitlistOdometer(
            value: 42,
            textStyle: TextStyle(fontSize: 24),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Each wheel renders 0-9; the value's digits must be present.
      expect(find.text('4'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rolls to a new value without overflow errors',
        (tester) async {
      var value = 8;
      late StateSetter setOuterState;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return MitlistOdometer(
                value: value,
                textStyle: const TextStyle(fontSize: 24),
              );
            },
          ),
        ),
      ));
      setOuterState(() => value = 12);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
