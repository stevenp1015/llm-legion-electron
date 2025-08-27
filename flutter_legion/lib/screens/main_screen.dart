import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../services/legion_api_service.dart';
import '../models/chat_message.dart';
import '../models/channel.dart';
import '../widgets/chat/chat_message_widget.dart';
import '../widgets/chat/chat_input_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late LegionApiService _legionService;
  String? _currentChannelId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _legionService = context.read<LegionApiService>();
    final appProvider = context.read<AppProvider>();
    final chatProvider = context.read<ChatProvider>();

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
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage(String content) async {
    if (_currentChannelId == null) return;
    
    final chatProvider = context.read<ChatProvider>();
    final appProvider = context.read<AppProvider>();
    
    // Create and add user message
    final userMessage = chatProvider.createUserMessage(
      _currentChannelId!,
      content,
      LegionApiService.legionCommanderName,
    );
    
    chatProvider.addMessage(_currentChannelId!, userMessage);
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && chatProvider.isAutoScrollEnabled) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Process message through Legion API
    await _legionService.processMessageTurn(
      channelId: _currentChannelId!,
      triggeringMessage: userMessage,
      onMinionResponse: (message) {
        chatProvider.upsertMessage(message);
        _autoScrollIfEnabled();
      },
      onMinionResponseChunk: (channelId, messageId, chunk) {
        chatProvider.processMessageChunk(channelId, messageId, chunk);
        _autoScrollIfEnabled();
      },
      onMinionProcessingUpdate: (minionName, isProcessing) {
        chatProvider.setActiveMinionProcessor(minionName, isProcessing);
      },
      onSystemMessage: (message) {
        chatProvider.addMessage(message.channelId, message);
        _autoScrollIfEnabled();
      },
      onRegulatorReport: (message) {
        chatProvider.addMessage(message.channelId, message);
        _autoScrollIfEnabled();
      },
      onToolUpdate: (message) {
        chatProvider.upsertMessage(message);
        _autoScrollIfEnabled();
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<AppProvider, ChatProvider>(
        builder: (context, appProvider, chatProvider, child) {
          if (!appProvider.isServiceInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing Legion Service...'),
                ],
              ),
            );
          }

          final currentChannel = appProvider.getChannel(chatProvider.currentChannelId ?? '');
          final messages = chatProvider.currentChannelMessages;

          return Column(
            children: [
              // Header
              _buildHeader(appProvider, chatProvider),
              
              // Channel info bar
              if (currentChannel != null) _buildChannelInfo(currentChannel),
              
              // Messages area
              Expanded(
                child: messages.isEmpty 
                  ? _buildEmptyState()
                  : _buildMessagesList(messages, appProvider, chatProvider),
              ),
              
              // Input area
              if (currentChannel != null)
                ChatInputWidget(
                  onSendMessage: _sendMessage,
                  isSending: chatProvider.isProcessingMessage,
                  disabled: currentChannel.type == ChannelType.minionMinionAuto && 
                           currentChannel.isAutoModeActive,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppProvider appProvider, ChatProvider chatProvider) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(100),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // App icon and title
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(50),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.military_tech,
              color: Colors.white,
              size: 24,
            ),
          ).animate()
            .rotate(duration: 2000.ms, curve: Curves.easeInOut)
            .then()
            .shimmer(duration: 1500.ms),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LLM Legion Command Center',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Flutter Edition • Commander: ${LegionApiService.legionCommanderName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Controls
          Row(
            children: [
              IconButton(
                onPressed: () {
                  chatProvider.setAutoScrollEnabled(!chatProvider.isAutoScrollEnabled);
                },
                icon: Icon(
                  chatProvider.isAutoScrollEnabled 
                    ? Icons.keyboard_double_arrow_down
                    : Icons.keyboard_arrow_up,
                  color: chatProvider.isAutoScrollEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(150),
                ),
                tooltip: chatProvider.isAutoScrollEnabled 
                  ? 'Auto-scroll enabled'
                  : 'Auto-scroll disabled',
              ),
              IconButton(
                onPressed: () {
                  // TODO: Open analytics
                },
                icon: Icon(
                  Icons.analytics,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
                tooltip: 'Analytics Dashboard',
              ),
              IconButton(
                onPressed: () {
                  // TODO: Open MCP manager
                },
                icon: Icon(
                  Icons.settings,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
                tooltip: 'MCP Server Manager',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelInfo(channel) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(100),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            channel.type == ChannelType.minionMinionAuto
              ? Icons.smart_toy
              : Icons.forum,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  channel.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          if (channel.type == ChannelType.minionMinionAuto) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: channel.isAutoModeActive
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                channel.isAutoModeActive ? 'AUTO ACTIVE' : 'AUTO PAUSED',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: channel.isAutoModeActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 800.ms)
      .moveY(begin: 20, duration: 800.ms, curve: Curves.easeOut);
  }

  Widget _buildMessagesList(
    List<ChatMessage> messages,
    AppProvider appProvider,
    ChatProvider chatProvider,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final minionConfig = appProvider.getMinionConfig(message.senderName);
        
        return ChatMessageWidget(
          message: message,
          minionConfig: minionConfig,
          isProcessing: chatProvider.activeMinionProcessors.containsKey(message.senderName) &&
                       chatProvider.activeMinionProcessors[message.senderName]!,
          isSelectionMode: chatProvider.isSelectionMode,
          isSelected: chatProvider.selectedMessageIds.contains(message.id),
          isBulkDiaryVisible: chatProvider.bulkDiaryVisible.contains(message.id),
          onEnterSelectionMode: () => chatProvider.toggleSelectionMode(),
          onToggleSelection: (shiftKey) => {
            // TODO: Implement selection logic
          },
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
          .fadeIn(duration: 400.ms, delay: (index * 50).ms)
          .moveY(begin: 10, duration: 400.ms, curve: Curves.easeOut);
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}