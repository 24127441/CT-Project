class AchievementProgress {
  final String location;
  final int visits;

  const AchievementProgress({required this.location, required this.visits});

  AchievementProgress copyWith({String? location, int? visits}) {
    return AchievementProgress(
      location: location ?? this.location,
      visits: visits ?? this.visits,
    );
  }

  Map<String, dynamic> toJson() => {
        'location': location,
        'visits': visits,
      };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      location: json['location']?.toString() ?? 'Không xác định',
      visits: int.tryParse(json['visits']?.toString() ?? '') ?? 0,
    );
  }
}

enum MedalTier { none, bronze, silver, gold }

MedalTier medalForVisits(int visits) {
  if (visits >= 5) return MedalTier.gold;
  if (visits >= 3) return MedalTier.silver;
  if (visits >= 1) return MedalTier.bronze;
  return MedalTier.none;
}
