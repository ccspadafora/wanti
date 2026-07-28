import 'package:flutter/foundation.dart';

enum AppMode { buyer, seller }

class AppModeController extends ChangeNotifier {
  AppMode _mode = AppMode.buyer;

  AppMode get mode => _mode;
  bool get isSeller => _mode == AppMode.seller;
  bool get isBuyer => _mode == AppMode.buyer;

  void setMode(AppMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    setMode(isBuyer ? AppMode.seller : AppMode.buyer);
  }
}
