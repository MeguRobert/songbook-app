// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verse.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Verse _$VerseFromJson(Map<String, dynamic> json) => Verse(
  number: (json['number'] as num).toInt(),
  hasNotation: json['hasNotation'] as bool? ?? false,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  plainText: json['plainText'] as String?,
);

Map<String, dynamic> _$VerseToJson(Verse instance) => <String, dynamic>{
  'number': instance.number,
  'hasNotation': instance.hasNotation,
  'lines': instance.lines,
  'plainText': instance.plainText,
};
