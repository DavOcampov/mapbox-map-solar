import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_v2/utils/conditions_map.dart';
import 'package:turf/turf.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Map Solar DNI',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MapboxMap? mapboxMap;
  PointAnnotation? pointAnnotation;
  PointAnnotationManager? pointAnnotationManager;

  List<String> styleStrings = [
    MapboxStyles.MAPBOX_STREETS,
    MapboxStyles.DARK,
    MapboxStyles.LIGHT,
    MapboxStyles.OUTDOORS,
    MapboxStyles.TRAFFIC_DAY,
    MapboxStyles.TRAFFIC_NIGHT,
    MapboxStyles.SATELLITE,
    MapboxStyles.SATELLITE_STREETS
  ];

  int styleIndex = 0;

  String dniData = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    var data = await rootBundle.loadString('assets/file.geojson');
    await mapboxMap.style.addSource(GeoJsonSource(id: "line", data: data));
    await mapboxMap.style.addLayer(FillLayer(id: "solar_layer", sourceId: "line", fillOpacity: 0.3));

    await mapboxMap.style.setStyleLayerProperty("solar_layer", "fill-color", MapProperties.valueProperty);

    // Cargar estilo del mapa desde Mapbox Studio
    //await mapboxMap.style.setStyleURI("mapbox://styles/algoritmia/clcb3serk000b14rop5j8cyxe");
  }

// On Tap Map ------------------------------------------------
  _onTap(ScreenCoordinate coordinate) async {
    log("OnTap ${coordinate.x} ${coordinate.y}");
    Map data = await getIrradiance(coordinate.x, coordinate.y);

    if (data.isNotEmpty) {
      if ((data["annual"]['data'] as Map)['DNI'] != null) {
        double dniDay = ((data["annual"]['data'] as Map)['DNI']) / 365;
        double dni = double.parse(dniDay.toStringAsFixed(2));

        setState(() {
          dniData = "$dni kwh/m2/Día";
        });
      } else {
        setState(() {
          dniData = 'N/A';
        });
      }
    }
  }

  // Funcion para crear el marcador o point
  void createOneAnnotation(Uint8List list, double x, double y) {
    pointAnnotationManager
        ?.create(PointAnnotationOptions(
            geometry: Point(
                coordinates: Position(
              x,
              y,
            )).toJson(),
            textColor: Colors.red.value,
            iconSize: 0.9,
            iconOffset: [0.0, -15.0],
            symbolSortKey: 10,
            image: list))
        .then((value) => pointAnnotation = value);
  }

  // Funcion para leer la radiacion desde la api
  Future getIrradiance(double x, double y) async {
    final http.Response response;
    // Funcion para agrega y actualizar el marcador al mapa
    if (pointAnnotation != null) {
      // var point = Point.fromJson((pointAnnotation!.geometry)!.cast());
      var newPoint = Point(coordinates: Position(y, x));
      pointAnnotation?.geometry = newPoint.toJson();
      pointAnnotationManager?.update(pointAnnotation!);
    } else {
      mapboxMap?.annotations.createPointAnnotationManager().then((value) async {
        pointAnnotationManager = value;
        final ByteData bytes = await rootBundle.load('assets/marker.png');
        final Uint8List list = bytes.buffer.asUint8List();
        createOneAnnotation(list, y, x);
      });
    }

    // Api de globalsolaratlas para consultar la radiacion solar anual
    String urlSolaris = "https://api.globalsolaratlas.info/data/lta?loc=$x,$y";

    // Api para leer las propiedades del layer y capturar radicacion desde el tileset en Mapbox
    // ignore: unused_local_variable
    // String urlMapbox = "https://api.mapbox.com/v4/algoritmia.82i9r5nq/tilequery/$y,$x.json?access_token=pk.eyJ1IjoiYWxnb3JpdG1pYSIsImEiOiJjbDd6OGRpaXkxOHAzM3ZvYXNkbjNucHJ3In0.Y51Nnul9mCcuqzO0wDDJrA";

    try {
      response = await http.get(Uri.parse(urlSolaris));
      var data = jsonDecode(response.body);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

// Mostrar radiacion solar desde el archivo geojson o tileset local
  /* void _clickMap(ScreenCoordinate coordinate) async {
    log("OnTap ${coordinate.x} ${coordinate.y}");

    ScreenCoordinate coordin = await mapboxMap!.pixelForCoordinate({
      "coordinates": [coordinate.y, coordinate.x]
    });

    List<QueriedFeature?> features = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry(type: Type.SCREEN_COORDINATE, value: json.encode(coordin.encode())), RenderedQueryOptions());

    if (features.isNotEmpty) {
      if ((features[0]!.feature["properties"] as Map)['description'] != null) {
        var radiation = (features[0]!.feature["properties"] as Map)['description'];
        log("Radiacion $radiation kWh/m2/día");
      } else {
        log('No hay inforacion para estas coordenadas');
      }
    } else {
      log('Informacion solo disponible para Colombia');
    } 
  } */

  // contenedor q muestra la distancia de una ruta entre ambos puntos
  distanceWidget() {
    return Positioned(
      top: 70,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
        ),
        width: 110,
        height: 40,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Radiacion: ',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    dniData,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              height: 40,
              width: 4,
              decoration: const BoxDecoration(color: Colors.red),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: Stack(children: [
            if (false)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: Colors.blue),
                  ],
                ),
              ),
            if (true)
              MapWidget(
                styleUri: styleStrings[styleIndex],
                key: const ValueKey("mapWidget"),
                resourceOptions: ResourceOptions(
                    accessToken: 'sk.eyJ1IjoiYWxnb3JpdG1pYSIsImEiOiJjbGNjaTB5a2MybnUwM3Fxa3E2YnAzcDIxIn0.IcXN5w5D6BUGsPECqiaNRg'),
                onMapCreated: onMapCreated,
                textureView: true,
                onTapListener: _onTap,
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(-73.301214, 4.0478237)).toJson(),
                  zoom: 5,
                ),
              ),
            distanceWidget(),
          ]),
        ),
      ),
    );
  }
}
