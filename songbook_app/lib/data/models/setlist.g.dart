// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Setlist _$SetlistFromJson(Map<String, dynamic> json) => Setlist(
  id: json['id'] as String,
  name: json['name'] as String,
  songIds:
      (Setlist._readSongIds(json, 'songIds') as List<dynamic>?)
          ?.map((e) => const SongIdConverter().fromJson(e as Object))
          .toList() ??
      [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SetlistToJson(Setlist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'songIds': instance.songIds.map(const SongIdConverter().toJson).toList(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
