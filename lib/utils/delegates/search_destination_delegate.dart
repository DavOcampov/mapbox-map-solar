import 'package:flutter/material.dart';

class SearchDestinationDelegate extends SearchDelegate {
  SearchDestinationDelegate() : super(searchFieldLabel: 'Buscar');

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

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          close(context, null);
        });
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Text('buildResults');
  }

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
                  close(context, null);
                },
              )
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: 10,
              itemBuilder: (context, index) {
                return ListTile(
                  onTap: () async {
                    //
                    close(
                      context,
                      null,
                    );
                  },
                  title: const Text(
                    '10',
                    style: TextStyle(color: Colors.black),
                  ),
                  subtitle: const Text(
                    '10',
                    style: TextStyle(color: Colors.black),
                  ),
                  leading: const Icon(Icons.location_on, color: Colors.blue),
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
