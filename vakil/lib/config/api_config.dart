import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the Vakil server is. Nobody types an address: [findServer] looks for
/// the laptop over USB (`adb reverse`, done by start-vakil-local.ps1), at the
/// Wi-Fi addresses the server last reported, and finally by searching the
/// Wi-Fi or hotspot network the phone is on. What it finds is remembered.
class ApiConfig {
  ApiConfig._();

  /// Built-in address (USB). Override at build time with
  /// `--dart-define=API_BASE_URL=http://<ip>:4000`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
  static const String _socketOverride = String.fromEnvironment('SOCKET_URL');
  static const _prefsKey = 'server_base_url';
  static const _knownKey = 'server_known_urls';
  static const int _port = 4000;
  static const Duration requestTimeout = Duration(seconds: 15);
  static const String unreachableMessage =
      "Can't reach the Vakil server. Make sure it is running on the laptop and this phone is connected to it by USB or on the same Wi-Fi or hotspot.";

  static String _baseUrl = defaultBaseUrl;
  static List<String> _known = const [];
  static Future<bool>? _search;
  static DateTime? _lastMiss;

  /// Changes whenever the server is found at a new address.
  static final ValueNotifier<String> changes = ValueNotifier(defaultBaseUrl);

  static String get baseUrl => _baseUrl;
  static String get socketUrl => _socketOverride.isEmpty ? _baseUrl : _socketOverride;

  /// A server file such as a profile photo: the server stores "/uploads/…",
  /// which is reached at whatever address the server was found on.
  static String? mediaUrl(String? path) => path == null || path.isEmpty ? null : path.startsWith('/') ? '$_baseUrl$path' : path;

  /// Loads the address found last time. Call once at start-up, and in
  /// background isolates (push handlers) before making requests.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) _baseUrl = saved;
      _known = prefs.getStringList(_knownKey) ?? const [];
      changes.value = _baseUrl;
    } catch (_) {}
  }

  /// Makes [baseUrl] point at a running Vakil server, searching for it when
  /// needed; false if none was found. Calls made while a search runs share it,
  /// and a failed search is not repeated for 20 seconds unless [force] is set.
  static Future<bool> findServer({bool force = false}) {
    final running = _search;
    if (running != null) return running;
    final miss = _lastMiss;
    if (!force && miss != null && DateTime.now().difference(miss) < const Duration(seconds: 20)) return Future.value(false);
    return _search = _find().whenComplete(() => _search = null);
  }

  static Future<bool> _find() async {
    // Addresses already known: the current one, USB, and those the server reported.
    var found = await _firstServer({_baseUrl, defaultBaseUrl, ..._known}.toList(), const Duration(seconds: 2));
    // Otherwise every device on the phone's own networks with port 4000 open.
    if (found == null) {
      for (final prefix in await _networkPrefixes()) {
        for (var first = 1; first < 255 && found == null; first += 64) {
          final batch = [for (var i = first; i < first + 64 && i < 255; i++) '$prefix.$i'];
          final open = await Future.wait(batch.map((host) async => await _portOpen(host) ? 'http://$host:$_port' : null));
          found = await _firstServer(open.whereType<String>().toList(), const Duration(seconds: 3));
        }
        if (found != null) break;
      }
    }
    if (found == null) {
      _lastMiss = DateTime.now();
      debugPrint('Vakil server not found');
      return false;
    }
    _lastMiss = null;
    _baseUrl = found.url;
    // Keep the laptop's Wi-Fi addresses for when the USB cable is unplugged.
    if (found.addresses.isNotEmpty) _known = found.addresses;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _baseUrl);
      await prefs.setStringList(_knownKey, _known);
    } catch (_) {}
    changes.value = _baseUrl;
    return true;
  }

  /// The first of [urls] that answers as a Vakil server, with the addresses it reports.
  static Future<({String url, List<String> addresses})?> _firstServer(List<String> urls, Duration timeout) {
    if (urls.isEmpty) return Future.value(null);
    final result = Completer<({String url, List<String> addresses})?>();
    var pending = urls.length;
    for (final url in urls) {
      _health(url, timeout).then((addresses) {
        if (addresses != null && !result.isCompleted) result.complete((url: url, addresses: addresses));
        if (--pending == 0 && !result.isCompleted) result.complete(null);
      });
    }
    return result.future;
  }

  /// The server's own Wi-Fi addresses if [url] is a Vakil server, else null.
  static Future<List<String>?> _health(String url, Duration timeout) async {
    try {
      final response = await http.get(Uri.parse('$url/api/health')).timeout(timeout);
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 || body is! Map || body['status'] != 'ok') return null;
      final addresses = body['addresses'];
      return addresses is List ? [for (final ip in addresses) 'http://$ip:$_port'] : const [];
    } catch (_) {
      return null;
    }
  }

  /// "a.b.c" for each private IPv4 network the phone is on (Wi-Fi, hotspot),
  /// skipping mobile data.
  static Future<List<String>> _networkPrefixes() async {
    try {
      final prefixes = <String>{};
      for (final interface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        if (RegExp(r'rmnet|ccmni|v4-|dummy|tun').hasMatch(interface.name)) continue;
        for (final address in interface.addresses) {
          final parts = address.address.split('.').map(int.parse).toList();
          final private = parts[0] == 10 || (parts[0] == 172 && parts[1] >= 16 && parts[1] < 32) || (parts[0] == 192 && parts[1] == 168);
          if (private) prefixes.add(parts.take(3).join('.'));
        }
      }
      return prefixes.toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> _portOpen(String host) async {
    try {
      final socket = await Socket.connect(host, _port, timeout: const Duration(milliseconds: 700));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
