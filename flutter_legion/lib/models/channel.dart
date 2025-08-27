import 'package:json_annotation/json_annotation.dart';

part 'channel.g.dart';

enum ChannelType {
  @JsonValue('dm')
  dm,
  @JsonValue('user_minion_group')
  userMinionGroup,
  @JsonValue('minion_minion_auto')
  minionMinionAuto,
  @JsonValue('user_only')
  userOnly,
}

@JsonSerializable()
class AutoModeDelay {
  final int min;
  final int max;

  const AutoModeDelay({required this.min, required this.max});

  factory AutoModeDelay.fromJson(Map<String, dynamic> json) =>
      _$AutoModeDelayFromJson(json);

  Map<String, dynamic> toJson() => _$AutoModeDelayToJson(this);
}

@JsonSerializable()
class Channel {
  final String id;
  final String name;
  final String description;
  final ChannelType type;
  final List<String> members;
  final bool isAutoModeActive;
  final String autoModeDelayType; // 'fixed' | 'random'
  final int? autoModeFixedDelay;
  final AutoModeDelay? autoModeRandomDelay;

  const Channel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.members,
    this.isAutoModeActive = false,
    this.autoModeDelayType = 'fixed',
    this.autoModeFixedDelay,
    this.autoModeRandomDelay,
  });

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);

  Map<String, dynamic> toJson() => _$ChannelToJson(this);

  Channel copyWith({
    String? id,
    String? name,
    String? description,
    ChannelType? type,
    List<String>? members,
    bool? isAutoModeActive,
    String? autoModeDelayType,
    int? autoModeFixedDelay,
    AutoModeDelay? autoModeRandomDelay,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      members: members ?? this.members,
      isAutoModeActive: isAutoModeActive ?? this.isAutoModeActive,
      autoModeDelayType: autoModeDelayType ?? this.autoModeDelayType,
      autoModeFixedDelay: autoModeFixedDelay ?? this.autoModeFixedDelay,
      autoModeRandomDelay: autoModeRandomDelay ?? this.autoModeRandomDelay,
    );
  }
}