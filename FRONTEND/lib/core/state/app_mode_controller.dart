import 'package:flutter/foundation.dart';

enum AppMode { buyer, seller }

class AppModeController extends ChangeNotifier {
  AppMode _mode = AppMode.buyer;
  int _catalogEpoch = 0;

  AppMode get mode => _mode;
  bool get isSeller => _mode == AppMode.seller;
  bool get isBuyer => _mode == AppMode.buyer;

  /// Incrementa cuando cambia inventario / sueños y las pantallas deben recargar.
  int get catalogEpoch => _catalogEpoch;

  void bumpCatalog() {
    _catalogEpoch++;
    notifyListeners();
  }

  void setMode(AppMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    setMode(isBuyer ? AppMode.seller : AppMode.buyer);
  }
}
