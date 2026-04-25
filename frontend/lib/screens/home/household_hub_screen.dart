import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_models.dart';
import '../../providers/list_provider.dart';
import '../../providers/group_provider.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/skeleton.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class HouseholdHubScreen extends ConsumerStatefulWidget {
  final String groupId;

  const HouseholdHubScreen({super.key, required this.groupId});

  @override
  ConsumerState<HouseholdHubScreen> createState() => _HouseholdHubScreenState();
}

class _HouseholdHubScreenState extends ConsumerState<HouseholdHubScreen> {
  bool _isLoading = true;
  Object? _error;
  Group? _data;
  int _listsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final group = await groupService.getGroup(widget.groupId);
      try {
        final listService = await ref.read(listServiceProviderAsync.future);
        final lists = await listService.listLists(widget.groupId);
        _listsCount = lists.length;
      } catch (_) {}
      setState(() {
        _data = group;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back to households',
          onPressed: () => context.goNamed('home'),
        ),
        title: Text(_data?.name ?? 'Household'),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'cog6Tooth'),
            tooltip: 'Settings',
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const _SkeletonDashboard()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppAlert(
                          type: AppAlertType.error,
                          message: 'Failed to load household',
                        ),
                        const SizedBox(height: MitlistSpacing.md),
                        AppButton(
                          text: 'Retry',
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _data?.name ?? '',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_data?.description != null) ...[
                          const SizedBox(height: MitlistSpacing.sm),
                          Text(
                            _data!.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: MitlistSpacing.space6),
                        Text(
                          'QUICK ACTIONS',
                          style: MitlistTypography.labelXSmall(),
                        ),
                        const SizedBox(height: MitlistSpacing.sm),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: MitlistSpacing.md,
                          crossAxisSpacing: MitlistSpacing.md,
                          childAspectRatio: 1.5,
                          children: [
                            _QuickActionCard(
                              iconName: 'clipboardDocumentList',
                              label: 'Lists',
                              count: _listsCount,
                              onTap: () => context.pushNamed('lists'),
                            ),
                            _QuickActionCard(
                              iconName: 'check',
                              label: 'Chores',
                              onTap: () => context.pushNamed('chores'),
                            ),
                            _QuickActionCard(
                              iconName: 'banknotes',
                              label: 'Money',
                              onTap: () => context.pushNamed('money'),
                            ),
                            _QuickActionCard(
                              iconName: 'safe',
                              label: 'Vault',
                              onTap: () => context.pushNamed('vault'),
                            ),
                            _QuickActionCard(
                              iconName: 'paw',
                              label: 'Pets & Plants',
                              onTap: () => context.pushNamed('livingThings'),
                            ),
                            _QuickActionCard(
                              iconName: 'bookOpen',
                              label: 'Recipes',
                              onTap: () => context.pushNamed('recipes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String iconName;
  final String label;
  final int? count;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.iconName,
    required this.label,
    this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: true,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(name: iconName, size: 28, color: MitlistColors.primary500),
          const SizedBox(height: MitlistSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          if (count != null)
            Text('$count', style: MitlistTypography.monoBody()),
        ],
      ),
    );
  }
}

class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(width: 200, height: 28),
          const SizedBox(height: MitlistSpacing.space6),
          const AppSkeleton(width: 100, height: 14),
          const SizedBox(height: MitlistSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: MitlistSpacing.md,
            crossAxisSpacing: MitlistSpacing.md,
            childAspectRatio: 1.5,
            children: const [
              _SkeletonCard(),
              _SkeletonCard(),
              _SkeletonCard(),
              _SkeletonCard(),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppSkeleton(width: 28, height: 28),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(width: 60, height: 14),
        ],
      ),
    );
  }
}
