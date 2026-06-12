import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/cook_mode.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';

// ---------------------------------------------------------------------------
// Screen entry point
// ---------------------------------------------------------------------------

class CookModeScreen extends ConsumerStatefulWidget {
  final String recipeId;
  final Recipe? recipe;
  final List<RecipeIngredient>? ingredients;
  final List<RecipeStep>? steps;

  const CookModeScreen({
    super.key,
    required this.recipeId,
    this.recipe,
    this.ingredients,
    this.steps,
  });

  @override
  ConsumerState<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends ConsumerState<CookModeScreen> {
  // Data
  Recipe? _recipe;
  List<RecipeIngredient> _ingredients = const [];
  List<RecipeStep> _steps = const [];
  bool _isLoading = true;
  bool _hasError = false;

  // Phase A: mise en place
  int _selectedServings = 1;
  final Set<String> _gathered = {};

  // Phase B: cook flow
  bool _cookStarted = false;
  int _currentStepIndex = 0;

  // Timers: map of stepIndex -> list of timers (one per parsed duration)
  final Map<int, List<_StepTimer>> _timers = {};
  Timer? _ticker;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _stepKeys = {};
  bool _currentStepOffscreen = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    if (widget.recipe != null &&
        widget.ingredients != null &&
        widget.steps != null) {
      _recipe = widget.recipe;
      _ingredients = widget.ingredients!;
      _steps = widget.steps!;
      _selectedServings = _recipe!.servings.clamp(1, 9999);
      _isLoading = false;
      _initStepKeys();
    } else {
      _load();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ticker?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _initStepKeys() {
    for (int i = 0; i < _steps.length; i++) {
      _stepKeys[i] = GlobalKey();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final recipe = await service.getRecipe(widget.recipeId);
      List<RecipeIngredient> ingredients = const [];
      List<RecipeStep> steps = const [];
      try {
        ingredients = await service.getRecipeIngredients(widget.recipeId);
      } catch (_) {}
      try {
        steps = await service.getRecipeSteps(widget.recipeId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _ingredients = ingredients;
        _steps = steps;
        _selectedServings = recipe.servings.clamp(1, 9999);
        _isLoading = false;
        _initStepKeys();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll tracking
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (!_cookStarted || _steps.isEmpty) return;
    final key = _stepKeys[_currentStepIndex];
    if (key == null || key.currentContext == null) return;
    final RenderObject? ro = key.currentContext!.findRenderObject();
    if (ro == null || ro is! RenderBox) return;
    final pos = ro.localToGlobal(Offset.zero);
    final screenH = MediaQuery.sizeOf(context).height;
    final offscreen = pos.dy > screenH || pos.dy + ro.size.height < 0;
    if (offscreen != _currentStepOffscreen) {
      setState(() => _currentStepOffscreen = offscreen);
    }
  }

  // ---------------------------------------------------------------------------
  // Scaling helpers
  // ---------------------------------------------------------------------------

  double get _scale {
    final recipe = _recipe;
    if (recipe == null) return 1.0;
    return cookScale(recipe.servings, _selectedServings);
  }

  String _scaledLabel(RecipeIngredient ing) {
    if (ing.quantity > 0) {
      final qty = formatScaledQuantity(ing.quantity, _scale);
      final unit = ing.unit.isNotEmpty ? ' ${ing.unit}' : '';
      return '$qty$unit ${ing.name}'.trim();
    } else {
      // rawText only
      if (_scale == 1.0) {
        return ing.rawText.isNotEmpty ? ing.rawText : ing.name;
      }
      final base = ing.rawText.isNotEmpty ? ing.rawText : ing.name;
      return '$base (unscaled)';
    }
  }

  // ---------------------------------------------------------------------------
  // Timer management
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkTimerCompletion();
    });
  }

  void _checkTimerCompletion() {
    final now = DateTime.now();
    for (final entry in _timers.entries) {
      for (final t in entry.value) {
        if (t.running && !t.completed && t.endTime != null) {
          if (now.isAfter(t.endTime!)) {
            t.completed = true;
            t.running = false;
            _fireTimerComplete();
          }
        }
      }
    }
  }

  void _fireTimerComplete() {
    unawaited(Haptics.success());
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timer done!')),
      );
    } else {
      _flashScreen();
    }
  }

  void _flashScreen() {
    // Full-screen 300ms primary-color flash via overlay.
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TimerFlash(
        onDone: () {
          entry.remove();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Timer done!')),
            );
          }
        },
      ),
    );
    overlay.insert(entry);
  }

  void _startTimer(int stepIndex, int timerIndex, Duration duration) {
    _timers.putIfAbsent(stepIndex, () => []);
    while (_timers[stepIndex]!.length <= timerIndex) {
      _timers[stepIndex]!.add(_StepTimer());
    }
    final t = _timers[stepIndex]![timerIndex];
    if (t.running) return;
    t.running = true;
    t.completed = false;
    t.endTime = DateTime.now().add(duration);
    if (_ticker == null || !(_ticker?.isActive ?? false)) {
      _startTicker();
    }
    setState(() {});
  }

  String _timerLabel(int stepIndex, int timerIndex, Duration baseDuration) {
    if ((_timers[stepIndex]?.length ?? 0) <= timerIndex) {
      return _durationLabel(baseDuration);
    }
    final t = _timers[stepIndex]![timerIndex];
    if (t.completed) return 'Done';
    if (!t.running) return _durationLabel(baseDuration);
    final remaining = t.endTime!.difference(DateTime.now());
    return _durationLabel(remaining < Duration.zero ? Duration.zero : remaining);
  }

  static String _durationLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Active timers for glance bar.
  List<({int step, int timer, Duration remaining})> get _activeTimers {
    final result = <({int step, int timer, Duration remaining})>[];
    for (final entry in _timers.entries) {
      for (int ti = 0; ti < entry.value.length; ti++) {
        final t = entry.value[ti];
        if (t.running && !t.completed && t.endTime != null) {
          final rem = t.endTime!.difference(DateTime.now());
          result.add((
            step: entry.key + 1,
            timer: ti,
            remaining: rem < Duration.zero ? Duration.zero : rem,
          ));
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _advanceStep() {
    if (_currentStepIndex >= _steps.length - 1) {
      // Mark as finished.
      setState(() => _currentStepIndex = _steps.length);
      return;
    }
    unawaited(Haptics.light());
    setState(() {
      _currentStepIndex++;
      _currentStepOffscreen = false;
    });
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _stepKeys[_currentStepIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
    });
  }

  void _jumpToStep(int index) {
    setState(() {
      _currentStepIndex = index;
      _currentStepOffscreen = false;
    });
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _stepKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
    });
  }

  void _scrollToCurrentStep() {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final key = _stepKeys[_currentStepIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Equipment parsing (reuse detail screen pattern)
  // ---------------------------------------------------------------------------

  static List<String> _parseEquipment(String jsonStr) {
    if (jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return [];
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _LoadingView();
    if (_hasError || _recipe == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(name: 'restaurant', size: 48),
              const SizedBox(height: MitlistSpacing.md),
              const Text('Could not load recipe'),
              const SizedBox(height: MitlistSpacing.md),
              AppButton(
                text: 'Retry',
                variant: AppButtonVariant.outline,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    if (!_cookStarted) {
      return _MiseEnPlaceView(
        recipe: _recipe!,
        ingredients: _ingredients,
        scale: _scale,
        selectedServings: _selectedServings,
        gathered: _gathered,
        onServingsChanged: (v) => setState(() => _selectedServings = v),
        onGatherToggle: (id) => setState(() {
          if (_gathered.contains(id)) {
            _gathered.remove(id);
          } else {
            _gathered.add(id);
          }
        }),
        onStart: () => setState(() => _cookStarted = true),
        scaledLabel: _scaledLabel,
        parseEquipment: _parseEquipment,
      );
    }

    // Phase B: finished?
    if (_currentStepIndex >= _steps.length) {
      return _FinishedView(onExit: () => Navigator.of(context).pop());
    }

    return _CookFlowView(
      recipe: _recipe!,
      steps: _steps,
      ingredients: _ingredients,
      currentStepIndex: _currentStepIndex,
      stepKeys: _stepKeys,
      scrollController: _scrollController,
      currentStepOffscreen: _currentStepOffscreen,
      activeTimers: _activeTimers,
      scale: _scale,
      timers: _timers,
      scaledLabel: _scaledLabel,
      onAdvance: _advanceStep,
      onJumpToStep: _jumpToStep,
      onScrollToCurrentStep: _scrollToCurrentStep,
      onStartTimer: _startTimer,
      timerLabel: _timerLabel,
    );
  }
}

// ---------------------------------------------------------------------------
// Phase A: Mise en place
// ---------------------------------------------------------------------------

class _MiseEnPlaceView extends StatelessWidget {
  final Recipe recipe;
  final List<RecipeIngredient> ingredients;
  final double scale;
  final int selectedServings;
  final Set<String> gathered;
  final ValueChanged<int> onServingsChanged;
  final ValueChanged<String> onGatherToggle;
  final VoidCallback onStart;
  final String Function(RecipeIngredient) scaledLabel;
  final List<String> Function(String) parseEquipment;

  const _MiseEnPlaceView({
    required this.recipe,
    required this.ingredients,
    required this.scale,
    required this.selectedServings,
    required this.gathered,
    required this.onServingsChanged,
    required this.onGatherToggle,
    required this.onStart,
    required this.scaledLabel,
    required this.parseEquipment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final equipmentList = parseEquipment(recipe.equipmentJson);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md,
                MitlistSpacing.md,
                MitlistSpacing.md,
                MitlistSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(name: 'xMark'),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Servings stepper
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md,
                vertical: MitlistSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Servings',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'Decrease servings',
                    button: true,
                    child: GestureDetector(
                      onTap: selectedServings > 1
                          ? () => onServingsChanged(selectedServings - 1)
                          : null,
                      child: Container(
                        width: MitlistSpacing.space11,
                        height: MitlistSpacing.space11,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Center(
                          child: AppIcon(
                            name: 'minusCircleOutline',
                            color: selectedServings > 1
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MitlistSpacing.space12,
                    child: Center(
                      child: Text(
                        '$selectedServings',
                        style: MitlistTypography.monoBody(),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Increase servings',
                    button: true,
                    child: GestureDetector(
                      onTap: () => onServingsChanged(selectedServings + 1),
                      child: Container(
                        width: MitlistSpacing.space11,
                        height: MitlistSpacing.space11,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Center(
                          child: AppIcon(
                            name: 'plus',
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Equipment chips
            if (equipmentList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.md,
                  vertical: MitlistSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: MitlistSpacing.sm,
                    runSpacing: MitlistSpacing.sm,
                    children: equipmentList
                        .map((e) => AppChip(label: e, selected: false))
                        .toList(),
                  ),
                ),
              ),
            ],
            const Divider(height: 1, thickness: 1),
            // Ingredient gather list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(
                  bottom: MitlistSpacing.md,
                ),
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ing = ingredients[index];
                  final isGathered = gathered.contains(ing.id);
                  return _GatherRow(
                    label: scaledLabel(ing),
                    isGathered: isGathered,
                    onTap: () => onGatherToggle(ing.id),
                  );
                },
              ),
            ),
            // Start cooking button
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outline, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Start cooking',
                      size: AppButtonSize.lg,
                      onPressed: onStart,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatherRow extends StatelessWidget {
  final String label;
  final bool isGathered;
  final VoidCallback onTap;

  const _GatherRow({
    required this.label,
    required this.isGathered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label, ${isGathered ? 'gathered' : 'not gathered'}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isGathered
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.zero,
                  color: isGathered
                      ? colorScheme.primary
                      : Colors.transparent,
                ),
                child: isGathered
                    ? AppIcon(
                        name: 'check',
                        size: 16,
                        color: colorScheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: MitlistSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: isGathered
                            ? TextDecoration.lineThrough
                            : null,
                        color: isGathered
                            ? colorScheme.onSurfaceVariant
                            : null,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase B: Cook flow
// ---------------------------------------------------------------------------

class _CookFlowView extends StatelessWidget {
  final Recipe recipe;
  final List<RecipeStep> steps;
  final List<RecipeIngredient> ingredients;
  final int currentStepIndex;
  final Map<int, GlobalKey> stepKeys;
  final ScrollController scrollController;
  final bool currentStepOffscreen;
  final List<({int step, int timer, Duration remaining})> activeTimers;
  final double scale;
  final Map<int, List<_StepTimer>> timers;
  final String Function(RecipeIngredient) scaledLabel;
  final VoidCallback onAdvance;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onScrollToCurrentStep;
  final void Function(int stepIndex, int timerIndex, Duration) onStartTimer;
  final String Function(int stepIndex, int timerIndex, Duration) timerLabel;

  const _CookFlowView({
    required this.recipe,
    required this.steps,
    required this.ingredients,
    required this.currentStepIndex,
    required this.stepKeys,
    required this.scrollController,
    required this.currentStepOffscreen,
    required this.activeTimers,
    required this.scale,
    required this.timers,
    required this.scaledLabel,
    required this.onAdvance,
    required this.onJumpToStep,
    required this.onScrollToCurrentStep,
    required this.onStartTimer,
    required this.timerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLast = currentStepIndex == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Glance bar
            _GlanceBar(
              stepIndex: currentStepIndex,
              stepCount: steps.length,
              activeTimers: activeTimers,
              colorScheme: colorScheme,
            ),
            // Step flow
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(
                      top: MitlistSpacing.sm,
                      bottom: MitlistSpacing.space20 + MitlistSpacing.space16,
                    ),
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      final desc = step.description.isNotEmpty
                          ? step.description
                          : step.name;
                      final isCurrent = index == currentStepIndex;
                      final isDone = index < currentStepIndex;

                      return _StepRow(
                        key: stepKeys[index],
                        stepNumber: index + 1,
                        description: desc,
                        isCurrent: isCurrent,
                        isDone: isDone,
                        ingredients: ingredients,
                        scale: scale,
                        scaledLabel: scaledLabel,
                        stepIndex: index,
                        timers: timers,
                        onJump: () => onJumpToStep(index),
                        onStartTimer: onStartTimer,
                        timerLabel: timerLabel,
                        colorScheme: colorScheme,
                        theme: theme,
                      );
                    },
                  ),
                  // Back to current step pill
                  if (currentStepOffscreen)
                    Positioned(
                      top: MitlistSpacing.md,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Semantics(
                          label: 'Back to step ${currentStepIndex + 1}',
                          button: true,
                          child: GestureDetector(
                            onTap: onScrollToCurrentStep,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MitlistSpacing.md,
                                vertical: MitlistSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Back to step ${currentStepIndex + 1}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom zone: Ingredients handle + Done
            _BottomZone(
              ingredients: ingredients,
              scale: scale,
              scaledLabel: scaledLabel,
              isLast: isLast,
              onAdvance: onAdvance,
              colorScheme: colorScheme,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glance bar
// ---------------------------------------------------------------------------

class _GlanceBar extends StatelessWidget {
  final int stepIndex;
  final int stepCount;
  final List<({int step, int timer, Duration remaining})> activeTimers;
  final ColorScheme colorScheme;

  const _GlanceBar({
    required this.stepIndex,
    required this.stepCount,
    required this.activeTimers,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Step ${stepIndex + 1} of $stepCount',
            style: MitlistTypography.monoBody(color: colorScheme.onSurface),
          ),
          if (activeTimers.isNotEmpty) ...[
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: activeTimers.map((t) {
                    return Padding(
                      padding: const EdgeInsets.only(right: MitlistSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.sm,
                          vertical: MitlistSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          'S${t.step} · ${_durationLabel(t.remaining)}',
                          style: MitlistTypography.monoBody(
                            color: colorScheme.onPrimaryContainer,
                          ).copyWith(fontSize: 11),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            const Spacer(),
          IconButton(
            icon: AppIcon(name: 'xMark', color: colorScheme.onSurface),
            tooltip: 'Exit cook mode',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  static String _durationLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Step row
// ---------------------------------------------------------------------------

class _StepRow extends StatelessWidget {
  final int stepNumber;
  final String description;
  final bool isCurrent;
  final bool isDone;
  final List<RecipeIngredient> ingredients;
  final double scale;
  final String Function(RecipeIngredient) scaledLabel;
  final int stepIndex;
  final Map<int, List<_StepTimer>> timers;
  final VoidCallback onJump;
  final void Function(int stepIndex, int timerIndex, Duration) onStartTimer;
  final String Function(int stepIndex, int timerIndex, Duration) timerLabel;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _StepRow({
    super.key,
    required this.stepNumber,
    required this.description,
    required this.isCurrent,
    required this.isDone,
    required this.ingredients,
    required this.scale,
    required this.scaledLabel,
    required this.stepIndex,
    required this.timers,
    required this.onJump,
    required this.onStartTimer,
    required this.timerLabel,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Semantics(
        label: 'Step $stepNumber done. Tap to revisit',
        button: true,
        child: InkWell(
          onTap: onJump,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
              vertical: MitlistSpacing.sm,
            ),
            child: Row(
              children: [
                AppIcon(name: 'checkCircleOutline', size: 16, color: colorScheme.primary),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    '$stepNumber. $description',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isCurrent) {
      final durations = parseStepDurations(description);
      final matches = matchIngredients(description, ingredients);

      return Semantics(
        label: 'Current step $stepNumber',
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colorScheme.primary, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: MitlistSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $stepNumber',
                  style: MitlistTypography.monoBody(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: MitlistSpacing.sm),
                _buildStepText(context, description, matches),
                // Timer chips
                if (durations.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.sm),
                  Wrap(
                    spacing: MitlistSpacing.sm,
                    runSpacing: MitlistSpacing.sm,
                    children: List.generate(durations.length, (ti) {
                      final dur = durations[ti];
                      final label = timerLabel(stepIndex, ti, dur);
                      final isRunning = (timers[stepIndex]?.length ?? 0) > ti &&
                          timers[stepIndex]![ti].running;
                      final isDoneTimer = label == 'Done';
                      return Semantics(
                        label: 'Timer: $label. Tap to start',
                        button: true,
                        child: GestureDetector(
                          onTap: isRunning || isDoneTimer
                              ? null
                              : () => onStartTimer(stepIndex, ti, dur),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MitlistSpacing.md,
                              vertical: MitlistSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isDoneTimer
                                  ? colorScheme.primaryContainer
                                  : isRunning
                                      ? colorScheme.primary
                                      : colorScheme.surface,
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  name: 'clockOutline',
                                  size: 14,
                                  color: isDoneTimer
                                      ? colorScheme.onPrimaryContainer
                                      : isRunning
                                          ? colorScheme.onPrimary
                                          : colorScheme.primary,
                                ),
                                const SizedBox(width: MitlistSpacing.xs),
                                Text(
                                  label,
                                  style: MitlistTypography.monoBody(
                                    color: isDoneTimer
                                        ? colorScheme.onPrimaryContainer
                                        : isRunning
                                            ? colorScheme.onPrimary
                                            : colorScheme.primary,
                                  ).copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Upcoming step
    return Semantics(
      label: 'Step $stepNumber: $description. Tap to jump to this step',
      button: true,
      child: InkWell(
        onTap: onJump,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$stepNumber.',
                  style: MitlistTypography.monoBody(
                    color: colorScheme.onSurfaceVariant,
                  ).copyWith(fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the current step text with inline ingredient quantity highlights.
  Widget _buildStepText(
      BuildContext context, String text, List<IngredientMatch> matches) {
    if (matches.isEmpty) {
      return Text(
        text,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 28,
          height: 1.35,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      final ing = m.ingredient;
      // Matched name
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      // Inline quantity suffix
      if (ing.quantity > 0) {
        final qty = formatScaledQuantity(ing.quantity, scale);
        final unit = ing.unit.isNotEmpty ? ' ${ing.unit}' : '';
        spans.add(TextSpan(
          text: ' · $qty$unit',
          style: MitlistTypography.monoBody(
            color: colorScheme.primary,
          ).copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 28,
          height: 1.35,
          color: colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom zone
// ---------------------------------------------------------------------------

class _BottomZone extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final double scale;
  final String Function(RecipeIngredient) scaledLabel;
  final bool isLast;
  final VoidCallback onAdvance;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _BottomZone({
    required this.ingredients,
    required this.scale,
    required this.scaledLabel,
    required this.isLast,
    required this.onAdvance,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline, width: 1),
        ),
        color: colorScheme.surface,
      ),
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ingredients handle (bottom-left)
              if (ingredients.isNotEmpty)
                _IngredientsHandle(
                  ingredients: ingredients,
                  scaledLabel: scaledLabel,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              // Done zone (full-width when no ingredients, otherwise expanded)
              Expanded(
                child: Semantics(
                  label: isLast ? 'Finish cooking' : 'Done, advance to next step',
                  button: true,
                  child: GestureDetector(
                    onTap: onAdvance,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 88),
                      color: colorScheme.primary,
                      child: Center(
                        child: Text(
                          isLast ? 'Finish' : 'Done →',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientsHandle extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final String Function(RecipeIngredient) scaledLabel;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _IngredientsHandle({
    required this.ingredients,
    required this.scaledLabel,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Show ingredients',
      button: true,
      child: GestureDetector(
        onTap: () => showAppBottomSheet(
          context: context,
          title: 'Ingredients',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ingredients.map((ing) {
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: Text(
                  scaledLabel(ing),
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }).toList(),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outline, width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(name: 'listBullet', color: colorScheme.primary),
              const SizedBox(height: MitlistSpacing.xs),
              Text(
                'Ingredients',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Finished state
// ---------------------------------------------------------------------------

class _FinishedView extends StatelessWidget {
  final VoidCallback onExit;

  const _FinishedView({required this.onExit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MitlistSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  name: 'checkCircle',
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: MitlistSpacing.lg),
                Text(
                  'Finished — nice work',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MitlistSpacing.xl),
                AppButton(
                  text: 'Done',
                  size: AppButtonSize.lg,
                  onPressed: onExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer flash overlay
// ---------------------------------------------------------------------------

class _TimerFlash extends StatefulWidget {
  final VoidCallback onDone;

  const _TimerFlash({required this.onDone});

  @override
  State<_TimerFlash> createState() => _TimerFlashState();
}

class _TimerFlashState extends State<_TimerFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.forward().then((_) {
      _controller.reverse().then((_) {
        widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return IgnorePointer(
          child: Container(
            color: colorScheme.primary
                .withValues(alpha: _controller.value * 0.6),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Timer data
// ---------------------------------------------------------------------------

class _StepTimer {
  bool running = false;
  bool completed = false;
  DateTime? endTime;
}
