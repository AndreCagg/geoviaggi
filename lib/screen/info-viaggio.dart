import 'dart:async';
import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoviaggi/model/chapter-media.dart';
import 'package:geoviaggi/model/chapter.dart';
import 'package:geoviaggi/model/geo-point.dart';
import 'package:geoviaggi/model/viaggio.dart';
import 'package:geoviaggi/provider/map-provider.dart';
import 'package:geoviaggi/widget/info-viaggio/map-controller.dart';
import 'package:geoviaggi/widget/info-viaggio/map.dart';
import 'package:geoviaggi/widget/info-viaggio/travel-card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class InfoViaggio extends StatefulWidget {
  const InfoViaggio({super.key});

  @override
  State<InfoViaggio> createState() => _InfoViaggioState();
}

class _InfoViaggioState extends State<InfoViaggio> {
  late Future<Viaggio?> travel;
  LatLng? initialPoint;
  List<Marker> markers = [];
  late MapController mapController;
  String? chapterTitle;
  List<String> titles = [];
  int? activeCard;
  late List<CarouselSliderController> buttonCarouselController = [];
  late ScrollController scrollController;
  late Map<int, int> imageActive = {};
  List<LatLng> travelLine = [LatLng(40.4, 16.36)];
  List<GlobalKey> itemKeys = [];
  String titoloViaggio = "";
  GlobalKey titoloTappaKey = GlobalKey();
  late double titleBottom;
  Timer? _scrollDebounce;
  late String lastTitle;
  List<GeoPoint> points = [];
  late ListObserverController observerController;
  bool mostraLinee = true;

  GlobalKey mapKey = GlobalKey();
  late CustomMap myMap;
  late CustomMapController customMapController;

  Future<Viaggio?> getTravel() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://geoviaggi.lucanasistemi.com/geoviaggi/api/geo-json/019c1f76-9564-77ea-b7d8-7dcd8d633104",
        ),
      );
      /*print(response.statusCode);
      print(response.body);*/

      if (response.statusCode != 200) return null;
      if (!response.body.startsWith("{")) return null;

      final Map<String, dynamic> json = jsonDecode(response.body);

      List<Chapter> chapters = [];
      List<Marker> _markers = [];
      List<dynamic> jsonChapters = json["features"] ?? [];
      mostraLinee = json["mostra"]["mostraLinee"] as bool;

      for (var f in jsonChapters) {
        Map<String, dynamic> properties = {};
        properties = f["properties"];
        final coords = f["geometry"]["coordinates"] as List<dynamic>;
        final point = LatLng(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        );

        List<ChapterMedia> images = [];
        List<dynamic> jsonImages = properties["images"] ?? [];
        for (var i in jsonImages) {
          images.add(
            ChapterMedia(
              active: i["active"] as bool? ?? false,
              id: i["idImage"] as String? ?? "",
              url: i["url"] as String? ?? "",
            ),
          );
        }

        if (properties["titoloTappa"] != null) {
          chapterTitle ??= properties["titoloTappa"];
        }

        chapters.add(
          Chapter(
            id: properties["id"] as int? ?? 0,
            point: point,
            images: images,
            chapter: properties["chapter"] as String? ?? "",
            description: properties["description"] as String? ?? "",
            zoom: (properties["zoom"] as num?)?.toDouble() ?? 13,
            videos: properties["videos"] as bool? ?? false,
            videoUrl: properties["videoUrl"] as String? ?? "",
            isCredit: properties["iscredit"] as bool? ?? false,
            credit: properties["source-credit"] as String? ?? "",
            videoDescription: properties["videoDes"] as String? ?? "",
            roundedCircle: properties["roundedCircle"] as bool? ?? false,
            titoloTappa: properties["titoloTappa"] as String? ?? "",
            sourceLink: properties["source-link"] as String? ?? "",
          ),
        );

        _markers.add(
          Marker(
            point: LatLng(point.latitude, point.longitude),
            child: GestureDetector(
              onTap: () {
                final chapterIndex = chapters.indexWhere(
                  (c) => c.id == properties["id"] as int,
                );
                scrollToCard(chapterIndex);
              },

              child: Icon(Icons.location_on, size: 40),
            ),
          ),
        );
      }

      List<LatLng> linePoints = [];
      final jsonFeatureLine = json["featureLine"]?["geometry"];
      if (jsonFeatureLine != null) {
        final coordinates =
            jsonFeatureLine["coordinates"] as List<dynamic>? ?? [];
        for (var c in coordinates) {
          linePoints.add(
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          );
        }
      }

      Provider.of<MapProvider>(context, listen: false).setMarkers(_markers);

      if (mostraLinee) {
        Provider.of<MapProvider>(
          context,
          listen: false,
        ).setTravelLine(linePoints);
      }

      //creazione primo titolo
      for (Chapter c in chapters) {
        if (c.titoloTappa.isNotEmpty) {
          lastTitle = c.titoloTappa;

          break;
        }
      }

      for (Chapter c in chapters) {
        if (c.titoloTappa.isEmpty) {
          c.titoloTappa = lastTitle;
        } else {
          lastTitle = c.titoloTappa;
        }

        titles.add(c.titoloTappa);
        points.add(GeoPoint(coords: c.point, zoom: c.zoom));
      }

      customMapController.animatedMove!(
        chapters.first.point,
        chapters.first.zoom,
      );

      Viaggio v = Viaggio(
        mostraLinee: json["mostra"]?["mostraLinee"] as bool? ?? false,
        chapters: chapters,
        titolo: json["titoloViaggio"]?["titolo"] as String? ?? "",
        line: linePoints,
      );

      setState(() {
        titoloViaggio = v.titolo;
      });

      return v;
    } catch (e) {
      /*print("Errore nel parsing del viaggio: $e");
      print(stack);*/
    }
    return null;
  }

  void _onScroll() {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    _scrollDebounce = Timer(Duration(milliseconds: 60), () {
      if (!mounted) return;
      _updateVisibleTitle();
    });
  }

  void _updateVisibleTitle() {
    if (!mounted) return;

    for (int idx = 0; idx < itemKeys.length; idx++) {
      final cardContext = itemKeys[idx].currentContext;
      if (cardContext == null) continue;

      final RenderBox cardBox = cardContext.findRenderObject() as RenderBox;
      final double cardTop = cardBox.localToGlobal(Offset.zero).dy;
      final double thr = cardBox.size.height * 0.45;

      //se la sto visualizzando e non è passata
      if ((cardTop <= (titleBottom + thr)) &&
          (cardTop + cardBox.size.height > (titleBottom + thr))) {
        if (activeCard == null || activeCard != idx) {
          activeCard = idx;
          _updateChapterTitle(idx);
        }
      }
    }
  }

  void _updateChapterTitle(int idx) {
    if (idx < 0 || idx >= titles.length) return;

    setState(() {
      chapterTitle = titles[idx];
    });

    GeoPoint p = points[idx];
    customMapController.animatedMove!(p.coords, p.zoom);
  }

  void scrollToCard(int idx) {
    observerController.jumpTo(index: idx);
  }

  @override
  void initState() {
    travel = getTravel();
    //per la visualizzazione della posizione sulla mappa
    mapController = MapController();

    //per l'animazione
    customMapController = CustomMapController();
    myMap = CustomMap(
      controller: mapController,
      mykey: mapKey,
      customMapController: customMapController,
    );
    scrollController = ScrollController();
    scrollController.addListener(_onScroll);
    observerController = ListObserverController(controller: scrollController);
    observerController.cacheJumpIndexOffset = false;

    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  double lastCardHeight = 0;

  @override
  Widget build(BuildContext context) {
    List<Widget> childrens = [
      FutureBuilder(
        future: travel,
        builder: (ctx, snp) {
          late Widget child;
          if (snp.connectionState == ConnectionState.waiting) {
            child = CircularProgressIndicator();
          } else {
            if (snp.hasData) {
              Viaggio v = snp.data!;
              child = Expanded(
                child: Column(
                  children: [
                    Container(
                      key: titoloTappaKey,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 173, 213, 236),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsetsGeometry.all(15),
                          child: Text(
                            chapterTitle!,
                            style: GoogleFonts.robotoFlex(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double listViewHeight = constraints.maxHeight;
                          // altezza ultima card
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (itemKeys.isNotEmpty) {
                              final contextLast = itemKeys.last.currentContext;
                              if (contextLast != null) {
                                final newHeight = contextLast.size?.height ?? 0;
                                if (newHeight != lastCardHeight) {
                                  setState(() {
                                    lastCardHeight = newHeight;
                                  });
                                }
                              }
                            }
                          });

                          // calcolo dimensioni titolo per aggiornamento titolo durante lo scroll
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final RenderBox titleBox =
                                titoloTappaKey.currentContext!
                                        .findRenderObject()
                                    as RenderBox;
                            titleBottom =
                                titleBox.localToGlobal(Offset.zero).dy +
                                titleBox.size.height;
                          });

                          if (buttonCarouselController.isEmpty) {
                            buttonCarouselController = List.generate(
                              v.chapters.length,
                              (_) => CarouselSliderController(),
                            );
                          }

                          if (imageActive.isEmpty) {
                            for (int i = 0; i < v.chapters.length; i++) {
                              imageActive[i] = 0;
                            }
                          }

                          if (itemKeys.isEmpty) {
                            itemKeys = List.generate(
                              v.chapters.length,
                              (_) => GlobalKey(),
                            );
                          }

                          ListView buildList = ListView.builder(
                            controller: scrollController,
                            itemCount: v.chapters.length, // spazio finale
                            padding: EdgeInsets.only(
                              bottom: listViewHeight + lastCardHeight,
                            ),
                            itemBuilder: (ctx, idx) {
                              return TravelCard(
                                chapter: v.chapters[idx],
                                cardKey: itemKeys[idx],
                              );
                            },
                          );

                          return ListViewObserver(
                            controller: observerController,
                            child: buildList,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            } else {
              child = Row(
                children: [
                  Icon(Icons.warning_amber_rounded),
                  Text("Non è stato possibile scaricare le informazioni"),
                ],
              );
            }
          }

          return child;
        },
      ),
    ];

    Size sizes = MediaQuery.of(context).size;
    double width = sizes.width, height = sizes.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titoloViaggio,
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: Padding(
        padding: EdgeInsetsGeometry.all(20),
        child: width > 600
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: width * 0.45, child: myMap),
                  SizedBox(width: 50),
                  ...childrens,
                ],
              )
            : Column(
                children: [
                  SizedBox(height: height * 0.2, child: myMap),
                  SizedBox(height: 40),
                  ...childrens,
                ],
              ),
      ),
    );
  }
}
