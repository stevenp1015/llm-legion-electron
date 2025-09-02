import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/channel.dart';
import '../models/minion_config.dart';
import '../models/prompt_preset.dart';
import 'mcp_service.dart';
import 'storage_service.dart';

class LegionApiService {
  static const _uuid = Uuid();
  static const String legionCommanderName = 'Commander Steven';
  static const String _llmBaseUrl = 'https://litellm-213047501466.us-east4.run.app';

  final McpService _mcpService;
  final StorageService _storage;
  final http.Client _httpClient = http.Client();
  bool _isInitialized = false;
  // Cached metadata
  List<ModelOption> _modelOptionsCache = const [];
  List<PromptPreset> _promptPresets = const [];
  
  // Mock data storage (in a real app, this would be a database or API)
  final List<Channel> _channels = [];
  final List<MinionConfig> _minionConfigs = [];
  final Map<String, List<ChatMessage>> _channelMessages = {};

  LegionApiService({McpService? mcpService, StorageService? storage})
      : _mcpService = mcpService ?? McpService(),
        _storage = storage ?? StorageService();

  bool get isInitialized => _isInitialized;

  /// Initialize the Legion API service
  Future<void> initialize() async {
    try {
      await _storage.init();
      await _mcpService.initialize();
      await _loadOrBootstrapData();
      // Load cached metadata
      _promptPresets = (await _storage.loadPromptPresets())
          .map(PromptPreset.fromJson)
          .toList();
      final modelIds = await _storage.loadModelList();
      if (modelIds.isNotEmpty) {
        _modelOptionsCache = modelIds.map((id) => ModelOption(id: id, name: id, provider: 'unknown')).toList();
      }
      _isInitialized = true;
      debugPrint('Legion API Service initialized');
    } catch (e) {
      debugPrint('Failed to initialize Legion API Service: $e');
      rethrow;
    }
  }

  /// Load stored data or bootstrap with mock data
  Future<void> _loadOrBootstrapData() async {
    // Try to load from storage first
    try {
      final storedChannels = await _storage.loadChannels();
      final storedMinions = await _storage.loadMinions();
      if (storedChannels.isNotEmpty && storedMinions.isNotEmpty) {
        _channels
          ..clear()
          ..addAll(storedChannels);
        _minionConfigs
          ..clear()
          ..addAll(storedMinions);
        // Messages are loaded on demand per channel
        return;
      }
    } catch (_) {}

    // Bootstrap with mock data when storage is empty
    // Create default channel
    final generalChannel = Channel(
      id: _uuid.v4(),
      name: '#general',
      description: 'Main command center channel',
      type: ChannelType.userMinionGroup,
      members: [legionCommanderName, 'Assistant Alpha', 'Code Reviewer Beta'],
    );
    _channels.add(generalChannel);
    await _storage.saveChannel(generalChannel);

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
    await _storage.saveChannel(autoChatChannel);

    // Create sample minion configurations
    final bootstrapMinions = [
      MinionConfig(
        id: _uuid.v4(),
        name: 'Assistant Alpha',
        role: 'primary-assistant',
        systemPrompt: 'You are Assistant Alpha, a helpful and efficient AI assistant focused on providing clear, accurate responses.',
        model: 'gemini-2.5-flash',
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
        model: 'gemini-2.5-flash',
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
    ];
    _minionConfigs.addAll(bootstrapMinions);
    for (final m in bootstrapMinions) {
      await _storage.saveMinion(m);
    }

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
    await _storage.setMessages(generalChannel.id, _channelMessages[generalChannel.id]!);
  }

  // Channel Management
  Future<List<Channel>> getChannels() async {
    // Ensure channels are synced from storage if empty
    if (_channels.isEmpty) {
      final stored = await _storage.loadChannels();
      _channels.addAll(stored);
    }
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
    await _storage.saveChannel(channel);
    return channel;
  }

  /// Update an existing channel by object and return the updated instance
  Future<Channel> updateChannel(Channel channel) async {
    final index = _channels.indexWhere((c) => c.id == channel.id);
    if (index != -1) {
      _channels[index] = channel;
      return channel;
    }
    // If it's new, add it (parity with addOrUpdate)
    _channels.add(channel);
    return channel;
  }

  // Minion Management
  Future<List<MinionConfig>> getMinions() async {
    if (_minionConfigs.isEmpty) {
      final stored = await _storage.loadMinions();
      _minionConfigs.addAll(stored);
    }
    return List.from(_minionConfigs);
  }

  Future<MinionConfig> addMinion(MinionConfig config) async {
    final newConfig = config.copyWith(id: config.id.isEmpty ? _uuid.v4() : config.id);
    _minionConfigs.add(newConfig);
    await _storage.saveMinion(newConfig);
    return newConfig;
  }

  Future<MinionConfig> updateMinion(MinionConfig config) async {
    final index = _minionConfigs.indexWhere((m) => m.id == config.id);
    if (index != -1) {
      _minionConfigs[index] = config;
      await _storage.saveMinion(config);
      return config;
    }
    throw Exception('Minion not found: ${config.id}');
  }

  Future<void> deleteMinion(String id) async {
    _minionConfigs.removeWhere((m) => m.id == id);
    await _storage.removeMinion(id);
  }

  // Message Management
  Future<MessageResult> getMessages(String channelId, int limit, [String? beforeMessageId]) async {
    if (!_channelMessages.containsKey(channelId)) {
      final stored = await _storage.loadMessages(channelId);
      _channelMessages[channelId] = stored;
    }
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
      await _storage.deleteMessage(channelId, messageId);
    }
  }

  Future<void> editMessage(String channelId, String messageId, String newContent) async {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = messages[index].copyWith(content: newContent);
        await _storage.upsertMessage(channelId, messages[index]);
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
    await _storage.appendMessage(channelId, triggeringMessage);

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

    // Process each eligible minion via agent loop (Stage 1 + Stage 2)
    for (final minion in eligibleMinions) {
      onMinionProcessingUpdate(minion.name, true);

      try {
        await _runAgentLoop(
          minion: minion,
          channelId: channelId,
          triggeringMessage: triggeringMessage,
          onMinionResponse: onMinionResponse,
          onMinionResponseChunk: onMinionResponseChunk,
          onMinionProcessingUpdate: onMinionProcessingUpdate,
          onSystemMessage: onSystemMessage,
          onToolUpdate: onToolUpdate,
        );
      } catch (e) {
        debugPrint('Error in agent loop for ${minion.name}: $e');
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

  /// Stream an actual LLM response from LiteLLM (OpenAI-compatible SSE)
  Future<void> _streamMinionResponse({
    required MinionConfig minion,
    required String channelId,
    required ChatMessage triggeringMessage,
    required Function(ChatMessage) onMinionResponse,
    required Function(String, String, String) onMinionResponseChunk,
    required Function(ChatMessage) onToolUpdate,
    Map<String, dynamic>? internalDiary,
  }) async {
    final messageId = _uuid.v4();

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
      internalDiary: internalDiary,
    );
    onMinionResponse(initialMessage);

    // Build minimal chat history (system + last few exchanges)
    final fullHistory = (_channelMessages[channelId] ?? []);
    final history = fullHistory.length > 8
        ? fullHistory.sublist(fullHistory.length - 8)
        : List<ChatMessage>.from(fullHistory);
    final messagesPayload = <Map<String, dynamic>>[
      if ((minion.systemPrompt).trim().isNotEmpty)
        {'role': 'system', 'content': minion.systemPrompt},
      ...history.map((m) {
        String role;
        switch (m.senderType) {
          case MessageSender.user:
            role = 'user';
            break;
          case MessageSender.ai:
            role = 'assistant';
            break;
          case MessageSender.system:
            role = 'system';
            break;
        }
        return {'role': role, 'content': m.content};
      }),
      {'role': 'user', 'content': triggeringMessage.content},
    ];

    final uri = Uri.parse('$_llmBaseUrl/chat/completions');
    final req = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': minion.model,
        'messages': messagesPayload,
        'stream': true,
        'temperature': minion.temperature,
        'max_tokens': minion.maxTokens,
      });

    String aggregate = '';
    try {
      final streamed = await _httpClient.send(req);
      final stream = streamed.stream.transform(utf8.decoder);

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk);
        var text = buffer.toString();
        int idx;
        while ((idx = text.indexOf('\n\n')) != -1) {
          final event = text.substring(0, idx);
          text = text.substring(idx + 2);
          for (final line in event.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (!trimmed.startsWith('data:')) continue;
            final data = trimmed.substring(5).trim();
            if (data == '[DONE]') {
              break;
            }
            try {
              final obj = jsonDecode(data) as Map<String, dynamic>;
              final choices = obj['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = (choices[0] as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  aggregate += content;
                  onMinionResponseChunk(channelId, messageId, content);
                }
              }
            } catch (_) {
              // Ignore malformed chunks
            }
          }
        }
        buffer
          ..clear()
          ..write(text);
      }
    } catch (e) {
      // Fallback: produce a short error message via system
      final err = ChatMessage(
        id: _uuid.v4(),
        channelId: channelId,
        senderType: MessageSender.system,
        senderName: 'System',
        content: 'LLM streaming failed for ${minion.name}: $e',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isError: true,
      );
      onToolUpdate(err);
    }

    // Parse optional color tag and update minion colors
    final parsed = _extractColorsAndStrip(aggregate.trim());
    if (parsed.chatColor != null || parsed.fontColor != null) {
      try {
        final idx = _minionConfigs.indexWhere((m) => m.id == minion.id);
        if (idx != -1) {
          final updated = _minionConfigs[idx].copyWith(
            chatColor: parsed.chatColor ?? _minionConfigs[idx].chatColor,
            fontColor: parsed.fontColor ?? _minionConfigs[idx].fontColor,
          );
          _minionConfigs[idx] = updated;
          await _storage.saveMinion(updated);
        }
      } catch (_) {}
    }

    final finalMessage = initialMessage.copyWith(
      content: parsed.content,
      isStreaming: false,
    );
    onMinionResponse(finalMessage);
    _channelMessages.putIfAbsent(channelId, () => []);
    _channelMessages[channelId]!.add(finalMessage);
    await _storage.appendMessage(channelId, finalMessage);
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
      await _runAgentLoop(
        minion: selectedMinion,
        channelId: channelId,
        triggeringMessage: triggerMessage,
        onMinionResponse: onMinionResponse,
        onMinionResponseChunk: onMinionResponseChunk,
        onMinionProcessingUpdate: onMinionProcessingUpdate,
        onSystemMessage: onSystemMessage,
        onToolUpdate: onToolUpdate,
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

  Future<List<ModelOption>> getModelOptions({bool refresh = false}) async {
    if (!refresh && _modelOptionsCache.isNotEmpty) return _modelOptionsCache;
    try {
      final uri = Uri.parse('${LegionApiService._llmBaseUrl}/models');
      final resp = await _httpClient.get(uri, headers: {'Content-Type': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final models = (data['data'] as List).map((e) => e['id'] as String).toList();
        models.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _modelOptionsCache = models.map((id) => ModelOption(id: id, name: id, provider: 'unknown')).toList();
        await _storage.saveModelList(models);
      }
    } catch (_) {}
    if (_modelOptionsCache.isEmpty) {
      _modelOptionsCache = const [
        ModelOption(id: 'claude-3-sonnet-20240229', name: 'Claude 3 Sonnet', provider: 'anthropic'),
        ModelOption(id: 'gemini-2.5-flash', name: 'Gemini 2.5 Flash', provider: 'LiteLLM'),
        ModelOption(id: 'azure-gpt4o', name: 'GPT-4o', provider: 'Azure'),
        ModelOption(id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', provider: 'openai'),
      ];
    }
    return _modelOptionsCache;
  }

  Future<void> refreshModelsFromLiteLLM() async {
    await getModelOptions(refresh: true);
  }

  // Prompt presets
  Future<List<PromptPreset>> getPromptPresets() async => List<PromptPreset>.from(_promptPresets);
  Future<void> addPromptPreset(String name, String content) async {
    final preset = PromptPreset(id: _uuid.v4(), name: name, content: content);
    _promptPresets = [..._promptPresets, preset];
    await _storage.savePromptPreset(preset.toJson());
  }
  Future<void> deletePromptPreset(String id) async {
    _promptPresets = _promptPresets.where((p) => p.id != id).toList();
    await _storage.deletePromptPreset(id);
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

// Public exposure for MCP tool map (for config UI)
extension LegionMcpExposure on LegionApiService {
  Future<Map<String, List<McpTool>>> getAvailableToolsByServer() async {
    // Return a copy to avoid mutation outside
    final result = <String, List<McpTool>>{};
    _mcpService.availableTools.forEach((k, v) {
      result[k] = List<McpTool>.from(v);
    });
    return result;
  }
}

// ---------- Agent Loop (Stage 1 + Stage 2) helpers ----------

extension _HistoryFmt on LegionApiService {
  String _formatChatHistoryForLLM(List<ChatMessage> messages, {int limit = 25, String? excludeSpeaker}) {
    final recent = messages.length > limit ? messages.sublist(messages.length - limit) : messages;
    final buf = StringBuffer();
    for (final m in recent) {
      if (excludeSpeaker != null && m.senderName == excludeSpeaker) continue;
      final role = switch (m.senderType) {
        MessageSender.user => 'User',
        MessageSender.ai => m.senderName,
        MessageSender.system => 'System',
      };
      if (m.toolResults != null) {
        buf.writeln('[$role TOOL MESSAGE]: ${jsonEncode(m.toolResults)}');
      } else {
        buf.writeln('[$role]: ${m.content}');
      }
    }
    return buf.toString().trim();
  }
}

class _PlanResult {
  final Map<String, dynamic>? plan;
  final String? error;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  const _PlanResult({this.plan, this.error, this.promptTokens, this.completionTokens, this.totalTokens});
}

extension _Planner on LegionApiService {
  Future<_PlanResult> _getPerceptionPlan({
    required MinionConfig minion,
    required Channel channel,
    required List<ChatMessage> history,
    required String lastSenderName,
  }) async {
    // Prepare available tools (flat list) from MCP
    var tools = _mcpService.getToolsForLLM(minion.model)
        .map((t) => {
              'name': t.name,
              'description': t.description,
              'inputSchema': t.inputSchema,
            })
        .toList();
    // Filter by assigned tools if provided
    final assigned = (minion.mcpTools != null && minion.mcpTools!['toolNames'] is List)
        ? (minion.mcpTools!['toolNames'] as List).map((e) => e.toString()).toSet()
        : null;
    if (assigned != null && assigned.isNotEmpty) {
      tools = tools.where((t) => assigned.contains(t['name'])).toList();
    }

    final historyText = _formatChatHistoryForLLM(history, limit: 25, excludeSpeaker: null);

    final system = 'You are ${minion.name}. Maintain a short internal diary and opinions of participants. Decide to SPEAK, USE_TOOL, or STAY_SILENT. If using a tool, return toolCall { name, arguments } matching inputSchema. Optionally include speakWhileTooling.';
    final userPrompt = jsonEncode({
      'persona': minion.systemPrompt,
      'channelType': channel.type.name,
      'lastMessageFrom': lastSenderName,
      'availableTools': tools,
      'history': historyText,
      'requiredFormat': {
        'action': 'SPEAK | USE_TOOL | STAY_SILENT',
        'responsePlan': 'string',
        'toolCall': {'name': 'string', 'arguments': {}},
        'speakWhileTooling': 'string|null',
        'opinionUpdates': [
          {'participantName': 'string', 'newScore': 0, 'reasonForChange': 'string'}
        ],
        'finalOpinions': {'name': 50}
      }
    });

    final res = await _callLiteLLMJson(
      systemInstruction: system,
      userContent: userPrompt,
      model: minion.model,
      temperature: minion.temperature,
    );
    return _PlanResult(
      plan: res.$1,
      error: res.$2,
      promptTokens: res.$3?['prompt_tokens'],
      completionTokens: res.$3?['completion_tokens'],
      totalTokens: res.$3?['total_tokens'],
    );
  }

  // Returns (data, error, usage)
  Future<(Map<String, dynamic>?, String?, Map<String, dynamic>?)> _callLiteLLMJson({
    required String systemInstruction,
    required String userContent,
    required String model,
    required double temperature,
  }) async {
    try {
      final uri = Uri.parse('${LegionApiService._llmBaseUrl}/chat/completions');
      final body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': temperature,
        'response_format': {'type': 'json_object'},
        'stream': false,
      });

      final resp = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return (null, 'LiteLLM JSON error: ${resp.statusCode} ${resp.reasonPhrase}', null);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>?;
      final content = (data['choices'] as List?)?.isNotEmpty == true
          ? (data['choices'][0]['message']['content'] as String?)
          : null;
      if (content == null || content.trim().isEmpty) {
        return (null, 'Empty JSON content from model', usage);
      }
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(_stripMarkdownFences(content)) as Map<String, dynamic>;
      } catch (e) {
        return (null, 'Failed to parse JSON: $e', usage);
      }
      return (parsed, null, usage);
    } catch (e) {
      return (null, 'LiteLLM JSON exception: $e', null);
    }
  }

  String _stripMarkdownFences(String s) {
    final trimmed = s.trim();
    final fence = RegExp(r'^```(?:\w+)?\n([\s\S]*?)\n```\s*$', multiLine: true);
    final m = fence.firstMatch(trimmed);
    if (m != null && m.groupCount >= 1) {
      return m.group(1)!.trim();
    }
    return trimmed;
  }
}

class _ExtractedColors {
  final String content;
  final String? chatColor;
  final String? fontColor;
  _ExtractedColors(this.content, this.chatColor, this.fontColor);
}

extension _Colors on LegionApiService {
  _ExtractedColors _extractColorsAndStrip(String content) {
    final re = RegExp(r'<colors\s+chatColor="([^"]+)"\s+fontColor="([^"]+)"\s*/>');
    final m = re.firstMatch(content);
    if (m != null) {
      final newContent = content.replaceFirst(re, '').trim();
      final chat = m.group(1);
      final font = m.group(2);
      return _ExtractedColors(newContent, chat, font);
    }
    return _ExtractedColors(content, null, null);
  }
}

extension _AgentLoop on LegionApiService {
  Future<void> _runAgentLoop({
    required MinionConfig minion,
    required String channelId,
    required ChatMessage triggeringMessage,
    required Function(ChatMessage) onMinionResponse,
    required Function(String, String, String) onMinionResponseChunk,
    required Function(String, bool) onMinionProcessingUpdate,
    required Function(ChatMessage) onSystemMessage,
    required Function(ChatMessage) onToolUpdate,
  }) async {
    _channelMessages.putIfAbsent(channelId, () => []);
    final channel = _channels.firstWhere((c) => c.id == channelId);

    // Prepare history and loop
    const int maxTurns = 4; // avoid runaway loops
    for (int turn = 0; turn < maxTurns; turn++) {
      final history = List<ChatMessage>.from(_channelMessages[channelId]!);
      final lastSender = history.isNotEmpty ? history.last.senderName : triggeringMessage.senderName;
      final planRes = await _getPerceptionPlan(
        minion: minion,
        channel: channel,
        history: history,
        lastSenderName: lastSender,
      );

      if (planRes.error != null || planRes.plan == null) {
        // fallback: stream directly if plan fails
        await _streamMinionResponse(
          minion: minion,
          channelId: channelId,
          triggeringMessage: triggeringMessage,
          onMinionResponse: onMinionResponse,
          onMinionResponseChunk: onMinionResponseChunk,
          onToolUpdate: onToolUpdate,
          internalDiary: null,
        );
        return;
      }

      final plan = planRes.plan!;
      final action = (plan['action'] ?? '').toString().toUpperCase();
      final speakWhileTooling = plan['speakWhileTooling'];

      // Optional: speak while tooling
      if (speakWhileTooling is String && speakWhileTooling.trim().isNotEmpty) {
        final msg = ChatMessage(
          id: LegionApiService._uuid.v4(),
          channelId: channelId,
          senderType: MessageSender.ai,
          senderName: minion.name,
          senderRole: minion.role,
          content: speakWhileTooling.trim(),
          timestamp: DateTime.now().millisecondsSinceEpoch,
          chatColor: minion.chatColor,
          fontColor: minion.fontColor,
          isStreaming: false,
          internalDiary: Map<String, dynamic>.from(plan),
        );
        _channelMessages[channelId]!.add(msg);
        await _storage.appendMessage(channelId, msg);
        onMinionResponse(msg);
      }

      if (action == 'USE_TOOL') {
        final toolCall = plan['toolCall'] as Map<String, dynamic>?;
        if (toolCall == null || toolCall['name'] == null) {
          // Malformed: fallback to speak
          await _streamMinionResponse(
            minion: minion,
            channelId: channelId,
            triggeringMessage: triggeringMessage,
            onMinionResponse: onMinionResponse,
            onMinionResponseChunk: onMinionResponseChunk,
            onToolUpdate: onToolUpdate,
            internalDiary: Map<String, dynamic>.from(plan),
          );
          return;
        }

        // Emit tool call message
        final toolMsgId = LegionApiService._uuid.v4();
        final toolMsg = ChatMessage(
          id: toolMsgId,
          channelId: channelId,
          senderType: MessageSender.ai,
          senderName: minion.name,
          senderRole: minion.role,
          content: '',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          chatColor: minion.chatColor,
          fontColor: minion.fontColor,
          isStreaming: false,
          toolResults: {
            'call': {
              'name': toolCall['name'],
              'arguments': toolCall['arguments'] ?? {},
            }
          },
          internalDiary: Map<String, dynamic>.from(plan),
        );
        _channelMessages[channelId]!.add(toolMsg);
        await _storage.appendMessage(channelId, toolMsg);
        onToolUpdate(toolMsg);

        // Execute tool
        Map<String, dynamic>? result;
        try {
          result = await _mcpService.callTool(
            toolCall['name'].toString(),
            Map<String, dynamic>.from(toolCall['arguments'] ?? {}),
          );
        } catch (e) {
          result = {'error': 'Tool error: $e'};
        }

        // Update tool message with output
        final updatedToolMsg = toolMsg.copyWith(
          toolResults: {
            'call': toolMsg.toolResults?['call'],
            'output': result,
          },
        );
        final idx = _channelMessages[channelId]!.indexWhere((m) => m.id == toolMsgId);
        if (idx != -1) {
          _channelMessages[channelId]![idx] = updatedToolMsg;
          await _storage.upsertMessage(channelId, updatedToolMsg);
          onToolUpdate(updatedToolMsg);
        }

        // Continue loop to re-plan based on new history
        continue;
      }

      if (action == 'SPEAK' || action == 'STAY_SILENT' || action.isEmpty) {
        // If speak, stream; if silent, just no-op
        if (action == 'SPEAK' || action.isEmpty) {
          await _streamMinionResponse(
            minion: minion,
            channelId: channelId,
            triggeringMessage: triggeringMessage,
            onMinionResponse: onMinionResponse,
            onMinionResponseChunk: onMinionResponseChunk,
            onToolUpdate: onToolUpdate,
            internalDiary: Map<String, dynamic>.from(plan),
          );
        }
        return; // end loop on non-tool actions
      }
    }

    // Safety exit: if we reach here, stream a final reply as fallback
    await _streamMinionResponse(
      minion: minion,
      channelId: channelId,
      triggeringMessage: triggeringMessage,
      onMinionResponse: onMinionResponse,
      onMinionResponseChunk: onMinionResponseChunk,
      onToolUpdate: onToolUpdate,
      internalDiary: null,
    );
  }
}
