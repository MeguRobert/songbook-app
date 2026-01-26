// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Origin _$OriginFromJson(Map<String, dynamic> json) => Origin(
  place: json['place'] as String?,
  year: (json['year'] as num?)?.toInt(),
);

Map<String, dynamic> _$OriginToJson(Origin instance) => <String, dynamic>{
  'place': instance.place,
  'year': instance.year,
};

Tune _$TuneFromJson(Map<String, dynamic> json) => Tune(
  name: json['name'] as String?,
  origin: json['origin'] == null
      ? null
      : Origin.fromJson(json['origin'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TuneToJson(Tune instance) => <String, dynamic>{
  'name': instance.name,
  'origin': instance.origin,
};

SheetMusic _$SheetMusicFromJson(Map<String, dynamic> json) => SheetMusic(
  type: json['type'] as String,
  basePath: json['basePath'] as String,
);

Map<String, dynamic> _$SheetMusicToJson(SheetMusic instance) =>
    <String, dynamic>{'type': instance.type, 'basePath': instance.basePath};

Song _$SongFromJson(Map<String, dynamic> json) => Song(
  number: (json['number'] as num).toInt(),
  title: json['title'] as String,
  reference: json['reference'] as String?,
  origin: json['origin'] == null
      ? null
      : Origin.fromJson(json['origin'] as Map<String, dynamic>),
  tune: json['tune'] == null
      ? null
      : Tune.fromJson(json['tune'] as Map<String, dynamic>),
  originalKey: json['originalKey'] as String,
  timeSignature: json['timeSignature'] as String?,
  sheetMusic: json['sheetMusic'] == null
      ? null
      : SheetMusic.fromJson(json['sheetMusic'] as Map<String, dynamic>),
  verses: (json['verses'] as List<dynamic>)
      .map((e) => Verse.fromJson(e as Map<String, dynamic>))
      .toList(),
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
);

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
  'number': instance.number,
  'title': instance.title,
  'reference': instance.reference,
  'origin': instance.origin,
  'tune': instance.tune,
  'originalKey': instance.originalKey,
  'timeSignature': instance.timeSignature,
  'sheetMusic': instance.sheetMusic,
  'verses': instance.verses,
  'tags': instance.tags,
};
