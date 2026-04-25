import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/skeleton.dart';

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
  bool _notificationsEnabled = true;
  String _language = 'English';
  bool _isEditingName = false;

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
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final user = await authService.getMe();
      if (mounted) {
        setState(() {
          _name = user.fullName;
          _email = user.email;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load profile. Please try again.';
        });
      }
    }
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

  void _showLanguagePicker() {
    const languages = ['English', 'Spanish', 'French', 'German'];
    showAppBottomSheet(
      context: context,
      title: 'Select Language',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.asMap().entries.map((entry) {
          final index = entry.key;
          final lang = entry.value;
          final isSelected = lang == _language;
          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  lang,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                ),
                trailing: isSelected
                    ? const AppIcon(
                        name: 'check',
                        size: 20,
                        color: MitlistColors.primary500,
                      )
                    : null,
                onTap: () {
                  setState(() => _language = lang);
                  Navigator.of(context).pop();
                },
              ),
              if (index < languages.length - 1) const Divider(),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showPasswordSheet() {
    showAppBottomSheet(
      context: context,
      title: 'Change Password',
      body: const Text('Password change form placeholder'),
    );
  }

  void _onLogout() async {
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.logout();
      ref.read(authStateProvider.notifier).state = false;
    } catch (_) {}
    if (mounted) context.goNamed('welcome');
  }

  Widget _buildSkeletonProfileCard() {
    return AppCard(
      child: Row(
        children: [
          const AppSkeleton(
            width: MitlistSpacing.space12,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(
                  width: MitlistSpacing.space20,
                  height: MitlistSpacing.space5,
                ),
                const SizedBox(height: MitlistSpacing.sm),
                const AppSkeleton(
                  width: MitlistSpacing.space14,
                  height: MitlistSpacing.space4,
                ),
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

  Widget _buildPreferencesCard() {
    return AppCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(name: 'bell'),
            title: const Text('Notifications'),
            trailing: _NeoSwitch(
              value: _notificationsEnabled,
              onChanged: (value) => setState(() => _notificationsEnabled = value),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(name: 'language'),
            title: const Text('Language'),
            subtitle: Text(_language),
            trailing: const AppIcon(name: 'chevronRight'),
            onTap: _showLanguagePicker,
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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening terms...')),
              );
            },
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
      appBar: AppBar(
        title: const Text('You'),
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

/// A neobrutalist toggle switch with a square track and 2dp border.
class _NeoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _NeoSwitch({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return GestureDetector(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: MitlistAnimations.micro,
        width: MitlistSpacing.space12,
        height: MitlistSpacing.space7,
        decoration: BoxDecoration(
          color: value ? MitlistColors.primary500 : MitlistColors.surfacePrimary,
          border: Border.all(
            color: MitlistColors.borderPrimary,
            width: MitlistSpacing.space1 / 2,
          ),
          boxShadow:
              enabled ? MitlistShadows.shadowSoft : MitlistShadows.shadowNone,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: MitlistAnimations.micro,
              curve: MitlistTheme.easeMicro,
              left: value ? MitlistSpacing.space6 : MitlistSpacing.space1,
              top: MitlistSpacing.space1,
              child: Container(
                width: MitlistSpacing.space5,
                height: MitlistSpacing.space5,
                decoration: BoxDecoration(
                  color: MitlistColors.surfacePrimary,
                  border: Border.all(
                    color: MitlistColors.borderPrimary,
                    width: MitlistSpacing.space1 / 2,
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
