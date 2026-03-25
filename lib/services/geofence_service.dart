import 'package:latlong2/latlong.dart';
import 'package:safechain/services/notification_service.dart';

class GeofenceService {
  GeofenceService._();
  static final GeofenceService instance = GeofenceService._();

  // null = initial state (no notification fired yet)
  bool? _wasInside;

  /// Call this with every new device GPS coordinate.
  Future<void> check(LatLng point) async {
    final inside = _isInsidePolygon(point, _kGulodBoundary);

    // First ever reading — just record the state, don't notify
    if (_wasInside == null) {
      _wasInside = inside;
      return;
    }

    // State changed: was outside, now inside → ARRIVAL
    if (!_wasInside! && inside) {
      _wasInside = true;
      await NotificationService.addNotification(
        '📍 You\'ve Arrived at Brgy. Gulod!',
        'Welcome home! You are now within the boundaries of Barangay Gulod, Novaliches. Stay safe and have a great day! 🏘️',
        NotificationType.device,
      );
    }

    // State changed: was inside, now outside → DEPARTURE
    else if (_wasInside! && !inside) {
      _wasInside = false;
      await NotificationService.addNotification(
        '👋 You\'ve Left Brgy. Gulod',
        'You have exited the boundaries of Barangay Gulod, Novaliches. Take care wherever you\'re headed — stay safe out there! 🛡️',
        NotificationType.device,
      );
    }
  }

  /// Reset state (call when device disconnects so the next connection
  /// doesn't assume previous inside/outside state).
  void reset() => _wasInside = null;

  // ── Ray-casting point-in-polygon algorithm ──────────────────────
  // Returns true if [point] is inside the polygon defined by [polygon].
  bool _isInsidePolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    final int n = polygon.length;

    for (int i = 0; i < n; i++) {
      final LatLng a = polygon[i];
      final LatLng b = polygon[(i + 1) % n];

      // Check if ray from point going right crosses edge a→b
      if (((a.longitude <= point.longitude && point.longitude < b.longitude) ||
          (b.longitude <= point.longitude && point.longitude < a.longitude)) &&
          (point.latitude <
              (b.latitude - a.latitude) *
                  (point.longitude - a.longitude) /
                  (b.longitude - a.longitude) +
                  a.latitude)) {
        intersections++;
      }
    }

    // Odd number of crossings = inside
    return (intersections % 2) == 1;
  }
}

const List<LatLng> _kGulodBoundary = [
  LatLng(14.7185219, 121.0398006),
  LatLng(14.7186418, 121.0399609),
  LatLng(14.7187774, 121.0401694),
  LatLng(14.7189758, 121.0405221),
  LatLng(14.7190653, 121.0408212),
  LatLng(14.7190822, 121.0411203),
  LatLng(14.718745,  121.0415923),
  LatLng(14.7183403, 121.0420805),
  LatLng(14.7183454, 121.0423755),
  LatLng(14.718444,  121.0426384),
  LatLng(14.7187346, 121.0430944),
  LatLng(14.7187346, 121.0433358),
  LatLng(14.7185582, 121.0435289),
  LatLng(14.7180497, 121.0436161),
  LatLng(14.7172922, 121.0438213),
  LatLng(14.7164776, 121.0440399),
  LatLng(14.7161637, 121.0442457),
  LatLng(14.716012,  121.0443594),
  LatLng(14.7158706, 121.0443121),
  LatLng(14.7155696, 121.0435396),
  LatLng(14.7149989, 121.0428959),
  LatLng(14.7142725, 121.0430193),
  LatLng(14.7135461, 121.0432392),
  LatLng(14.7131752, 121.0430541),
  LatLng(14.712773,  121.0429334),
  LatLng(14.7123735, 121.043081),
  LatLng(14.7120518, 121.0433197),
  LatLng(14.712,     121.043545),
  LatLng(14.7120311, 121.0437488),
  LatLng(14.7125266, 121.0444033),
  LatLng(14.7129495, 121.0451275),
  LatLng(14.7129287, 121.0455942),
  LatLng(14.7127782, 121.0459429),
  LatLng(14.7123528, 121.0462755),
  LatLng(14.7119688, 121.0467154),
  LatLng(14.71145,   121.0471445),
  LatLng(14.7108792, 121.0466939),
  LatLng(14.7104123, 121.0460502),
  LatLng(14.709996,  121.0466173),
  LatLng(14.7092104, 121.0468214),
  LatLng(14.7090859, 121.0470574),
  LatLng(14.7053189, 121.0473471),
  LatLng(14.7046651, 121.0454374),
  LatLng(14.7053085, 121.0453945),
  LatLng(14.7052048, 121.0417896),
  LatLng(14.7068029, 121.0412531),
  LatLng(14.7078199, 121.0414033),
  LatLng(14.7083934, 121.0391347),
  LatLng(14.7093896, 121.0377614),
  LatLng(14.7096179, 121.0373752),
  LatLng(14.7094934, 121.0369889),
  LatLng(14.7093273, 121.0365383),
  LatLng(14.7096594, 121.0346286),
  LatLng(14.7098538, 121.0337481),
  LatLng(14.7103727, 121.0333619),
  LatLng(14.7103519, 121.0338983),
  LatLng(14.7105387, 121.0342309),
  LatLng(14.7109849, 121.0341987),
  LatLng(14.711566,  121.0335979),
  LatLng(14.7117528, 121.0336945),
  LatLng(14.712199,  121.0343275),
  LatLng(14.7127075, 121.0347566),
  LatLng(14.7130292, 121.0346708),
  LatLng(14.7131122, 121.0345098),
  LatLng(14.7134028, 121.0342202),
  LatLng(14.7138178, 121.0342202),
  LatLng(14.7144923, 121.0348424),
  LatLng(14.7147829, 121.0351107),
  LatLng(14.7147933, 121.0353467),
  LatLng(14.7145961, 121.0368165),
  LatLng(14.7152706, 121.0373744),
  LatLng(14.7158517, 121.0373744),
  LatLng(14.71663,   121.0387906),
  LatLng(14.7172215, 121.0387692),
  LatLng(14.7185219, 121.0398006),
];