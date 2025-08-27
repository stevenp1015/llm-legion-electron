import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/minion_config.dart';

class AppProvider extends ChangeNotifier {
  // Core app state
  List<Channel> _channels = [];
  List<MinionConfig> _minionConfigs = [];
  bool _isServiceInitialized = false;
  
  // UI state
  bool _isMinionsPanelOpen = false;
  bool _isAnalyticsOpen = false;
  bool _isMcpManagerOpen = false;
  
  // Getters
  List<Channel> get channels => _channels;
  List<MinionConfig> get minionConfigs => _minionConfigs;
  bool get isServiceInitialized => _isServiceInitialized;
  bool get isMinionsPanelOpen => _isMinionsPanelOpen;
  bool get isAnalyticsOpen => _isAnalyticsOpen;
  bool get isMcpManagerOpen => _isMcpManagerOpen;
  
  List<String> get allMinionNames => _minionConfigs.map((m) => m.name).toList();
  
  Channel? getChannel(String channelId) {
    try {
      return _channels.firstWhere((c) => c.id == channelId);
    } catch (e) {
      return null;
    }
  }

  MinionConfig? getMinionConfig(String minionName) {
    try {
      return _minionConfigs.firstWhere((m) => m.name == minionName);
    } catch (e) {
      return null;
    }
  }

  // Service initialization
  void setServiceInitialized(bool initialized) {
    if (_isServiceInitialized != initialized) {
      _isServiceInitialized = initialized;
      notifyListeners();
    }
  }

  // Channel management
  void setChannels(List<Channel> channels) {
    _channels = channels;
    notifyListeners();
  }

  void addChannel(Channel channel) {
    _channels.add(channel);
    notifyListeners();
  }

  void updateChannel(Channel channel) {
    final index = _channels.indexWhere((c) => c.id == channel.id);
    if (index != -1) {
      _channels[index] = channel;
      notifyListeners();
    }
  }

  void removeChannel(String channelId) {
    _channels.removeWhere((c) => c.id == channelId);
    notifyListeners();
  }

  // Minion management
  void setMinionConfigs(List<MinionConfig> configs) {
    // Use a more robust comparison to prevent unnecessary re-renders
    if (_minionConfigs.length != configs.length || 
        !_deepEquals(_minionConfigs, configs)) {
      _minionConfigs = configs;
      notifyListeners();
    }
  }

  void addMinionConfig(MinionConfig config) {
    _minionConfigs.add(config);
    notifyListeners();
  }

  void updateMinionConfig(MinionConfig config) {
    final index = _minionConfigs.indexWhere((m) => m.id == config.id);
    if (index != -1) {
      _minionConfigs[index] = config;
      notifyListeners();
    }
  }

  void removeMinionConfig(String configId) {
    _minionConfigs.removeWhere((m) => m.id == configId);
    notifyListeners();
  }

  // UI state management
  void setMinionsPanelOpen(bool open) {
    if (_isMinionsPanelOpen != open) {
      _isMinionsPanelOpen = open;
      notifyListeners();
    }
  }

  void toggleMinionsPanelOpen() {
    _isMinionsPanelOpen = !_isMinionsPanelOpen;
    notifyListeners();
  }

  void setAnalyticsOpen(bool open) {
    if (_isAnalyticsOpen != open) {
      _isAnalyticsOpen = open;
      notifyListeners();
    }
  }

  void setMcpManagerOpen(bool open) {
    if (_isMcpManagerOpen != open) {
      _isMcpManagerOpen = open;
      notifyListeners();
    }
  }

  // Helper method for deep equality check
  bool _deepEquals(List<MinionConfig> list1, List<MinionConfig> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      final config1 = list1[i];
      final config2 = list2[i];
      
      if (config1.id != config2.id ||
          config1.name != config2.name ||
          config1.role != config2.role ||
          config1.chatColor != config2.chatColor ||
          config1.fontColor != config2.fontColor ||
          config1.usageStats?.totalTokens != config2.usageStats?.totalTokens) {
        return false;
      }
    }
    return true;
  }
}