class GeoDepartment {
  GeoDepartment({required this.id, required this.name, this.code = ''});

  final String id;
  final String name;
  final String code;

  factory GeoDepartment.fromJson(Map<String, dynamic> json) => GeoDepartment(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
      );
}

class GeoCity {
  GeoCity({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.departmentName,
    this.latitude,
    this.longitude,
    this.isCapital = false,
  });

  final String id;
  final String name;
  final String departmentId;
  final String departmentName;
  final double? latitude;
  final double? longitude;
  final bool isCapital;

  factory GeoCity.fromJson(Map<String, dynamic> json) => GeoCity(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        departmentId: json['department_id']?.toString() ?? '',
        departmentName: json['department_name']?.toString() ?? '',
        latitude: double.tryParse(json['latitude']?.toString() ?? ''),
        longitude: double.tryParse(json['longitude']?.toString() ?? ''),
        isCapital: json['is_capital'] == true,
      );
}
