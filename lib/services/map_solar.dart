import 'package:http/http.dart' as http;
import 'package:mapbox_v2/utils/delegates/places_response.dart';

// server urls
var urlServer = 'https://api.moterosyrutas.appmoterosyrutas.com';

//
Future<List<Feature>> getPlaces(originlng, originlat, search) async {
  //
  String url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/';
  //
  final response = await http.get(
      Uri.parse(
          '$url$search.json?limit=10&proximity=$originlat,$originlng&language=es&access_token=sk.eyJ1IjoiYWxnb3JpdG1pYSIsImEiOiJjbGNjaTB5a2MybnUwM3Fxa3E2YnAzcDIxIn0.IcXN5w5D6BUGsPECqiaNRg'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'steps': 'application/json; charset=UTF-8',
      });
  //
  final datos = PlacesResponse.fromJson(response.body);
  //
  return datos.features;
}
