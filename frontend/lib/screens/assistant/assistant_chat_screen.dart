import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/assistant_models.dart';
import '../../providers/assistant_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';

class AssistantChatScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const AssistantChatScreen({super.key, required this.sessionId});

  @override
  ConsumerState<AssistantChatScreen> createState() =>
      _AssistantChatScreenState();
}

class _AssistantChatScreenState
    extends ConsumerState<AssistantChatScreen> {
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String _sessionTitle = '';
  List<ChatMessageModel> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service =
          await ref.read(assistantServiceProviderAsync.future);

      final results = await Future.wait([
        service.getSession(widget.sessionId),
        service.listMessages(widget.sessionId),
      ]);

      if (!mounted) return;

      final session = results[0] as ChatSessionModel;
      final messages = results[1] as List<ChatMessageModel>;

      setState(() {
        _sessionTitle = session.title;
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chat.';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    _inputController.clear();

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final service =
          await ref.read(assistantServiceProviderAsync.future);

      await service.sendMessage(
        widget.sessionId,
        SendMessageRequest(content: content),
      );

      if (!mounted) return;

      final allMessages =
          await service.listMessages(widget.sessionId);

      if (!mounted) return;
      setState(() {
        _messages = allMessages;
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = 'Failed to send message.';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        _sessionTitle.isNotEmpty ? _sessionTitle : 'Assistant',
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(MitlistColors.primary500),
              ),
            )
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MitlistSpacing.md,
                      vertical: MitlistSpacing.sm,
                    ),
                    child: AppAlert(
                        type: AppAlertType.error, message: _error!),
                  ),
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(
                                MitlistSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 56,
                                  color:
                                      MitlistColors.primary300,
                                ),
                                const SizedBox(
                                    height: MitlistSpacing.md),
                                Text(
                                  'Ask me anything about your household',
                                  style: textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(
                                    height: MitlistSpacing.sm),
                                Text(
                                  'Try "What chores are due today?" or "Suggest meals for this week."',
                                  style: textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(
                              MitlistSpacing.md),
                          itemCount: _messages.length +
                              (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _LoadingBubble();
                            }
                            final msg = _messages[index];
                            final isUser = msg.role == 'user';
                            return _MessageBubble(
                              message: msg,
                              isUser: isUser,
                            );
                          },
                        ),
                ),
                _buildInputBar(colorScheme),
              ],
            ),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.sm,
        MitlistSpacing.sm,
        MitlistSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Ask anything...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                    vertical: MitlistSpacing.sm,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: const AppIcon(
                name: 'arrowRight',
                color: MitlistColors.primary500,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    MitlistColors.primary50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isUser;

  const _MessageBubble({
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser
        ? MitlistColors.primary50
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final borderColor = isUser
        ? MitlistColors.primary200
        : Theme.of(context).colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(
                  MitlistSpacing.sm),
            ),
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Text(
              message.content,
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MitlistSpacing.sm,
            ),
            child: Text(
              DateFormat('h:mm a')
                  .format(message.createdAt.toLocal()),
              style: textTheme.bodySmall?.copyWith(
                color: MitlistColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBubble extends StatefulWidget {
  @override
  State<_LoadingBubble> createState() => _LoadingBubbleState();
}

class _LoadingBubbleState extends State<_LoadingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: colorScheme.outline,
                  width: 1,
                ),
                borderRadius:
                    BorderRadius.circular(MitlistSpacing.sm),
              ),
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: MitlistSpacing.space2,
                    height: MitlistSpacing.space2,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        MitlistColors.primary500,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  Text(
                    'Thinking…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
