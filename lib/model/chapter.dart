import 'package:geoviaggi/model/chapter-media.dart';
import 'package:latlong2/latlong.dart';

class Chapter {
  Chapter({
    required this.id,
    required this.point,
    required this.images,
    required this.chapter,
    required this.description,
    required this.zoom,
    required this.videos,
    required this.videoUrl,
    required this.isCredit,
    required this.credit,
    required this.videoDescription,
    required this.roundedCircle,
    required this.titoloTappa,
    required this.sourceLink,
  });

  final int id;
  final LatLng point;
  final List<ChapterMedia> images;
  final String chapter;
  final String description;
  final double zoom;
  final bool videos;
  final String videoUrl;
  final bool isCredit;
  final String credit;
  final String videoDescription;
  final bool roundedCircle;
  String titoloTappa;
  final String sourceLink;
}
