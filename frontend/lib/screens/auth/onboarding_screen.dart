import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
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
import '../../providers/onboarding_provider.dart';
import '../../router.dart' show currentGroupIdProvider, resetLastShellTab;
import '../../screens/scanner/invite_qr_scan_screen.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../services/product_events.dart';
import '../../utils/haptics.dart';
import '../../utils/invite_link.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_currency_dropdown.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/board/cork_board.dart';

/// First run, staged as the app's own metaphor: one cork board, four beats.
///
/// 1. Choose — a torn paper slip with the invite-code field (join right
///    here, paste-aware) and a fresh sticky note ("create") drop onto the
///    board and settle with a spring wobble. Joining goes straight home.
/// 2. Name — the household name is written directly on the sticky note and
///    pinned to the board. The currency is guessed from the device and only
///    asked for behind "Change".
/// 3. Invite — a slip with the invite code (and its QR) is torn off for the
///    rest of the house. "Later" skips it; Home's checklist asks again.
/// 4. Intent — "What do you want to sort out first?" puts that step first
///    on Home's checklist (plans/048 stage 6). "Just looking" changes nothing.
///    It replaces the old "three things to know" recap: Home itself now shows
///    what needs you.
///
/// Under reduced motion every beat is simply already in place.
enum _Stage { choose, name, invite, intent }

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

  // The board holds until we know whether this account already belongs to a
  // household. Existing accounts go straight home without ever seeing the
  // create/join notes; new ones get the full entrance. A hint appears only
  // when the check is slow enough to feel like waiting.
  bool _membershipResolved = false;
  bool _showResolveHint = false;
  Timer? _resolveHintTimer;

  _Stage _stage = _Stage.choose;

  // Choose beat: joining with a code.
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _joinError;

  // Name beat.
  final _nameController = TextEditingController();
  String? _currency;
  bool _showCurrencyPicker = false;
  bool _isCreating = false;
  String? _createError;

  // Invite beat.
  Group? _createdGroup;
  GroupInvite? _invite;
  bool _inviteLoading = false;
  String? _inviteError;
  bool _copied = false;
  bool _shared = false;
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
      _resolveHintTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted && !_membershipResolved) {
          setState(() => _showResolveHint = true);
        }
      });
      unawaited(_resolveMembership());
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

  Future<void> _resolveMembership() async {
    final pending = ref.read(cachedGroupsProvider.future);
    try {
      final groups = await pending.timeout(const Duration(seconds: 4));
      if (!mounted) return;
      // `isPersonal` is absent from real API payloads (the backend has no such
      // field), so match on "not explicitly personal" — `== false` silently
      // treated every genuine household as missing and re-ran onboarding on
      // each OAuth sign-in.
      if (groups.any((g) => g.isPersonal != true)) {
        // Existing household: this screen was never for them.
        context.goNamed('home');
        return;
      }
      _revealChoose();
    } catch (_) {
      // Slow or offline — let the user proceed rather than hold the door.
      if (!mounted) return;
      _revealChoose();
      unawaited(_skipIfLateResultHasHousehold(pending));
    }
  }

  /// The 4s reveal timeout gave up on the fetch, but the fetch itself may
  /// still land. If it eventually reports an existing household and the user
  /// hasn't started dressing the board, skip home late rather than never.
  Future<void> _skipIfLateResultHasHousehold(
    Future<List<Group>> pending,
  ) async {
    try {
      final groups = await pending;
      if (!mounted) return;
      final hasHousehold = groups.any((g) => g.isPersonal != true);
      if (hasHousehold && _stage == _Stage.choose) {
        context.goNamed('home');
      }
    } catch (_) {
      // API unavailable — onboarding stays usable.
    }
  }

  void _revealChoose() {
    _resolveHintTimer?.cancel();
    setState(() {
      _membershipResolved = true;
      _showResolveHint = false;
    });
    _startAnimation();
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
    _resolveHintTimer?.cancel();
    _copiedTimer?.cancel();
    _codeController.dispose();
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

  bool get _canJoin => _codeController.text.trim().length >= 4 && !_isJoining;

  /// The field takes whatever people were sent: a pasted link becomes its
  /// code.
  void _onCodeChanged(String value) {
    final code = value.contains('/') ? extractInviteCode(value) : null;
    if (code != null) {
      _codeController.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
    }
    setState(() => _joinError = null);
  }

  Future<void> _pasteCode() async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final code = data?.text == null ? null : extractInviteCode(data!.text!);
    if (code == null) {
      unawaited(Haptics.failure());
      AppToast.info(context, l10n.joinPasteNoCode);
      return;
    }
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    unawaited(Haptics.light());
    setState(() => _joinError = null);
  }

  /// The in-app QR scanner only exists on the mobile platforms.
  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> _scanCode() async {
    final code = await InviteQrScanScreen.show(context);
    if (!mounted || code == null) return;
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    await _joinHousehold();
  }

  /// Joining with a code lands in the household: it already has its people
  /// and its things, so there is nothing to name, invite or choose.
  Future<void> _joinHousehold() async {
    if (!_canJoin) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isJoining = true;
      _joinError = null;
    });
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final group = await svc.joinGroup(
        JoinGroupRequest(code: _codeController.text.trim().toUpperCase()),
      );
      ProductEvents.instance.householdStarted(
        ProductEventName.householdJoined,
        group.id,
        source: 'onboarding',
      );
      // Seed the cache first so Home never lands on "no household" for one
      // that demonstrably exists (see _pinHousehold).
      await refreshCachedGroups(ref, ensure: group);
      // Joined, not created: Home gives them the joiner checklist once the
      // household has things in it (plans/048 stage 7).
      await markHubQuickStartJoined(group.id);
      if (!mounted) return;
      unawaited(ref.read(currentGroupIdProvider.notifier).set(group.id));
      unawaited(Haptics.success());
      await _goToBoard();
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      setState(() {
        _isJoining = false;
        _joinError = friendlyErrorMessage(e, l10n);
      });
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
      ProductEvents.instance.householdStarted(
        ProductEventName.householdCreated,
        group.id,
        source: 'onboarding',
      );
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
    _markInvited();
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _goToBoard() async {
    unawaited(Haptics.light());
    // Finishing first run lands on the household board. The shell restores the
    // tab a previous session ended on the moment it builds, which overrode
    // this navigation and dropped a brand-new household into whatever tab was
    // last — clearing it first is what makes "go to the board" go to the
    // board.
    await resetLastShellTab();
    if (!mounted) return;
    context.goNamed('home');
  }

  /// Copying or sharing the code is asking someone in: tick "Invite someone"
  /// on Home's checklist, and say "Continue" rather than "Later".
  void _markInvited() {
    final group = _createdGroup;
    if (group == null) return;
    setState(() => _shared = true);
    unawaited(markHubQuickStartInvited(group.id));
  }

  void _showIntent() {
    unawaited(Haptics.light());
    _toStage(_Stage.intent);
  }

  Future<void> _answerIntent(HubQuickStartIntent? intent, String answer) async {
    final group = _createdGroup;
    if (group != null) {
      if (intent != null) {
        await setHubQuickStartIntent(group.id, intent);
        ref.invalidate(hubQuickStartPrefsProvider(group.id));
      }
      ProductEvents.instance.track(
        ProductEventName.intentAnswered,
        groupId: group.id,
        props: {'intent': answer},
      );
    }
    await _goToBoard();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_membershipResolved) {
      // Membership check in flight: hold the bare board. The hint paper only
      // appears once the check is slow enough to feel like waiting, so the
      // common fast path is a beat of cork before the notes drop in.
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CorkBoardBackground(),
            if (_showResolveHint)
              SafeArea(
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: TapedPaper(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.lg,
                        vertical: MitlistSpacing.space5,
                      ),
                      child: Text(
                        l10n.authOnboardingResolving,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: MitlistColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

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
                                  _Stage.intent =>
                                    _intentStage(l10n, noteWidth),
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
      _Stage.intent => (
          l10n.authOnboardingIntentTitle,
          l10n.authOnboardingIntentBody,
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
    // Join first (an invite code is the one thing that cannot be typed
    // later), create second: the Life360 / Notion shape.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: math.max(noteWidth, 320.0),
            child: BoardDrop(
              t: _createT,
              tilt: 0.022,
              child: _JoinSlip(
                title: l10n.authOnboardingHaveCode,
                body: l10n.authOnboardingJoinDesc,
                field: AppInput(
                  hint: l10n.sheetJoinCodeExample,
                  controller: _codeController,
                  textInputAction: TextInputAction.go,
                  enabled: !_isJoining,
                  onChanged: _onCodeChanged,
                  onSubmitted: (_) => _joinHousehold(),
                ),
                error: _joinError,
                actions: [
                  if (_canScan)
                    AppButton(
                      variant: AppButtonVariant.ghost,
                      color: AppButtonColor.neutral,
                      size: AppButtonSize.sm,
                      text: l10n.joinScanButton,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      onPressed: _isJoining ? null : _scanCode,
                    ),
                  AppButton(
                    variant: AppButtonVariant.ghost,
                    color: AppButtonColor.neutral,
                    size: AppButtonSize.sm,
                    text: l10n.joinPasteButton,
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    onPressed: _isJoining ? null : _pasteCode,
                  ),
                ],
                join: AppButton(
                  variant: AppButtonVariant.solid,
                  color: AppButtonColor.primary,
                  text: _isJoining ? l10n.authJoinJoining : l10n.sheetJoinJoin,
                  isLoading: _isJoining,
                  onPressed: _canJoin ? _joinHousehold : null,
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
              tilt: -0.032,
              child: BoardPressable(
                semanticLabel: l10n.authOnboardingCreateHousehold,
                onTap: _isJoining ? () {} : _onCreateHousehold,
                child: _ChoiceNote(
                  title: l10n.authOnboardingCreateHousehold,
                  body: l10n.authOnboardingCreateDesc,
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
                    if (_showCurrencyPicker)
                      AppCurrencyDropdown(
                        value: _currency ?? 'USD',
                        onChanged: _isCreating
                            ? null
                            : (v) {
                                if (v != null) setState(() => _currency = v);
                              },
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.authOnboardingCurrency(_currency ?? 'USD'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppButton(
                            variant: AppButtonVariant.ghost,
                            color: AppButtonColor.neutral,
                            size: AppButtonSize.sm,
                            text: l10n.authOnboardingCurrencyChange,
                            onPressed: _isCreating
                                ? null
                                : () =>
                                    setState(() => _showCurrencyPicker = true),
                          ),
                        ],
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
                        const SizedBox(height: MitlistSpacing.space2),
                        Center(
                          child: AppButton(
                            key: ValueKey(_copied),
                            size: AppButtonSize.sm,
                            text: _copied
                                ? l10n.sheetInviteCopied
                                : l10n.sheetInviteCopy,
                            icon: _copied
                                ? const AppIcon(name: 'checkCircle', size: 16)
                                : const AppIcon(name: 'copy', size: 16),
                            onPressed: _copyCode,
                            variant: AppButtonVariant.ghost,
                            color: _copied
                                ? AppButtonColor.success
                                : AppButtonColor.neutral,
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        AppButton(
                          variant: AppButtonVariant.solid,
                          color: AppButtonColor.primary,
                          size: AppButtonSize.lg,
                          text: l10n.sheetInviteShare,
                          icon: const AppIcon(name: 'share', size: 18),
                          onPressed: () {
                            _markInvited();
                            unawaited(SharePlus.instance.share(
                              ShareParams(
                                text: inviteShareText(code, l10n),
                              ),
                            ));
                          },
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
        // One thing to do here, and it isn't leaving: sharing the invite is
        // the only solid button on the beat. Continuing is a quiet outline and
        // copying is a text button that lives with the code it copies — the
        // three used to be near-equal blocks competing for the same tap.
        AppButton(
          variant: AppButtonVariant.outline,
          color: AppButtonColor.neutral,
          size: AppButtonSize.lg,
          text: _shared
              ? l10n.authOnboardingGoToBoard
              : l10n.authOnboardingInviteLater,
          onPressed: _showIntent,
        ),
      ],
    );
  }

  // ── Final beat: what first ─────────────────────────────────────────────────

  Widget _intentStage(AppLocalizations l10n, double noteWidth) {
    final options = [
      (HubQuickStartIntent.lists, l10n.authOnboardingIntentLists, 'lists'),
      (HubQuickStartIntent.money, l10n.authOnboardingIntentMoney, 'money'),
      (HubQuickStartIntent.chores, l10n.authOnboardingIntentChores, 'chores'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: math.max(noteWidth, 320.0),
            child: Transform.rotate(
              angle: -0.012,
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
                    for (final (i, (intent, label, answer)) in options.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : MitlistSpacing.space3,
                        ),
                        child: AppButton(
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          size: AppButtonSize.lg,
                          text: label,
                          onPressed: () => _answerIntent(intent, answer),
                        ),
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
          text: l10n.authOnboardingIntentJustLooking,
          onPressed: () => _answerIntent(null, 'just_looking'),
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
          const SizedBox(height: MitlistSpacing.space4),
          // The blank name line the next beat asks you to write on — the same
          // show-the-thing move as the join slip's empty code boxes.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.edit_outlined,
                  size: 18, color: ink.withValues(alpha: 0.65)),
              const SizedBox(width: MitlistSpacing.space2),
              Container(
                width: 120,
                height: 2,
                color: ink.withValues(alpha: 0.45),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward, size: 20, color: ink),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Have an invite code?": a slip of paper torn off a note, pinned at one
/// corner, with the code field right on it.
class _JoinSlip extends StatelessWidget {
  const _JoinSlip({
    required this.title,
    required this.body,
    required this.field,
    required this.actions,
    required this.join,
    this.error,
  });

  final String title;
  final String body;
  final Widget field;
  final List<Widget> actions;
  final Widget join;
  final String? error;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          if (error != null) ...[
            AppAlert(type: AppAlertType.error, message: error!),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          field,
          Wrap(alignment: WrapAlignment.end, children: actions),
          const SizedBox(height: MitlistSpacing.space2),
          join,
        ],
      ),
    );
  }
}
