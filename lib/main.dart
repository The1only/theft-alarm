import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  // Disable verbose Bluetooth logging
  FlutterBluePlus.setLogLevel(LogLevel.none);
  runApp(const MotionAlarmApp());
}

// Platform channel for native volume control and sleep prevention
class VolumeController {
  static const platform = MethodChannel('volume_control');
  
  static Future<double> getVolume() async {
    try {
      final double volume = await platform.invokeMethod('getVolume');
      return volume;
    } on PlatformException catch (e) {
      print('Failed to get volume: ${e.message}');
      return 0.5;
    }
  }
  
  static Future<bool> setVolume(double volume) async {
    try {
      final bool result = await platform.invokeMethod('setVolume', {'volume': volume});
      return result;
    } on PlatformException catch (e) {
      print('Failed to set volume: ${e.message}');
      return false;
    }
  }
  
  static Future<bool> preventSleep() async {
    try {
      final bool result = await platform.invokeMethod('preventSleep');
      return result;
    } on PlatformException catch (e) {
      print('Failed to prevent sleep: ${e.message}');
      return false;
    }
  }
  
  static Future<bool> allowSleep() async {
    try {
      final bool result = await platform.invokeMethod('allowSleep');
      return result;
    } on PlatformException catch (e) {
      print('Failed to allow sleep: ${e.message}');
      return false;
    }
  }
  
  static Future<bool> isPreventingSleep() async {
    try {
      final bool result = await platform.invokeMethod('isPreventingSleep');
      return result;
    } on PlatformException catch (e) {
      print('Failed to check sleep prevention status: ${e.message}');
      return false;
    }
  }
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
    
    // Initialize Bluetooth adapter state monitoring
    _initializeBluetooth();
    
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });
  }

  void _initializeBluetooth() async {
    // Wait a moment for the adapter to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check initial adapter state to warm up the system
    try {
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      print('Initial Bluetooth state: $state');
    } catch (e) {
      print('Error checking initial Bluetooth state: $e');
    }
  }

  void _startScan() async {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    try {
      // Wait for Bluetooth adapter to be ready
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      
      // If adapter state is unknown or turning on, wait a bit and check again
      if (adapterState == BluetoothAdapterState.unknown) {
        await Future.delayed(const Duration(seconds: 1));
        adapterState = await FlutterBluePlus.adapterState.first;
      }
      
      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth is not on. Current state: $adapterState');
      }
      
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      print('Error starting scan: $e');
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bluetooth error: Please ensure Bluetooth is enabled'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  'Scan for Witmotion devices',
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
            child: Builder(
              builder: (context) {
                // Filter to only show Witmotion devices
                final witmotionResults = scanResults.where((result) {
                  final name = result.device.platformName.toUpperCase();
                  return name.contains('WT') || name.contains('WITMOTION');
                }).toList();

                if (witmotionResults.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Witmotion devices found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Press "Scan for Devices" to start',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: witmotionResults.length,
                  itemBuilder: (context, index) {
                    final result = witmotionResults[index];
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
  double movementThreshold = 0.045; // Above RMS noise, sensitive to small movements
  DateTime? lastAlarmCheck;
  DateTime? lastMovementTime;
  Timer? alarmTimer;
  Timer? countdownTimer;
  int countdownSeconds = 0;
  double originalVolume = 0.5; // Store original system volume

  bool isConnected = false;
  String connectionStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _setupConnection();
    _captureInitialVolume();
  }

  void _captureInitialVolume() async {
    try {
      originalVolume = await VolumeController.getVolume();
      print('💾 Initial volume captured: ${(originalVolume * 100).round()}%');
    } catch (e) {
      print('⚠️ Failed to capture initial volume: $e');
      originalVolume = 0.5; // fallback
    }
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
      await Future.delayed(const Duration(milliseconds: 50));

      // Enable combined output (0x61 packet)
      await writeCharacteristic!.write([0xFF, 0xAA, 0x02, 0x1E, 0x00]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Save configuration
      await writeCharacteristic!.write([0xFF, 0xAA, 0x00, 0x00, 0x00]);
    } catch (e) {
      print('❌ IMU configuration error: $e');
    }
  }

  void _parseIMUData(List<int> data) {
    // Handle 40-byte packet (two 20-byte segments)
    if (data.length == 40) {
      List<int> segment1 = data.sublist(0, 20);
      List<int> segment2 = data.sublist(20, 40);
      _parseSinglePacket(segment1);
      _parseSinglePacket(segment2);
      return;
    }
    
    // Handle single packet
    _parseSinglePacket(data);
  }

  void _parseSinglePacket(List<int> data) {
    try {
      final bytes = Uint8List.fromList(data);
      if (bytes.length < 11) return;

      final type = bytes[1];

      // Type 0x61: Combined packet (20 bytes)
      if (type == 0x61 && data.length == 20) {
        // Extract 9 little-endian signed 16-bit integers starting at byte 2
        // vals[0-2]: AX, AY, AZ (accelerometer)
        // vals[3-5]: GX, GY, GZ (gyroscope)
        // vals[6-8]: Roll, Pitch, Yaw (angles)
        List<int> vals = [];
        for (int i = 0; i < 9; i++) {
          int idx = 2 + i * 2;
          vals.add(_bytesToInt16(bytes, idx));
        }
        
        // Parse accelerometer (vals 0-2)
        accelX = vals[0] / 32768.0 * 16; // ±16g range
        accelY = vals[1] / 32768.0 * 16;
        accelZ = vals[2] / 32768.0 * 16;

        // Check for movement if alarm is armed
        if (alarmArmed) {
          _checkMovement(DateTime.now());
        }
      }
    } catch (e) {
      print('Parse error: $e');
    }
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
        print('🚨 ALARM TRIGGERED! Movement: ${movement.toStringAsFixed(3)}G');
      }
    }
  }

  void _playAlarm() async {
    alarmTimer?.cancel();

    try {
      // Capture current system volume right before alarm (in case it changed)
      double currentVolume = await VolumeController.getVolume();
      originalVolume = currentVolume;
      print('💾 Volume saved: ${(originalVolume * 100).round()}%');
      
      // Set to maximum volume
      bool volumeSet = await VolumeController.setVolume(1.0);
      if (!volumeSet) {
        print('⚠️ Failed to set volume to maximum');
      } else {
        print('🔊 Volume set to maximum');
      }
      
      await audioPlayer.stop();
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.setVolume(1.0);
      
      await audioPlayer.play(AssetSource('car_alarm_and_indistinct_talk_in_the_background_f9X.wav'));

      // Check every 100ms if we should stop
      alarmTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (lastMovementTime != null) {
          final timeSinceMovement =
              DateTime.now().difference(lastMovementTime!);
          if (timeSinceMovement.inSeconds >= 5) {
            timer.cancel();
            audioPlayer.stop();
            // Restore original volume
            _restoreVolume();
            setState(() {
              alarmTriggered = false;
            });
            return;
          }
        }

        if (!alarmArmed) {
          timer.cancel();
          audioPlayer.stop();
          // Restore original volume
          _restoreVolume();
          setState(() {
            alarmTriggered = false;
          });
          return;
        }
      });
    } catch (e) {
      print('❌ Alarm failed: $e');
      // Restore volume even if alarm failed
      _restoreVolume();
    }
  }

  void _stopAlarm() async {
    alarmTimer?.cancel();
    alarmTimer = null;
    await audioPlayer.stop();
    
    // Restore original system volume
    _restoreVolume();
    
    setState(() {
      alarmTriggered = false;
      lastMovementTime = null;
    });
  }

  void _restoreVolume() async {
    try {
      bool restored = await VolumeController.setVolume(originalVolume);
      if (restored) {
        print('🔊 Volume restored to ${(originalVolume * 100).round()}%');
      } else {
        print('❌ Failed to restore volume');
      }
    } catch (e) {
      print('❌ Error restoring volume: $e');
    }
  }

  void _armAlarm() async {
    double accelMagnitude =
        math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
    
    // Update the original volume to current system volume when arming
    try {
      originalVolume = await VolumeController.getVolume();
      print('💾 Volume captured on arm: ${(originalVolume * 100).round()}%');
    } catch (e) {
      print('⚠️ Failed to capture volume on arm: $e');
    }
    
    // Start 4-second countdown
    setState(() {
      countdownSeconds = 4;
    });
    
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        countdownSeconds--;
      });
      
      if (countdownSeconds <= 0) {
        timer.cancel();
        // Actually arm the alarm after countdown
        setState(() {
          baselineAccelMagnitude = accelMagnitude;
          alarmArmed = true;
          alarmTriggered = false;
          countdownSeconds = 0;
        });
        
        // Prevent laptop from sleeping while alarm is armed
        VolumeController.preventSleep().then((success) {
          if (success) {
            print('🛌 Sleep prevention activated - laptop will stay awake when closed');
          } else {
            print('❌ Failed to prevent sleep');
          }
        });
      }
    });
  }

  void _disarmAlarm() async {
    alarmTimer?.cancel();
    alarmTimer = null;
    countdownTimer?.cancel();
    countdownTimer = null;
    await audioPlayer.stop();
    
    // Allow laptop to sleep normally again
    VolumeController.allowSleep().then((success) {
      if (success) {
        print('😴 Sleep prevention disabled - laptop can sleep normally');
      } else {
        print('❌ Failed to allow sleep');
      }
    });
    
    setState(() {
      alarmArmed = false;
      alarmTriggered = false;
      lastMovementTime = null;
      countdownSeconds = 0;
    });
  }

  @override
  void dispose() {
    alarmTimer?.cancel();
    countdownTimer?.cancel();
    audioPlayer.dispose();
    characteristicSubscription?.cancel();
    widget.device.disconnect();
    
    // Ensure sleep is allowed when app closes
    VolumeController.allowSleep();
    
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
                    : countdownSeconds > 0
                        ? 'Arming in ${countdownSeconds} seconds...\nClose your computer now!'
                        : alarmArmed
                            ? 'Monitoring for movement...\nThreshold: ${movementThreshold.toStringAsFixed(2)}G'
                            : 'Arm the alarm to monitor for movement',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Control Buttons
              if (!alarmArmed && countdownSeconds == 0)
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

              if (countdownSeconds > 0)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: null, // Disabled during countdown
                    icon: Icon(Icons.timer, size: 32),
                    label: Text(
                      'ARMING IN ${countdownSeconds}s',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.amber,
                      disabledForegroundColor: Colors.white,
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
                    print('🔊 Testing car alarm...');
                    try {
                      await audioPlayer.stop();
                      await audioPlayer.setVolume(1.0);
                      
                      print('📁 Playing from asset source...');
                      await audioPlayer.play(AssetSource('car_alarm_and_indistinct_talk_in_the_background_f9X.wav'));
                      
                      audioPlayer.onPlayerStateChanged.listen((state) {
                        print('🔊 Test player state: $state');
                      });
                      
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
