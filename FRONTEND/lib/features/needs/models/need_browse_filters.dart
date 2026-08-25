class NeedBrowseFilters {
  NeedBrowseFilters({
    this.assetType = 'VEHICLE',
    this.vehicleCategory,
    this.brand,
    this.model,
    this.year,
    this.city,
    this.propertyType,
    this.listingIntent,
    this.bedroomsMin,
    this.bathroomsMin,
    this.areaMinSqm,
    this.socioeconomicStratum,
    this.parkingSpotsMin,
    this.maxBudget,
  });

  String assetType;
  String? vehicleCategory;
  String? brand;
  String? model;
  int? year;
  String? city;
  String? propertyType;
  String? listingIntent;
  int? bedroomsMin;
  int? bathroomsMin;
  int? areaMinSqm;
  int? socioeconomicStratum;
  int? parkingSpotsMin;
  double? maxBudget;

  bool get isVehicle => assetType == 'VEHICLE';

  int get activeCount {
    var n = 0;
    if (city != null && city!.isNotEmpty) n++;
    if (isVehicle) {
      if (vehicleCategory != null) n++;
      if (brand != null && brand!.isNotEmpty) n++;
      if (model != null && model!.isNotEmpty) n++;
      if (year != null) n++;
    } else {
      if (propertyType != null) n++;
      if (listingIntent != null) n++;
      if (bedroomsMin != null) n++;
      if (bathroomsMin != null) n++;
      if (areaMinSqm != null) n++;
      if (socioeconomicStratum != null) n++;
      if (parkingSpotsMin != null) n++;
    }
    if (maxBudget != null && maxBudget! > 0) n++;
    return n;
  }

  NeedBrowseFilters copy() => NeedBrowseFilters(
        assetType: assetType,
        vehicleCategory: vehicleCategory,
        brand: brand,
        model: model,
        year: year,
        city: city,
        propertyType: propertyType,
        listingIntent: listingIntent,
        bedroomsMin: bedroomsMin,
        bathroomsMin: bathroomsMin,
        areaMinSqm: areaMinSqm,
        socioeconomicStratum: socioeconomicStratum,
        parkingSpotsMin: parkingSpotsMin,
        maxBudget: maxBudget,
      );

  void clearVehicleIdentity() {
    brand = null;
    model = null;
    year = null;
  }

  void clearPropertyFilters() {
    propertyType = null;
    listingIntent = null;
    bedroomsMin = null;
    bathroomsMin = null;
    areaMinSqm = null;
    socioeconomicStratum = null;
    parkingSpotsMin = null;
  }

  void clearAll() {
    vehicleCategory = null;
    brand = null;
    model = null;
    year = null;
    city = null;
    clearPropertyFilters();
    maxBudget = null;
  }
}
