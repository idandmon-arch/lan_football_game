import 'dart:io';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';

class LANNetworkManager {
  RawDatagramSocket? _socket;
  final int port = 7474;
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String?> getWifiIP() async {
    return await _networkInfo.getWifiIP();
  }

  Future<void> listenForPeerPackets(Function(Map<String, dynamic> data) onPackageReceived) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket?.broadcastEnabled = true;
      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _socket?.receive();
          if (dg != null) {
            String decoded = utf8.decode(dg.data);
            try {
              Map<String, dynamic> jsonMap = jsonDecode(decoded);
              onPackageReceived(jsonMap);
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      print("Socket binding failure: $e");
    }
  }

  void transmitMatchDataPacket(String ip, Map<String, dynamic> payload) {
    if (_socket != null && ip.isNotEmpty) {
      String frameString = jsonEncode(payload);
      List<int> bytes = utf8.encode(frameString);
      try {
        _socket?.send(bytes, InternetAddress(ip), port);
      } catch (_) {}
    }
  }

  void stop() {
    _socket?.close();
  }
}
