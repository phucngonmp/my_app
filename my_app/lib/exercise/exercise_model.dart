class Exercise {
  final int index;
  final String name;
  final int sets;
  final int? reps;
  final int? seconds;
  final int setsCompleted;

  Exercise({
    required this.index,
    required this.name,
    required this.sets,
    this.reps,
    this.seconds,
    this.setsCompleted = 0,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      index: json['index'],
      name: json['name'],
      sets: json['sets'],
      reps: json['reps'],
      seconds: json['seconds'],
      setsCompleted: json['setsCompleted'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'name': name,
      'sets': sets,
      'reps': reps,
      'seconds': seconds,
      'setsCompleted': setsCompleted,
    };
  }

}