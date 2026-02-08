import 'package:flutter/material.dart';

class TitleProvider extends ChangeNotifier {
  String _titolo = "";

  String get titolo {
    return _titolo;
  }

  set titolo(String t) {
    _titolo = t;
    notifyListeners();
  }
}
