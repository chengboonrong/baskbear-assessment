class OutletDto {
  OutletDto({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  factory OutletDto.fromJson(Map<String, dynamic> j) => OutletDto(
        id: j['id'] as int,
        name: j['name'] as String,
        address: j['address'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
      );
}
