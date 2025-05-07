class Trip {
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final List<DayItinerary> itinerary;
  final double estimatedCost;

  Trip({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.itinerary,
    required this.estimatedCost,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final days = json['itinerary'] as List;
    return Trip(
      destination: json['destination'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      itinerary: days.map((day) => DayItinerary.fromJson(day)).toList(),
      estimatedCost: json['estimatedCost']?.toDouble() ?? 0,
    );
  }

  int get duration => endDate.difference(startDate).inDays;
}

class DayItinerary {
  final int dayNumber;
  final List<Activity> morning;
  final List<Activity> afternoon;
  final List<Activity> evening;

  DayItinerary({
    required this.dayNumber,
    required this.morning,
    required this.afternoon,
    required this.evening,
  });

  factory DayItinerary.fromJson(Map<String, dynamic> json) {
    return DayItinerary(
      dayNumber: json['dayNumber'],
      morning:
          (json['morning'] as List).map((a) => Activity.fromJson(a)).toList(),
      afternoon:
          (json['afternoon'] as List).map((a) => Activity.fromJson(a)).toList(),
      evening:
          (json['evening'] as List).map((a) => Activity.fromJson(a)).toList(),
    );
  }
}

class Activity {
  final String title;
  final String description;
  final String location;
  final String type;
  final double? cost;
  final String? imageUrl;
  final Duration? duration;

  Activity({
    required this.title,
    required this.description,
    required this.location,
    required this.type,
    this.cost,
    this.imageUrl,
    this.duration,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      title: json['title'],
      description: json['description'],
      location: json['location'],
      type: json['type'],
      cost: json['cost']?.toDouble(),
      imageUrl: json['imageUrl'],
      duration:
          json['duration'] != null ? Duration(minutes: json['duration']) : null,
    );
  }
}
