import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io' show File, Directory, Process, Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MotionAlarmApp());
}

class MotionAlarmApp extends StatelessWidget {
  const MotionAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motion Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const BluetoothScanPage(),
    );
  }
}

// Bluetooth Scan Page
class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });
  }

  void _startScan() async {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      print('Error starting scan: $e');
    }

    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Alarm - Scan Devices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Scan for Bluetooth devices',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isScanning ? null : _startScan,
                  child: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                ),
              ],
            ),
          ),
          Expanded(
            child: scanResults.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Press "Scan for Devices" to start',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: scanResults.length,
                    itemBuilder: (context, index) {
                      final result = scanResults[index];
                      final device = result.device;
                      final name = device.platformName;

                      return ListTile(
                        leading: const Icon(
                          Icons.bluetooth,
                          color: Colors.blue,
                        ),
                        title: Text(
                          name.isNotEmpty ? name : 'Unknown Device',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${device.remoteId}'),
                            Text('Signal: ${result.rssi} dBm'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AlarmPage(device: device),
                              ),
                            );
                          },
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Motion Alarm Page
class AlarmPage extends StatefulWidget {
  final BluetoothDevice device;

  const AlarmPage({super.key, required this.device});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  BluetoothCharacteristic? writeCharacteristic;
  StreamSubscription<List<int>>? characteristicSubscription;

  // Accelerometer data
  double accelX = 0, accelY = 0, accelZ = 0;

  // Alarm variables
  bool alarmArmed = false;
  bool alarmTriggered = false;
  final AudioPlayer audioPlayer = AudioPlayer();
  double baselineAccelMagnitude = 1.0;
  double movementThreshold = 0.3;
  DateTime? lastAlarmCheck;
  DateTime? lastMovementTime;
  Timer? alarmTimer;

  bool isConnected = false;
  String connectionStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _setupConnection();
  }

  void _setupConnection() async {
    try {
      await widget.device.connect();
      setState(() {
        isConnected = true;
        connectionStatus = 'Connected';
      });

      List<BluetoothService> services = await widget.device.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristicSubscription = characteristic.value.listen((value) {
              _parseIMUData(value);
            });
          }

          if (characteristic.properties.write) {
            writeCharacteristic = characteristic;
          }
        }
      }

      // Send configuration to sensor
      await Future.delayed(const Duration(milliseconds: 500));
      await _configureIMU();
    } catch (e) {
      setState(() {
        connectionStatus = 'Connection failed: $e';
      });
    }
  }

  Future<void> _configureIMU() async {
    if (writeCharacteristic == null) return;

    try {
      // Unlock register
      await writeCharacteristic!.write([0xFF, 0xAA, 0x69, 0x88, 0xB5]);
      await Future.delayed(const Duration(milliseconds: 20));

      // Enable combined output (0x61 packet)
      await writeCharacteristic!.write([0xFF, 0xAA, 0x02, 0x1E, 0x00]);
      await Future.delayed(const Duration(milliseconds: 20));

      // Save configuration
      await writeCharacteristic!.write([0xFF, 0xAA, 0x00, 0x00, 0x00]);

      print('✅ IMU configured');
    } catch (e) {
      print('❌ IMU configuration error: $e');
    }
  }

  void _parseIMUData(List<int> data) {
    try {
      final bytes = Uint8List.fromList(data);
      if (bytes.length < 11) return;

      final header = bytes[0];
      final type = bytes[1];

      // Type 0x61: Combined packet
      if (type == 0x61 && bytes.length == 20) {
        // Accel: bytes 2-7 (X, Y, Z)
        accelX = _bytesToInt16(bytes, 2) / 32768.0 * 16; // ±16g range
        accelY = _bytesToInt16(bytes, 4) / 32768.0 * 16;
        accelZ = _bytesToInt16(bytes, 6) / 32768.0 * 16;

        // Check for movement if alarm is armed
        if (alarmArmed) {
          _checkMovement(DateTime.now());
        }
      }
    } catch (e) {
      print('Parse error: $e');
    }
  }

  void _checkMovement(DateTime now) {
    if (lastAlarmCheck != null &&
        now.difference(lastAlarmCheck!).inMilliseconds < 100) {
      return;
    }
    lastAlarmCheck = now;

    if (!alarmArmed) return;

    // Calculate acceleration magnitude
    double accelMagnitude =
        math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

    // Check if movement exceeds threshold
    double movement = (accelMagnitude - baselineAccelMagnitude).abs();

    if (movement > movementThreshold) {
      lastMovementTime = now;

      if (!alarmTriggered) {
        setState(() {
          alarmTriggered = true;
        });
        _playAlarm();
        print(
            '🚨 ALARM TRIGGERED! Movement: ${movement.toStringAsFixed(3)}G');
      }
    }
  }

  void _playAlarm() async {
    alarmTimer?.cancel();

    print('🚨 STARTING ALARM: 0.5Hz + 500Hz + 1kHz');

    try {
      final audioPath = await _generateAlarmTone();
      await audioPlayer.stop();
      await audioPlayer.setVolume(1.0);
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.play(DeviceFileSource(audioPath));

      print('✅ Alarm playing');

      // Check every 100ms if we should stop
      alarmTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (lastMovementTime != null) {
          final timeSinceMovement =
              DateTime.now().difference(lastMovementTime!);
          if (timeSinceMovement.inSeconds >= 5) {
            timer.cancel();
            audioPlayer.stop();
            setState(() {
              alarmTriggered = false;
            });
            print('🔇 Alarm auto-stopped');
            return;
          }
        }

        if (!alarmArmed) {
          timer.cancel();
          audioPlayer.stop();
          setState(() {
            alarmTriggered = false;
          });
          return;
        }
      });
    } catch (e) {
      print('❌ Alarm failed: $e');
      // Fallback
      alarmTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (lastMovementTime != null) {
          final timeSinceMovement =
              DateTime.now().difference(lastMovementTime!);
          if (timeSinceMovement.inSeconds >= 5 || !alarmArmed) {
            timer.cancel();
            setState(() {
              alarmTriggered = false;
            });
            return;
          }
        }
        print('\a🚨 ALARM! 🚨');
      });
    }
  }

  void _stopAlarm() async {
    alarmTimer?.cancel();
    alarmTimer = null;
    await audioPlayer.stop();
    setState(() {
      alarmTriggered = false;
      lastMovementTime = null;
    });
    print('🔇 Alarm stopped manually');
  }

  void _armAlarm() {
    double accelMagnitude =
        math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
    setState(() {
      baselineAccelMagnitude = accelMagnitude;
      alarmArmed = true;
      alarmTriggered = false;
    });
    print(
        '🔒 Alarm ARMED. Baseline: ${baselineAccelMagnitude.toStringAsFixed(2)}G');
  }

  void _disarmAlarm() async {
    alarmTimer?.cancel();
    alarmTimer = null;
    await audioPlayer.stop();
    setState(() {
      alarmArmed = false;
      alarmTriggered = false;
      lastMovementTime = null;
    });
    print('🔓 Alarm DISARMED');
  }

  Future<String> _generateAlarmTone() async {
    try {
      const int sampleRate = 44100;
      const double duration = 2.0;
      int numSamples = (sampleRate * duration).toInt();

      const double freq1 = 0.5;
      const double freq2 = 500.0;
      const double freq3 = 1000.0;

      List<int> samples = [];
      for (int i = 0; i < numSamples; i++) {
        double t = i / sampleRate;
        double wave1 = math.sin(2 * math.pi * freq1 * t);
        double wave2 = math.sin(2 * math.pi * freq2 * t);
        double wave3 = math.sin(2 * math.pi * freq3 * t);
        double mixed = (wave1 + wave2 + wave3) / 3.0;
        int sample = (mixed * 32767).toInt().clamp(-32768, 32767);
        samples.add(sample & 0xFF);
        samples.add((sample >> 8) & 0xFF);
      }

      List<int> wavData = [];
      wavData.addAll('RIFF'.codeUnits);
      wavData.addAll(_intToBytes(36 + samples.length, 4));
      wavData.addAll('WAVE'.codeUnits);
      wavData.addAll('fmt '.codeUnits);
      wavData.addAll(_intToBytes(16, 4));
      wavData.addAll(_intToBytes(1, 2));
      wavData.addAll(_intToBytes(1, 2));
      wavData.addAll(_intToBytes(sampleRate, 4));
      wavData.addAll(_intToBytes(sampleRate * 2, 4));
      wavData.addAll(_intToBytes(2, 2));
      wavData.addAll(_intToBytes(16, 2));
      wavData.addAll('data'.codeUnits);
      wavData.addAll(_intToBytes(samples.length, 4));
      wavData.addAll(samples);

      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/alarm_tone.wav');
      await file.writeAsBytes(Uint8List.fromList(wavData));

      return file.path;
    } catch (e) {
      print('❌ Error generating alarm: $e');
      rethrow;
    }
  }

  Uint8List _intToBytes(int value, int numBytes) {
    final bytes = Uint8List(numBytes);
    for (int i = 0; i < numBytes; i++) {
      bytes[i] = (value >> (8 * i)) & 0xFF;
    }
    return bytes;
  }

  int _bytesToInt16(Uint8List bytes, int offset) {
    int low = bytes[offset];
    int high = bytes[offset + 1];
    int value = (high << 8) | low;
    if (value >= 32768) {
      value -= 65536;
    }
    return value;
  }

  @override
  void dispose() {
    alarmTimer?.cancel();
    characteristicSubscription?.cancel();
    audioPlayer.dispose();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Motion Alarm - ${widget.device.platformName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              Icon(
                alarmTriggered
                    ? Icons.warning_amber_rounded
                    : alarmArmed
                        ? Icons.shield
                        : Icons.shield_outlined,
                size: 120,
                color: alarmTriggered
                    ? Colors.red
                    : alarmArmed
                        ? Colors.orange
                        : Colors.grey,
              ),
              const SizedBox(height: 32),

              // Status Text
              Text(
                alarmTriggered
                    ? '🚨 ALARM TRIGGERED! 🚨'
                    : alarmArmed
                        ? 'Alarm Armed'
                        : 'Alarm Disarmed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: alarmTriggered
                      ? Colors.red
                      : alarmArmed
                          ? Colors.orange
                          : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Info Text
              Text(
                alarmTriggered
                    ? 'Movement detected!\nAlarm will stop 5 sec after movement ends'
                    : alarmArmed
                        ? 'Monitoring for movement...\nThreshold: ${movementThreshold.toStringAsFixed(2)}G'
                        : 'Arm the alarm to monitor for movement',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Control Buttons
              if (!alarmArmed)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _armAlarm,
                    icon: const Icon(Icons.lock, size: 32),
                    label: const Text(
                      'ARM ALARM',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              if (alarmArmed && !alarmTriggered)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _disarmAlarm,
                    icon: const Icon(Icons.lock_open, size: 32),
                    label: const Text(
                      'DISARM ALARM',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              if (alarmTriggered)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _stopAlarm,
                    icon: const Icon(Icons.stop, size: 32),
                    label: const Text(
                      'STOP ALARM',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Test Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    print('🔊 Testing alarm...');
                    try {
                      final audioPath = await _generateAlarmTone();
                      await audioPlayer.stop();
                      await audioPlayer.setVolume(1.0);
                      await audioPlayer.play(DeviceFileSource(audioPath));
                      print('✅ Test playing');
                      await Future.delayed(const Duration(seconds: 3));
                      await audioPlayer.stop();
                      print('🔇 Test complete');
                    } catch (e) {
                      print('❌ Test failed: $e');
                    }
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('TEST ALARM SOUND'),
                ),
              ),

              const SizedBox(height: 32),

              // Connection Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isConnected ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connectionStatus,
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
