import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'esp32_socket_service.dart';

/// BLE counterpart to [Esp32SocketService]. It implements the Niva GATT
/// contract in the firmware rather than a generic serial terminal protocol.
///
/// The ESP32 fragments JSON notifications because a BLE link may begin with
/// only a 20-byte payload. Each notification starts with a sequence byte and
/// flags byte: bit 0 starts a frame, bit 1 finishes it.
class Esp32BleService {
  static final Guid serviceUuid = Guid('c4f00001-dc50-4c44-a4d8-f0164e510001');
  static final Guid rxUuid = Guid('c4f00002-dc50-4c44-a4d8-f0164e510001');
  static final Guid txUuid = Guid('c4f00003-dc50-4c44-a4d8-f0164e510001');

  final _stateController = StreamController<Esp32ConnectionState>.broadcast();
  Esp32ConnectionState _state = const Esp32ConnectionState();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _scanTimeout;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandCharacteristic;
  BytesBuilder _frame = BytesBuilder(copy: false);
  int? _sequence;
  bool _manuallyDisconnected = true;

  Stream<Esp32ConnectionState> get stateStream => _stateController.stream;
  Esp32ConnectionState get state => _state;

  void _emit(Esp32ConnectionState next) {
    _state = next;
    _stateController.add(next);
  }

  Future<void> connect() async {
    await disconnect(emitState: false);
    _manuallyDisconnected = false;
    _emit(_state.copyWith(
      isConnecting: true,
      isConnected: false,
      activeUrl: 'ble://scanning',
      clearError: true,
    ));

    try {
      if (!await FlutterBluePlus.isSupported) {
        throw StateError(
            'Bluetooth Low Energy is not supported on this device.');
      }
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw StateError('Turn on Bluetooth, then try again.');
      }

      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (_device != null) {
          return;
        }
        for (final result in results) {
          if (result.advertisementData.serviceUuids.contains(serviceUuid)) {
            unawaited(_connectTo(result.device));
            return;
          }
        }
      },
          onError: (_) => _fail(
              'Bluetooth scan failed. Check Bluetooth permission and try again.'));

      _scanTimeout = Timer(const Duration(seconds: 10), () {
        if (_device == null) {
          _fail('Niva Insole was not found. Keep it powered on and nearby.');
        }
      });
      await FlutterBluePlus.startScan(
          withServices: [serviceUuid], timeout: const Duration(seconds: 10));
    } catch (error) {
      _fail(error is StateError
          ? error.message
          : 'Bluetooth connection could not start.');
    }
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    if (_device != null || _manuallyDisconnected) {
      return;
    }
    _device = device;
    _scanTimeout?.cancel();
    await FlutterBluePlus.stopScan();

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      _connectionSubscription =
          device.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected &&
            !_manuallyDisconnected) {
          _fail('Bluetooth connection to Niva Insole ended.');
        }
      });

      final services = await device.discoverServices();
      final service = services
          .where((candidate) => candidate.uuid == serviceUuid)
          .firstOrNull;
      if (service == null) {
        throw StateError('Niva telemetry service was not found.');
      }
      final telemetry = service.characteristics
          .where((candidate) => candidate.uuid == txUuid)
          .firstOrNull;
      final command = service.characteristics
          .where((candidate) => candidate.uuid == rxUuid)
          .firstOrNull;
      if (telemetry == null || command == null) {
        throw StateError('Niva telemetry characteristics were not found.');
      }

      _commandCharacteristic = command;
      _notificationSubscription =
          telemetry.onValueReceived.listen(_onNotification, onError: (_) {
        _fail('Bluetooth telemetry stream failed.');
      });
      await telemetry.setNotifyValue(true);
      _emit(_state.copyWith(
        isConnected: true,
        isConnecting: false,
        activeUrl: 'ble://${device.remoteId.str}',
        clearError: true,
      ));
    } catch (error) {
      _fail(error is StateError
          ? error.message
          : 'Could not connect to Niva Insole over Bluetooth.');
    }
  }

  void _onNotification(List<int> value) {
    if (value.length < 2) {
      return;
    }
    final sequence = value[0];
    final flags = value[1];
    final isStart = (flags & 0x01) != 0;
    final isEnd = (flags & 0x02) != 0;

    if (isStart) {
      _frame = BytesBuilder(copy: false);
      _sequence = sequence;
    }
    if (_sequence != sequence) {
      _frame = BytesBuilder(copy: false);
      _sequence = null;
      return;
    }
    _frame.add(value.sublist(2));
    if (!isEnd) {
      return;
    }

    try {
      final decoded =
          jsonDecode(utf8.decode(_frame.takeBytes())) as Map<String, dynamic>;
      _emit(_state.copyWith(
        isConnected: true,
        isConnecting: false,
        lastMessageAt: DateTime.now(),
        latestPacket: decoded,
        clearError: true,
      ));
    } catch (_) {
      _emit(_state.copyWith(
          error: 'Received a malformed Bluetooth telemetry frame.'));
    } finally {
      _sequence = null;
    }
  }

  Future<void> tare() async {
    final command = _commandCharacteristic;
    if (command == null || !_state.isConnected) {
      throw StateError('Connect to Niva Insole before starting a tare.');
    }
    await command.write(utf8.encode('{"cmd":"tare"}'), withoutResponse: false);
  }

  void _fail(String message) {
    if (_manuallyDisconnected) {
      return;
    }
    _emit(_state.copyWith(
        isConnected: false, isConnecting: false, error: message));
  }

  Future<void> disconnect({bool emitState = true}) async {
    _manuallyDisconnected = true;
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _device?.disconnect();
    _scanSubscription = null;
    _notificationSubscription = null;
    _connectionSubscription = null;
    _device = null;
    _commandCharacteristic = null;
    _sequence = null;
    _frame = BytesBuilder(copy: false);
    if (emitState) {
      _emit(_state.copyWith(
          isConnected: false, isConnecting: false, clearError: true));
    }
  }

  void dispose() {
    unawaited(disconnect());
    _stateController.close();
  }
}
