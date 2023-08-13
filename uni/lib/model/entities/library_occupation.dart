import 'package:json_annotation/json_annotation.dart';

part 'library_occupation.g.dart';

/// Overall occupation of the library
@JsonSerializable()
class LibraryOccupation {
  LibraryOccupation(this.occupation, this.capacity) {
    floors = [];
  }
  late int occupation;
  late int capacity;
  late List<FloorOccupation> floors;

  void addFloor(FloorOccupation floor) {
    floors.add(floor);
    occupation += floor.occupation;
    capacity += floor.capacity;
  }

  int get percentage {
    if (capacity == 0) return 0;
    return (occupation * 100 / capacity).round();
  }

  FloorOccupation getFloor(int number) {
    if (floors.length < number || number < 0) return FloorOccupation(0, 0, 0);
    return floors[number - 1];
  }

  factory LibraryOccupation.fromJson(Map<String, dynamic> json) =>
      _$LibraryOccupationFromJson(json);
  Map<String, dynamic> toJson() => _$LibraryOccupationToJson(this);
}

/// Occupation values of a single floor
@JsonSerializable()
class FloorOccupation {
  FloorOccupation(this.number, this.occupation, this.capacity);
  final int number;
  final int occupation;
  final int capacity;

  int get percentage {
    if (capacity == 0) return 0;
    return (occupation * 100 / capacity).round();
  }

  factory FloorOccupation.fromJson(Map<String, dynamic> json) =>
      _$FloorOccupationFromJson(json);
  Map<String, dynamic> toJson() => _$FloorOccupationToJson(this);
}
