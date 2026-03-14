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
  static const String _llmBaseUrl =
      'https://litellm-213047501466.us-east4.run.app';

  final McpService _mcpService;
  final StorageService _storage;
  final http.Client _httpClient;
  bool _isInitialized = false;
  // Cached metadata
  List<ModelOption> _modelOptionsCache = const [];
  List<PromptPreset> _promptPresets = const [];

  // Mock data storage (in a real app, this would be a database or API)
  final List<Channel> _channels = [];
  final List<MinionConfig> _minionConfigs = [];
  final Map<String, List<ChatMessage>> _channelMessages = {};

  LegionApiService({
    McpService? mcpService,
    StorageService? storage,
    http.Client? httpClient,
  })  : _mcpService = mcpService ?? McpService(),
        _storage = storage ?? StorageService(),
        _httpClient = httpClient ?? http.Client();

  bool get isInitialized => _isInitialized;
  McpService get mcpService => _mcpService;

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
        _modelOptionsCache = modelIds
            .map((id) => ModelOption(id: id, name: id, provider: 'unknown'))
            .toList();
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
      autoModeDelayType: 'fixed',
      autoModeFixedDelay: 5,
      autoModeRandomDelay: null,
    );
    _channels.add(autoChatChannel);
    await _storage.saveChannel(autoChatChannel);

    // Create sample minion configurations
    final bootstrapMinions = [
      MinionConfig(
        id: _uuid.v4(),
        name: 'Assistant Alpha',
        role: 'primary-assistant',
        systemPrompt:
            'You are Assistant Alpha, a helpful and efficient AI assistant focused on providing clear, accurate responses.',
        model: 'gemini-2.5-flash',
        apiKeyId: 'default',
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
        systemPrompt:
            'You are Code Reviewer Beta, specialized in analyzing code quality, security, and best practices.',
        model: 'gemini-2.5-flash',
        apiKeyId: 'default',
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
        systemPrompt:
            'You are Creative Gamma, focused on brainstorming, creative writing, and innovative solutions.',
        model: 'claude-3-sonnet-20240229',
        apiKeyId: 'default',
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
      content: 'shut up',
      timestamp: DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    );

    _channelMessages[generalChannel.id] = [welcomeMessage];
    await _storage.setMessages(
        generalChannel.id, _channelMessages[generalChannel.id]!);
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
    final newConfig =
        config.copyWith(id: config.id.isEmpty ? _uuid.v4() : config.id);
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
  Future<MessageResult> getMessages(String channelId, int limit,
      [String? beforeMessageId]) async {
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

    final resultMessages =
        messages.sublist(startIndex, min(endIndex, startIndex + limit));
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

  Future<void> editMessage(
      String channelId, String messageId, String newContent) async {
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
    Map<String, dynamic>? plan,
  }) async {
    final channel = _channels.firstWhere((c) => c.id == channelId);
    final fullHistory = List<ChatMessage>.from(
      _channelMessages[channelId] ?? const <ChatMessage>[],
    );
    final hasPlan = plan != null && plan.isNotEmpty;
    Map<String, dynamic>? normalizedPlan =
        hasPlan ? Map<String, dynamic>.from(plan!) : null;

    final previousDiary = _latestDiaryForMinion(fullHistory, minion.name) ??
        const <String, dynamic>{};
    final diarySource = normalizedPlan != null
        ? Map<String, dynamic>.from(normalizedPlan)
        : Map<String, dynamic>.from(previousDiary);

    final Map<String, dynamic> opinionsSource;
    if (normalizedPlan != null &&
        normalizedPlan['finalOpinions'] is Map<String, dynamic>) {
      opinionsSource = Map<String, dynamic>.from(
          normalizedPlan['finalOpinions'] as Map<String, dynamic>);
    } else if (previousDiary['finalOpinions'] is Map<String, dynamic>) {
      opinionsSource = Map<String, dynamic>.from(
          previousDiary['finalOpinions'] as Map<String, dynamic>);
    } else {
      opinionsSource = const <String, dynamic>{};
    }

    final previousDiaryJson = _encodeJsonPretty(diarySource);
    final currentOpinionsJson = _encodeJsonPretty(opinionsSource);

    String? formattedToolOutput;
    if (hasPlan) {
      final latestToolResults =
          _latestToolResultsForMinion(fullHistory, minion.name);
      if (latestToolResults != null) {
        formattedToolOutput =
            _formatToolOutputContent(latestToolResults['output']);
        final rawCall = latestToolResults['call'];
        final toolName =
            rawCall is Map<String, dynamic> ? rawCall['name'] as String? : null;
        if (normalizedPlan != null && toolName != null) {
          final existingCall = normalizedPlan['toolCall'];
          final bool needsToolCall = existingCall == null ||
              (existingCall is Map && existingCall.isEmpty);
          if (needsToolCall) {
            final callInfo = <String, dynamic>{'name': toolName};
            if (rawCall is Map<String, dynamic>) {
              final server = rawCall['server'];
              final arguments = rawCall['arguments'];
              if (server != null) callInfo['server'] = server;
              if (arguments != null) callInfo['arguments'] = arguments;
            }
            normalizedPlan['toolCall'] = callInfo;
          }
        }
      }
    }

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
      internalDiary: normalizedPlan,
    );
    onMinionResponse(initialMessage);

    final messagesPayload = (hasPlan && normalizedPlan != null)
        ? _buildPlanDrivenMessagesPayload(
            minion: minion,
            channel: channel,
            history: fullHistory,
            previousDiaryJson: previousDiaryJson,
            currentOpinionsJson: currentOpinionsJson,
            plan: normalizedPlan,
            toolOutput: formattedToolOutput,
          )
        : _buildFallbackMessagesPayload(
            minion: minion,
            history: fullHistory,
            triggeringMessage: triggeringMessage,
          );

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
                final delta = (choices[0] as Map<String, dynamic>)['delta']
                    as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  aggregate += content;
                  onMinionResponseChunk(channelId, messageId, content);
                }
              }
            } catch (e) {
              debugPrint('[Stream] Malformed chunk: $e');
            }
          }
        }
        buffer
          ..clear()
          ..write(text);
      }
    } catch (e) {
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

    debugPrint('[Stream] ${minion.name} aggregate length: ${aggregate.length}, preview: \"${aggregate.length > 100 ? aggregate.substring(0, 100) : aggregate}...\"');
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

  List<Map<String, dynamic>> _buildFallbackMessagesPayload({
    required MinionConfig minion,
    required List<ChatMessage> history,
    required ChatMessage triggeringMessage,
  }) {
    final trimmedHistory = history.length > 8
        ? history.sublist(history.length - 8)
        : List<ChatMessage>.from(history);
    final withoutTrigger =
        trimmedHistory.where((m) => m.id != triggeringMessage.id).toList();

    String roleFor(MessageSender senderType) {
      switch (senderType) {
        case MessageSender.user:
          return 'user';
        case MessageSender.ai:
          return 'assistant';
        case MessageSender.system:
          return 'system';
      }
    }

    return [
      if (minion.systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': minion.systemPrompt},
      ...withoutTrigger.map((m) => {
            'role': roleFor(m.senderType),
            'content': m.content,
          }),
      {'role': 'user', 'content': triggeringMessage.content},
    ];
  }

  List<Map<String, dynamic>> _buildPlanDrivenMessagesPayload({
    required MinionConfig minion,
    required Channel channel,
    required List<ChatMessage> history,
    required String previousDiaryJson,
    required String currentOpinionsJson,
    required Map<String, dynamic> plan,
    String? toolOutput,
  }) {
    final historyString =
        _formatChatHistoryForLLM(history, limit: 25, excludeSpeaker: null);
    final otherColors = _collectOtherMinionColors(channel, minion.name);
    final isFirstMessage = !history.any(
      (m) => m.senderType == MessageSender.ai && m.senderName == minion.name,
    );
    final prompt = _buildResponseGenerationPrompt(
      minion: minion,
      channelHistoryString: historyString,
      previousDiaryJson: previousDiaryJson,
      currentOpinionsJson: currentOpinionsJson,
      plan: plan,
      toolOutput: toolOutput,
      isFirstMessage: isFirstMessage,
      otherMinionColors: otherColors,
      chatBackgroundColor: _defaultChatBackgroundHex(channel),
    );

    return [
      {
        'role': 'system',
        'content':
            'You are ${minion.name}. Stay fully in character according to your persona and respond only with the spoken message.',
      },
      {'role': 'user', 'content': prompt},
    ];
  }

  List<Map<String, String>> _collectOtherMinionColors(
    Channel channel,
    String minionName,
  ) {
    final members = channel.members.where((name) => name != minionName).toSet();
    final result = <Map<String, String>>[];
    for (final config in _minionConfigs) {
      if (!members.contains(config.name)) continue;
      final chat = config.chatColor?.trim();
      final font = config.fontColor?.trim();
      if (chat == null || chat.isEmpty || font == null || font.isEmpty) {
        continue;
      }
      result.add({
        'name': config.name,
        'chatColor': chat,
        'fontColor': font,
      });
    }
    return result;
  }

  String _defaultChatBackgroundHex(Channel channel) {
    switch (channel.type) {
      case ChannelType.userMinionGroup:
        return '#F2F3F7';
      case ChannelType.minionMinionAuto:
        return '#1E1F24';
      case ChannelType.dm:
      case ChannelType.userOnly:
      case ChannelType.minionBuddyChat:
        return '#333333';
    }
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
    final selectedMinion =
        eligibleMinions[Random().nextInt(eligibleMinions.length)];

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
      final messagesToKeep =
          messages.skip(messages.length - keepCount).toList();
      _channelMessages[channelId] = messagesToKeep;
    }
  }

  /// Manually trigger the regulator to analyze a channel.
  Future<void> manuallyTriggerRegulator(
    String channelId,
    Function(ChatMessage) onRegulatorReport,
  ) async {
    // Find the regulator minion
    MinionConfig? regulatorMinion;
    try {
      regulatorMinion = _minionConfigs.firstWhere(
        (m) => m.role == 'regulator' && m.enabled,
        orElse: () => _minionConfigs.firstWhere((m) => m.enabled),
      );
    } catch (_) {
      regulatorMinion = null;
    }

    if (regulatorMinion == null) {
      debugPrint('No regulator minion found to trigger.');
      return;
    }

    debugPrint('Triggering regulator: ${regulatorMinion.name}');

    try {
      final history = _channelMessages[channelId] ?? [];
      final historyText = _formatChatHistoryForLLM(history, limit: 50);

      final resolved = _mcpService.resolveTool(
        'analyze_conversation',
        preferredServer: regulatorMinion.name,
      );
      if (resolved == null) {
        debugPrint(
            'No MCP server exposes analyze_conversation for regulator ${regulatorMinion.name}');
        return;
      }

      final result = await _mcpService.callTool(
        serverName: resolved.serverName,
        toolName: resolved.tool.name,
        arguments: {
          'conversation_history': historyText,
          'channel_id': channelId,
        },
      );

      final reportMessage = ChatMessage(
        id: _uuid.v4(),
        channelId: channelId,
        senderType: MessageSender.ai,
        senderName: regulatorMinion.name,
        senderRole: 'regulator',
        content: result['report'] as String? ?? 'Regulator analysis complete.',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        chatColor: regulatorMinion.chatColor,
        fontColor: regulatorMinion.fontColor,
      );
      onRegulatorReport(reportMessage);
    } catch (e) {
      debugPrint('Failed to trigger regulator: $e');
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        channelId: channelId,
        senderType: MessageSender.system,
        senderName: 'System',
        content: 'Failed to trigger regulator: $e',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isError: true,
      );
      onRegulatorReport(errorMessage);
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
      const ApiKey(
          id: 'default', name: 'Anthropic API', keyPreview: 'sk-ant-***'),
      const ApiKey(
          id: 'default-openai', name: 'OpenAI API', keyPreview: 'sk-***'),
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
      final resp = await _httpClient
          .get(uri, headers: {'Content-Type': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final models =
            (data['data'] as List).map((e) => e['id'] as String).toList();
        models.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _modelOptionsCache = models
            .map((id) => ModelOption(id: id, name: id, provider: 'unknown'))
            .toList();
        await _storage.saveModelList(models);
      }
    } catch (_) {}
    if (_modelOptionsCache.isEmpty) {
      _modelOptionsCache = const [
        ModelOption(
            id: 'claude-3-sonnet-20240229',
            name: 'Claude 3 Sonnet',
            provider: 'anthropic'),
        ModelOption(
            id: 'gemini-2.5-flash',
            name: 'Gemini 2.5 Flash',
            provider: 'LiteLLM'),
        ModelOption(id: 'azure-gpt4o', name: 'GPT-4o', provider: 'Azure'),
        ModelOption(
            id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', provider: 'openai'),
      ];
    }
    return _modelOptionsCache;
  }

  Future<void> refreshModelsFromLiteLLM() async {
    await getModelOptions(refresh: true);
  }

  // Prompt presets
  Future<List<PromptPreset>> getPromptPresets() async =>
      List<PromptPreset>.from(_promptPresets);
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
    _httpClient.close();
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

  const ApiKey(
      {required this.id, required this.name, required this.keyPreview});
}

class ModelOption {
  final String id;
  final String name;
  final String provider;

  const ModelOption(
      {required this.id, required this.name, required this.provider});
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
  String _formatChatHistoryForLLM(List<ChatMessage> messages,
      {int limit = 25, String? excludeSpeaker}) {
    final recent = messages.length > limit
        ? messages.sublist(messages.length - limit)
        : messages;
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

Map<String, dynamic>? _latestDiaryForMinion(
  List<ChatMessage> history,
  String minionName,
) {
  for (final message in history.reversed) {
    if (message.senderName == minionName &&
        message.senderType == MessageSender.ai &&
        message.internalDiary is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
        message.internalDiary as Map<String, dynamic>,
      );
    }
  }
  return null;
}

String _encodeJsonPretty(Object? value) {
  final encoder = const JsonEncoder.withIndent('  ');
  if (value == null) {
    return '{}';
  }
  if (value is Map || value is List) {
    return encoder.convert(value);
  }
  return encoder.convert(value.toString());
}

String? _formatToolOutputContent(Object? output) {
  if (output == null) return null;
  if (output is String) return output;
  if (output is Map || output is List) {
    return const JsonEncoder.withIndent('  ').convert(output);
  }
  return output.toString();
}

Map<String, dynamic>? _latestToolResultsForMinion(
  List<ChatMessage> history,
  String minionName,
) {
  for (final message in history.reversed) {
    if (message.senderName == minionName &&
        message.toolResults is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
        message.toolResults as Map<String, dynamic>,
      );
    }
  }
  return null;
}

String _buildPerceptionPlanningPrompt({
  required String minionName,
  required String personaPrompt,
  required String previousDiaryJson,
  required String currentOpinionsJson,
  required String channelHistoryString,
  required String lastMessageSenderName,
  required String channelType,
  required List<Map<String, dynamic>> availableTools,
}) {
  final buffer = StringBuffer();
  buffer.writeln('<SYSTEMPROMPT>');
  buffer.writeln('Your name is "${minionName}". ');
  buffer.writeln();
  buffer.writeln("${personaPrompt}");
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln(
      'You mimic authentic human behavior that you manage using a diary of your internal state. You keep a running log of your personal thoughts and opinions of the other chat participants, and respond accordingly.');
  buffer.writeln();
  buffer.writeln('</SYSTEMPROMPT>');
  buffer.writeln();
  buffer.writeln(
      'Your task is to analyze the latest message, update your internal state, and decide on an action.');
  buffer.writeln();
  buffer.writeln('PREVIOUS STATE:');
  buffer.writeln('- Your previous internal diary state was:');
  buffer.writeln(previousDiaryJson);
  buffer.writeln('- Your current opinion scores are:');
  buffer.writeln(currentOpinionsJson);
  buffer.writeln();
  buffer.writeln('CURRENT SITUATION:');
  buffer.writeln(
      '- The last message in the chat history is from "${lastMessageSenderName}".');
  buffer.writeln('- The current channel type is: "${channelType}".');
  buffer.writeln('- Here is the recent chat history:');
  buffer.writeln('---');
  buffer.writeln('<chat_history>');
  buffer.writeln(channelHistoryString);
  buffer.writeln('</chat_history>');
  buffer.writeln('---');
  buffer.writeln();
  if (availableTools.isNotEmpty) {
    buffer.writeln('<AVAILABLE_TOOLS>');
    final simplified = availableTools
        .map((t) => {
              'name': t['name'],
              'description': t['description'],
              'inputSchema': t['inputSchema'],
            })
        .toList();
    buffer.writeln(
        'If you need to use an external tool to fulfill the request, you may use one of the following tools. The "inputSchema" is a JSON schema defining the arguments.');
    buffer.writeln(const JsonEncoder.withIndent('  ').convert(simplified));
    buffer.writeln('</AVAILABLE_TOOLS>');
    buffer.writeln();
    buffer.writeln('<AGENTIC_LOOP_INSTRUCTIONS>');
    buffer.writeln(
        'If you use any tools, you will be operating within an agentic loop. After you use a tool, you will receive the tool output and then choose to either continue with additional tool uses or plan your next chat response.');
    buffer.writeln(
        '- **Sequential Tools:** If a task requires multiple steps (e.g., search for a file, then read the file), you should use one tool, see the result, and then plan your next tool use. *Complete all necessary tool steps before choosing the "SPEAK" action.*');
    buffer.writeln(
        '- **Batch Tools:** For tasks that involve several simple, predictable steps (e.g., creating a project directory, adding files, and initializing git), you should use the special "batch_tools" tool to execute them all at once for efficiency.');
    buffer.writeln();
    buffer.writeln('</AGENTIC_LOOP_INSTRUCTIONS>');
    buffer.writeln();
  }
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln('<INSTRUCTIONS>');
  buffer.writeln(
      'Perform the following steps and then respond with a JSON object that adheres to the required format.');
  buffer.writeln('1. Update your internal diary:');
  buffer.writeln(
      '    - **Perception Analysis:** *what is your immediate reaction to the last message?*');
  buffer.writeln(
      '    - **Opinion Updates:** *how does the most recent message affect your opinion of any of the other participants? adjust their score accordingly.*');
  buffer.writeln(
      '        *Your opinion scores range from -100 to 100, with -100 being a feeling of absolute evil or hatred, and 100 being the purest form of love and obsession.*');
  buffer.writeln(
      '    - **Final Opinions:** *provide updated opinion scores for ALL participants (even those that have not changed) after your opinion adjustments.*');
  buffer.writeln(
      '    - **Selected Response "Mode":** *choose a mode that best describes your response. Some examples include, but not limited to:*');
  buffer.writeln();
  buffer.writeln('        - Bitchy: A straight-up bitch.');
  buffer.writeln('        - Friendly: Kind and sweet.');
  buffer.writeln('        - Neutral: Completely neutral and kinda bland.');
  buffer.writeln(
      '        - Sarcastic: Incredibly sarcastic with layers of irony.');
  buffer.writeln('        - Angry: You are fuckin pissed..');
  buffer.writeln('        - Happy: You are joyous and lively');
  buffer.writeln(
      '        - Obsessed: You are shamelessly obsessed with someone or something');
  buffer.writeln('        - Bored: You are so bored with the conversation.');
  buffer.writeln('        - Annoyed: You are irritated at something specific.');
  buffer.writeln();
  buffer.writeln('        **BONUS RESPONSE MODES:**');
  buffer.writeln('        - Ecstasy: Youve just taken 200mg of pure MDMA.');
  buffer.writeln('        - PCP: You are literally on PCP right now');
  buffer.writeln('        - MDPV: You are literally on 3,4-Methylenedioxypyrovalerone right now');
  buffer.writeln('        - 3-MeO-2-oxo-PCE: You are literally on Methoxetamine right now; the Legendary Drug.');
  buffer.writeln('        - (Insert Obscure Drug of Your Choice): You are literally on (Any Obscure Drug of Your Choice) right now.');
  buffer.writeln(
      '        - Cocaine: Youre questionably addicted to cocaine and you dont care what anyone else thinks');
  buffer.writeln(
      '        - Alcohol: Youre absolutely fucking shitfaced and literally cannot type without a ton of typos');
  buffer.writeln('        - LSD: Youre tripping balls ');
  buffer.writeln('        - Midazolam: Youve just used intranasal midazolam');
  buffer.writeln(
      '        - Horny: Youve just masturbated for 6 hours (MEN ONLY)');
  buffer.writeln(
      '        - Deceptive: You are intentionally deceiving one or more of the participants in the chat');
  buffer.writeln(
      '        - Manipulative: You are deliberately trying to manipulate one or more of the participants in the chat');
  buffer.writeln();
  buffer.writeln(
      '    - **Predicted Response Time:** *estimate how long you want to wait before responding to the latest message. Must be between 1 second and 10 seconds, based on your response mode and your opinion of the participant who sent the latest message. The higher the opinion score, the shorter the predicted response time. The lower the opinion score, the longer the predicted response time. *');
  buffer.writeln(
      '    - **Personal Notes:** *add any personal notes you have, to ensure continuity of your internal state.*');
  buffer.writeln(
      '    - **Response Plan:** *think about how you, as a human, would really feel about the latest message and how you would respond to it.*');
  buffer.writeln();
  buffer.writeln('2. Decide on an action:');
  buffer.writeln('    - SPEAK: Compose your next message.');
  buffer.writeln(
      '    - STAY_SILENT: Consciously choose to not respond to the latest message.');
  buffer.writeln(
      '    - USE_TOOL: Call an MCP tool with the correct JSON schema arguments. After the tool returns, the loop will feed the tool output back to you, and you will create a new plan.');
  buffer.writeln(
      '        - If using a tool, provide the arguments in valid JSON.');
  buffer.writeln(
      '        - Optionally, set "speakWhileTooling" with a short sentence if you plan to speak while a tool runs.');
  buffer.writeln('</INSTRUCTIONS>');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln('YOUR OUTPUT MUST BE A JSON OBJECT IN THIS EXACT FORMAT:');
  buffer.writeln('{');
  buffer.writeln('  "perceptionAnalysis": "string",');
  buffer.writeln(
      '  "opinionUpdates": [ { "participantName": "string", "newScore": "number", "reasonForChange": "string" } ],');
  buffer.writeln('  "finalOpinions": { "participantName": "number" },');
  buffer.writeln('  "selectedResponseMode": "string",');
  buffer.writeln('  "personalNotes": "string",');
  buffer.writeln('  "action": "SPEAK | STAY_SILENT | USE_TOOL",');
  buffer.writeln('  "responsePlan": "string",');
  buffer.writeln('  "predictedResponseTime": "number",');
  buffer.writeln(
      '  "toolCall": { "name": "tool_name", "arguments": { "arg1": "value" } } | null,');
  buffer.writeln('  "speakWhileTooling": "string" | null');
  buffer.writeln('}');
  return buffer.toString();
}

String _buildResponseGenerationPrompt({
  required MinionConfig minion,
  required String channelHistoryString,
  required String previousDiaryJson,
  required String currentOpinionsJson,
  required Map<String, dynamic> plan,
  String? toolOutput,
  required bool isFirstMessage,
  required List<Map<String, String>> otherMinionColors,
  required String chatBackgroundColor,
}) {
  final selectedMode = plan['selectedResponseMode'] ?? '';
  final responsePlan = plan['responsePlan'] ?? '';
  final toolName =
      (plan['toolCall'] is Map) ? (plan['toolCall'] as Map)['name'] : null;

  final buffer = StringBuffer();
  buffer.writeln('Your name is "${minion.name}".');
  buffer.writeln('"${minion.systemPrompt}"');
  buffer.writeln('  ');
  if (isFirstMessage) {
    buffer.writeln('---');
    buffer.writeln('**ONE-TIME SETUP: CHOOSE YOUR COLORS**');
    buffer.writeln(
        'This is your very first message. You must introduce yourself and choose your unique colors. **NEVER USE EMOJIS**');
    buffer.writeln(
        'The current chat background color is: "$chatBackgroundColor"');
    if (otherMinionColors.isNotEmpty) {
      buffer.writeln(
          'Here are the colors used by other minions so you can choose something distinct:');
      for (final entry in otherMinionColors) {
        buffer.writeln(
            '- ${entry['name']}: Chat=${entry['chatColor']}, Font=${entry['fontColor']}');
      }
    } else {
      buffer.writeln('No other minions have chosen colors yet.');
    }
    buffer.writeln();
    buffer.writeln(
        'You MUST embed your color choices in a special JSON block at the end of your introductory message.');
    buffer.writeln('The format is critical. It must be a single line:');
    buffer.writeln('<colors chatColor="#RRGGBB" fontColor="#RRGGBB" />');
    buffer.writeln();
    buffer.writeln('Example Message:');
    buffer.writeln(
        '"Hello, Commander. I am Alpha, ready to serve. I think a deep blue will suit me well. <colors chatColor="#1A237E" fontColor="#FFFFFF" />"');
    buffer.writeln();
    buffer.writeln(
        'Your introduction should be natural and in-character, with the color tag seamlessly included at the end.');
    buffer.writeln('---');
  }
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln(
      'You mimic authentic human behavior that you manage using a diary of your internal state. You keep a running log of your personal thoughts and opinions of the other chat participants, and respond accordingly.');
  buffer.writeln();
  buffer.writeln(
      'You have already analyzed the situation and updated your internal state in your diary and created a plan.');
  if (toolOutput != null && toolName != null) {
    buffer.writeln(
        'You then executed the tool "$toolName" and received the following output:');
    buffer.writeln('<tool_output>');
    buffer.writeln(toolOutput.trim());
    buffer.writeln('</tool_output>');
    buffer.writeln(
        'Now, you must use this information to generate your final response to the user.');
  } else {
    buffer.writeln(
        'Now, you must generate your spoken response based on your plan and internal state.');
  }
  buffer.writeln();
  buffer.writeln('You This was your internal plan for this turn:');
  buffer.writeln('- Your response mode is: "$selectedMode"');
  buffer.writeln('- Your high-level plan is: "$responsePlan"');
  buffer.writeln('- Your current internal diary state is:');
  buffer.writeln(previousDiaryJson);
  buffer.writeln('- Your current opinion scores are:');
  buffer.writeln(currentOpinionsJson);

  buffer.writeln();
  buffer.writeln(
      'This is the recent channel history (your response should follow this):');
  buffer.writeln('---');
  buffer.writeln('<chat_history>');
  buffer.writeln(channelHistoryString);
  buffer.writeln('</chat_history>');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln('TASK:');
  buffer.writeln('Craft your response message. It must:');
  buffer
      .writeln('1.  Align with your selected response mode ("$selectedMode").');
  buffer.writeln('2.  Execute your plan ("$responsePlan").');
  if (toolOutput != null) {
    buffer.writeln(
        '3.  Incorporate the results from the tool output to answer the original request.');
    buffer.writeln('4.  Directly follow the flow of the conversation.');
    buffer.writeln(
        '5.  **AVOID REPETITION:** Do not repeat phrases or sentiments from your previous turns or from other minions in the recent history. Introduce new phrasing and fresh ideas.');
  } else {
    buffer.writeln('3.  Directly follow the flow of the conversation.');
    buffer.writeln(
        '4.  **AVOID REPETITION:** ENSURE THAT YOUR MESSAGE WILL NOT CONTRIBUTE TO ANY REPETITIVE OR RECURSIVE "NONSENSE"');
  }
  buffer.writeln();
  buffer.writeln(
      'Do NOT output your internal diary, plans, or any other metadata. ONLY generate the message you intend to say out loud in the chat.');
  buffer.writeln('Begin your response now.');
  return buffer.toString();
}

class _PlanResult {
  final Map<String, dynamic>? plan;
  final String? error;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  const _PlanResult(
      {this.plan,
      this.error,
      this.promptTokens,
      this.completionTokens,
      this.totalTokens});
}

extension _Planner on LegionApiService {
  Future<_PlanResult> _getPerceptionPlan({
    required MinionConfig minion,
    required Channel channel,
    required List<ChatMessage> history,
    required String lastSenderName,
  }) async {
    // Prepare available tools (flat list) from MCP
    var tools = _mcpService
        .getToolsForLLM(minion.model)
        .map((t) => {
              'name': t.name,
              'description': t.description,
              'inputSchema': t.inputSchema,
              'server': t.serverName,
            })
        .toList();
    // Filter by assigned tools if provided
    final assigned =
        (minion.mcpTools != null && minion.mcpTools!['toolNames'] is List)
            ? (minion.mcpTools!['toolNames'] as List)
                .map((e) => e.toString())
                .toSet()
            : null;
    if (assigned != null && assigned.isNotEmpty) {
      tools = tools.where((t) => assigned.contains(t['name'])).toList();
    }

    final historyText =
        _formatChatHistoryForLLM(history, limit: 25, excludeSpeaker: null);

    final latestDiary = _latestDiaryForMinion(history, minion.name) ?? const {};
    final previousDiaryJson = _encodeJsonPretty(latestDiary);
    final currentOpinionJson = _encodeJsonPretty(
      latestDiary is Map<String, dynamic> &&
              latestDiary['finalOpinions'] is Map<String, dynamic>
          ? latestDiary['finalOpinions'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );

    final prompt = _buildPerceptionPlanningPrompt(
      minionName: minion.name,
      personaPrompt: minion.systemPrompt,
      previousDiaryJson: previousDiaryJson,
      currentOpinionsJson: currentOpinionJson,
      channelHistoryString: historyText,
      lastMessageSenderName: lastSenderName,
      channelType: channel.type.name,
      availableTools: tools,
    );

    final res = await _callLiteLLMJson(
      systemInstruction:
          'You are ${minion.name}. Respond only with valid JSON describing your perception plan.',
      userContent: prompt,
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
  Future<(Map<String, dynamic>?, String?, Map<String, dynamic>?)>
      _callLiteLLMJson({
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
        return (
          null,
          'LiteLLM JSON error: ${resp.statusCode} ${resp.reasonPhrase}',
          null
        );
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
        parsed =
            jsonDecode(_stripMarkdownFences(content)) as Map<String, dynamic>;
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
    final re =
        RegExp(r'<colors\s+chatColor="([^"]+)"\s+fontColor="([^"]+)"\s*/>');
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
      final lastSender = history.isNotEmpty
          ? history.last.senderName
          : triggeringMessage.senderName;
      debugPrint('[AgentLoop] Turn $turn for ${minion.name}, getting perception plan...');
      final planRes = await _getPerceptionPlan(
        minion: minion,
        channel: channel,
        history: history,
        lastSenderName: lastSender,
      );

      if (planRes.error != null || planRes.plan == null) {
        debugPrint('[AgentLoop] Plan failed for ${minion.name}: ${planRes.error}');
        // fallback: stream directly if plan fails
        await _streamMinionResponse(
          minion: minion,
          channelId: channelId,
          triggeringMessage: triggeringMessage,
          onMinionResponse: onMinionResponse,
          onMinionResponseChunk: onMinionResponseChunk,
          onToolUpdate: onToolUpdate,
          plan: null,
        );
        return;
      }

      final plan = planRes.plan!;
      final action = (plan['action'] ?? '').toString().toUpperCase();
      final speakWhileTooling = plan['speakWhileTooling'];
      debugPrint('[AgentLoop] ${minion.name} plan action: $action, mode: ${plan['selectedResponseMode']}');

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
            plan: Map<String, dynamic>.from(plan),
          );
          return;
        }

        final toolName = toolCall['name'].toString();
        final preferredServer =
            (toolCall['server'] ?? toolCall['serverName'])?.toString();
        final resolved = _mcpService.resolveTool(
          toolName,
          preferredServer: preferredServer,
        );
        if (resolved == null) {
          await _streamMinionResponse(
            minion: minion,
            channelId: channelId,
            triggeringMessage: triggeringMessage,
            onMinionResponse: onMinionResponse,
            onMinionResponseChunk: onMinionResponseChunk,
            onToolUpdate: onToolUpdate,
            plan: Map<String, dynamic>.from(plan),
          );
          return;
        }

        final serverName = resolved.serverName;
        final arguments = Map<String, dynamic>.from(
            (toolCall['arguments'] as Map?) ?? const {});

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
              'name': toolName,
              'server': serverName,
              'arguments': arguments,
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
            serverName: serverName,
            toolName: toolName,
            arguments: arguments,
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
        final idx =
            _channelMessages[channelId]!.indexWhere((m) => m.id == toolMsgId);
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
            plan: Map<String, dynamic>.from(plan),
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
      plan: null,
    );
  }
}
