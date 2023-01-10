import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_v2/models/models.dart';
import 'package:mapbox_v2/services/map_solar.dart';
import 'package:mapbox_v2/utils/delegates/places_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchDestinationDelegate extends SearchDelegate<SearchResult> {
  // cargamos las preferencias del cache
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  SearchDestinationDelegate({this.latOrigin = 0, this.lngOrigin = 0}) : super(searchFieldLabel: 'Buscar') {
    _loadCache();
  }
  // creamos variables privadas
  final ValueNotifier<List<Feature>> _results = ValueNotifier(<Feature>[]);
  List<Feature> _records = <Feature>[];
  double? latOrigin;
  double? lngOrigin;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
          icon: const Icon(Icons.cancel_outlined),
          onPressed: () {
            query = '';
          })
    ];
  }

  // cargamos el cache
  _loadCache() async {
    // tomamos datos del cache
    final prefs = await SharedPreferences.getInstance();
    final String? records = prefs.getString('records');
    //
    if (records != null) {
      List data = jsonDecode(records);
      for (int i = 0; i < data.length; i++) {
        Feature info = Feature.fromMap(jsonDecode(data[i]));
        _records.add(info);
      }
    }
  }

  // guardamos en cache la busqueda para el historial
  _saveToCache(Feature data) async {
    List<Feature> records = _records.where((record) {
      return (record.text != data.text) ? true : false;
    }).toList();
    //
    _records = records;
    _records.insert(0, data);
    SharedPreferences prefs = await _prefs;
    await prefs.setString('records', jsonEncode(_records));
  }

  // Elimanamos el item seleccionado de la cache
  _deleteOneToCache(Feature data) async {
    List<Feature> recosrs = _records.removeWhere((item) => item.text == data.text) as List<Feature>;
    _records = recosrs;
    SharedPreferences prefs = await _prefs;
    await prefs.setString('records', jsonEncode(_records));
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          final result = SearchResult(cancel: true);
          close(context, result);
        });
  }

  // widget q no retorna la lista de resultados de la busqueda
  @override
  Widget buildResults(BuildContext context) {
    //
    if (query != '') {
      getPlaces(latOrigin, lngOrigin, query).then(
        (data) => {
          if (data.isNotEmpty) {_results.value = data},
        },
      );
    } else {
      _results.value = [];
    }
    //
    return ValueListenableBuilder(
      valueListenable: _results,
      builder: (context, value, child) {
        if (_results.value.isEmpty) return Container();
        //
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: ListView.separated(
            itemCount: _results.value.length,
            itemBuilder: (context, index) {
              return ListTile(
                onTap: () {
                  //
                  _saveToCache(_results.value[index]);
                  //
                  close(
                    context,
                    SearchResult(
                      cancel: false,
                      latDestination: _results.value[index].geometry.coordinates[1],
                      lngDestination: _results.value[index].geometry.coordinates[0],
                    ),
                  );
                },
                title: Text(
                  _results.value[index].text,
                  style: const TextStyle(color: Colors.black),
                ),
                subtitle: Text(
                  _results.value[index].placeName,
                  style: const TextStyle(color: Colors.black),
                ),
                leading: const Icon(Icons.location_on, color: Colors.black),
              );
            },
            separatorBuilder: (BuildContext context, int index) => const Divider(),
          ),
        );
      },
    );
  }

// widget q nos retorna la lista con el historial de busquedas
  @override
  Widget buildSuggestions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        children: [
          ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: Colors.black,
                ),
                title: const Text(
                  'Puedes buscar la ubicacion tocando el mapa!',
                  style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
                ),
                onTap: () {
                  close(context, SearchResult(cancel: true));
                },
              )
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: _records.length,
              itemBuilder: (context, index) {
                return ListTile(
                  onTap: () async {
                    //
                    close(
                      context,
                      SearchResult(
                        cancel: false,
                        latDestination: _records[index].geometry.coordinates[1],
                        lngDestination: _records[index].geometry.coordinates[0],
                      ),
                    );
                    //
                    _saveToCache(_records[index]);
                  },
                  title: Text(
                    _records[index].text,
                    style: const TextStyle(color: Colors.black),
                  ),
                  subtitle: Text(
                    _records[index].placeName,
                    style: const TextStyle(color: Colors.black),
                  ),
                  leading: const Icon(Icons.watch_later_outlined, color: Colors.black),
                );
              },
              separatorBuilder: (BuildContext context, int index) => const Divider(),
            ),
          ),
        ],
      ),
    );
  }
}
