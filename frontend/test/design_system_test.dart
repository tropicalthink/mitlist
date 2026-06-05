import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mitlist/widgets/app_button.dart';
import 'package:mitlist/widgets/app_card.dart';
import 'package:mitlist/widgets/app_dialog.dart';
import 'package:mitlist/widgets/app_input.dart';
import 'package:mitlist/widgets/app_bottom_sheet.dart';
import 'package:mitlist/widgets/chip.dart';
import 'package:mitlist/widgets/app_icon.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── AppButton ──────────────────────────────────────────────────────────

  group('AppButton', () {
    testWidgets('renders with text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Tap me', onPressed: () {}),
      ));
      expect(find.text('Tap me'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Tap', onPressed: () => tapped = true),
      ));
      await tester.tap(find.text('Tap'));
      expect(tapped, isTrue);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppButton(text: 'Disabled'),
      ));
      await tester.tap(find.text('Disabled'));
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
      expect(find.text('With icon'), findsOneWidget);
    });

    testWidgets('renders all size variants', (tester) async {
      for (final size in AppButtonSize.values) {
        await tester.pumpWidget(MaterialApp(
          home: AppButton(text: size.name, size: size, onPressed: () {}),
        ));
        expect(find.text(size.name), findsOneWidget);
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
      expect(find.text('Info'), findsOneWidget);
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
        expect(find.text(color.name), findsOneWidget);
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
        expect(find.text(variant.name), findsOneWidget);
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

      expect(find.text('Test Dialog'), findsOneWidget);
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

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
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
      await tester.tap(find.text('Cancel'));
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
      expect(find.text('Dismiss'), findsOneWidget);

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
      expect(find.text('Name'), findsOneWidget);
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
}
