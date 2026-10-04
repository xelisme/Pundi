import 'package:flutter/foundation.dart';

/// Index of the visible tab in the bottom navigation shell.
///
/// Extracted so a screen can ask the shell to switch tabs — Ringkasan sends the
/// user to Riwayat when they tap a category to see the records behind a total.
/// Keeping the index in a widget would have meant passing a callback through
/// every screen in the IndexedStack to reach the shell's setState.
class MainTabController extends ChangeNotifier {
  static const int beranda = 0;
  static const int riwayat = 1;
  static const int ringkasan = 2;
  static const int pengaturan = 3;

  int _index = beranda;

  int get index => _index;

  void select(int index) {
    if (index == _index || index < 0 || index > pengaturan) return;
    _index = index;
    notifyListeners();
  }
}
