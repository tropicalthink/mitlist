import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../providers/auth_provider.dart'
    show authServiceProviderAsync, authStateProvider;
import '../../providers/group_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/list_provider.dart' show appDatabaseProvider;
import '../../providers/finance_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../utils/haptics.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/friendly_error.dart';

const String _appVersion = '1.0.0';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  String _name = '';
  String _email = '';
  bool _isGuest = false;
  bool _isEditingName = false;
  bool _isExporting = false;
  List<Group> _households = [];
  String? _activeHouseholdId;

  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(_onNameFocusChange);
    _loadData();
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_onNameFocusChange);
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onNameFocusChange() {
    if (!_nameFocusNode.hasFocus && _isEditingName) {
      _saveName();
    }
  }

  Future<void> _loadData() async {
    User? user;
    List<Group> households = [];

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      user = await authService.getMe();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.accountFailedLoadProfile;
      });
      return;
    }

    try {
      households = await ref.read(cachedGroupsProvider.future);
    } catch (_) {
      // Households are optional for this screen.
    }

    if (!mounted) return;
    setState(() {
      _name = user!.fullName;
      _email = user.email;
      _isGuest = user.isGuest;
      _households = households;
      _activeHouseholdId = households.isNotEmpty ? households.first.id : null;
      _isLoading = false;
      _error = null;
    });
  }

  void _startEditingName() {
    setState(() {
      _isEditingName = true;
      _nameController.text = _name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  Future<void> _saveName() async {
    if (_isSaving) return;
    _isSaving = true;
    if (!_isEditingName) { _isSaving = false; return; }
    final newName = _nameController.text.trim();
    setState(() => _isEditingName = false);
    if (newName.isEmpty) { _isSaving = false; return; }
    final l10n2 = AppLocalizations.of(context)!;
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.updateMe(UpdateUserRequest(firstName: newName.split(' ')[0], lastName: newName.contains(' ') ? newName.split(' ').sublist(1).join(' ') : ''));
      setState(() => _name = newName);
    } catch (e) {
      if (mounted) setState(() => _error = l10n2.accountFailedSaveName);
    } finally {
      _isSaving = false;
    }
  }

  void _showPasswordSheet() {
    final l10n = AppLocalizations.of(context)!;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var isSaving = false;
    String? error;

    showAppBottomSheet(
      context: context,
      title: l10n.accountChangePassword,
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final currentPassword = currentPasswordController.text.trim();
            final newPassword = newPasswordController.text.trim();
            final confirmPassword = confirmPasswordController.text.trim();

            if (currentPassword.isEmpty ||
                newPassword.isEmpty ||
                confirmPassword.isEmpty) {
              setSheetState(() => error = l10n.accountFillPasswordFields);
              return;
            }
            if (newPassword.length < 6) {
              setSheetState(
                  () => error = l10n.accountPasswordMinLength);
              return;
            }
            if (newPassword != confirmPassword) {
              setSheetState(() => error = l10n.accountPasswordsMismatch);
              return;
            }

            setSheetState(() {
              isSaving = true;
              error = null;
            });

            try {
              final authService = await ref.read(authServiceProviderAsync.future);
              await authService.changePassword(
                ChangePasswordRequest(
                  oldPassword: currentPassword,
                  newPassword: newPassword,
                ),
              );
              if (!mounted || !context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text(l10n.accountPasswordChanged)),
              );
            } catch (e) {
              setSheetState(() {
                isSaving = false;
                error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
              });
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                AppAlert(type: AppAlertType.error, message: error!),
                const SizedBox(height: MitlistSpacing.md),
              ],
              AppInput(
                controller: currentPasswordController,
                obscureText: true,
                label: l10n.accountCurrentPassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: MitlistSpacing.md),
              AppInput(
                controller: newPasswordController,
                obscureText: true,
                label: l10n.accountNewPassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: MitlistSpacing.md),
              AppInput(
                controller: confirmPasswordController,
                obscureText: true,
                label: l10n.accountConfirmPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: isSaving ? l10n.commonSaving : l10n.accountChangePasswordButton,
                onPressed: isSaving ? null : submit,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTermsSheet() {
    final l10n = AppLocalizations.of(context)!;
    showAppBottomSheet(
      context: context,
      title: l10n.accountTermsTitle,
      body: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountTermsBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onLogout() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.logout();
      await ref.read(appDatabaseProvider).clearAllUserData();
      ref.read(authStateProvider.notifier).state = false;
      unawaited(ref.read(currentGroupIdProvider.notifier).set(null));
      ref.invalidate(cachedGroupsProvider);
      ref.invalidate(hubQuickStartDismissedProvider);
    } catch (_) {
    }
    if (mounted) context.goNamed('welcome');
    _isSaving = false;
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.accountDeleteAccount,
      body: Text(l10n.accountDeleteAccountBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) { _isSaving = false; return; }
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.deleteMe();
      await ref.read(appDatabaseProvider).clearAllUserData();
      ref.read(authStateProvider.notifier).state = false;
      unawaited(ref.read(currentGroupIdProvider.notifier).set(null));
      ref.invalidate(cachedGroupsProvider);
      ref.invalidate(hubQuickStartDismissedProvider);
      if (!mounted) return;
      context.goNamed('welcome');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    } finally {
      _isSaving = false;
    }
  }

  Widget _buildSkeletonProfileCard() {
    return AppCard(
      child: Row(
        children: [
          const AppSkeleton(
            width: MitlistSpacing.space12,
            height: MitlistSpacing.space12,
            borderRadius: AppSkeletonRadius.sm,
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 200, height: 24),
                const SizedBox(height: MitlistSpacing.sm),
                AppSkeleton(width: 160, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: MitlistSpacing.space12,
            height: MitlistSpacing.space12,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: MitlistSpacing.space1 / 2,
              ),
            ),
            child: Center(
              child: AppIcon(
                name: 'userCircle',
                size: MitlistSpacing.space8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditingName)
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    style: textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _saveName(),
                    textInputAction: TextInputAction.done,
                  )
                else
                  Semantics(
                    button: true,
                    label: l10n.accountEditYourName,
                    child: GestureDetector(
                      onTap: _startEditingName,
                      child: Text(
                        _name,
                        style: textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(height: MitlistSpacing.sm),
                Text(
                  _email,
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdCard() {
    final l10n = AppLocalizations.of(context)!;
    if (_households.length < 2) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountHouseholdSection,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          ..._households.map((h) {
            final isActive = h.id == _activeHouseholdId;
            return Semantics(
              button: true,
              label: l10n.accountSwitchToHousehold(h.name),
              child: InkWell(
              onTap: () {
                setState(() => _activeHouseholdId = h.id);
                ref.read(currentGroupIdProvider.notifier).set(h.id);
                context.goNamed('home');
              },
              borderRadius: BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        h.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                    if (isActive)
                      AppIcon(
                        name: 'check',
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
          }),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return AppCard(
      child: Column(
        children: [
          _MenuRow(
            icon: const AppIcon(name: 'inbox'),
            label: l10n.accountNotificationInbox,
            onTap: () => context.goNamed('notifications'),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'cog6Tooth'),
            label: l10n.accountNotificationPreferences,
            onTap: () => context.goNamed('notificationPreferences'),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'sun'),
            label: l10n.accountAppearance,
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.accountAppearanceSystem)),
                DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.accountAppearanceLight)),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.accountAppearanceDark)),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).set(mode);
                }
              },
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'language'),
            label: l10n.accountLanguage,
            trailing: DropdownButton<Locale?>(
              value: locale,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.accountLanguageSystem)),
                ...LocaleNotifier.availableLanguages.entries.map(
                  (e) => DropdownMenuItem(value: Locale(e.key), child: Text(e.value)),
                ),
              ],
              onChanged: (loc) {
                ref.read(localeProvider.notifier).set(loc);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: _MenuRow(
        icon: const AppIcon(name: 'key'),
        label: l10n.accountChangePasswordRow,
        onTap: _showPasswordSheet,
      ),
    );
  }

  Widget _buildAboutCard() {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        children: [
          _MenuRow(
            icon: const AppIcon(name: 'informationCircle'),
            label: l10n.accountVersion,
            value: _appVersion,
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'identification'),
            label: l10n.accountTermsRow,
            onTap: _showTermsSheet,
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'informationCircle'),
            label: l10n.accountOpenDataRow,
            onTap: _showOpenDataSheet,
          ),
        ],
      ),
    );
  }

  void _showOpenDataSheet() {
    final l10n = AppLocalizations.of(context)!;
    showAppBottomSheet(
      context: context,
      title: l10n.accountOpenDataTitle,
      body: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountOpenDataBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExpenses(String format) async {
    if (_isExporting || _activeHouseholdId == null) return;
    setState(() => _isExporting = true);
    try {
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final groupId = _activeHouseholdId!;
      String data;
      String extension;
      String mime;

      if (format == 'csv') {
        data = await financeService.exportExpensesCsv(groupId);
        extension = 'csv';
        mime = 'text/csv';
      } else {
        final expenses = await financeService.exportExpensesJson(groupId);
        data = expenses.map((e) => e.toJson()).toString();
        extension = 'json';
        mime = 'application/json';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mitlist_expenses.$extension');
      await file.writeAsString(data);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: mime)]),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _copyExpensesJson() async {
    final l10n = AppLocalizations.of(context)!;
    if (_activeHouseholdId == null) return;
    try {
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final expenses = await financeService.exportExpensesJson(
        _activeHouseholdId!,
      );
      final json = expenses.map((e) => e.toJson()).toString();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      unawaited(Haptics.light());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountJSONCopied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  Future<void> _showConvertGuestSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? sheetError;
    bool isConverting = false;

    await showAppBottomSheet<void>(
      context: context,
      title: l10n.accountCreateAccountTitle,
      body: StatefulBuilder(builder: (ctx, setLocal) {
        Future<void> submit() async {
          final name = nameCtrl.text.trim();
          final email = emailCtrl.text.trim();
          final password = passCtrl.text;
          if (name.isEmpty || email.isEmpty || password.isEmpty) {
            setLocal(() => sheetError = l10n.accountFillAllFields);
            return;
          }
          setLocal(() { isConverting = true; sheetError = null; });
          try {
            final authSvc = await ref.read(authServiceProviderAsync.future);
            final parts = name.split(' ');
            await authSvc.convertGuest(ConvertGuestRequest(
              email: email,
              password: password,
              firstName: parts.first,
              lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
            ));
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (mounted) {
              ref.read(authStateProvider.notifier).state = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.accountCreatedWelcome)),
              );
            }
          } catch (e) {
            setLocal(() {
              isConverting = false;
              sheetError = friendlyErrorMessage(e, AppLocalizations.of(context)!);
            });
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              label: l10n.accountYourName,
              hint: l10n.accountYourNameHint,
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              maxLength: 100,
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppInput(
              label: l10n.accountEmail,
              hint: l10n.accountEmailHint,
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              maxLength: 200,
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppInput(
              label: l10n.accountPassword,
              controller: passCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              maxLength: 128,
              onChanged: (_) => setLocal(() {}),
            ),
            if (sheetError != null) ...[
              const SizedBox(height: MitlistSpacing.sm),
              AppAlert(type: AppAlertType.error, message: sheetError!),
            ],
            const SizedBox(height: MitlistSpacing.lg),
            AppButton(
              text: isConverting ? l10n.accountCreatingAccount : l10n.accountCreateAccount,
              variant: AppButtonVariant.solid,
              color: AppButtonColor.primary,
              size: AppButtonSize.lg,
              isLoading: isConverting,
              onPressed: isConverting ? null : submit,
            ),
          ],
        );
      }),
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
  }

  Widget _buildGuestUpgradeCard() {
    final l10n = AppLocalizations.of(context)!;
    if (!_isGuest) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        variant: AppCardVariant.filled,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  name: 'star',
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.accountGuestTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.accountGuestDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: l10n.accountCreateFullAccount,
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                onPressed: _showConvertGuestSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard() {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        children: [
          _MenuRow(
            icon: const AppIcon(name: 'arrowDownTray'),
            label: l10n.accountExportCSV,
            onTap: _isExporting || _activeHouseholdId == null
                ? null
                : () => _exportExpenses('csv'),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'arrowDownTray'),
            label: l10n.accountShareJSON,
            onTap: _isExporting || _activeHouseholdId == null
                ? null
                : () => _exportExpenses('json'),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'copy'),
            label: l10n.accountCopyJSON,
            onTap: _activeHouseholdId == null
                ? null
                : _copyExpensesJson,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: l10n.accountLogOut,
            variant: AppButtonVariant.soft,
            color: AppButtonColor.error,
            size: AppButtonSize.lg,
            onPressed: _onLogout,
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: l10n.accountDeleteAccountButton,
            variant: AppButtonVariant.ghost,
            color: AppButtonColor.error,
            size: AppButtonSize.lg,
            onPressed: _confirmDeleteAccount,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.accountAppBarTitle,
        showStandardActions: false,
      ),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MitlistSpacing.md),
          children: [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.commonRetry,
              onPressed: _loadData,
            ),
            const SizedBox(height: MitlistSpacing.md),
          ],
          if (_isLoading) ...[
            _buildSkeletonProfileCard(),
            const SizedBox(height: MitlistSpacing.md),
          ] else ...[
            _buildProfileCard(),
            const SizedBox(height: MitlistSpacing.md),
          ],
          _buildHouseholdCard(),
          if (_households.length >= 2) const SizedBox(height: MitlistSpacing.md),
          _buildGuestUpgradeCard(),
          _buildPreferencesCard(),
          const SizedBox(height: MitlistSpacing.md),
          if (!_isGuest) ...[
            _buildSecurityCard(),
            const SizedBox(height: MitlistSpacing.md),
          ],
          _buildAboutCard(),
          const SizedBox(height: MitlistSpacing.md),
          _buildDataCard(),
          const SizedBox(height: MitlistSpacing.md),
          _buildDangerZone(),
        ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
        child: Row(
          children: [
            icon,
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (value != null)
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              AppIcon(name: 'chevronRight', color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
