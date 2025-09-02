import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/channel.dart';
import '../models/chat_message.dart';
import '../models/minion_config.dart';

class StorageService {
  static const String _channelsBox = 'channels_box';
  static const String _minionsBox = 'minions_box';
  static const String _messagesBox = 'messages_box'; // key = channelId, value = List<Map>
  static const String _presetsBox = 'presets_box';
  static const String _modelsBox = 'models_box'; // key 'list' => List<String>

  Box<Map>? _channels;
  Box<Map>? _minions;
  Box<dynamic>? _messages; // stores List<Map>
  Box<Map>? _presets; // key=id, value={id,name,content}
  Box<dynamic>? _models; // key='list', value=List<String>

  Future<void> init() async {
    await Hive.initFlutter();
    _channels = await Hive.openBox<Map>(_channelsBox);
    _minions = await Hive.openBox<Map>(_minionsBox);
    _messages = await Hive.openBox<dynamic>(_messagesBox);
    _presets = await Hive.openBox<Map>(_presetsBox);
    _models = await Hive.openBox<dynamic>(_modelsBox);
  }

  // Channels
  Future<List<Channel>> loadChannels() async {
    final box = _channels!;
    return box.values
        .map((m) => Channel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> saveChannel(Channel c) async {
    await _channels!.put(c.id, c.toJson());
  }

  Future<void> removeChannel(String id) async {
    await _channels!.delete(id);
    await _messages!.delete(id);
  }

  // Minions
  Future<List<MinionConfig>> loadMinions() async {
    final box = _minions!;
    return box.values
        .map((m) => MinionConfig.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> saveMinion(MinionConfig m) async {
    await _minions!.put(m.id, m.toJson());
  }

  Future<void> removeMinion(String id) async {
    await _minions!.delete(id);
  }

  // Messages
  Future<List<ChatMessage>> loadMessages(String channelId) async {
    final raw = _messages!.get(channelId);
    if (raw is List) {
      return raw
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<void> setMessages(String channelId, List<ChatMessage> messages) async {
    final list = messages.map((m) => m.toJson()).toList();
    await _messages!.put(channelId, list);
  }

  Future<void> appendMessage(String channelId, ChatMessage message) async {
    final current = await loadMessages(channelId);
    current.add(message);
    await setMessages(channelId, current);
  }

  Future<void> upsertMessage(String channelId, ChatMessage message) async {
    final current = await loadMessages(channelId);
    final idx = current.indexWhere((m) => m.id == message.id);
    if (idx >= 0) {
      current[idx] = message;
    } else {
      current.add(message);
    }
    await setMessages(channelId, current);
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    final current = await loadMessages(channelId);
    current.removeWhere((m) => m.id == messageId);
    await setMessages(channelId, current);
  }

  // Prompt Presets
  Future<List<Map<String, dynamic>>> loadPromptPresets() async {
    final box = _presets!;
    return box.values.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<void> savePromptPreset(Map<String, dynamic> preset) async {
    await _presets!.put(preset['id'] as String, Map<String, dynamic>.from(preset));
  }

  Future<void> deletePromptPreset(String id) async {
    await _presets!.delete(id);
  }

  // Model list caching (optional)
  Future<List<String>> loadModelList() async {
    final raw = _models!.get('list');
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  Future<void> saveModelList(List<String> ids) async {
    await _models!.put('list', ids);
  }
}
