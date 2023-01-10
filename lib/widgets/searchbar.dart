import 'package:flutter/material.dart';
import 'package:mapbox_v2/utils/delegates/delegates.dart';

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      width: double.infinity,
      height: 40,
      child: GestureDetector(
        onTap: () {
          showSearch(context: context, delegate: SearchDestinationDelegate());
        },
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 5))]),
          child: const Text(
            'Buscar ubicacón',
            style: TextStyle(color: Colors.black26),
          ),
        ),
      ),
    );
  }
}
