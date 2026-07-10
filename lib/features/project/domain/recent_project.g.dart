// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecentProjectImpl _$$RecentProjectImplFromJson(Map<String, dynamic> json) =>
    _$RecentProjectImpl(
      filePath: json['filePath'] as String,
      name: json['name'] as String,
      lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
    );

Map<String, dynamic> _$$RecentProjectImplToJson(_$RecentProjectImpl instance) =>
    <String, dynamic>{
      'filePath': instance.filePath,
      'name': instance.name,
      'lastOpenedAt': instance.lastOpenedAt.toIso8601String(),
    };
