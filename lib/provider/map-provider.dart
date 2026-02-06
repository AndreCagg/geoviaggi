import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapProvider extends ChangeNotifier {
  List<Marker> markers = [];
  List<LatLng> travelLine = [LatLng(40.4, 16.36)];

  void setMarkers(List<Marker> m) {
    markers = m;
    notifyListeners();
  }

  void setTravelLine(List<LatLng> t) {
    travelLine = t;
    notifyListeners();
  }
}
