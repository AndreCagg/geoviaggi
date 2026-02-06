import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:geoviaggi/model/chapter.dart';

class TravelCard extends StatefulWidget {
  const TravelCard({super.key, required this.chapter, required this.cardKey});
  final Chapter chapter;
  final GlobalKey cardKey;

  @override
  State<TravelCard> createState() => _TravelCardState();
}

class _TravelCardState extends State<TravelCard> {
  int imageActive = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: widget.cardKey,
      color: Color.fromARGB(255, 247, 243, 232),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CarouselSlider.builder(
              options: CarouselOptions(
                autoPlay: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    imageActive = index;
                  });
                },
                enlargeCenterPage: widget.chapter.images.length > 1
                    ? true
                    : false,
                enableInfiniteScroll: widget.chapter.images.length > 1
                    ? true
                    : false,
                viewportFraction: 0.8,
                aspectRatio: 16 / 9,
                initialPage: 0,
              ),
              itemCount: widget.chapter.images.length,
              itemBuilder: (context, index, realIndex) {
                return Image.network(
                  widget.chapter.images[index].url,
                  //key: UniqueKey(),
                  //webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        return child;
                      },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, size: 50),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(child: CircularProgressIndicator());
                  },
                  width: double.infinity,
                  fit: BoxFit.contain,
                );
              },
            ),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  widget.chapter.images.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == imageActive ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 40),
            Text(widget.chapter.chapter),
            SizedBox(height: 30),
            Html(data: widget.chapter.description),
          ],
        ),
      ),
    );
  }
}
