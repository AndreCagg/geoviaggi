import 'package:geoviaggi/model/chapter.dart';
import 'package:latlong2/latlong.dart';

class Viaggio {
  const Viaggio({
    required this.mostraLinee,
    required this.chapters,
    required this.titolo,
    required this.line,
  });

  final bool mostraLinee;
  final List<Chapter> chapters;
  final String titolo;
  final List<LatLng> line;
}
