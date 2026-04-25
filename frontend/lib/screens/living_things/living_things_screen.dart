import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/living_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';

enum LivingThingType { pet, plant }

/// A data model representing a pet or plant.
class LivingThing {
  final String id;
  final String name;
  final LivingThingType type;
  final String? photoUrl;
  final DateTime? nextCareDate;

  const LivingThing({
    required this.id,
    required this.name,
    required this.type,
    this.photoUrl,
    this.nextCareDate,
  });
}

class LivingThingsScreen extends ConsumerStatefulWidget {
  const LivingThingsScreen({super.key});

  @override
  ConsumerState<LivingThingsScreen> createState() => _LivingThingsScreenState();
}

class _LivingThingsScreenState extends ConsumerState<LivingThingsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<LivingThing> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final livingService = await ref.read(livingServiceProviderAsync.future);
      final items = await livingService.listLivingThings('');

      if (!mounted) return;

      setState(() {
        _items = items.where((t) => t.species == 'pet' || t.species == 'plant').map((t) => LivingThing(
          id: t.id,
          name: t.name,
          type: t.species == 'pet' ? LivingThingType.pet : LivingThingType.plant,
          photoUrl: t.imageUrl,
          nextCareDate: t.createdAt.add(const Duration(days: 1)),
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load pets and plants.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets & Plants'),
      ),
      body: _buildBody(textTheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to LivingThingCreationSheet.
        },
        label: const Text('Add'),
        icon: const AppIcon(name: 'plus'),
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) {
      return _SkeletonList();
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppAlert(
          type: AppAlertType.error,
          message: _errorMessage!,
        ),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          icon: AppIcon(name: 'paw', size: 56),
          title: 'No pets or plants yet',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: MitlistSpacing.sm),
      itemBuilder: (context, index) {
        final item = _items[index];
        return AppCard(
          interactive: true,
          onTap: () {
            // TODO: Navigate to LivingThingDetailScreen.
          },
          child: Row(
            children: [
              _buildLeading(item),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleSmall,
                    ),
                    if (item.nextCareDate != null)
                      Text(
                        _formatNextCareDate(item.nextCareDate!),
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeading(LivingThing item) {
    const double size = 48;

    if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: MitlistColors.neutral100,
        ),
        child: Image.network(
          item.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: AppIcon(
              name: 'paw',
              size: 24,
              color: MitlistColors.neutral400,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: MitlistColors.neutral100,
      ),
      child: const Center(
        child: AppIcon(
          name: 'paw',
          size: 24,
          color: MitlistColors.neutral400,
        ),
      ),
    );
  }

  String _formatNextCareDate(DateTime date) {
    return 'Next care: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, __) =>
          const SizedBox(height: MitlistSpacing.sm),
      itemBuilder: (context, index) {
        return const AppCard(
          child: Row(
            children: [
              AppSkeleton(
                width: 48,
                height: 48,
              ),
              SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(
                      width: 120,
                      height: 14,
                    ),
                    SizedBox(height: MitlistSpacing.space1),
                    AppSkeleton(
                      width: 80,
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
