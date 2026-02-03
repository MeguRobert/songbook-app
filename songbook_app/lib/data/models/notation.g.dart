// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotatedBeat _$NotatedBeatFromJson(Map<String, dynamic> json) => NotatedBeat(
  pitch: json['pitch'] as String,
  duration: $enumDecode(_$NoteDurationEnumMap, json['duration']),
  syllable: json['syllable'] as String?,
  syllables: (json['syllables'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  chord: json['chord'] as String?,
  tieStart: json['tieStart'] as bool? ?? false,
  tieEnd: json['tieEnd'] as bool? ?? false,
  dotted: json['dotted'] as bool? ?? false,
);

Map<String, dynamic> _$NotatedBeatToJson(NotatedBeat instance) =>
    <String, dynamic>{
      'pitch': instance.pitch,
      'duration': _$NoteDurationEnumMap[instance.duration]!,
      'syllable': instance.syllable,
      'syllables': instance.syllables,
      'chord': instance.chord,
      'tieStart': instance.tieStart,
      'tieEnd': instance.tieEnd,
      'dotted': instance.dotted,
    };

const _$NoteDurationEnumMap = {
  NoteDuration.whole: 'whole',
  NoteDuration.half: 'half',
  NoteDuration.quarter: 'quarter',
  NoteDuration.eighth: 'eighth',
  NoteDuration.sixteenth: 'sixteenth',
};

NotatedMeasure _$NotatedMeasureFromJson(Map<String, dynamic> json) =>
    NotatedMeasure(
      beats: (json['beats'] as List<dynamic>)
          .map((e) => NotatedBeat.fromJson(e as Map<String, dynamic>))
          .toList(),
      repeatStart: json['repeatStart'] as bool? ?? false,
      repeatEnd: json['repeatEnd'] as bool? ?? false,
      lineBreakAfter: json['lineBreakAfter'] as bool? ?? false,
    );

Map<String, dynamic> _$NotatedMeasureToJson(NotatedMeasure instance) =>
    <String, dynamic>{
      'beats': instance.beats,
      'repeatStart': instance.repeatStart,
      'repeatEnd': instance.repeatEnd,
      'lineBreakAfter': instance.lineBreakAfter,
    };

NotatedVerse _$NotatedVerseFromJson(Map<String, dynamic> json) => NotatedVerse(
  number: (json['number'] as num).toInt(),
  measures: (json['measures'] as List<dynamic>)
      .map((e) => NotatedMeasure.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$NotatedVerseToJson(NotatedVerse instance) =>
    <String, dynamic>{'number': instance.number, 'measures': instance.measures};

SongNotation _$SongNotationFromJson(Map<String, dynamic> json) => SongNotation(
  originalKey: json['originalKey'] as String,
  timeSignature: json['timeSignature'] as String,
  showTimeSignature: json['showTimeSignature'] as bool? ?? true,
  verses: (json['verses'] as List<dynamic>)
      .map((e) => NotatedVerse.fromJson(e as Map<String, dynamic>))
      .toList(),
  pickup: (json['pickup'] as List<dynamic>?)
      ?.map((e) => NotatedBeat.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SongNotationToJson(SongNotation instance) =>
    <String, dynamic>{
      'originalKey': instance.originalKey,
      'timeSignature': instance.timeSignature,
      'showTimeSignature': instance.showTimeSignature,
      'verses': instance.verses,
      'pickup': instance.pickup,
    };
