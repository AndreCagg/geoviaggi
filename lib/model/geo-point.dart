import 'package:latlong2/latlong.dart';

class GeoPoint {
  const GeoPoint({required this.coords, required this.zoom});

  final LatLng coords;
  final double zoom;
}
