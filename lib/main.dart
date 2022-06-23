import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:psyduck/bluetooth_connection.dart';
import 'package:psyduck/constants.dart';
import 'package:psyduck/device_screen.dart';

void main() {
  runApp(
    BluetoothConnection(
      builder: (device) => DeviceScreen(device: device),
      withServices: [Guid(psyduckServiceUUID)],
    ),
  );
}
