// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyric_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricLine _$LyricLineFromJson(Map<String, dynamic> json) => LyricLine(
  text: json['text'] as String,
  chords:
      (json['chords'] as List<dynamic>?)
          ?.map((e) => ChordPosition.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$LyricLineToJson(LyricLine instance) => <String, dynamic>{
  'text': instance.text,
  'chords': instance.chords,
};
