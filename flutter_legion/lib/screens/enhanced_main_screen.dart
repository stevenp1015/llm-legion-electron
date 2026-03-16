/// Enhanced main screen with macOS command-center styling
/// The complete transformation of your React masterpiece into Flutter glory
///
/// Features: selection system, glassy panels, animated everything
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../services/legion_api_service.dart';
import '../models/chat_message.dart';
import '../models/channel.dart';
import '../widgets/chat/enhanced_chat_message.dart';
import '../widgets/common/selection_header.dart';
import '../animations/config.dart';
import '../widgets/panels/channel_form_dialog.dart';
import '../widgets/panels/minion_config_panel.dart';
import '../widgets/panels/minion_config_sidebar.dart';
import '../widgets/panels/minion_buddylist.dart';
import 'mcp_manager_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'dart:async';

class EnhancedMainScreen extends StatefulWidget {
  const EnhancedMainScreen({super.key});

  @override
  State<EnhancedMainScreen> createState() => _EnhancedMainScreenState();
}

class _EnhancedMainScreenState extends State<EnhancedMainScreen>
    with TickerProviderStateMixin {

  late LegionApiService _legionService;
  String? _currentChannelId;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  Timer? _autoChatTimer;
  bool _isMinionSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
    _initializeServices();
  }

  @override
  void dispose() {
    _inputController.removeListener(_handleInputChanged);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _autoChatTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _legionService = context.read<LegionApiService>();
    final appProvider = context.read<AppProvider>();

    try {
      await _legionService.initialize();
      appProvider.setServiceInitialized(true);
      
      // Load initial data
      final channels = await _legionService.getChannels();
      appProvider.setChannels(channels);
      
      final minions = await _legionService.getMinions();
      appProvider.setMinionConfigs(minions);

      // Select first channel
      if (channels.isNotEmpty) {
        _selectChannel(channels.first.id);
      }
    } catch (e) {
      debugPrint('Failed to initialize services: $e');
    }
  }

  Future<void> _selectChannel(String channelId) async {
    final chatProvider = context.read<ChatProvider>();
    
    if (_currentChannelId != channelId) {
      _currentChannelId = channelId;
      chatProvider.setCurrentChannel(channelId);
      
      // Load messages for this channel
      final result = await _legionService.getMessages(channelId, 50);
      chatProvider.setMessages(channelId, result.messages, result.hasMore);
      
      // Smooth scroll to bottom with easing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: SpringConfig.slideDuration,
            curve: SpringConfig.slide,
          );
        }
      });

      _rescheduleAutoChat();
    }
  }

  Future<void> _createBuddyChat(String minionName) async {
    final appProvider = context.read<AppProvider>();
    
    // Create a new minion_buddy_chat channel
    final newChannel = Channel(
      id: 'channel-${DateTime.now().millisecondsSinceEpoch}',
      name: '$minionName DM',
      description: '1:1 chat with $minionName',
      type: ChannelType.minionBuddyChat,
      members: ['Legion Commander', minionName],
      isAutoModeActive: false,
    );
    
    appProvider.addChannel(newChannel);
    _selectChannel(newChannel.id);
  }

  Future<void> _deleteChannel(String channelId) async {
    final appProvider = context.read<AppProvider>();
    appProvider.removeChannel(channelId);
    
    // Select first remaining channel
    if (appProvider.channels.isNotEmpty) {
      _selectChannel(appProvider.channels.first.id);
    }
  }



  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    await chatProvider.sendMessage(content);
    
    _inputController.clear();
    if (mounted) {
      setState(() {});
    }
    _autoScrollIfEnabled();
  }

  void _autoScrollIfEnabled() {
    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.isAutoScrollEnabled) {
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
  }

  void _handleInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _attemptSend(Channel currentChannel) async {
    final disabled = currentChannel.type == ChannelType.minionMinionAuto &&
        currentChannel.isAutoModeActive;
    if (disabled) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    await _sendMessage(text);
  }

  void _rescheduleAutoChat() {
    _autoChatTimer?.cancel();
    final appProvider = context.read<AppProvider>();
    final current = appProvider.getChannel(_currentChannelId ?? '');
    if (current == null) return;
    if (current.type != ChannelType.minionMinionAuto || !current.isAutoModeActive) return;

    final delay = _computeAutoDelay(current);
    _autoChatTimer = Timer(delay, () async {
      await _legionService.triggerNextAutoChatTurn(
        current.id,
        (m) {
          context.read<ChatProvider>().upsertMessage(m);
          _autoScrollIfEnabled();
        },
        (chId, msgId, chunk) {
          context.read<ChatProvider>().processMessageChunk(chId, msgId, chunk);
          _autoScrollIfEnabled();
        },
        (minionName, isProcessing) {
          context.read<ChatProvider>().setActiveMinionProcessor(minionName, isProcessing);
        },
        (m) {
          context.read<ChatProvider>().addMessage(m.channelId, m);
          _autoScrollIfEnabled();
        },
        (m) {
          context.read<ChatProvider>().addMessage(m.channelId, m);
          _autoScrollIfEnabled();
        },
        (m) {
          context.read<ChatProvider>().upsertMessage(m);
          _autoScrollIfEnabled();
        },
      );

      if (mounted) {
        _rescheduleAutoChat();
      }
    });
  }

  Duration _computeAutoDelay(Channel c) {
    if (c.autoModeDelayType == 'random' && c.autoModeRandomDelay != null) {
      final min = c.autoModeRandomDelay!.min;
      final max = c.autoModeRandomDelay!.max;
      final secs = (min + (max - min) * (DateTime.now().millisecond % 1000) / 1000).round();
      return Duration(seconds: secs.clamp(1, 60));
    }
    return Duration(seconds: (c.autoModeFixedDelay ?? 5).clamp(1, 60));
  }

  // Selection mode handlers
  void _handleToggleSelection(String messageId, bool shiftKey) {
    final chatProvider = context.read<ChatProvider>();
    
    if (shiftKey && chatProvider.lastSelectedMessageId != null) {
      // Range selection
      chatProvider.selectMessageRange(
        chatProvider.lastSelectedMessageId!,
        messageId,
        chatProvider.currentChannelMessages,
      );
    } else {
      // Single selection
      chatProvider.selectMessage(messageId);
    }
  }

  void _handleDeleteSelected() {
    final chatProvider = context.read<ChatProvider>();
    if (_currentChannelId != null) {
      chatProvider.deleteSelectedMessages(_currentChannelId!);
    }
  }

  void _handleToggleDiary() {
    final chatProvider = context.read<ChatProvider>();
    final selectedMessages = chatProvider.currentChannelMessages
        .where((m) => chatProvider.selectedMessageIds.contains(m.id))
        .where((m) => m.senderType == MessageSender.ai && m.internalDiary != null)
        .map((m) => m.id)
        .toList();
    
    if (selectedMessages.isNotEmpty) {
      chatProvider.toggleBulkDiary(selectedMessages);
    }
  }

  void _handleManualRegulatorCall() async {
    if (_currentChannelId == null) return;
    final chatProvider = context.read<ChatProvider>();

    await _legionService.manuallyTriggerRegulator(
      _currentChannelId!,
      (reportMessage) {
        chatProvider.addMessage(reportMessage.channelId, reportMessage);
        _autoScrollIfEnabled();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final macosTheme = MacosTheme.of(context);

    return Stack(
      children: [
        MacosWindow(
      disableWallpaperTinting: true,
      sidebar: Sidebar(
        minWidth: 240,
        dragClosed: false,
        maxWidth: 300,
        top: _buildSidebarHeader(context, appProvider),
        builder: (context, controller) {
          final chatProvider = context.watch<ChatProvider>();
          return _buildSidebarItems(
            context,
            controller,
            appProvider,
            chatProvider,
          );
        },
      ),
      child: MacosScaffold(
        backgroundColor: macosTheme.canvasColor,
        toolBar: _buildToolbar(context),
        children: [
          ContentArea(
            minWidth: 640,
            builder: (context, scrollController) {
              final chatProvider = context.watch<ChatProvider>();
              return _buildContentArea(context, appProvider, chatProvider);
            },
          ),
        ],
      ),
    ),
    // Minion Config Sidebar overlay
    MinionConfigSidebar(
      isOpen: _isMinionSidebarOpen,
      onClose: () => setState(() => _isMinionSidebarOpen = false),
    ),
      ],
    );
  }

  ToolBar _buildToolbar(BuildContext context) {
    return ToolBar(
      height: 52,
      title: const Text('Legion Command Center'),
      titleWidth: 260,
      actions: [
        ToolBarIconButton(
          label: 'MCP',
          icon: const MacosIcon(CupertinoIcons.option),
          showLabel: false,
          tooltipMessage: 'Manage MCP servers',
          onPressed: () => McpManagerScreen.show(context),
        ),
        ToolBarIconButton(
          label: 'Regulator',
          icon: const MacosIcon(CupertinoIcons.zzz),
          showLabel: false,
          tooltipMessage: 'Trigger regulator analysis',
          onPressed: _handleManualRegulatorCall,
        ),
        ToolBarIconButton(
          label: 'Analytics',
          icon: const MacosIcon(CupertinoIcons.chart_bar_alt_fill),
          showLabel: false,
          tooltipMessage: 'Open analytics dashboard',
          onPressed: () => AnalyticsDashboardScreen.show(context),
        ),

        ToolBarIconButton(
          label: 'Minions',
          icon: const MacosIcon(CupertinoIcons.person_add_solid),
          showLabel: false,
          tooltipMessage: 'Manage minion configurations',
          onPressed: () => setState(() => _isMinionSidebarOpen = true),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader(BuildContext context, AppProvider appProvider) {
    final typography = MacosTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Text(
            'Channels',
            style: typography.caption1.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          MacosIconButton(
            onPressed: () async {
              final created = await ChannelFormDialog.show(context);
              if (created != null) {
                _selectChannel(created.id);
              }
            },
            icon: const MacosIcon(CupertinoIcons.add_circled),
            boxConstraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItems(
    BuildContext context,
    ScrollController scrollController,
    AppProvider appProvider,
    ChatProvider chatProvider,
  ) {
    final channels = appProvider.channels;

    if (channels.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        children: const [
          Text(
            'No channels yet. Create one to start coordinating your legion.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    final rawIndex = channels
        .indexWhere((channel) => channel.id == chatProvider.currentChannelId);
    final currentIndex = rawIndex >= 0
        ? rawIndex
        : (channels.isNotEmpty ? 0 : -1);

    return SidebarItems(
      scrollController: scrollController,
      currentIndex: currentIndex,
      onChanged: (index) => _selectChannel(channels[index].id),
      items: [
        for (final channel in channels)
          SidebarItem(
            leading: MacosIcon(
              channel.type == ChannelType.userOnly
                  ? CupertinoIcons.person_crop_circle
                  : CupertinoIcons.chat_bubble,
            ),
            label: Text(
              channel.name,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: channel.isAutoModeActive
                ? const MacosIcon(CupertinoIcons.clock)
                : null,
          ),
      ],
    );
  }

  Widget _buildContentArea(
    BuildContext context,
    AppProvider appProvider,
    ChatProvider chatProvider,
  ) {
    if (!appProvider.isServiceInitialized) {
      return _buildLoadingState(context);
    }

    final currentChannel =
        appProvider.getChannel(chatProvider.currentChannelId ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          SelectionHeader(
            isVisible: chatProvider.isSelectionMode,
            selectedCount: chatProvider.selectedMessageIds.length,
            hasMinions: chatProvider.currentChannelMessages
                .where(
                  (m) => chatProvider.selectedMessageIds.contains(m.id),
                )
                .any(
                  (m) =>
                      m.senderType == MessageSender.ai &&
                      m.internalDiary != null,
                ),
            onDelete: _handleDeleteSelected,
            onShowDiary: _handleToggleDiary,
            onDone: () => chatProvider.toggleSelectionMode(),
          ),
          if (chatProvider.isSelectionMode) const SizedBox(height: 12),
          Expanded(
            child: currentChannel == null
                ? _buildEmptyState(context)
                : _buildChatArea(
                    context,
                    appProvider,
                    chatProvider,
                    currentChannel,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressCircle(radius: 21),
          const SizedBox(height: 18),
          Text(
            'Initializing Legion Command Center…',
            style: typography.headline.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Spinning up MCP hub and calibrating minion diaries.',
            textAlign: TextAlign.center,
            style: typography.subheadline,
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(
    BuildContext context,
    AppProvider appProvider,
    ChatProvider chatProvider,
    Channel currentChannel,
  ) {
    final macosTheme = MacosTheme.of(context);
    final background = macosTheme.brightness == Brightness.dark
        ? const LinearGradient(colors: [
            Color.fromRGBO(37, 37, 37, 1),
            Color.fromRGBO(67, 67, 67, 1),
          ])
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(255, 255, 255, 1),
              Color.fromRGBO(230, 230, 230, 1),
            ],
          );
    final borderColor = macosTheme.dividerColor;
    final messages = chatProvider.currentChannelMessages;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _buildChatHeader(
            context,
            appProvider,
            chatProvider,
            currentChannel,
          ),
          Container(
            height: 1,
            color: borderColor.withValues(alpha: 0.6),
          ),
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(context)
                : _buildMessagesList(
                    context,
                    messages,
                    appProvider,
                    chatProvider,
                  ),
          ),
          Container(
            height: 1,
            color: borderColor.withValues(alpha: 0.6),
          ),
          _buildChatInput(context, chatProvider, currentChannel),
        ],
      ),
    );
  }

  Widget _buildChatHeader(
    BuildContext context,
    AppProvider appProvider,
    ChatProvider chatProvider,
    Channel currentChannel,
  ) {
    final typography = MacosTheme.of(context).typography;
    final channelIcon = currentChannel.type == ChannelType.userOnly
        ? CupertinoIcons.person_badge_plus
        : CupertinoIcons.bubble_left_bubble_right_fill;
    final isAutoChannel =
        currentChannel.type == ChannelType.minionMinionAuto;
    final description = currentChannel.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          MacosIcon(
            channelIcon,
            size: 24,
            color: MacosTheme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentChannel.name,
                  style: typography.title2.copyWith(fontWeight: FontWeight.w600),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: typography.caption1,
                  ),
              ],
            ),
          ),
          if (isAutoChannel) ...[
            Text('Auto', style: typography.caption1),
            const SizedBox(width: 6),
            MacosSwitch(
              value: currentChannel.isAutoModeActive,
              onChanged: (value) async {
                final updated = currentChannel.copyWith(isAutoModeActive: value);
                await _legionService.updateChannel(updated);
                appProvider.updateChannel(updated);
                _rescheduleAutoChat();
              },
            ),
            const SizedBox(width: 12),
          ],
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: () async {
              final edited =
                  await ChannelFormDialog.show(context, initial: currentChannel);
              if (edited != null) {
                _selectChannel(edited.id);
              }
            },
            child: const Text('Edit'),
          ),
          const SizedBox(width: 8),
          MacosSwitch(
            value: chatProvider.isAutoScrollEnabled,
            onChanged: (value) => chatProvider.setAutoScrollEnabled(
              !chatProvider.isAutoScrollEnabled,
            ),
            activeColor: const MacosColor(0xFFFFFFFF),
            trackColor: const MacosColor(0xBFFFFFFF),
            knobColor: MacosColor(MacosTheme.of(context).primaryColor.value),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    final accent =
        MacosTheme.of(context).primaryColor.withValues(alpha: 0.25);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: MacosIcon(
                CupertinoIcons.chat_bubble_2,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: typography.title1.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start commanding your legion.',
            style: typography.subheadline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(
    BuildContext context,
    List<ChatMessage> messages,
    AppProvider appProvider,
    ChatProvider chatProvider,
  ) {
    return MacosScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final minionConfig = appProvider.getMinionConfig(message.senderName);

          return EnhancedChatMessage(
            message: message,
            minionConfig: minionConfig,
            isProcessing: chatProvider.activeMinionProcessors.containsKey(message.senderName) &&
                chatProvider.activeMinionProcessors[message.senderName]!,
            isSelectionMode: chatProvider.isSelectionMode,
            isSelected: chatProvider.selectedMessageIds.contains(message.id),
            isBulkDiaryVisible: chatProvider.bulkDiaryVisible.contains(message.id),
            onEnterSelectionMode: () => chatProvider.toggleSelectionMode(),
            onToggleSelection: _handleToggleSelection,
            onDelete: () async {
              await _legionService.deleteMessage(message.channelId, message.id);
              chatProvider.deleteMessage(message.channelId, message.id);
            },
            onEdit: (newContent) async {
              await _legionService.editMessage(message.channelId, message.id, newContent);
              final updatedMessage = message.copyWith(content: newContent);
              chatProvider.updateMessage(message.channelId, message.id, updatedMessage);
            },
          ).animate()
            .fadeIn(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: (index % 6) * 40),
            )
            .slide(
              begin: const Offset(0, 0.03),
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: (index % 6) * 40),
            );
        },
      ),
    );
  }

  Widget _buildChatInput(
    BuildContext context,
    ChatProvider chatProvider,
    Channel currentChannel,
  ) {
    final disabled = currentChannel.type == ChannelType.minionMinionAuto &&
        currentChannel.isAutoModeActive;
    final isComposing = _inputController.text.trim().isNotEmpty;
    final sendEnabled = isComposing && !chatProvider.isProcessingMessage && !disabled;
    final placeholder = disabled
        ? 'Auto-mode active. Input disabled.'
        : 'Message your legion…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: MacosTextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              placeholder: placeholder,
              enabled: !disabled,
              maxLines: 6,
              minLines: 1,
              decoration: kDefaultRoundedBorderDecoration.copyWith(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MacosTheme.of(context).dividerColor, width: 1),
                color: MacosTheme.of(context).canvasColor,
              ),
              focusedDecoration: kDefaultRoundedBorderDecoration.copyWith(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MacosTheme.of(context).primaryColor, width: 1),
                color: MacosTheme.of(context).canvasColor,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              cursorWidth: 1,
              autocorrect: true,
              autofocus: true,
              enableSuggestions: true,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _attemptSend(currentChannel),
            ),
          ),
          const SizedBox(width: 12),
          if (chatProvider.isProcessingMessage) ...[
            const ProgressCircle(radius: 9),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}
