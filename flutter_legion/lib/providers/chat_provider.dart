import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/channel.dart';
import '../models/minion_config.dart';

import '../services/legion_api_service.dart';

class ChatProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  final LegionApiService _legionApiService;
  
  // Core state
  final Map<String, List<ChatMessage>> _channelMessages = {};
  final Map<String, bool> _hasMoreMessages = {};
  String? _currentChannelId;
  bool _isProcessingMessage = false;
  bool _isAutoScrollEnabled = true;
  
  // Selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};
  String? _lastSelectedMessageId;
  final Set<String> _bulkDiaryVisible = {};
  
  // Active processing state
  final Map<String, bool> _activeMinionProcessors = {};

  ChatProvider(this._legionApiService);

  // Getters
  List<ChatMessage> getChannelMessages(String? channelId) {
    if (channelId == null) return [];
    return _channelMessages[channelId] ?? [];
  }

  bool hasMoreMessages(String? channelId) {
    if (channelId == null) return false;
    return _hasMoreMessages[channelId] ?? false;
  }

  String? get currentChannelId => _currentChannelId;
  bool get isProcessingMessage => _isProcessingMessage;
  bool get isAutoScrollEnabled => _isAutoScrollEnabled;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedMessageIds => _selectedMessageIds;
  String? get lastSelectedMessageId => _lastSelectedMessageId;
  Set<String> get bulkDiaryVisible => _bulkDiaryVisible;
  Map<String, bool> get activeMinionProcessors => _activeMinionProcessors;

  List<ChatMessage> get currentChannelMessages => getChannelMessages(_currentChannelId);
  
  // Channel management
  void setCurrentChannel(String channelId) {
    if (_currentChannelId != channelId) {
      _currentChannelId = channelId;
      clearSelection();
      notifyListeners();
    }
  }

  // Message operations
  void addMessage(String channelId, ChatMessage message) {
    _channelMessages.putIfAbsent(channelId, () => []);
    _channelMessages[channelId]!.add(message);
    notifyListeners();
  }

  void updateMessage(String channelId, String messageId, ChatMessage updatedMessage) {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = updatedMessage;
        notifyListeners();
      }
    }
  }

  void upsertMessage(ChatMessage message) {
    _channelMessages.putIfAbsent(message.channelId, () => []);
    final messages = _channelMessages[message.channelId]!;
    
    final existingIndex = messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      messages[existingIndex] = message;
    } else {
      messages.add(message);
    }
    notifyListeners();
  }

  void processMessageChunk(String channelId, String messageId, String chunk) {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final currentMessage = messages[index];
        messages[index] = currentMessage.copyWith(
          content: currentMessage.content + chunk,
          isStreaming: true,
        );
        notifyListeners();
      }
    }
  }

  void deleteMessage(String channelId, String messageId) {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      messages.removeWhere((m) => m.id == messageId);
      _selectedMessageIds.remove(messageId);
      _bulkDiaryVisible.remove(messageId);
      notifyListeners();
    }
  }

  void setMessages(String channelId, List<ChatMessage> messages, bool hasMore) {
    _channelMessages[channelId] = messages;
    _hasMoreMessages[channelId] = hasMore;
    notifyListeners();
  }

  void prependMessages(String channelId, List<ChatMessage> messages, bool hasMore) {
    _channelMessages.putIfAbsent(channelId, () => []);
    _channelMessages[channelId]!.insertAll(0, messages);
    _hasMoreMessages[channelId] = hasMore;
    notifyListeners();
  }

  // Processing state
  void setProcessingMessage(bool isProcessing) {
    if (_isProcessingMessage != isProcessing) {
      _isProcessingMessage = isProcessing;
      notifyListeners();
    }
  }

  void setActiveMinionProcessor(String minionName, bool isProcessing) {
    if (isProcessing) {
      _activeMinionProcessors[minionName] = true;
    } else {
      _activeMinionProcessors.remove(minionName);
    }
    notifyListeners();
  }

  void clearActiveMinionProcessors() {
    if (_activeMinionProcessors.isNotEmpty) {
      _activeMinionProcessors.clear();
      notifyListeners();
    }
  }

  // Auto-scroll
  void setAutoScrollEnabled(bool enabled) {
    if (_isAutoScrollEnabled != enabled) {
      _isAutoScrollEnabled = enabled;
      notifyListeners();
    }
  }

  // Selection mode
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      clearSelection();
    }
    notifyListeners();
  }

  void selectMessage(String messageId) {
    if (_selectedMessageIds.contains(messageId)) {
      _selectedMessageIds.remove(messageId);
    } else {
      _selectedMessageIds.add(messageId);
    }
    _lastSelectedMessageId = messageId;
    notifyListeners();
  }

  void selectMessageRange(String fromId, String toId, List<ChatMessage> messages) {
    final fromIndex = messages.indexWhere((m) => m.id == fromId);
    final toIndex = messages.indexWhere((m) => m.id == toId);
    
    if (fromIndex != -1 && toIndex != -1) {
      final start = fromIndex < toIndex ? fromIndex : toIndex;
      final end = fromIndex < toIndex ? toIndex : fromIndex;
      
      for (int i = start; i <= end; i++) {
        _selectedMessageIds.add(messages[i].id);
      }
      _lastSelectedMessageId = toId;
      notifyListeners();
    }
  }

  void clearSelection() {
    if (_selectedMessageIds.isNotEmpty || _bulkDiaryVisible.isNotEmpty) {
      _selectedMessageIds.clear();
      _bulkDiaryVisible.clear();
      _lastSelectedMessageId = null;
      notifyListeners();
    }
  }

  void deleteSelectedMessages(String channelId) {
    final messages = _channelMessages[channelId];
    if (messages != null) {
      messages.removeWhere((m) => _selectedMessageIds.contains(m.id));
      _selectedMessageIds.clear();
      _bulkDiaryVisible.clear();
      notifyListeners();
    }
  }

  void toggleBulkDiary(List<String> messageIds) {
    bool allVisible = messageIds.every((id) => _bulkDiaryVisible.contains(id));
    
    if (allVisible) {
      messageIds.forEach(_bulkDiaryVisible.remove);
    } else {
      _bulkDiaryVisible.addAll(messageIds);
    }
    notifyListeners();
  }

  // User message creation helper
  ChatMessage _createUserMessage(String channelId, String content) {
    return ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      channelId: channelId,
      senderType: MessageSender.user,
      senderName: LegionApiService.legionCommanderName,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // --- Actions with Business Logic ---

  Future<void> sendMessage(String content) async {
    if (currentChannelId == null || content.trim().isEmpty) return;

    final userMessage = _createUserMessage(currentChannelId!, content.trim());

    addMessage(currentChannelId!, userMessage);

    setProcessingMessage(true);
    clearActiveMinionProcessors();

    await _legionApiService.processMessageTurn(
      channelId: currentChannelId!,
      triggeringMessage: userMessage,
      onMinionResponse: (message) {
        upsertMessage(message);
      },
      onMinionResponseChunk: (channelId, messageId, chunk) {
        processMessageChunk(channelId, messageId, chunk);
      },
      onMinionProcessingUpdate: (minionName, isProcessing) {
        setActiveMinionProcessor(minionName, isProcessing);
      },
      onSystemMessage: (message) {
        addMessage(message.channelId, message);
      },
      onRegulatorReport: (message) {
        addMessage(message.channelId, message);
      },
      onToolUpdate: (message) {
        upsertMessage(message);
      },
    );

    setProcessingMessage(false);
  }
}