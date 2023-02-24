import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import 'package:uni/controller/fetchers/public_transportation_fetchers/public_transportation_fetcher.dart';
import 'package:uni/model/entities/stop.dart';
import 'package:uni/model/entities/route.dart';


class ExplorePortoAPIFetcher extends PublicTransportationFetcher{

  ExplorePortoAPIFetcher() : super("explorePorto");

  static final Uri _endpoint = Uri.https("otp.services.porto.digital", "/otp/routers/default/index/graphql");


  static TransportationType convertVehicleMode(String vehicleMode){
    switch(vehicleMode){
      case "BUS":
        return TransportationType.bus;
      case "SUBWAY":
        return TransportationType.subway;
      case "TRAM":
        return TransportationType.tram;
      case "FUNICULAR":
        return TransportationType.funicular;
      default:
        throw ArgumentError("vehicleMode: $vehicleMode is not a supported type..");
    }
  }

  @override
  Future<Map<String, Stop>> fetchStops() async{
    final Map<String, Stop> map = {};
    final response = await http.post(_endpoint,
      headers:  {"Content-Type": "application/json"}, 
      body: "{\"query\":\"{stops{gtfsId, name, code, vehicleMode, lat, lon}\\n}\"}");
    if(response.statusCode != 200){
      return Future.error(HttpException("Explore.porto API returned status ${response.statusCode} while fetching stops..."));
    }
    final List<dynamic> responseStops = jsonDecode(response.body)['data']['stops'];
    for (dynamic entry in responseStops){
      final TransportationType transportType = convertVehicleMode(entry['vehicleMode']);
      //when the stop is of a subway they have no code so we have to deal with it differently
      if(transportType == TransportationType.subway || transportType == TransportationType.funicular){
        map.putIfAbsent(entry['gtfsId'], () => 
          Stop(entry['gtfsId'], entry['name'], transportType, entry['lat'], entry['lon'], providerName));
      } else{
        map.putIfAbsent(entry['gtfsId'], () => 
          Stop(entry['gtfsId'], entry['code'], transportType, entry['lat'], entry['lon'], providerName, longName: entry['name']));
      }
    }
    return map;
  }

  @override
  Future<Map<String,Route>> fetchRoutes(Map<String, Stop> stopMap) async {
    final Map<String,Route> routes = {};
    final response = await http.post(_endpoint, 
    headers: {"Content-Type": "application/json"}, 
    body: "{\"query\":\"{routes {gtfsId, longName, shortName, mode, patterns{code,stops{gtfsId},directionId}}}\"}");
    if(response.statusCode != 200){
      return Future.error(HttpException("Explore.porto API returned status ${response.statusCode} while fetching routes..."));
    }
    final List<dynamic> responseRoutes = jsonDecode(response.body)['data']['routes'];
    for (dynamic entry in responseRoutes){
      final TransportationType transportType = convertVehicleMode(entry['mode']);
      final List<dynamic> patternsList = entry["patterns"];
      final List<RoutePattern> patterns = patternsList.map((e) {
        final LinkedHashSet<Stop> stops = LinkedHashSet.identity();
        for (dynamic stop in e['stops']){
          final Stop? s = stopMap[stop['gtfsId']];
          if(s == null){
            Logger().e("Couldn't find stop ${stop['gtfsId']} on route ${entry['gtfsId']}...");
            continue;
          }
          stops.add(s);
        }
        return RoutePattern(e["code"], e['directionId'], stops, providerName, {});
      }).toList();
      final Route route = Route(
        entry['gtfsId'], 
        entry['shortName'], 
        transportType, 
        providerName,
        longName: entry['longName'],
        routePatterns: patterns
        );
      routes.putIfAbsent(entry['gtfsId'], () => route);
    }
    return routes;
  }
  
  @override
  Future<void> fetchRoutePatternTimetable(RoutePattern routePattern) async {
    final response = await http.post(_endpoint, 
      headers: {"Content-Type":"application/json"},
      body: '{"query":"{pattern(id: "${routePattern.patternId}"){trips{activeDates,stoptimes{scheduledArrival,serviceDay}}}}"}'
    );
    if(response.statusCode != 200){
      return Future.error(HttpException("Explore.porto API returned status ${response.statusCode} while fetching timetable..."));
    }
    final List<dynamic> trips = jsonDecode(response.body)["data"]["pattern"];

    //format using in date
    final DateFormat dateFormat = DateFormat("yMMd");

    for(dynamic trip in trips){
      final List<int> stoptimes = (trip["stoptimes"] as List<Map<String,int>>).map((e) => e["scheduledArrival"]!).toList();
      final List<DateTime> serviceDates = (trip["activeDates"] as List<String>).map((e) => dateFormat.parse(e)).toList(); 

      for(DateTime serviceDate in serviceDates){
        if(routePattern.timetable.containsKey(serviceDate)){
          routePattern.timetable[serviceDate]!.add(stoptimes);
        } else{
          routePattern.timetable[serviceDate] = {stoptimes};
        }
      }
    }

  }



}