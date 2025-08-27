/// Enhanced main screen with sophisticated UX and Vista aero effects
/// The complete transformation of your React masterpiece into Flutter glory
/// 
/// Features: selection system, Vista glass, morphing channels, animated everything

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../services/legion_api_service.dart';
import '../models/chat_message.dart';
import '../models/channel.dart';
import '../widgets/chat/enhanced_chat_message.dart';
import '../widgets/common/minion_avatar.dart';
import '../widgets/common/animated_send_button.dart';
import '../widgets/common/selection_header.dart';
import '../widgets/common/morphing_channel_list.dart';
import '../widgets/common/auto_hiding_scrollbar.dart';
import '../theming/vista_effects.dart';
import '../animations/config.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
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
      
      // Smooth scroll to bottom with Vista animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: SpringConfig.slideDuration,
            curve: SpringConfig.slide,
          );
        }
      });
    }
  }

  Future<void> _sendMessage(String content) async {
    if (_currentChannelId == null || content.trim().isEmpty) return;
    
    final chatProvider = context.read<ChatProvider>();
    
    // Create and add user message
    final userMessage = chatProvider.createUserMessage(
      _currentChannelId!,
      content.trim(),
      LegionApiService.legionCommanderName,
    );
    
    chatProvider.addMessage(_currentChannelId!, userMessage);
    _inputController.clear();
    
    // Auto-scroll to bottom
    _autoScrollIfEnabled();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer2<AppProvider, ChatProvider>(
        builder: (context, appProvider, chatProvider, child) {
          if (!appProvider.isServiceInitialized) {
            return _buildLoadingState(context);
          }

          return Stack(
            children: [
              // Main content with Vista glass effect
              Row(
                children: [
                  // Channel sidebar
                  MorphingChannelList(
                    channels: appProvider.channels,
                    currentChannelId: chatProvider.currentChannelId,
                    onChannelSelected: _selectChannel,
                    onEditChannel: (channel) {
                      // TODO: Open channel edit dialog
                    },
                    onCreateChannel: () {
                      // TODO: Open channel creation dialog
                    },
                  ),
                  
                  // Main chat area
                  Expanded(
                    child: VistaGlass(
                      opacity: 0.95,
                      blurIntensity: 12.0,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: _buildChatArea(context, appProvider, chatProvider),
                    ),
                  ),
                ],
              ),
              
              // Floating selection header
              SelectionHeader(
                isVisible: chatProvider.isSelectionMode,
                selectedCount: chatProvider.selectedMessageIds.length,
                hasMinions: chatProvider.currentChannelMessages
                    .where((m) => chatProvider.selectedMessageIds.contains(m.id))
                    .any((m) => m.senderType == MessageSender.ai && m.internalDiary != null),
                onDelete: _handleDeleteSelected,
                onShowDiary: _handleToggleDiary,
                onDone: () => chatProvider.toggleSelectionMode(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: VistaGlass(
        opacity: 0.9,
        blurIntensity: 15.0,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom spinning icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.military_tech,
                  color: Colors.white,
                  size: 32,
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: const Duration(seconds: 3))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.1, 1.1),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                )
                .then()
                .scale(
                  begin: const Offset(1.1, 1.1),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                ),
              
              const SizedBox(height: 24),
              
              Text(
                'Initializing Legion Command Center',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Preparing your minions for battle...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ).animate()
        .fadeIn(
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        )
        .scale(
          begin: const Offset(0.8, 0.8),
          duration: SpringConfig.bouncyDuration,
          curve: SpringConfig.bouncy,
        ),
    );
  }

  Widget _buildChatArea(BuildContext context, AppProvider appProvider, ChatProvider chatProvider) {
    final currentChannel = appProvider.getChannel(chatProvider.currentChannelId ?? '');
    final messages = chatProvider.currentChannelMessages;

    return Column(
      children: [
        // Chat header
        _buildChatHeader(context, appProvider, chatProvider, currentChannel),
        
        // Messages area
        Expanded(
          child: messages.isEmpty 
              ? _buildEmptyState(context)
              : _buildMessagesList(context, messages, appProvider, chatProvider),
        ),
        
        // Input area
        if (currentChannel != null)
          _buildChatInput(context, chatProvider, currentChannel),
      ],
    );
  }

  Widget _buildChatHeader(BuildContext context, AppProvider appProvider, ChatProvider chatProvider, Channel? currentChannel) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // App icon and title
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.military_tech,
              color: Colors.white,
              size: 28,
            ),
          ).animate()
            .rotate(
              begin: 0,
              end: 0.05,
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
            )
            .then()
            .rotate(
              begin: 0.05,
              end: -0.05,
              duration: const Duration(milliseconds: 4000),
              curve: Curves.easeInOut,
            )
            .then()
            .rotate(
              begin: -0.05,
              end: 0,
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
            ),
          
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LLM Legion Command Center',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Text(
                      'Flutter Edition',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Text(
                      'Commander: ${LegionApiService.legionCommanderName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Controls
          Row(
            children: [
              VistaTooltip(
                message: chatProvider.isAutoScrollEnabled 
                    ? 'Auto-scroll enabled'
                    : 'Auto-scroll disabled',
                child: VistaButton(
                  onPressed: () => chatProvider.setAutoScrollEnabled(!chatProvider.isAutoScrollEnabled),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    chatProvider.isAutoScrollEnabled 
                        ? Icons.keyboard_double_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              VistaTooltip(
                message: 'Analytics Dashboard',
                child: VistaButton(
                  onPressed: () {
                    // TODO: Open analytics
                  },
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.analytics,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              VistaTooltip(
                message: 'MCP Server Manager',
                child: VistaButton(
                  onPressed: () {
                    // TODO: Open MCP manager
                  },
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.settings,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.2),
                  theme.colorScheme.secondary.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'No messages yet',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w300,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Send a message to start commanding your legion',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate()
      .fadeIn(
        duration: const Duration(milliseconds: 800),
        curve: SpringConfig.gentle,
      )
      .moveY(
        begin: 40,
        duration: const Duration(milliseconds: 800),
        curve: SpringConfig.gentle,
      );
  }

  Widget _buildMessagesList(BuildContext context, List<ChatMessage> messages, AppProvider appProvider, ChatProvider chatProvider) {
    return VistaScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
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
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: index * 50),
              curve: SpringConfig.gentle,
            )
            .moveY(
              begin: 20,
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: index * 50),
              curve: SpringConfig.gentle,
            );
        },
      ),
    );
  }

  Widget _buildChatInput(BuildContext context, ChatProvider chatProvider, Channel currentChannel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !(currentChannel.type == ChannelType.minionMinionAuto && 
                               currentChannel.isAutoModeActive),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: (currentChannel.type == ChannelType.minionMinionAuto && 
                                  currentChannel.isAutoModeActive)
                            ? 'Auto-mode active. Input disabled.'
                            : 'Message your legion...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      cursorColor: const Color(0xFFF59E0B), // Amber cursor
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          AnimatedSendButton(
            onPressed: () => _sendMessage(_inputController.text),
            isSending: chatProvider.isProcessingMessage,
            isEnabled: _inputController.text.trim().isNotEmpty &&
                      !(currentChannel.type == ChannelType.minionMinionAuto && 
                        currentChannel.isAutoModeActive),
            size: 56,
          ),
        ],
      ),
    );
  }
}