import 'package:flutter/material.dart';

class Section {
  final int? id;
  final int trackId;
  final String label;
  final Duration startTime;
  final Duration endTime;
  final Color color;
  final int orderIndex;

  const Section({
    this.id,
    required this.trackId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.orderIndex = 0,
  });

  Duration get duration => endTime - startTime;

  Section copyWith({
    int? id,
    int? trackId,
    String? label,
    Duration? startTime,
    Duration? endTime,
    Color? color,
    int? orderIndex,
  }) {
    return Section(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trackId': trackId,
      'label': label,
      'startTimeMs': startTime.inMilliseconds,
      'endTimeMs': endTime.inMilliseconds,
      'colorValue': color.toARGB32(),
      'orderIndex': orderIndex,
    };
  }

  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as int?,
      trackId: map['trackId'] as int,
      label: map['label'] as String,
      startTime: Duration(milliseconds: map['startTimeMs'] as int),
      endTime: Duration(milliseconds: map['endTimeMs'] as int),
      color: Color(map['colorValue'] as int),
      orderIndex: map['orderIndex'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'Section(id: $id, label: $label)';
}
