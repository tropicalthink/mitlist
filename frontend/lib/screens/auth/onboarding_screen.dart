import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../sheets/join_household_sheet.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/invite_link.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_currency_dropdown.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/board/cork_board.dart';

/// First run, staged as the app's own metaphor: one cork board, three beats.
///
/// 1. Choose — a fresh sticky note ("create") and a torn paper slip ("join")
///    drop onto the board and settle with a spring wobble.
/// 2. Name — the household name is written directly on the sticky note and
///    pinned to the board. No detour through a generic form sheet.
/// 3. Invite — a slip with the invite code (and its QR) is torn off for the
///    rest of the house; the board the user just dressed becomes their hub.
///
/// Under reduced motion every beat is simply already in place.
enum _Stage { choose, name, invite }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // One master timeline; each element owns an interval of it. Springs are
  // expressed as curves so the whole entrance is a single ticker (no timers,
  // deterministic under test, trivially skippable for reduced motion).
  late final Animation<double> _headerT;
  late final Animation<double> _createT;
  late final Animation<double> _joinT;

  // Landing haptics fire once per note as its spring first reaches rest.
  static const double _createLandsAt = 0.66;
  static const double _joinLandsAt = 0.84;
  bool _createLanded = false;
  bool _joinLanded = false;
  bool _didStart = false;

  _Stage _stage = _Stage.choose;

  // Name beat.
  final _nameController = TextEditingController();
  String? _currency;
  bool _isCreating = false;
  String? _createError;

  // Invite beat.
  Group? _createdGroup;
  GroupInvite? _invite;
  bool _inviteLoading = false;
  String? _inviteError;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _headerT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.22, curve: MitlistAnimations.easeEnter),
    );
    _createT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.72, curve: SettleCurve()),
    );
    _joinT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.90, curve: SettleCurve()),
    );

    _controller.addListener(_onTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAnimation();
      unawaited(_checkExistingGroups());
    });
  }

  void _onTick() {
    final v = _controller.value;
    if (!_createLanded && v >= _createLandsAt) {
      _createLanded = true;
      unawaited(Haptics.light());
    }
    if (!_joinLanded && v >= _joinLandsAt) {
      _joinLanded = true;
      unawaited(Haptics.light());
    }
  }

  Future<void> _checkExistingGroups() async {
    try {
      final groups = await ref
          .read(cachedGroupsProvider.future)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      // Only skip onboarding when the user already belongs to a shared
      // household, and only while they haven't started dressing the board.
      final hasHousehold = groups.any((g) => g.isPersonal == false);
      if (hasHousehold && _stage == _Stage.choose) {
        context.goNamed('home');
      }
    } catch (_) {
      // API slow/unavailable — keep onboarding visible so the user can proceed.
    }
  }

  void _startAnimation() {
    if (_didStart) return;
    _didStart = true;
    if (MediaQuery.of(context).disableAnimations) {
      _createLanded = true;
      _joinLanded = true;
      _controller.value = 1.0;
    } else {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _nameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── Stage transitions ──────────────────────────────────────────────────────

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _toStage(_Stage stage) {
    if (_stage == stage) return;
    setState(() => _stage = stage);
  }

  void _onCreateHousehold() {
    unawaited(Haptics.light());
    _currency ??= _defaultCurrency(context);
    _toStage(_Stage.name);
  }

  Future<void> _onJoinHousehold() async {
    unawaited(Haptics.light());
    final group = await JoinHouseholdSheet.show(context);
    if (group != null && mounted) {
      unawaited(ref.read(currentGroupIdProvider.notifier).set(group.id));
      context.goNamed('home');
    }
  }

  /// Best-guess currency from the device locale, clamped to the supported set.
  String _defaultCurrency(BuildContext context) {
    const supported = {
      'USD',
      'EUR',
      'GBP',
      'JPY',
      'CAD',
      'AUD',
      'CHF',
      'SEK',
      'NOK',
      'DKK',
      'PLN',
      'CZK',
      'HUF',
    };
    try {
      final locale = Localizations.localeOf(context).toString();
      final code = NumberFormat.simpleCurrency(locale: locale).currencyName;
      if (code != null && supported.contains(code)) return code;
    } catch (_) {}
    return 'USD';
  }

  bool get _canPin => _nameController.text.trim().isNotEmpty && !_isCreating;

  Future<void> _pinHousehold() async {
    if (!_canPin) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isCreating = true;
      _createError = null;
    });

    try {
      final service = await ref.read(groupServiceProviderAsync.future);
      final group = await service.createGroup(CreateGroupRequest(
        name: _nameController.text.trim(),
        currency: _currency ?? 'USD',
      ));
      // The cached household list must be refetched before any screen
      // resolves its active group against it — without this the new group is
      // missing from the cache and the hub lands on "no household".
      // Seed the cache with the household the server just handed us, then
      // refresh. Seeding first means the new household is present even if the
      // refetch fails — no screen should land on "no household" for one that
      // demonstrably exists.
      await refreshCachedGroups(ref, ensure: group);
      if (!mounted) return;
      unawaited(ref.read(currentGroupIdProvider.notifier).set(group.id));
      unawaited(Haptics.success());
      setState(() {
        _isCreating = false;
        _createdGroup = group;
      });
      _toStage(_Stage.invite);
      unawaited(_generateInvite());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError = friendlyErrorMessage(e, l10n);
      });
    }
  }

  Future<void> _generateInvite() async {
    final group = _createdGroup;
    if (group == null) return;
    setState(() {
      _inviteLoading = true;
      _inviteError = null;
      _copied = false;
    });
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final invite = await svc.inviteMember(
        group.id,
        const InviteMemberRequest(role: 'member'),
      );
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _inviteLoading = false;
      });
      unawaited(Haptics.light());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inviteError = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _inviteLoading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    final code = _invite?.code;
    if (code == null || code.trim().isEmpty || _copied) return;
    try {
      await Clipboard.setData(ClipboardData(text: code.trim()));
    } catch (_) {
      return; // Clipboard unavailable; silently ignore.
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _goToBoard() {
    unawaited(Haptics.light());
    context.goNamed('home');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CorkBoardBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final noteWidth = math.min(400.0, constraints.maxWidth * 0.86);
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MitlistSpacing.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BoardDrop(
                              t: _headerT,
                              tilt: 0.010,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: _header(l10n),
                                ),
                              ),
                            ),
                            const SizedBox(height: MitlistSpacing.space8),
                            AnimatedSwitcher(
                              duration: _reduceMotion
                                  ? Duration.zero
                                  : MitlistAnimations.medium,
                              switchInCurve: MitlistAnimations.easeEnter,
                              switchOutCurve: MitlistAnimations.easeExit,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, -0.05),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_stage),
                                child: switch (_stage) {
                                  _Stage.choose =>
                                    _chooseStage(l10n, noteWidth),
                                  _Stage.name => _nameStage(l10n, noteWidth),
                                  _Stage.invite =>
                                    _inviteStage(l10n, noteWidth),
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The headline, written on a strip of paper taped to the board. The paper
  /// stays; the words on it are rewritten as the beats advance.
  Widget _header(AppLocalizations l10n) {
    final (title, body) = switch (_stage) {
      _Stage.choose => (
          l10n.authOnboardingSetupHome,
          l10n.authOnboardingCreateOrJoin,
        ),
      _Stage.name => (
          l10n.authOnboardingNameTitle,
          l10n.authOnboardingNameBody,
        ),
      _Stage.invite => (
          l10n.authOnboardingInviteTitle,
          l10n.authOnboardingInviteBody,
        ),
    };

    return TapedPaper(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.lg,
        MitlistSpacing.space5,
        MitlistSpacing.lg,
        MitlistSpacing.lg,
      ),
      child: AnimatedSwitcher(
        duration: _reduceMotion ? Duration.zero : MitlistAnimations.medium,
        child: Column(
          key: ValueKey(_stage),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: MitlistColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: MitlistSpacing.space2),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MitlistColors.textPrimary.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Beat 1: choose ─────────────────────────────────────────────────────────

  Widget _chooseStage(AppLocalizations l10n, double noteWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: noteWidth,
            child: BoardDrop(
              t: _createT,
              tilt: -0.040,
              child: BoardPressable(
                semanticLabel: l10n.authOnboardingCreateHousehold,
                onTap: _onCreateHousehold,
                child: _ChoiceNote(
                  title: l10n.authOnboardingCreateHousehold,
                  body: l10n.authOnboardingCreateDesc,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: MitlistSpacing.space7),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: noteWidth,
            child: BoardDrop(
              t: _joinT,
              tilt: 0.032,
              child: BoardPressable(
                semanticLabel: l10n.authOnboardingJoinSemantic,
                onTap: _onJoinHousehold,
                child: _JoinSlip(
                  title: l10n.authOnboardingJoinInvite,
                  body: l10n.authOnboardingJoinDesc,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Beat 2: name ───────────────────────────────────────────────────────────

  Widget _nameStage(AppLocalizations l10n, double noteWidth) {
    final ink = stickyNoteInk(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: math.max(noteWidth, 320.0),
            child: Transform.rotate(
              angle: -0.018,
              child: StickyNoteSurface(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.lg,
                  MitlistSpacing.space6,
                  MitlistSpacing.lg,
                  MitlistSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInput(
                      label: l10n.sheetCreateHouseholdName,
                      hint: l10n.sheetCreateHouseholdNameHint,
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _pinHousehold(),
                    ),
                    const SizedBox(height: MitlistSpacing.space3),
                    AppCurrencyDropdown(
                      value: _currency ?? 'USD',
                      onChanged: _isCreating
                          ? null
                          : (v) {
                              if (v != null) setState(() => _currency = v);
                            },
                    ),
                    const SizedBox(height: MitlistSpacing.space4),
                    if (_createError != null) ...[
                      AppAlert(
                        type: AppAlertType.error,
                        message: _createError!,
                      ),
                      const SizedBox(height: MitlistSpacing.space3),
                    ],
                    AppButton(
                      variant: AppButtonVariant.solid,
                      color: AppButtonColor.primary,
                      size: AppButtonSize.lg,
                      text: l10n.authOnboardingPinIt,
                      isLoading: _isCreating,
                      onPressed: _canPin ? _pinHousehold : null,
                    ),
                    const SizedBox(height: MitlistSpacing.space2),
                    Align(
                      alignment: Alignment.centerRight,
                      child:
                          Icon(Icons.push_pin_outlined, size: 18, color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: MitlistSpacing.space4),
        AppButton(
          variant: AppButtonVariant.ghost,
          color: AppButtonColor.neutral,
          text: l10n.commonBack,
          onPressed: _isCreating ? null : () => _toStage(_Stage.choose),
        ),
      ],
    );
  }

  // ── Beat 3: invite ─────────────────────────────────────────────────────────

  Widget _inviteStage(AppLocalizations l10n, double noteWidth) {
    final code = _invite?.code ?? '';
    final parts =
        code.trim().isEmpty ? const <String>[] : code.trim().split('-');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: math.max(noteWidth, 320.0),
            child: Transform.rotate(
              angle: 0.022,
              child: TornSlip(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.lg,
                  MitlistSpacing.space6,
                  MitlistSpacing.lg,
                  MitlistSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_createdGroup != null) ...[
                      Text(
                        _createdGroup!.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: MitlistColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: MitlistSpacing.space4),
                    ],
                    if (_inviteError != null) ...[
                      AppAlert(
                        type: AppAlertType.error,
                        message: _inviteError!,
                      ),
                      const SizedBox(height: MitlistSpacing.space3),
                      AppButton(
                        variant: AppButtonVariant.outline,
                        color: AppButtonColor.neutral,
                        text: l10n.commonRetry,
                        onPressed: _generateInvite,
                      ),
                    ] else ...[
                      Center(
                        child: _inviteLoading && _invite == null
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: MitlistSpacing.xl,
                                ),
                                child: CircularProgressIndicator(),
                              )
                            : Semantics(
                                label: l10n.inviteCodeLabel(code.trim()),
                                child: Wrap(
                                  spacing: MitlistSpacing.space2,
                                  runSpacing: MitlistSpacing.space2,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (final part in parts)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: MitlistSpacing.space3,
                                          vertical: MitlistSpacing.space2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MitlistColors.surfaceSecondary,
                                          border: Border.all(
                                            color: MitlistColors.borderPrimary,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          part.toUpperCase(),
                                          style: MitlistTypography.monoBody(
                                            color: MitlistColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      if (code.isNotEmpty) ...[
                        const SizedBox(height: MitlistSpacing.space4),
                        Center(
                          child: Semantics(
                            label: l10n.inviteQrSemantic,
                            child: QrImageView(
                              data: buildWebInviteLink(code),
                              version: QrVersions.auto,
                              size: 132,
                              backgroundColor: Colors.transparent,
                              eyeStyle: const QrEyeStyle(
                                color: MitlistColors.textPrimary,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                color: MitlistColors.textPrimary,
                              ),
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              errorStateBuilder: (context, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        AppButton(
                          variant: AppButtonVariant.solid,
                          color: AppButtonColor.primary,
                          text: l10n.sheetInviteShare,
                          icon: const AppIcon(name: 'share', size: 18),
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: inviteShareText(code, l10n),
                            ),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space2),
                        AppButton(
                          key: ValueKey(_copied),
                          text: _copied
                              ? l10n.sheetInviteCopied
                              : l10n.sheetInviteCopy,
                          icon: _copied
                              ? const AppIcon(name: 'checkCircle', size: 18)
                              : const AppIcon(name: 'copy', size: 18),
                          onPressed: _copyCode,
                          variant: _copied
                              ? AppButtonVariant.solid
                              : AppButtonVariant.outline,
                          color: _copied
                              ? AppButtonColor.success
                              : AppButtonColor.neutral,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: MitlistSpacing.space6),
        AppButton(
          variant: AppButtonVariant.solid,
          color: AppButtonColor.primary,
          size: AppButtonSize.lg,
          text: l10n.authOnboardingGoToBoard,
          onPressed: _goToBoard,
        ),
      ],
    );
  }
}

// ─── Choose-beat board objects ────────────────────────────────────────────────

/// "Create a household": a fresh sticky note held by a pushpin.
class _ChoiceNote extends StatelessWidget {
  const _ChoiceNote({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ink = stickyNoteInk(context);

    return StickyNoteSurface(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.lg,
        MitlistSpacing.space6,
        MitlistSpacing.lg,
        MitlistSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: MitlistSpacing.space2),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ink.withValues(alpha: 0.82),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: MitlistSpacing.space3),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.arrow_forward, size: 20, color: ink),
          ),
        ],
      ),
    );
  }
}

/// "Join with invite": a slip of paper torn off a note, pinned at one corner,
/// with a blank code field waiting to be filled.
class _JoinSlip extends StatelessWidget {
  const _JoinSlip({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // Paper stays paper-white in both themes so ink contrast is constant.
    const ink = MitlistColors.textPrimary;

    return TornSlip(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.lg,
        MitlistSpacing.space6,
        MitlistSpacing.lg,
        MitlistSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: MitlistSpacing.space2),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ink.withValues(alpha: 0.72),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: MitlistSpacing.space4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.space3,
                  vertical: MitlistSpacing.space2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ink.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: Text(
                  '····-····',
                  style: MitlistTypography.monoBody(
                    color: ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, size: 20, color: ink),
            ],
          ),
        ],
      ),
    );
  }
}
