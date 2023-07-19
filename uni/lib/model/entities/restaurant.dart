import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uni/model/entities/meal.dart';
import 'package:uni/model/utils/day_of_week.dart';

part 'restaurant.g.dart';

@JsonSerializable()
class Restaurant {
  @JsonKey(name: 'id')
  final int? id;
  @JsonKey(name: 'name')
  final String name;
  @JsonKey(name: 'ref')
  final String reference; // Used only in html parser
  final Map<DayOfWeek, List<Meal>> meals;

  get isNotEmpty {
    return meals.isNotEmpty;
  }

  Restaurant(this.id, this.name, this.reference, {required List<Meal> meals})
      : meals = groupBy(meals, (meal) => meal.dayOfWeek);

  factory Restaurant.fromJson(Map<String, dynamic> json, List<Meal> meals) =>
      _$RestaurantFromJson(json, meals);
  Map<String, dynamic> toJson() => _$RestaurantToJson(this);

  List<Meal> getMealsOfDay(DayOfWeek dayOfWeek) {
    return meals[dayOfWeek] ?? [];
  }
}
