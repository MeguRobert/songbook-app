// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Favorite _$FavoriteFromJson(Map<String, dynamic> json) => Favorite(
  songId: const SongIdConverter().fromJson(
    Favorite._readSongId(json, 'songId') as Object,
  ),
  addedAt: DateTime.parse(json['addedAt'] as String),
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$FavoriteToJson(Favorite instance) => <String, dynamic>{
  'songId': const SongIdConverter().toJson(instance.songId),
  'addedAt': instance.addedAt.toIso8601String(),
  'sortOrder': instance.sortOrder,
};
