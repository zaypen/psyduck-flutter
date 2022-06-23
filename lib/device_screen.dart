import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'constants.dart';

typedef WriteCallback = void Function(List<int>);
typedef Builder = Widget Function(BuildContext, List<int>?, WriteCallback);

class _CharacteristicTile extends StatelessWidget {
  final String title;
  final BluetoothCharacteristic characteristic;
  final Builder builder;

  const _CharacteristicTile({
    Key? key,
    required this.title,
    required this.characteristic,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
      key: key,
      stream: characteristic.value,
      initialData: characteristic.lastValue,
      builder: (c, snapshot) {
        final value = snapshot.data;
        return ListTile(
          title: Text(title),
          subtitle: Text(value?.firstOrNull?.toString() ?? ""),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              builder(context, value, (v) {
                characteristic.write(v);
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
          builder: (context, value, write) => CupertinoSwitch(
            value: value?.singleOrNull == 1 ? true : false,
            onChanged: (bool value) {
              write([value ? 1 : 0]);
            },
          ),
        );
      case psyduckArmEnabledUUID:
        return _CharacteristicTile(
          title: "Arm Enabled",
          characteristic: characteristic,
          builder: (context, value, write) => CupertinoSwitch(
            value: value?.singleOrNull == 1 ? true : false,
            onChanged: (bool value) {
              write([value ? 1 : 0]);
            },
          ),
        );
      case psyduckArmWaitUUID:
        return _CharacteristicTile(
          title: "Arm Wait",
          characteristic: characteristic,
          builder: (context, value, write) => CupertinoSlider(
            value: value?.firstOrNull?.toDouble() ?? 2000,
            divisions: 100,
            min: 2000,
            max: 10000,
            onChanged: (_) {},
            onChangeEnd: (double value) {
              write([value.toInt()]);
            },
          ),
        );
      case psyduckFootEnabledUUID:
        return _CharacteristicTile(
          title: "Spinning Enabled",
          characteristic: characteristic,
          builder: (context, value, write) => CupertinoSwitch(
            value: value?.singleOrNull == 1 ? true : false,
            onChanged: (bool value) {
              write([value ? 1 : 0]);
            },
          ),
        );
      case psyduckFootSpeedUUID:
        return _CharacteristicTile(
          title: "Spinning Speed",
          characteristic: characteristic,
          builder: (context, value, write) => CupertinoSlider(
            value: value?.firstOrNull?.toDouble() ?? 127,
            divisions: 8,
            min: 127,
            max: 255,
            onChanged: (_) {},
            onChangeEnd: (double value) {
              write([value.toInt()]);
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
