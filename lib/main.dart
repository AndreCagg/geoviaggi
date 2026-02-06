import 'package:flutter/material.dart';
import 'package:geoviaggi/provider/map-provider.dart';
import 'package:geoviaggi/screen/info-viaggio.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (context) => MapProvider(), child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: InfoViaggio());
  }
}
