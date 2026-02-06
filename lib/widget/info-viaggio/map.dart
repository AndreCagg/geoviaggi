import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoviaggi/provider/map-provider.dart';
import 'package:geoviaggi/widget/info-viaggio/map-controller.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class CustomMap extends StatefulWidget {
  CustomMap({
    super.key,
    required this.controller,
    required this.mykey,
    required this.customMapController,
  });
  final MapController controller;
  final GlobalKey mykey;
  final CustomMapController customMapController;

  @override
  State<CustomMap> createState() {
    return _CustomMapState();
  }
}

class _CustomMapState extends State<CustomMap> with TickerProviderStateMixin {
  void animatedMapMove(LatLng destLocation, double destZoom) {
    final camera = widget.controller.camera;

    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );

    final controller = AnimationController(
      duration: Duration(milliseconds: 450),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    controller.addListener(() {
      widget.controller.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        destZoom,
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  void initState() {
    widget.customMapController.animatedMove = animatedMapMove;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (BuildContext context, MapProvider value, Widget? child) {
        return FlutterMap(
          key: widget.mykey,
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: LatLng(40.666634, 16.601161),
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: "com.geoviaggi.geoviaggi",
              tileProvider: NetworkTileProvider(silenceExceptions: true),
              keepBuffer: 4,
              errorTileCallback: (tile, error, stackTrace) {
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded),
                    Text("Errore nel caricamento della mappa"),
                  ],
                );
              },
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: value.travelLine,
                  color: Colors.blue,
                  pattern: StrokePattern.dashed(segments: [30, 10]),
                  borderStrokeWidth: 1,
                  borderColor: Colors.blue,
                ),
              ],
            ),
            MarkerLayer(markers: value.markers),
          ],
        );
      },
    );
  }
}
