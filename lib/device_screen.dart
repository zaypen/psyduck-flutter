import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'constants.dart';

typedef WriteCallback = void Function(int);
typedef Builder = Widget Function(BuildContext, int?, WriteCallback);
typedef Reader = int? Function(List<int>?);
typedef Writer = List<int> Function(int);

int? readUint8(List<int>? value) {
  return value?.firstOrNull;
}

List<int> writeUint8(int value) {
  return [value];
}

int? readUint32(List<int>? value) {
  return value != null && value.length >= 4
      ? Uint8List.fromList(value)
          .buffer
          .asByteData()
          .getUint32(0, Endian.little)
      : null;
}

List<int> writeUint32(int value) {
  return Uint8List(4)
    ..buffer.asByteData().setUint32(0, value.toInt(), Endian.little);
}

class _CharacteristicTile extends StatelessWidget {
  final String title;
  final BluetoothCharacteristic characteristic;
  final Reader reader;
  final Writer writer;
  final Builder builder;

  const _CharacteristicTile({
    Key? key,
    required this.title,
    required this.characteristic,
    required this.builder,
    required this.reader,
    required this.writer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
      key: key,
      stream: characteristic.value,
      initialData: characteristic.lastValue,
      builder: (c, snapshot) {
        final value = reader(snapshot.data);
        return ListTile(
          title: Text(title),
          subtitle: Text(value?.toString() ?? "?"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              builder(context, value, (v) {
                characteristic.write(writer(v));
                characteristic.read();
              }),
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () => characteristic.read(),
              )
            ],
          ),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final BluetoothService service;

  const _ServiceTile({Key? key, required this.service}) : super(key: key);

  Widget? _toWidget(BluetoothCharacteristic? characteristic) {
    if (characteristic == null) {
      return null;
    }
    switch (characteristic.uuid.toString().toUpperCase()) {
      case psyduckModeUUID:
        return _CharacteristicTile(
          title: "Auto",
          characteristic: characteristic,
          reader: readUint8,
          writer: writeUint8,
          builder: (context, value, write) => CupertinoSwitch(
            value: value == 1 ? true : false,
            onChanged: (bool value) {
              write(value ? 1 : 0);
            },
          ),
        );
      case psyduckArmEnabledUUID:
        return _CharacteristicTile(
          title: "Arm Enabled",
          characteristic: characteristic,
          reader: readUint8,
          writer: writeUint8,
          builder: (context, value, write) => CupertinoSwitch(
            value: value == 1 ? true : false,
            onChanged: (bool value) {
              write(value ? 1 : 0);
            },
          ),
        );
      case psyduckArmWaitUUID:
        return _CharacteristicTile(
          title: "Arm Wait",
          characteristic: characteristic,
          reader: readUint32,
          writer: writeUint32,
          builder: (context, value, write) {
            final remote = value?.toDouble() ?? 2000.0;
            return CupertinoSlider(
              value: remote,
              divisions: 100,
              min: 1000,
              max: 10000,
              onChanged: (_) {},
              onChangeEnd: (double value) {
                write(value.round());
              },
            );
          },
        );
      case psyduckFootEnabledUUID:
        return _CharacteristicTile(
          title: "Spinning Enabled",
          characteristic: characteristic,
          reader: readUint8,
          writer: writeUint8,
          builder: (context, value, write) => CupertinoSwitch(
            value: value == 1 ? true : false,
            onChanged: (bool value) {
              write(value ? 1 : 0);
            },
          ),
        );
      case psyduckFootSpeedUUID:
        return _CharacteristicTile(
          title: "Spinning Power",
          characteristic: characteristic,
          reader: readUint8,
          writer: writeUint8,
          builder: (context, value, write) => CupertinoSlider(
            value: value?.toDouble() ?? 127,
            divisions: 8,
            min: 95,
            max: 255,
            onChanged: (_) {},
            onChangeEnd: (double value) {
              write(value.toInt());
            },
          ),
        );
      default:
        return const ListTile(title: Text("Unsupported Characteristic"));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (service.uuid.toString().toUpperCase() == psyduckServiceUUID) {
      return ExpansionTile(
        title: Text(service.deviceId.toString()),
        initiallyExpanded: true,
        children:
            service.characteristics.map(_toWidget).whereNotNull().toList(),
      );
    }
    return ListTile(
      title: const Text('Unknown Service'),
      subtitle: Text(service.uuid.toString()),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? const Icon(Icons.bluetooth_connected)
                    : const Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      const IconButton(
                        icon: SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) =>
                  snapshot.data == BluetoothDeviceState.connected
                      ? StreamBuilder<List<BluetoothService>>(
                          stream: device.services,
                          initialData: const [],
                          builder: (c, snapshot) {
                            return Column(
                              children: snapshot.data!
                                  .map((s) => _ServiceTile(service: s))
                                  .toList(),
                            );
                          },
                        )
                      : Container(),
            ),
          ],
        ),
      ),
    );
  }
}
