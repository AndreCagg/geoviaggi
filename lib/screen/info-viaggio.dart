import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoviaggi/model/chapter-media.dart';
import 'package:geoviaggi/model/chapter.dart';
import 'package:geoviaggi/model/geo-point.dart';
import 'package:geoviaggi/model/viaggio.dart';
import 'package:geoviaggi/provider/map-provider.dart';
import 'package:geoviaggi/provider/title-provider.dart';
import 'package:geoviaggi/widget/info-viaggio/map-controller.dart';
import 'package:geoviaggi/widget/info-viaggio/map.dart';
import 'package:geoviaggi/widget/info-viaggio/travel-card.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late ScrollController scrollController;
  late ListObserverController observerController;
  late CustomMapController customMapController;
  late CustomMap myMap;

  String? chapterTitle;
  String titoloViaggio = "";
  late String lastTitle;

  List<String> titles = [];
  List<GeoPoint> points = [];
  List<GlobalKey> itemKeys = [];
  late List<CarouselSliderController> buttonCarouselController = [];
  late Map<int, int> imageActive = {};

  int? activeCard;
  int? pendingScrollCard;

  double lastOffset = 0;
  double lastCardHeight = 0;
  late double titleBottom;
  double _lastTitleHeight = 0;

  late double triggerLine;
  late double width, height;

  bool mostraLinee = true;
  bool isScrollUpdateScheduled = false;

  Timer? _scrollDebounce;

  GlobalKey titoloTappaKey = GlobalKey();
  GlobalKey mapKey = GlobalKey();

  double? viewportH;

  @override
  void initState() {
    super.initState();
    travel = getTravel();
    customMapController = CustomMapController();
    myMap = CustomMap(mykey: mapKey, customMapController: customMapController);
    scrollController = ScrollController();
    //scrollController.addListener(_onScroll);
    observerController = ListObserverController(controller: scrollController);
    observerController.cacheJumpIndexOffset = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sizes = MediaQuery.of(context).size;
    width = sizes.width;
    height = sizes.height;
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    scrollController.dispose();
    //scrollController.removeListener(_onScroll);
    super.dispose();
  }

  Future<Viaggio?> getTravel() async {
    try {
      final s = await rootBundle.loadString('tmp.json');
      final Map<String, dynamic> json = jsonDecode(s);

      List<Chapter> chapters = [];
      List<Marker> _markers = [];
      List<dynamic> jsonChapters = json["features"] ?? [];
      mostraLinee = json["mostra"]["mostraLinee"] as bool;

      for (var f in jsonChapters) {
        Map<String, dynamic> properties = f["properties"];
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

        if (properties["titoloTappa"] != null && chapterTitle == null) {
          Provider.of<TitleProvider>(context, listen: false).titolo =
              properties["titoloTappa"];
          chapterTitle = properties["titoloTappa"];
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
      return null;
    }
  }

  //UFFICIALE
  /*void _onScroll(ScrollNotification notification) {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    _scrollDebounce = Timer(Duration(milliseconds: 5), () {
      /*if (!mounted) return;
      //_updateVisibleTitle();
      _updateVisibleTitle(notification);*/
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _updateVisibleTitle(notification);
      });
    });
  }*/
  void _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      _updateVisibleTitle(notification);
    }
  }

  /*void _updateVisibleTitle() {
    if (!mounted) return;

    final double offset = scrollController.offset;
    final bool isScrollingUp = offset < lastOffset;
    lastOffset = offset;

    final double triggerPoint = titleBottom;

    for (int idx = 0; idx < itemKeys.length; idx++) {
      final cardContext = itemKeys[idx].currentContext;
      if (cardContext == null) continue;

      final RenderBox? cardBox = cardContext.findRenderObject() as RenderBox?;
      if (cardBox == null || !cardBox.hasSize) continue;

      final double cardTop = cardBox.localToGlobal(Offset.zero).dy;
      final double cardHeight = cardBox.size.height;
      final double cardBottom = cardTop + cardHeight;

      // Scroll giù: quando leggi 75% della card CORRENTE, mostra la PROSSIMA
      // Scroll su: quando vedi 25% della card CORRENTE, mostra la CORRENTE
      if (isScrollingUp) {
        // Scroll su: punto al 25% dall'alto
        final double card25PercentPoint = cardTop + (cardHeight * 0.25);

        if (card25PercentPoint <= triggerPoint && cardBottom > triggerPoint) {
          if (activeCard != idx) {
            activeCard = idx;
            _updateChapterTitle(idx);
          }
          return;
        }
      } else {
        // Scroll giù: punto al 75% dall'alto
        final double card75PercentPoint = cardTop + (cardHeight * 0.75);

        if (card75PercentPoint <= triggerPoint && cardBottom > triggerPoint) {
          // Mostra la card SUCCESSIVA (se esiste)
          final int nextIdx = (idx + 1).clamp(0, itemKeys.length - 1);
          if (activeCard != nextIdx) {
            activeCard = nextIdx;
            _updateChapterTitle(nextIdx);
          }
          return;
        }
      }
    }
  }*/

  /*UFFICIALE
  void _updateVisibleTitle() {
    if (!mounted) return;

    final double offset = scrollController.offset;
    final bool isScrollingUp = offset < lastOffset;
    lastOffset = offset;

    final double triggerPoint = titleBottom;

    // OTTIMIZZAZIONE: cerca prima nelle card vicine
    final int startIdx = activeCard ?? 0;
    final int searchRange = 3;

    // Prima cerca nelle vicinanze
    for (int i = -searchRange; i <= searchRange; i++) {
      final int idx = (startIdx + i).clamp(0, itemKeys.length - 1);

      final cardContext = itemKeys[idx].currentContext;
      if (cardContext == null) continue;

      final RenderBox? cardBox = cardContext.findRenderObject() as RenderBox?;
      if (cardBox == null || !cardBox.hasSize) continue;

      final double cardTop = cardBox.localToGlobal(Offset.zero).dy;
      final double cardHeight = cardBox.size.height;
      final double cardBottom = cardTop + cardHeight;

      if (isScrollingUp) {
        final double card25PercentPoint = cardTop + (cardHeight * 0.25);

        if (card25PercentPoint <= triggerPoint && cardBottom > triggerPoint) {
          if (activeCard != idx) {
            activeCard = idx;
            _updateChapterTitle(idx);
          }
          return;
        }
      } else {
        final double card75PercentPoint = cardTop + (cardHeight * 0.75);

        if (card75PercentPoint <= triggerPoint && cardBottom > triggerPoint) {
          final int nextIdx = (idx + 1).clamp(0, itemKeys.length - 1);
          if (activeCard != nextIdx) {
            activeCard = nextIdx;
            _updateChapterTitle(nextIdx);
          }
          return;
        }
      }
    }

    // Fallback: cerca in tutte le card solo se non trovata nelle vicinanze
    for (int idx = 0; idx < itemKeys.length; idx++) {
      final cardContext = itemKeys[idx].currentContext;
      if (cardContext == null) continue;

      final RenderBox? cardBox = cardContext.findRenderObject() as RenderBox?;
      if (cardBox == null || !cardBox.hasSize) continue;

      final double cardTop = cardBox.localToGlobal(Offset.zero).dy;
      final double cardHeight = cardBox.size.height;
      final double cardBottom = cardTop + cardHeight;

      if (isScrollingUp) {
        final double card25PercentPoint = cardTop + (cardHeight * 0.25);

        if (card25PercentPoint <= triggerPoint && cardBottom > triggerPoint) {
          if (activeCard != idx) {
            activeCard = idx;
            _updateChapterTitle(idx);
          }
          return;
        }
      } else {
        final double card75PercentPoint = cardTop + (cardHeight * 0.75);

        if (card75PercentPoint <= triggerPoint && cardBottom > triggerPoint) {
          final int nextIdx = (idx + 1).clamp(0, itemKeys.length - 1);
          if (activeCard != nextIdx) {
            activeCard = nextIdx;
            _updateChapterTitle(nextIdx);
          }
          return;
        }
      }
    }
  }*/

  //si puo bloccare per scrolling veloce per via di troppi tentativi di animazioni
  void _updateVisibleTitle(ScrollNotification notification) {
    if (!mounted) return;
    viewportH ??= notification.metrics.viewportDimension;

    final double band = viewportH! * 0.1;

    final double offset = notification.metrics.pixels;
    if ((lastOffset - offset).abs() <= 10) return;
    final bool isScrollingUp = offset < lastOffset;
    lastOffset = offset;

    final double triggerPoint = titleBottom;
    final int startIdx = activeCard ?? 0;
    const int searchRange = 2;

    int? candidate;

    bool checkCard(int idx) {
      final ctx = itemKeys[idx].currentContext;
      if (ctx == null) return false;

      final RenderBox? box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return false;

      final double top = box.localToGlobal(Offset.zero).dy;
      final double h = box.size.height;
      final double bottom = top + h;

      /*final double bandTop = titleBottom - band;
      final double bandBottom = titleBottom + band;*/

      /*if (isScrollingUp) {
        // scroll verso l’alto → candidate quando la card corrente entra nella banda dal basso
        if (bottom > band && top < band) {
          candidate = idx;
          return true;
        }
      } else {
        // scroll verso il basso → candidate quando la card corrente esce dalla banda superiore
        if (top <= band && bottom >= band) {
          candidate = (idx).clamp(0, itemKeys.length - 1);
          return true;
        }
      }*/

      if (isScrollingUp) {
        if (top + max(h * 0.85, band) > triggerPoint && bottom > triggerPoint) {
          candidate = idx;
          return true;
        }
      } else {
        if (top + max(h * 0.75, band) <= triggerPoint &&
            bottom > triggerPoint) {
          candidate = (idx + 1).clamp(
            0,
            itemKeys.length - 1,
          ); //perche questo calcolo
          return true;
        }
      }

      return false;
    }

    // Cerca vicino all'ultima card attiva
    for (int i = -searchRange; i <= searchRange; i++) {
      final idx = (startIdx + i).clamp(0, itemKeys.length - 1);
      if (checkCard(idx)) break;
    }

    // Fallback limitato: conta quante card scorri
    if (candidate == null) {
      for (int idx = startIdx + searchRange; idx < itemKeys.length; idx++) {
        if (checkCard(idx)) break;
      }
    }

    if (candidate != null && candidate != activeCard) {
      activeCard = candidate;
      //print("vedo $activeCard");
      _dispatchCardUpdate(candidate!);
    }
  }

  void _dispatchCardUpdate(int idx) {
    activeCard = idx;

    // 🔹 microtask: aggiorna titolo (cheap)
    /*scheduleMicrotask(() {
      if (!mounted) return;
      _updateChapterTitle(idx);
      _updateMap(idx);
    });*/
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateChapterTitle(idx);
      _updateMap(idx);
    });

    // 🔹 frame successivo: mappa + layout
    /*
      if (!mounted) return;
      _updateMap(idx);
      //_recalculateTitleBottom();
    });*/
    /*SchedulerBinding.instance.addPostFrameCallback((_) {
    });*/
  }

  /*void _updateMap(int idx) {
    final GeoPoint p = points[idx];
    customMapController.animatedMove!(p.coords, p.zoom);
  }*/

  Timer? _mapDebounce;
  Duration mapDebounceDuration = Duration(milliseconds: 200);

  void _updateMap(int idx) {
    final GeoPoint p = points[idx];

    // Annulla eventuali update già schedulati
    _mapDebounce?.cancel();

    // Schedule update della mappa dopo un piccolo ritardo
    _mapDebounce = Timer(mapDebounceDuration, () {
      if (!mounted) return;
      customMapController.animatedMove!(p.coords, p.zoom);
    });
  }

  void _updateChapterTitle(int idx) {
    if (idx < 0 || idx >= titles.length) return;

    Provider.of<TitleProvider>(context, listen: false).titolo = titles[idx];

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final titleContext = titoloTappaKey.currentContext;
      if (titleContext != null) {
        final RenderBox? titleBox =
            titleContext.findRenderObject() as RenderBox?;
        if (titleBox != null && titleBox.hasSize) {
          final double newHeight = titleBox.size.height;

          // Calcola titleBottom SOLO se l'altezza è cambiata
          //if ((newHeight - _lastTitleHeight).abs() > 1) {
          //_lastTitleHeight = newHeight;
          titleBottom = titleBox.localToGlobal(Offset.zero).dy + newHeight;
          //}
        }
      }
    });
  }

  void scrollToCard(int idx) {
    observerController.jumpTo(index: idx);
  }

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
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 173, 213, 236),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(15),
                        child: Column(
                          //togli
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Consumer<TitleProvider>(
                              builder: (context, value, child) {
                                return Text(
                                  value.titolo,
                                  style: GoogleFonts.robotoFlex(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double listViewHeight = constraints.maxHeight;

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

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final RenderBox titleBox =
                                titoloTappaKey.currentContext!
                                        .findRenderObject()
                                    as RenderBox;
                            titleBottom =
                                titleBox.localToGlobal(Offset.zero).dy +
                                titleBox.size.height;
                            //triggerLine = titleBottom + (titleBottom * 0.25);
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

                          NotificationListener buildList =
                              NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification
                                      is ScrollUpdateNotification) {
                                    _onScroll(notification);
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: scrollController,
                                  itemCount: v.chapters.length + 1,
                                  physics: BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.only(
                                    bottom: listViewHeight + lastCardHeight,
                                  ),
                                  itemBuilder: (ctx, idx) {
                                    if (idx == v.chapters.length) {
                                      return FilledButton(
                                        onPressed: () {
                                          scrollToCard(0);
                                          _dispatchCardUpdate(0);
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.keyboard_arrow_up),
                                            Text("Torna su"),
                                          ],
                                        ),
                                      );
                                    } else {
                                      return TravelCard(
                                        chapter: v.chapters[idx],
                                        cardKey: itemKeys[idx],
                                      );
                                    }
                                  },
                                ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titoloViaggio,
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: Padding(
        padding: EdgeInsets.all(20),
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
