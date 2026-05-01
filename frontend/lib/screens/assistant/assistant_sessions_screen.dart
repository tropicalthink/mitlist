import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/assistant_models.dart';
import '../../providers/assistant_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';

class AssistantSessionsScreen extends ConsumerStatefulWidget {
  const AssistantSessionsScreen({super.key});

  @override
  ConsumerState<AssistantSessionsScreen> createState() =>
      _AssistantSessionsScreenState();
}

class _AssistantSessionsScreenState
    extends ConsumerState<AssistantSessionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<ChatSessionModel> _sessions = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service =
          await ref.read(assistantServiceProviderAsync.future);
      final sessions = await service.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load sessions.';
        _isLoading = false;
      });
    }
  }

  Future<void> _createSession() async {
    setState(() => _isCreating = true);
    try {
      final service =
          await ref.read(assistantServiceProviderAsync.future);

      final count = _sessions.length + 1;
      final session = await service.createSession(
        CreateSessionRequest(title: 'Chat $count'),
      );
      if (!mounted) return;
      setState(() {
        _sessions.insert(0, session);
        _isCreating = false;
      });
      context.pushNamed('assistantChat', pathParameters: {
        'sessionId': session.id,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'Failed to create session.';
      });
    }
  }

  Future<void> _deleteSession(ChatSessionModel session) async {
    try {
      final service =
          await ref.read(assistantServiceProviderAsync.future);
      await service.deleteSession(session.id);
      setState(() => _sessions.removeWhere((s) => s.id == session.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to delete session.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Assistant',
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createSession,
        icon: _isCreating
            ? const SizedBox(
                width: MitlistSpacing.space5,
                height: MitlistSpacing.space5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(MitlistColors.textOnPrimary),
                ),
              )
            : const AppIcon(
                name: 'plus',
                color: MitlistColors.textOnPrimary,
              ),
        label: const Text('New chat'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(MitlistColors.primary500),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                children: [
                  if (_error != null) ...[
                    AppAlert(
                        type: AppAlertType.error, message: _error!),
                    const SizedBox(height: MitlistSpacing.md),
                  ],
                  if (_sessions.isEmpty && _error == null)
                    const AppEmptyState(
                      icon: Icon(Icons.auto_awesome_outlined,
                          size: 56),
                      title: 'No chats yet',
                      description:
                          'Ask the assistant about chores, meal plans, shopping lists, or anything household-related.',
                    )
                  else
                    ..._sessions.map((session) {
                      final dateStr = DateFormat('MMM d, h:mm a')
                          .format(session.updatedAt.toLocal());

                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: MitlistSpacing.sm),
                        child: Dismissible(
                          key: ValueKey(session.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                                horizontal: MitlistSpacing.md),
                            decoration: BoxDecoration(
                              color: MitlistColors.error500
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  MitlistSpacing.sm),
                            ),
                            child: const Icon(
                                Icons.delete_outline,
                                color: MitlistColors.error500),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteSession(session);
                            return false;
                          },
                          child: AppCard(
                            interactive: true,
                            onTap: () => context.pushNamed(
                              'assistantChat',
                              pathParameters: {
                                'sessionId': session.id,
                              },
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  MitlistSpacing.md),
                              child: Row(
                                children: [
                                  const AppIcon(
                                    name: 'bolt',
                                    size: MitlistSpacing.space6,
                                    color:
                                        MitlistColors.primary500,
                                  ),
                                  const SizedBox(
                                      width: MitlistSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          session.title,
                                          style: textTheme
                                              .titleMedium,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(
                                            height:
                                                MitlistSpacing.xs),
                                        Text(
                                          dateStr,
                                          style: textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const AppIcon(
                                      name: 'chevronRight'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
