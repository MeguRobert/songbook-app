// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Setlist _$SetlistFromJson(Map<String, dynamic> json) => Setlist(
  id: json['id'] as String,
  name: json['name'] as String,
  songNumbers:
      (json['songNumbers'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SetlistToJson(Setlist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'songNumbers': instance.songNumbers,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
