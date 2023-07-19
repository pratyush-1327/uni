import 'package:json_annotation/json_annotation.dart';
import 'package:logger/logger.dart';

part 'trip.g.dart';

/// Stores information about a bus trip.
@JsonSerializable()
class Trip {
  final String line;
  final String destination;
  final int timeRemaining;

  Trip(
      {required this.line,
      required this.destination,
      required this.timeRemaining});

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
  Map<String, dynamic> toJson() => _$TripToJson(this);

  /// Prints the data in this trip to the [Logger] with an INFO level.
  void printTrip() {
    Logger().i('$line ($destination) - $timeRemaining');
  }

  /// Compares the remaining time of two trips.
  int compare(Trip other) {
    return (timeRemaining.compareTo(other.timeRemaining));
  }
}
