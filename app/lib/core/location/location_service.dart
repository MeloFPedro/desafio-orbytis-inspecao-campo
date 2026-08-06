import 'package:geolocator/geolocator.dart';

import '../error/failures.dart';

class LocationService {
  const LocationService();

  /// Posição atual do dispositivo.
  ///
  /// Lança [LocationFailure] em qualquer um dos quatro modos de falha:
  /// serviço desligado, permissão negada, permissão negada permanentemente,
  /// ou sem sinal dentro do tempo limite.
  Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'A localização do dispositivo está desligada.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Permissão de localização negada permanentemente.',
        canOpenSettings: true,
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Permissão de localização negada.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        // desiredAccuracy e timeLimit soltos foram depreciados em favor de
        // LocationSettings.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Sem limite, o técnico dentro de uma subestação fica preso num
          // spinner indefinido em vez de receber um erro tratável.
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      throw const LocationFailure(
        'Não foi possível obter o sinal de GPS. Tente em área aberta.',
      );
    }
  }

  /// Distância em metros entre dois pontos.
  ///
  /// O geolocator já traz o cálculo geodésico — não precisamos de Haversine
  /// escrito à mão.
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) =>
      Geolocator.distanceBetween(startLat, startLng, endLat, endLng);

  Future<void> openSettings() => Geolocator.openAppSettings();
}
