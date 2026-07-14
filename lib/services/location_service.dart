import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DetectedLocation {
  const DetectedLocation({required this.city, required this.timezone});
  final String city;
  final String timezone;
}

class LocationService {
  static Future<DetectedLocation> detectCity() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on Location Services and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was not granted.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Enable location for StyleStack in Settings.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (places.isEmpty) throw Exception('Could not determine your city.');
    final place = places.first;
    final city =
        [place.locality, place.subAdministrativeArea, place.administrativeArea]
            .whereType<String>()
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (city.isEmpty) throw Exception('Could not determine your city.');
    return DetectedLocation(city: city, timezone: DateTime.now().timeZoneName);
  }
}
