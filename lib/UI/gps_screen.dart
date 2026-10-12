import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_services.dart';

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  State createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  String _address = 'Obteniendo dirección...';
  bool _isTracking = false;
  String _statusMessage = 'Presiona "Iniciar rastreo" para comenzar';

  Future _updateLocationData(Position position) async {
    final String addressResult = await _locationService
        .getAddressFromCoordinates(position.latitude, position.longitude);

    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _address = addressResult;
    });

    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _mapController.camera.zoom > 10 ? _mapController.camera.zoom : 16.0,
    );
  }

  Future _toggleTracking() async {
    if (_isTracking) {
      _locationService.stopLocationUpdates();
      setState(() {
        _isTracking = false;
        _statusMessage = 'Rastreo detenido.';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Obteniendo señal GPS...';
    });

    try {
      final Position initialPosition = await _locationService
          .getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _isTracking = true;
        _statusMessage = 'Rastreando en tiempo real';
      });

      await _updateLocationData(initialPosition);

      _locationService.startLocationUpdates(
        onData: (Position position) {
          _updateLocationData(position);
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Error en tiempo real: $error';
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTracking = false;
        _statusMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _locationService.stopLocationUpdates();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rastreador GPS'), centerTitle: true),
      body: Column(
        children: [
          // MAPA INTERACTIVO
          Expanded(
            flex: 5,
            child: _currentPosition == null
                ? Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.gpsapp',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // PANEL DE INFORMACIÓN Y MÉTRICAS
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_currentPosition != null) ...[
                    // DIRECCIÓN TRADUCIDA (GEOCODING)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_city,
                            color: Colors.teal,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ubicación aproximada:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _address,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MÉTRICAS NUMÉRICAS GPS
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MetricItem(
                                  label: 'Latitud',
                                  value: _currentPosition!.latitude
                                      .toStringAsFixed(6),
                                ),
                                _MetricItem(
                                  label: 'Longitud',
                                  value: _currentPosition!.longitude
                                      .toStringAsFixed(6),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MetricItem(
                                  label: 'Precisión',
                                  value:
                                      '${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                                ),
                                _MetricItem(
                                  label: 'Velocidad',
                                  value:
                                      '${_currentPosition!.speed.toStringAsFixed(1)} m/s',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // BOTÓN DE ACCIÓN
                  ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isTracking ? 'Detener rastreo' : 'Iniciar rastreo',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _isTracking
                          ? Colors.redAccent
                          : Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
