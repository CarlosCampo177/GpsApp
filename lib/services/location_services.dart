import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  /// Configuración compartida del GPS según la plataforma
  LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  /// Verificar servicios y permisos del dispositivo
  Future<bool> checkAndRequestPermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación (GPS) está desactivado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado por el usuario.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permiso de ubicación denegado permanentemente. Habilítalo en Ajustes.',
      );
    }

    return true;
  }

  /// Obtener la ubicación inicial del GPS
  Future<Position> getCurrentLocation() async {
    await checkAndRequestPermissions();

    return await Geolocator.getCurrentPosition(
      locationSettings: _locationSettings,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () =>
          throw TimeoutException('Tiempo de espera agotado al buscar GPS.'),
    );
  }

  /// Convertir coordenadas a dirección de texto (geocodificación inversa).
  /// 1) Intenta con el geocoder nativo de Android/iOS.
  /// 2) Si falla, usa OpenStreetMap (Nominatim) como respaldo.
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (kIsWeb) {
      return 'Geocodificación no disponible en plataforma Web';
    }

    // 1) Geocoder nativo
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final List<String> partes = <String>[
          place.locality ?? place.subAdministrativeArea ?? '',
          place.administrativeArea ?? '',
          place.country ?? '',
        ].where((e) => e.isNotEmpty).toList();

        if (partes.isNotEmpty) return partes.join(', ');
      }
    } catch (e) {
      debugPrint('Geocoder nativo falló: $e');
    }

    // 2) Respaldo: OpenStreetMap (Nominatim)
    try {
      final Uri uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
        'zoom': '10',
        'accept-language': 'es',
      });

      final http.Response res = await http
          .get(
            uri,
            headers: {'User-Agent': 'gpsapp/1.0 (proyecto universitario)'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(res.body) as Map<String, dynamic>;
        final Map<String, dynamic>? a =
            data['address'] as Map<String, dynamic>?;

        if (a != null) {
          final List<String> partes = <String>[
            (a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '')
                as String,
            (a['state'] ?? '') as String,
            (a['country'] ?? '') as String,
          ].where((e) => e.isNotEmpty).toList();

          if (partes.isNotEmpty) return partes.join(', ');
        }
        return (data['display_name'] as String?) ?? 'Dirección no encontrada';
      }
      return 'Dirección no encontrada';
    } catch (e) {
      return 'Geocodificación no disponible ($e)';
    }
  }

  /// Iniciar escucha continua del GPS (Stream)
  void startLocationUpdates({
    required Function(Position) onData,
    required Function(dynamic) onError,
  }) {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(onData, onError: onError);
  }

  /// Detener la escucha del GPS
  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
