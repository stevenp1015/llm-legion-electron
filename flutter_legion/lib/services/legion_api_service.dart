import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/channel.dart';
import '../models/minion_config.dart';
import 'mcp_service.dart';

class LegionApiService {
  static const _uuid = Uuid();
  static const String legionCommanderName = 'Commander Steven';

  final McpService _mcpService;
  bool _isInitialized = false;
  
  // Mock data storage (in a real app, this would be a database or API)
  final List<Channel> _channels = [];
  final List<MinionConfig> _minionConfigs = [];
  final Map<String, List<ChatMessage>> _channelMessages = {};

  LegionApiService({McpService? mcpService}) 
    : _mcpService = mcpService ?? McpService();

  bool get isInitialized => _isInitialized;

  /// Initialize the Legion API service
  Future<void> initialize() async {
    try {
      await _mcpService.initialize();
      await _loadMockData();
      _isInitialized = true;
      debugPrint('Legion API Service initialized');
    } catch (e) {
      debugPrint('Failed to initialize Legion API Service: $e');
      rethrow;
    }
  }

  /// Load mock data for demonstration
  Future<void> _loadMockData() async {
    // Create default channel
    final generalChannel = Channel(
      id: _uuid.v4(),
      name: '#general',
      description: 'Main command center channel',
      type: ChannelType.userMinionGroup,
      members: [legionCommanderName, 'Assistant Alpha', 'Code Reviewer Beta'],
    );
    _channels.add(generalChannel);

    // Create auto-chat channel
    final autoChatChannel = Channel(
      id: _uuid.v4(),
      name: '#minion-debate',
      description: 'Autonomous minion discussion',
      type: ChannelType.minionMinionAuto,
      members: ['Assistant Alpha', 'Code Reviewer Beta', 'Creative Gamma'],
      isAutoModeActive: false,
      autoModeDelayType: 'random',
      autoModeRandomDelay: const AutoModeDelay(min: 3, max: 8),
    );
    _channels.add(autoChatChannel);

    // Create sample minion configurations
    _minionConfigs.addAll([
      MinionConfig(
        id: _uuid.v4(),
        name: 'Assistant Alpha',
        role: 'primary-assistant',
        systemPrompt: 'You are Assistant Alpha, a helpful and efficient AI assistant focused on providing clear, accurate responses.',
        model: 'claude-3-sonnet-20240229',
        apiKeyId: 'default-anthropic',
        chatColor: '#3B82F6',
        fontColor: '#FFFFFF',
        temperature: 0.7,
        maxTokens: 2000,
        usageStats: const UsageStats(
          totalTokens: 12500,
          totalRequests: 45,
          totalCost: 125,
          lastUsed: null,
        ),
      ),
      MinionConfig(
        id: _uuid.v4(),
        name: 'Code Reviewer Beta',
        role: 'code-reviewer',
        systemPrompt: 'You are Code Reviewer Beta, specialized in analyzing code quality, security, and best practices.',
        model: 'claude-3-sonnet-20240229',
        apiKeyId: 'default-anthropic',
        chatColor: '#EF4444',
        fontColor: '#FFFFFF',
        temperature: 0.3,
        maxTokens: 3000,
        usageStats: const UsageStats(
          totalTokens: 8750,
          totalRequests: 23,
          totalCost: 87,
          lastUsed: null,
        ),
      ),
      MinionConfig(
        id: _uuid.v4(),
        name: 'Creative Gamma',
        role: 'creative-assistant',
        systemPrompt: 'You are Creative Gamma, focused on brainstorming, creative writing, and innovative solutions.',
        model: 'claude-3-sonnet-20240229',
        apiKeyId: 'default-anthropic',
        chatColor: '#10B981',
        fontColor: '#FFFFFF',
        temperature: 0.9,
        maxTokens: 2500,
      ),
    ]);

    // Add some sample messages
    final welcomeMessage = ChatMessage(
      id: _uuid.v4(),
      channelId: generalChannel.id,
      senderType: MessageSender.system,
      senderName: 'System',
      content: 'Welcome to Legion Command Center! Your Flutter version is online and ready for action.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );

    _channelMessages[generalChannel.id] = [welcomeMessage];
  }

  // Channel Management
  Future<List<Channel>> getChannels() async {
    return List.from(_channels);
  }

  Future<Channel> addOrUpdateChannel(Map<String, dynamic> channelData) async {
    final channel = Channel(
      id: channelData['id'] ?? _uuid.v4(),
      name: channelData['name'],
      description: channelData['description'] ?? '',
      type: _parseChannelType(channelData['type']),
      members: List<String>.from(channelData['members']),
      isAutoModeActive: channelData['isAutoModeActive'] ?? false,
      autoModeDelayType: channelData['autoModeDelayType'] ?? 'fixed',
      autoModeFixedDelay: channelData['autoModeFixedDelay'],
      autoModeRandomDelay: channelData['autoModeRandomDelay'] != null 
        ? AutoModeDelay.fromJson(channelData['autoModeRandomDelay'])
        : null,
    );

    final existingIndex = _channels.indexWhere((c) => c.id == channel.id);
    if (existingIndex != -1) {
      _channels[existingIndex] = channel;
    } else {
      _channels.add(channel);
    }

    return channel;
  }

  // Minion Management
  Future<List<MinionConfig>> getMinions() async {
    return List.from(_minionConfigs);
  }

  Future<MinionConfig> addMinion(MinionConfig config) async {
    final newConfig = config.copyWith(id: config.id.isEmpty ? _uuid.v4() : config.id);
    _minionConfigs.add(newConfig);
    return newConfig;
  }

  Future<MinionConfig> updateMinion(MinionConfig config) async {
    final index = _minionConfigs.indexWhere((m) => m.id == config.id);
    if (index != -1) {
      _minionConfigs[index] = config;
      return config;
    }
    throw Exception('Minion not found: ${config.id}');
  }

  Future<void> deleteMinion(String id) async {
    _minionConfigs.removeWhere((m) => m.id == id);
  }

  // Message Management
  Future<MessageResult> getMessages(String channelId, int limit, [String? beforeMessageId]) async {
    final messages = _channelMessages[channelId] ?? [];
    
    int startIndex = 0;
    if (beforeMessageId != null) {
      final beforeIndex = messages.indexWhere((m) => m.id == beforeMessageId);
      if (beforeIndex > 0) {
        startIndex = max(0, beforeIndex - limit);
      }
    }

    final endIndex = beforeMessageId != null 
      ? messages.indexWhere((m) => m.id == beforeMessageId)
      : messages.length;

    final resultMessages = messages.sublist(startIndex, min(endIndex, startIndex + limit));
    final hasMore = startIndex > 0;

    return MessageResult(
      messages: resultMessages,
      hasMore: hasMore,
    );
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      messages.removeWhere((m) => m.id == messageId);
    }
  }

  Future<void> editMessage(String channelId, String messageId, String newContent) async {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = messages[index].copyWith(content: newContent);
      }
    }
  }

  /// Process a message turn with streaming responses
  Future<void> processMessageTurn({
    required String channelId,
    required ChatMessage triggeringMessage,
    required Function(ChatMessage) onMinionResponse,
    required Function(String, String, String) onMinionResponseChunk,
    required Function(String, bool) onMinionProcessingUpdate,
    required Function(ChatMessage) onSystemMessage,
    required Function(ChatMessage) onRegulatorReport,
    required Function(ChatMessage) onToolUpdate,
  }) async {
    // Add the triggering message to storage
    _channelMessages.putIfAbsent(channelId, () => []);
    _channelMessages[channelId]!.add(triggeringMessage);

    final channel = _channels.firstWhere((c) => c.id == channelId);
    final eligibleMinions = _minionConfigs
        .where((m) => channel.members.contains(m.name) && m.enabled)
        .toList();

    if (eligibleMinions.isEmpty) {
      final systemMessage = ChatMessage(
        id: _uuid.v4(),
        channelId: channelId,
        senderType: MessageSender.system,
        senderName: 'System',
        content: 'No active minions found in this channel.',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      onSystemMessage(systemMessage);
      return;
    }

    // Process each eligible minion
    for (final minion in eligibleMinions) {
      onMinionProcessingUpdate(minion.name, true);
      
      try {
        await _generateMinionResponse(
          minion,
          channelId,
          triggeringMessage,
          onMinionResponse,
          onMinionResponseChunk,
          onToolUpdate,
        );
      } catch (e) {
        debugPrint('Error processing minion ${minion.name}: $e');
        final errorMessage = ChatMessage(
          id: _uuid.v4(),
          channelId: channelId,
          senderType: MessageSender.system,
          senderName: 'System',
          content: 'Error processing response from ${minion.name}: $e',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        onSystemMessage(errorMessage);
      } finally {
        onMinionProcessingUpdate(minion.name, false);
      }
    }
  }

  /// Generate a simulated minion response with streaming
  Future<void> _generateMinionResponse(
    MinionConfig minion,
    String channelId,
    ChatMessage triggeringMessage,
    Function(ChatMessage) onMinionResponse,
    Function(String, String, String) onMinionResponseChunk,
    Function(ChatMessage) onToolUpdate,
  ) async {
    final messageId = _uuid.v4();
    final responses = [
      'I understand your request. Let me help you with that.',
      'That\'s an interesting question! Here\'s what I think...',
      'Based on my analysis, I would recommend the following approach:',
      'I\'ve reviewed the information and here are my thoughts:',
      'Let me break this down for you step by step:',
    ];

    final selectedResponse = responses[Random().nextInt(responses.length)];
    
    // Create initial message
    final initialMessage = ChatMessage(
      id: messageId,
      channelId: channelId,
      senderType: MessageSender.ai,
      senderName: minion.name,
      senderRole: minion.role,
      content: '',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      chatColor: minion.chatColor,
      fontColor: minion.fontColor,
      isStreaming: true,
    );

    onMinionResponse(initialMessage);

    // Simulate streaming response
    final words = selectedResponse.split(' ');
    for (int i = 0; i < words.length; i++) {
      await Future.delayed(Duration(milliseconds: 50 + Random().nextInt(100)));
      final chunk = i == 0 ? words[i] : ' ${words[i]}';
      onMinionResponseChunk(channelId, messageId, chunk);
    }

    // Finalize message
    final finalMessage = initialMessage.copyWith(
      content: selectedResponse,
      isStreaming: false,
    );
    onMinionResponse(finalMessage);

    // Store in local messages
    _channelMessages[channelId]!.add(finalMessage);
  }

  /// Trigger next auto-chat turn for minion-to-minion channels
  Future<void> triggerNextAutoChatTurn(
    String channelId,
    Function(ChatMessage) onMinionResponse,
    Function(String, String, String) onMinionResponseChunk,
    Function(String, bool) onMinionProcessingUpdate,
    Function(ChatMessage) onSystemMessage,
    Function(ChatMessage) onRegulatorReport,
    Function(ChatMessage) onToolUpdate,
  ) async {
    final channel = _channels.firstWhere((c) => c.id == channelId);
    if (channel.type != ChannelType.minionMinionAuto) return;

    final eligibleMinions = _minionConfigs
        .where((m) => channel.members.contains(m.name) && m.enabled)
        .toList();

    if (eligibleMinions.isEmpty) return;

    // Select a random minion to respond
    final selectedMinion = eligibleMinions[Random().nextInt(eligibleMinions.length)];

    // Create a synthetic trigger message
    final triggerMessage = ChatMessage(
      id: _uuid.v4(),
      channelId: channelId,
      senderType: MessageSender.system,
      senderName: 'Auto-Chat System',
      content: '[Auto-chat continuation]',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    onMinionProcessingUpdate(selectedMinion.name, true);

    try {
      await _generateMinionResponse(
        selectedMinion,
        channelId,
        triggerMessage,
        onMinionResponse,
        onMinionResponseChunk,
        onToolUpdate,
      );
    } finally {
      onMinionProcessingUpdate(selectedMinion.name, false);
    }
  }

  /// Clean up old messages to prevent memory bloat
  Future<void> cleanupOldMessages(String channelId, int keepCount) async {
    final messages = _channelMessages[channelId];
    if (messages != null && messages.length > keepCount) {
      final messagesToKeep = messages.skip(messages.length - keepCount).toList();
      _channelMessages[channelId] = messagesToKeep;
    }
  }

  // Helper methods
  ChannelType _parseChannelType(String? type) {
    switch (type) {
      case 'user_minion_group':
        return ChannelType.userMinionGroup;
      case 'minion_minion_auto':
        return ChannelType.minionMinionAuto;
      case 'user_only':
        return ChannelType.userOnly;
      default:
        return ChannelType.userMinionGroup;
    }
  }

  /// Mock API key management (in a real app, these would be encrypted)
  Future<List<ApiKey>> getApiKeys() async {
    return [
      const ApiKey(id: 'default-anthropic', name: 'Anthropic API', keyPreview: 'sk-ant-***'),
      const ApiKey(id: 'default-openai', name: 'OpenAI API', keyPreview: 'sk-***'),
    ];
  }

  Future<void> addApiKey(String name, String key) async {
    // Implementation would store encrypted key
  }

  Future<void> deleteApiKey(String id) async {
    // Implementation would remove key
  }

  // Mock model options
  Future<List<ModelOption>> getModelOptions() async {
    return [
      const ModelOption(id: 'claude-3-sonnet-20240229', name: 'Claude 3 Sonnet', provider: 'anthropic'),
      const ModelOption(id: 'claude-3-haiku-20240307', name: 'Claude 3 Haiku', provider: 'anthropic'),
      const ModelOption(id: 'gpt-4-turbo-preview', name: 'GPT-4 Turbo', provider: 'openai'),
      const ModelOption(id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', provider: 'openai'),
    ];
  }

  void dispose() {
    _mcpService.dispose();
  }
}

class MessageResult {
  final List<ChatMessage> messages;
  final bool hasMore;

  const MessageResult({required this.messages, required this.hasMore});
}

class ApiKey {
  final String id;
  final String name;
  final String keyPreview;

  const ApiKey({required this.id, required this.name, required this.keyPreview});
}

class ModelOption {
  final String id;
  final String name;
  final String provider;

  const ModelOption({required this.id, required this.name, required this.provider});
}