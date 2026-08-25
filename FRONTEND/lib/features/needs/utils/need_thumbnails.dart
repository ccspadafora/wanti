/// Miniaturas generadas con IA para categorías de sueños / publicaciones.
class NeedThumbnails {
  NeedThumbnails._();

  static const car = 'assets/images/catalog/catalog_car.png';
  static const suv = 'assets/images/catalog/catalog_suv.png';
  static const moto = 'assets/images/catalog/catalog_moto.png';
  static const apto = 'assets/images/catalog/catalog_apto.png';
  static const casa = 'assets/images/catalog/catalog_casa.png';
  static const local = 'assets/images/catalog/catalog_local.png';

  static const _suvBrands = {
    'Toyota',
    'Jeep',
    'Ford',
    'Nissan',
    'Hyundai',
    'Kia',
    'Mazda',
    'Volkswagen',
    'Chevrolet',
  };

  static String assetFor({
    required String assetType,
    Map<String, dynamic>? detail,
  }) {
    if (assetType == 'PROPERTY') {
      final type = (detail?['property_type'] ?? '').toString().toUpperCase();
      if (type == 'CASA' || type == 'LOTE_FINCA') return casa;
      if (type == 'LOCAL' || type == 'BODEGA' || type == 'CONSULTORIO') return local;
      return apto;
    }

    final category = (detail?['vehicle_category'] ?? 'CAR').toString().toUpperCase();
    if (category == 'MOTO') return moto;
    if (category == 'SUV' || category == 'TRUCK') return suv;
    if (category == 'NAUTICAL' || category == 'HEAVY_MACHINERY') return car;
    final brand = (detail?['brand'] ?? '').toString();
    final model = (detail?['model'] ?? '').toString().toLowerCase();
    if (category == 'COLLECTION') return car;
    if (model.contains('hilux') ||
        model.contains('prado') ||
        model.contains('rav') ||
        model.contains('tucson') ||
        model.contains('sportage') ||
        model.contains('tracker') ||
        model.contains('duster') ||
        _suvBrands.contains(brand)) {
      return suv;
    }
    return car;
  }
}
