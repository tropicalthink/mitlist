import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';

const String _appVersion = '1.0.0';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isLoading = true;
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
    if (!_isEditingName) return;
    final newName = _nameController.text.trim();
    setState(() => _isEditingName = false);
    if (newName.isEmpty) return;
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.updateMe(UpdateUserRequest(firstName: newName.split(' ')[0], lastName: newName.contains(' ') ? newName.split(' ').sublist(1).join(' ') : ''));
      setState(() => _name = newName);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save name');
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
      title: 'Change Password',
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
                error = e.toString().replaceFirst('Exception: ', '');
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
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: MitlistSpacing.md),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: MitlistSpacing.md),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
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
      body: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use mitlist responsibly. Shared household content is visible to the members of that household.',
          ),
          SizedBox(height: MitlistSpacing.md),
          Text(
            'Do not upload unlawful content, impersonate others, or abuse the service. Accounts and shared data may be removed for misuse.',
          ),
          SizedBox(height: MitlistSpacing.md),
          Text(
            'The app is provided as-is while the product is still evolving. Keep your own backups for anything critical.',
          ),
        ],
      ),
    );
  }

  void _onLogout() async {
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.logout();
      ref.read(authStateProvider.notifier).state = false;
    } catch (_) {
      debugPrint('[AccountScreen] Logout failed');
    }
    if (mounted) context.goNamed('welcome');
  }

  Widget _buildSkeletonProfileCard() {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
              child: Row(
                children: [
                  const SizedBox(
                    width: MitlistSpacing.space12,
                    height: MitlistSpacing.space12,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(MitlistColors.primary500),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.md),
                  Expanded(
                    child: Text(
                      'Loading profile…',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
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
              color: MitlistColors.primary100,
              shape: BoxShape.circle,
              border: Border.all(
                color: MitlistColors.borderPrimary,
                width: MitlistSpacing.space1 / 2,
              ),
            ),
            child: const Center(
              child: AppIcon(
                name: 'userCircle',
                size: MitlistSpacing.space8,
                color: MitlistColors.primary500,
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
                  GestureDetector(
                    onTap: _startEditingName,
                    child: Text(
                      _name,
                      style: textTheme.headlineSmall,
                    ),
                  ),
                const SizedBox(height: MitlistSpacing.sm),
                Text(
                  _email,
                  style: textTheme.bodySmall,
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
              color: MitlistColors.textSecondary,
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          ..._households.map((h) {
            final isActive = h.id == _activeHouseholdId;
            return InkWell(
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
                      Icon(
                        Icons.check,
                        size: 18,
                        color: MitlistColors.primary500,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return AppCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(name: 'inbox'),
            title: const Text('Notification inbox'),
            trailing: const AppIcon(name: 'chevronRight'),
            onTap: () => context.goNamed('notifications'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(name: 'cog6Tooth'),
            title: const Text('Notification preferences'),
            trailing: const AppIcon(name: 'chevronRight'),
            onTap: () => context.goNamed('notificationPreferences'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const AppIcon(name: 'key'),
        title: const Text('Change Password'),
        trailing: const AppIcon(name: 'chevronRight'),
        onTap: _showPasswordSheet,
      ),
    );
  }

  Widget _buildAboutCard() {
    return AppCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(name: 'informationCircle'),
            title: const Text('Version'),
            subtitle: const Text(_appVersion),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(name: 'identification'),
            title: const Text('Terms of Service'),
            trailing: const AppIcon(name: 'arrowRight'),
            onTap: _showTermsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        text: 'Log out',
        variant: AppButtonVariant.soft,
        color: AppButtonColor.error,
        size: AppButtonSize.lg,
        onPressed: _onLogout,
      ),
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
