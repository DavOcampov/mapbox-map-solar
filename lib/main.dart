import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_v2/utils/delegates/delegates.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:turf/turf.dart' as turf;
import 'package:location/location.dart' as loc;
import 'package:fluttertoast/fluttertoast.dart';

GlobalKey globalKey = GlobalKey();

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

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  MapboxMap? mapboxMap;
  PointAnnotation? pointAnnotation;
  PointAnnotationManager? pointAnnotationManager;
  late FToast fToast;
  String dniData = 'N/A';
  double? dniS;
  bool hasExecuted = true;
  bool isLoading = false;
  bool isSelected = false;
  int _styleIndex = 0;
  bool _removeLayer = false;
  final double _zoom = 5;
  final List<dynamic> _position = [4.0000000, -72.0000000];
  final geolocator.GeolocatorPlatform _geolocatorPlatform = geolocator.GeolocatorPlatform.instance;
  StreamSubscription<geolocator.ServiceStatus>? _serviceStatusStreamSubscription;
  loc.Location location = loc.Location();

  List<String> styleStrings = [
    MapboxStyles.MAPBOX_STREETS,
    MapboxStyles.DARK,
    MapboxStyles.LIGHT,
    MapboxStyles.OUTDOORS,
    MapboxStyles.TRAFFIC_DAY,
    MapboxStyles.TRAFFIC_NIGHT,
    MapboxStyles.SATELLITE_STREETS
  ];

  List<String> styleStringsLayer = [
    'mapbox://styles/algoritmia/clcb3serk000b14rop5j8cyxe',
    'mapbox://styles/algoritmia/clchuhhe1005a14pa7xhe4gwp',
    'mapbox://styles/algoritmia/clchtzym5002h14pnjxzv82b0',
    'mapbox://styles/algoritmia/clchtrxr4002j14o2jn148bna',
    'mapbox://styles/algoritmia/clchuzk40000c16qux6c4uo16',
    'mapbox://styles/algoritmia/clchum7sv001g14ohujg8m15f',
    'mapbox://styles/algoritmia/clcht97a8000714pkgp50l9aa',
  ];

  // Obtain shared preferences.
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    getPreferencer();
    toggleServiceStatusStream();
    hasExecuted = false;
    fToast = FToast();
    fToast.init(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  _eventObserver(Event event) {
    print("Receive event, type: ${event.type}, data: ${event.data}");
  }

  // Escuchador de eventos para verificar si esta encendido o no el servicio del GPS
  toggleServiceStatusStream() {
    if (_serviceStatusStreamSubscription == null) {
      final serviceStatusStream = _geolocatorPlatform.getServiceStatusStream();
      _serviceStatusStreamSubscription = serviceStatusStream.handleError((error) {
        _serviceStatusStreamSubscription?.cancel();
        _serviceStatusStreamSubscription = null;
      }).listen((serviceStatus) async {
        if (serviceStatus == geolocator.ServiceStatus.enabled) {
          PermissionStatus status = await Permission.location.status;
          if (status == PermissionStatus.granted) {
            mapboxMap?.location
                .updateSettings(LocationComponentSettings(enabled: true, pulsingEnabled: true, puckBearingEnabled: true));
          }
        } else {
          mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: false));
        }
      });
    }
  }

  // Se solicita encenter el servicio de gps
  statusServicesGps() async {
    bool serviceEnabled;

    try {
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return false;
        }
        return true;
      }
      return true;
    } on PlatformException {
      serviceEnabled = false;
      statusServicesGps();
      return false;
    }
  }

  // Funcion - Virificar Si hay preferencias de estilos guardados en la memoria
  getPreferencer() async {
    SharedPreferences prefs = await _prefs;
    _removeLayer = prefs.getBool('removeLayer') ?? false;
    _styleIndex = prefs.getInt('styleIndex') ?? 0;
  }

  // Funcion - Cambiar los estilo del mapa
  onChangeMap() async {
    SharedPreferences prefs = await _prefs;
    await prefs.setInt('styleIndex', _styleIndex);
    if (_removeLayer) {
      await mapboxMap?.style.setStyleURI(styleStrings[_styleIndex]);
    } else {
      await mapboxMap?.style.setStyleURI(styleStringsLayer[_styleIndex]);
    }
  }

  // Opciones para el controlador mapbox
  onMapCreated(MapboxMap mapboxMap) async {
    if (!hasExecuted) {
      this.mapboxMap = mapboxMap;
      mapboxMap.subscribe(_eventObserver, [
        MapEvents.STYLE_LOADED,
        MapEvents.MAP_LOADED,
        MapEvents.MAP_IDLE,
      ]);
      PermissionStatus status = await Permission.location.status;
      if (status == PermissionStatus.granted) {
        await mapboxMap.location
            .updateSettings(LocationComponentSettings(enabled: true, pulsingEnabled: true, puckBearingEnabled: true));
      }
      //await addLayer();
      if (_removeLayer) {
        await mapboxMap.style.setStyleURI(styleStrings[_styleIndex]);
      } else {
        await mapboxMap.style.setStyleURI(styleStringsLayer[_styleIndex]);
      }
      hasExecuted = true;
    }

    // Cargar estilo del mapa desde Mapbox Studio
    //await mapboxMap.style.setStyleURI("mapbox://styles/algoritmia/clcb3serk000b14rop5j8cyxe");
  }

  // funcion que obtiene la posicion del dispositivo
  _getPosition() async {
    var position = await geolocator.Geolocator.getCurrentPosition();
    mapboxMap?.easeTo(
        CameraOptions(
            center: turf.Point(
                coordinates: turf.Position(
              position.longitude,
              position.latitude,
            )).toJson(),
            zoom: 15,
            bearing: 0,
            pitch: 0),
        MapAnimationOptions(
          duration: 1500,
          startDelay: 0,
        ));
  }

  // On Tap Map
  _onTap(ScreenCoordinate coordinate) async {
    if (!isLoading) {
      log("OnTap ${coordinate.x} ${coordinate.y}");
      // Funcion para agrega y actualizar el marcador al mapa
      if (pointAnnotation != null) {
        // var point = Point.fromJson((pointAnnotation!.geometry)!.cast());
        var newPoint = turf.Point(coordinates: turf.Position(coordinate.y, coordinate.x));
        pointAnnotation?.geometry = newPoint.toJson();
        pointAnnotationManager?.update(pointAnnotation!);
      } else {
        mapboxMap?.annotations.createPointAnnotationManager().then((value) async {
          pointAnnotationManager = value;
          final ByteData bytes = await rootBundle.load('assets/marker.png');
          final Uint8List list = bytes.buffer.asUint8List();
          createOneAnnotation(list, coordinate.y, coordinate.x);
        });
      }

      try {
        var data = await getIrradiance(coordinate.x, coordinate.y);
        if (data.isNotEmpty || data == null) {
          if ((data["annual"]['data'] as Map)['DNI'] != null) {
            double dniDay = ((data["annual"]['data'] as Map)['DNI']) / 365;
            double dni = double.parse(dniDay.toStringAsFixed(2));

            setState(() {
              isLoading = false;
              dniS = dni;
              dniData = "$dni kwh/m²/Día";
            });
          } else {
            setState(() {
              isLoading = false;
              dniData = 'N/A';
            });
          }
        } else {
          setState(() {
            isLoading = false;
            dniData = 'N/A';
          });
        }
      } catch (e) {
        setState(() {
          isLoading = false;
          dniData = 'N/A';
        });
      }
    }
  }

  // Funcion para crear el marcador o point
  createOneAnnotation(Uint8List list, double x, double y) {
    pointAnnotationManager
        ?.create(PointAnnotationOptions(
            geometry: turf.Point(
                coordinates: turf.Position(
              x,
              y,
            )).toJson(),
            iconSize: 0.9,
            iconOffset: [0.0, -15.0],
            symbolSortKey: 10,
            image: list))
        .then((value) => pointAnnotation = value);
  }

  // Funcion para leer la radiacion desde la api
  getIrradiance(double x, double y) async {
    if (isLoading) return;
    isLoading = true;
    setState(() {});
    final http.Response response;

    // Api de globalsolaratlas para consultar la radiacion solar anual
    String urlSolaris = "https://api.globalsolaratlas.info/data/lta?loc=$x,$y";

    try {
      response = await http.get(Uri.parse(urlSolaris));
      var data = jsonDecode(response.body);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  // contenedor q muestra la distancia de una ruta entre ambos puntos
  radiationWidget() {
    return Positioned(
      top: 70,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
        ),
        width: 123,
        height: 45,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 7, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.sunny,
                        color: Colors.yellow,
                        size: 20.0,
                      ),
                      Text(
                        ' Radiación:',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (isLoading)
                    Container(
                      width: 112,
                      alignment: Alignment.center,
                      child: Flex(
                          direction: Axis.vertical,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                            ),
                          ]),
                    )
                  else
                    Text(
                      '  $dniData',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              height: 45,
              width: 4,
              decoration: const BoxDecoration(color: Colors.red),
            )
          ],
        ),
      ),
    );
  }

  // Toast para confirmar que se denegaron los permisos
  _showBuilderToast() {
    double width = MediaQuery.of(context).size.width;
    fToast.showToast(
        child: Container(
            width: width,
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 15.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5.0),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Se rechazó el permiso a la app.'),
                Container(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 17),
                        ),
                        onPressed: () async {
                          await openAppSettings();
                        },
                        child: const Text('Configuración'))),
              ],
            )),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
        positionedToastBuilder: (context, child) {
          return Positioned(
            bottom: 5.0,
            right: 7,
            left: 7,
            child: child,
          );
        });
  }

  // Widget boton para mostrar la ubicacion
  getLocation() {
    return Positioned(
        bottom: 90,
        right: 15,
        child: Container(
          alignment: Alignment.center,
          width: 45.0,
          height: 45.0,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color.fromARGB(255, 0, 0, 0),
              width: 1,
            ),
            shape: BoxShape.circle,
            color: const Color.fromARGB(255, 53, 53, 53),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                spreadRadius: 0.5,
                blurRadius: 3,
                offset: const Offset(0, 2), // changes position of shadow
              ),
            ],
          ),
          child: IconButton(
              padding: const EdgeInsets.all(0),
              onPressed: () async {
                /* bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: false));
                } */
                var status = await Permission.locationWhenInUse.request();
                if (status == PermissionStatus.granted) {
                  var statusGps = await statusServicesGps();
                  if (statusGps) {
                    await mapboxMap?.location
                        .updateSettings(LocationComponentSettings(enabled: true, pulsingEnabled: true, puckBearingEnabled: true));
                    _getPosition();
                  }
                } else if (status == PermissionStatus.permanentlyDenied) {
                  _showBuilderToast();
                }
              },
              icon: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 23.0,
              )),
        ));
  }

  // Cambiar el tipo de mapa
  changeTypeMap(context) {
    return Positioned(
      top: 130,
      right: 15,
      child: Container(
        alignment: Alignment.center,
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.fromARGB(255, 0, 0, 0),
            width: 1,
          ),
          shape: BoxShape.circle,
          color: const Color.fromARGB(255, 53, 53, 53),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 0.5,
              blurRadius: 3,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: IconButton(
            padding: const EdgeInsets.all(0),
            onPressed: () {
              showMaterialModalBottomSheet(
                  context: context,
                  builder: (BuildContext context) => StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                        return Material(
                            color: const Color.fromARGB(255, 245, 245, 245),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Tipo de mapa',
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                                fontFamily: 'FiraSans'),
                                            textAlign: TextAlign.center),
                                        IconButton(
                                            splashRadius: 1,
                                            alignment: Alignment.topRight,
                                            padding: const EdgeInsets.all(0),
                                            onPressed: () => Navigator.of(context).pop(),
                                            icon: const Icon(
                                              Icons.close,
                                            ))
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                                        child: IconButton(
                                            splashRadius: 56,
                                            iconSize: 84,
                                            onPressed: () async {
                                              setState(() {
                                                _styleIndex = 0;
                                              });
                                              onChangeMap();
                                            },
                                            icon: Column(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7.0),
                                                    border: Border.all(
                                                      style: _styleIndex == 0 ? BorderStyle.solid : BorderStyle.none,
                                                      color: Colors.blue,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    margin: const EdgeInsets.all(1.5),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(5.0),
                                                      child: Image.asset(
                                                        'assets/normal.png',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 6,
                                                ),
                                                const Text('Estándar')
                                              ],
                                            )),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                                        child: IconButton(
                                            splashRadius: 56,
                                            iconSize: 84,
                                            onPressed: () async {
                                              setState(() {
                                                _styleIndex = 1;
                                              });
                                              onChangeMap();
                                            },
                                            icon: Column(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7.0),
                                                    border: Border.all(
                                                      style: _styleIndex == 1 ? BorderStyle.solid : BorderStyle.none,
                                                      color: Colors.blue,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    margin: const EdgeInsets.all(1.5),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(5.0),
                                                      child: Image.asset(
                                                        'assets/dark.png',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 6,
                                                ),
                                                const Text('Noche')
                                              ],
                                            )),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                                        child: IconButton(
                                            splashRadius: 56,
                                            iconSize: 84,
                                            onPressed: () async {
                                              setState(() {
                                                _styleIndex = 6;
                                              });
                                              onChangeMap();
                                            },
                                            icon: Column(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7.0),
                                                    border: Border.all(
                                                      style: _styleIndex == 6 ? BorderStyle.solid : BorderStyle.none,
                                                      color: Colors.blue,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    margin: const EdgeInsets.all(1.5),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(5.0),
                                                      child: Image.asset(
                                                        'assets/satellite.jfif',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 6,
                                                ),
                                                const Text('Satélite')
                                              ],
                                            )),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                                        child: IconButton(
                                            splashRadius: 56,
                                            iconSize: 84,
                                            onPressed: () async {
                                              setState(() {
                                                _styleIndex = 4;
                                              });
                                              onChangeMap();
                                            },
                                            icon: Column(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7.0),
                                                    border: Border.all(
                                                      style: _styleIndex == 4 ? BorderStyle.solid : BorderStyle.none,
                                                      color: Colors.blue,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    margin: const EdgeInsets.all(1.5),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(5.0),
                                                      child: Image.asset(
                                                        'assets/street.png',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 6,
                                                ),
                                                const Text('Calles')
                                              ],
                                            )),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 15.0, left: 20.0, right: 20.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: const [
                                        Text('Detalles del mapa',
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                                fontFamily: 'FiraSans'),
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                                        child: IconButton(
                                            splashRadius: 56,
                                            iconSize: 84,
                                            onPressed: () async {
                                              setState(() {
                                                _removeLayer = !_removeLayer;
                                              });
                                              SharedPreferences prefs = await _prefs;
                                              await prefs.setBool('removeLayer', _removeLayer);
                                              if (_removeLayer) {
                                                await mapboxMap?.style.setStyleURI(styleStrings[_styleIndex]);
                                              } else {
                                                await mapboxMap?.style.setStyleURI(styleStringsLayer[_styleIndex]);
                                              }
                                            },
                                            icon: Column(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7.0),
                                                    border: Border.all(
                                                      style: _removeLayer ? BorderStyle.none : BorderStyle.solid,
                                                      color: Colors.blue,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    margin: const EdgeInsets.all(1.5),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(5.0),
                                                      child: Image.asset(
                                                        'assets/normal.png',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 6,
                                                ),
                                                const Text('Radiación')
                                              ],
                                            )),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ));
                      }));
            },
            icon: const Icon(
              Icons.layers_outlined,
              color: Colors.white,
              size: 25.0,
            )),
      ),
    );
  }

  // Guardar la radiacion solar
  btnSaveData() {
    return FloatingActionButton.extended(
      onPressed: () {
        if (dniS != null) {
          print(dniS);
          //Navigator.pushNamed(context, "/rutaName", arguments: dniS);
        }
      },
      label: const Text('Guardar & salir'),
      icon: const Icon(Icons.save),
    );
  }

  btnSearch() {
    return Positioned(
      top: 180,
      right: 15,
      child: Container(
        alignment: Alignment.center,
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.fromARGB(255, 0, 0, 0),
            width: 1,
          ),
          shape: BoxShape.circle,
          color: const Color.fromARGB(255, 53, 53, 53),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 0.5,
              blurRadius: 3,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: IconButton(
            padding: const EdgeInsets.all(0),
            onPressed: () async {
              PermissionStatus status = await Permission.location.status;
              if (status == PermissionStatus.granted) {
                var statusGps = await statusServicesGps();
                if (statusGps) {
                  var position = await geolocator.Geolocator.getCurrentPosition();
                  final result = await showSearch(
                      context: context,
                      delegate: SearchDestinationDelegate(latOrigin: position.latitude, lngOrigin: position.longitude));
                  if (result == null) return;
                } else {
                  final result = await showSearch(context: context, delegate: SearchDestinationDelegate());
                  if (result == null) return;
                }
              } else {
                final result = await showSearch(context: context, delegate: SearchDestinationDelegate());
                if (result == null) return;
              }
            },
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 23.0,
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      key: globalKey,
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: Stack(children: [
            if (true)
              SizedBox(
                width: size.width,
                height: size.height,
                child: MapWidget(
                  styleUri: styleStrings[_styleIndex],
                  key: const ValueKey("mapWidget"),
                  resourceOptions: ResourceOptions(
                      accessToken: 'sk.eyJ1IjoiYWxnb3JpdG1pYSIsImEiOiJjbGNjaTB5a2MybnUwM3Fxa3E2YnAzcDIxIn0.IcXN5w5D6BUGsPECqiaNRg'),
                  onMapCreated: onMapCreated,
                  textureView: true,
                  onTapListener: _onTap,
                  cameraOptions: CameraOptions(
                    center: turf.Point(coordinates: turf.Position(_position[1], _position[0])).toJson(),
                    zoom: _zoom,
                  ),
                ),
              ),
            btnSearch(),
            radiationWidget(),
            changeTypeMap(context),
            getLocation(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Container(
                alignment: Alignment.bottomCenter,
                child: btnSaveData(),
              ),
            )
          ]),
        ),
      ),
    );
  }
}
