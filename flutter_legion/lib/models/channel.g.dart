// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AutoModeDelay _$AutoModeDelayFromJson(Map<String, dynamic> json) =>
    AutoModeDelay(
      min: (json['min'] as num).toInt(),
      max: (json['max'] as num).toInt(),
    );

Map<String, dynamic> _$AutoModeDelayToJson(AutoModeDelay instance) =>
    <String, dynamic>{
      'min': instance.min,
      'max': instance.max,
    };

Channel _$ChannelFromJson(Map<String, dynamic> json) => Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: $enumDecode(_$ChannelTypeEnumMap, json['type']),
      members:
          (json['members'] as List<dynamic>).map((e) => e as String).toList(),
      isAutoModeActive: json['isAutoModeActive'] as bool? ?? false,
      autoModeDelayType: json['autoModeDelayType'] as String? ?? 'fixed',
      autoModeFixedDelay: (json['autoModeFixedDelay'] as num?)?.toInt(),
      autoModeRandomDelay: json['autoModeRandomDelay'] == null
          ? null
          : AutoModeDelay.fromJson(
              json['autoModeRandomDelay'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ChannelToJson(Channel instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'type': _$ChannelTypeEnumMap[instance.type]!,
      'members': instance.members,
      'isAutoModeActive': instance.isAutoModeActive,
      'autoModeDelayType': instance.autoModeDelayType,
      'autoModeFixedDelay': instance.autoModeFixedDelay,
      'autoModeRandomDelay': instance.autoModeRandomDelay?.toJson(),
    };

const _$ChannelTypeEnumMap = {
  ChannelType.dm: 'dm',
  ChannelType.userMinionGroup: 'user_minion_group',
  ChannelType.minionMinionAuto: 'minion_minion_auto',
  ChannelType.userOnly: 'user_only',
};
