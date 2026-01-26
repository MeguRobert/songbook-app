// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chord_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChordPosition _$ChordPositionFromJson(Map<String, dynamic> json) =>
    ChordPosition(
      chord: json['chord'] as String,
      position: (json['position'] as num).toInt(),
    );

Map<String, dynamic> _$ChordPositionToJson(ChordPosition instance) =>
    <String, dynamic>{'chord': instance.chord, 'position': instance.position};
