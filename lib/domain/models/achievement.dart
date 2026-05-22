import 'package:equatable/equatable.dart';

/// Represents an achievement that can be earned through cycling activity.
///
/// [type] categorizes the achievement: distance, totalRides, totalTime,
/// singleRide, or elevation.
/// [earnedAt] is null when the achievement is still locked; non-null when
/// it has been unlocked.
class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String icon;
  final double requiredValue;
  final String type;
  final DateTime? earnedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredValue,
    required this.type,
    this.earnedAt,
  });

  bool get isUnlocked => earnedAt != null;

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    double? requiredValue,
    String? type,
    DateTime? earnedAt,
    bool clearEarnedAt = false,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      requiredValue: requiredValue ?? this.requiredValue,
      type: type ?? this.type,
      earnedAt: clearEarnedAt ? null : earnedAt ?? this.earnedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        icon,
        requiredValue,
        type,
        earnedAt,
      ];
}
