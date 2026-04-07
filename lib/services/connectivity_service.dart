import 'dart:async';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get stream => _controller.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;

  void initialize() {
    _checkConnectivity();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _checkConnectivity(),
    );
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  Future<void> _checkConnectivity() async {
    bool online;
    try {
      final response = await http
          .head(Uri.parse('https://safechain.site'))
          .timeout(const Duration(seconds: 4));
      online = response.statusCode < 500;
    } catch (_) {
      online = false;
    }
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
    }
  }
}