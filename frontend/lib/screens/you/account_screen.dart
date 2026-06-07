import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
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
  bool _isEditingName = false;
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
        _error = 'Failed to load profile. Please try again.';
      });
      return;
    }

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      households = await groupService.listGroups();
    } catch (_) {
      // Households are optional for this screen.
    }

    if (!mounted) return;
    setState(() {
      _name = user!.fullName;
      _email = user.email;
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
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.updateMe(UpdateUserRequest(firstName: newName.split(' ')[0], lastName: newName.contains(' ') ? newName.split(' ').sublist(1).join(' ') : ''));
      setState(() => _name = newName);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save name');
    } finally {
      _isSaving = false;
    }
  }

  void _showPasswordSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var isSaving = false;
    String? error;

    showAppBottomSheet(
      context: context,
      title: 'Change password',
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final currentPassword = currentPasswordController.text.trim();
            final newPassword = newPasswordController.text.trim();
            final confirmPassword = confirmPasswordController.text.trim();

            if (currentPassword.isEmpty ||
                newPassword.isEmpty ||
                confirmPassword.isEmpty) {
              setSheetState(() => error = 'Fill out all password fields.');
              return;
            }
            if (newPassword.length < 6) {
              setSheetState(
                  () => error = 'New password must be at least 6 characters.');
              return;
            }
            if (newPassword != confirmPassword) {
              setSheetState(() => error = 'New passwords do not match.');
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
                const SnackBar(content: Text('Password changed')),
              );
            } catch (e) {
              setSheetState(() {
                isSaving = false;
                error = friendlyErrorMessage(e);
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
                label: 'Current password',
              ),
              const SizedBox(height: MitlistSpacing.md),
              AppInput(
                controller: newPasswordController,
                obscureText: true,
                label: 'New password',
              ),
              const SizedBox(height: MitlistSpacing.md),
              AppInput(
                controller: confirmPasswordController,
                obscureText: true,
                label: 'Confirm new password',
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: isSaving ? 'Saving...' : 'Change password',
                onPressed: isSaving ? null : submit,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTermsSheet() {
    showAppBottomSheet(
      context: context,
      title: 'Terms of Service',
      body: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use mitlist responsibly. Shared household content is visible to the members of that household.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: MitlistSpacing.md),
            Text(
              'Do not upload unlawful content, impersonate others, or abuse the service. Accounts and shared data may be removed for misuse.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: MitlistSpacing.md),
            Text(
              'The app is provided as-is while the product is still evolving. Keep your own backups for anything critical.',
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
      ref.read(authStateProvider.notifier).state = false;
    } catch (_) {
    }
    if (mounted) context.goNamed('welcome');
    _isSaving = false;
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isSaving) return;
    _isSaving = true;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete account',
      body: const Text('This will permanently delete your account and all associated data. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) { _isSaving = false; return; }
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.deleteMe();
      ref.read(authStateProvider.notifier).state = false;
      if (!mounted) return;
      context.goNamed('welcome');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
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
                    label: 'Edit your name',
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
    if (_households.length < 2) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Household',
            style: MitlistTypography.labelXSmall(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          ..._households.map((h) {
            final isActive = h.id == _activeHouseholdId;
            return Semantics(
              button: true,
              label: 'Switch to ${h.name}',
              child: InkWell(
              onTap: () {
                setState(() => _activeHouseholdId = h.id);
                context.goNamed('householdHub', pathParameters: {'groupId': h.id});
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
    final themeMode = ref.watch(themeModeProvider);

    return AppCard(
      child: Column(
        children: [
          _MenuRow(
            icon: const AppIcon(name: 'inbox'),
            label: 'Notification inbox',
            onTap: () => context.goNamed('notifications'),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'cog6Tooth'),
            label: 'Notification preferences',
            onTap: () => context.goNamed('notificationPreferences'),
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'sun'),
            label: 'Appearance',
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).set(mode);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return AppCard(
      child: _MenuRow(
        icon: const AppIcon(name: 'key'),
        label: 'Change Password',
        onTap: _showPasswordSheet,
      ),
    );
  }

  Widget _buildAboutCard() {
    return AppCard(
      child: Column(
        children: [
          _MenuRow(
            icon: const AppIcon(name: 'informationCircle'),
            label: 'Version',
            value: _appVersion,
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _MenuRow(
            icon: const AppIcon(name: 'identification'),
            label: 'Terms of Service',
            onTap: _showTermsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: 'Log out',
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
            text: 'Delete account',
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
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'You',
        showStandardActions: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        children: [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: 'Retry',
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
          _buildPreferencesCard(),
          const SizedBox(height: MitlistSpacing.md),
          _buildSecurityCard(),
          const SizedBox(height: MitlistSpacing.md),
          _buildAboutCard(),
          const SizedBox(height: MitlistSpacing.md),
          _buildDangerZone(),
        ],
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
