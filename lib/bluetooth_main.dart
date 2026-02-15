import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';  // Commented out for macOS
import 'dart:async';
import 'dart:typed_data';
import 'kalman_filter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Witmotion IMU Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BluetoothScanPage(),
    );
  }
}

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void initState() {
    super.initState();
    // Skip permission requests on macOS
    print('Initializing Bluetooth scan page');
  }

  void _startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    try {
      print('Starting simple Bluetooth scan...');
      
      // Just start scanning directly
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 5),
      );

      // Listen to scan results
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print('Found ${results.length} devices:');
        for (var result in results) {
          print('  - ${result.device.name.isNotEmpty ? result.device.name : "Unknown"} (${result.device.id})');
        }
        setState(() {
          scanResults = results;
        });
      });

      // Stop scan after timeout
      await Future.delayed(Duration(seconds: 5));
      await FlutterBluePlus.stopScan();
      print('Scan completed');
      
    } catch (e) {
      print('Scan failed: $e');
      _showError("Scan failed: $e");
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  bool _isWitmotionDevice(ScanResult result) {
    final deviceName = result.device.platformName.toLowerCase();
    
    // Check if device name contains Witmotion identifiers
    if (deviceName.contains('witmotion') || 
        deviceName.contains('wt901') ||
        deviceName.contains('wt9011') ||
        deviceName.contains('wit')) {
      return true;
    }
    
    // Check if device advertises the Witmotion service UUID
    for (var serviceUuid in result.advertisementData.serviceUuids) {
      if (serviceUuid.toString().toLowerCase().contains('ffe0') ||
          serviceUuid.toString().toLowerCase().contains('ffe4')) {
        return true;
      }
    }
    
    return false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IMUDataPage(device: device),
        ),
      );
    } catch (e) {
      _showError("Failed to connect: $e");
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Witmotion IMU'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Looking for Witmotion WT9011DCL IMU sensor',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (!isScanning && scanResults.isNotEmpty)
                  Text(
                    'Found ${scanResults.where(_isWitmotionDevice).length} Witmotion device(s)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isScanning ? null : _startScan,
                  child: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                ),
              ],
            ),
          ),
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                // Filter to only show Witmotion devices
                final witmotionDevices = scanResults.where(_isWitmotionDevice).toList();
                
                if (witmotionDevices.isEmpty && !isScanning) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No Witmotion sensors found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try scanning again',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: witmotionDevices.length,
                  itemBuilder: (context, index) {
                    final result = witmotionDevices[index];
                    final device = result.device;
                    final deviceName = device.platformName.isEmpty 
                        ? 'Witmotion Sensor' 
                        : device.platformName;
                    
                    return Card(
                      color: Colors.green.shade50,
                      child: ListTile(
                        leading: Icon(
                          Icons.sensors,
                          color: Colors.green,
                          size: 32,
                        ),
                        title: Text(
                          deviceName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${device.remoteId}'),
                            Text('Signal: ${result.rssi} dBm'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _connectToDevice(device),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Connect'),
                        ),
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

class IMUDataPage extends StatefulWidget {
  final BluetoothDevice device;

  const IMUDataPage({super.key, required this.device});

  @override
  State<IMUDataPage> createState() => _IMUDataPageState();
}

class _IMUDataPageState extends State<IMUDataPage> {
  BluetoothCharacteristic? notifyCharacteristic;
  BluetoothCharacteristic? writeCharacteristic;
  StreamSubscription<List<int>>? characteristicSubscription;
  
  // Raw IMU data variables
  double accelX = 0, accelY = 0, accelZ = 0;
  double gyroX = 0, gyroY = 0, gyroZ = 0;
  double magX = 0, magY = 0, magZ = 0;
  double roll = 0, pitch = 0, yaw = 0;
  double temperature = 0;
  
  // Filtered IMU data variables (from Kalman filter)
  double filteredRoll = 0, filteredPitch = 0, filteredYaw = 0;
  double gyroBiasX = 0, gyroBiasY = 0, gyroBiasZ = 0;
  
  // Kalman filter instance
  final KalmanFilter kalmanFilter = KalmanFilter();
  DateTime? lastUpdateTime;
  
  bool isConnected = false;
  String connectionStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _setupConnection();
  }

  void _setupConnection() async {
    try {
      // Ensure we're connected
      print('Connecting to device: ${widget.device.platformName}');
      await widget.device.connect();
      
      setState(() {
        isConnected = true;
        connectionStatus = 'Connected - Discovering services...';
      });

      // Discover services
      print('Discovering services...');
      List<BluetoothService> services = await widget.device.discoverServices();
      print('Found ${services.length} services');

      // Log all services and characteristics
      for (BluetoothService service in services) {
        print('Service: ${service.uuid}');
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print('  Characteristic: ${characteristic.uuid}');
          print('    Properties: notify=${characteristic.properties.notify}, '
                'read=${characteristic.properties.read}, '
                'write=${characteristic.properties.write}');
          
          // Save write characteristic for configuration
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            writeCharacteristic = characteristic;
            print('  -> Found write characteristic');
          }
          
          // Subscribe to ALL notify/indicate characteristics
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            try {
              print('  -> Subscribing to ${characteristic.uuid}');
              await characteristic.setNotifyValue(true);
              
              characteristic.lastValueStream.listen(
                (value) {
                  print('Data received from ${characteristic.uuid}: ${value.length} bytes');
                  _parseIMUData(value);
                },
                onError: (error) {
                  print('Characteristic error on ${characteristic.uuid}: $error');
                },
              );
              
              notifyCharacteristic = characteristic;
              print('  -> Successfully subscribed!');
            } catch (e) {
              print('  -> Failed to subscribe: $e');
            }
          }
        }
      }
      
      // Configure sensor to output magnetometer data
      if (writeCharacteristic != null) {
        try {
          print('Configuring sensor to enable individual packet outputs...');
          // Unlock register writes: KEY register = 0x69, value = 0xB588 (little-endian)
          await writeCharacteristic!.write([0xFF, 0xAA, 0x69, 0x88, 0xB5], withoutResponse: true);
          await Future.delayed(Duration(milliseconds: 100));
          
          // Set RSW (Return Switch) register = 0x02
          // RSW bits: 0x01=time, 0x02=accel, 0x04=gyro, 0x08=angle, 0x10=mag, 0x20=dport, 0x40=press, 0x80=gps, 0x100=velocity, 0x200=quaternion
          // Value: 0x1E = 0x02 + 0x04 + 0x08 + 0x10 (accel + gyro + angle + mag)
          await writeCharacteristic!.write([0xFF, 0xAA, 0x02, 0x1E, 0x00], withoutResponse: true);
          await Future.delayed(Duration(milliseconds: 100));
          
          // Save configuration: SAVE register = 0x00
          await writeCharacteristic!.write([0xFF, 0xAA, 0x00, 0x00, 0x00], withoutResponse: true);
          await Future.delayed(Duration(milliseconds: 100));
          
          print('Configuration sent! Sensor configured for separate packets (0x51, 0x52, 0x53, 0x54)');
        } catch (e) {
          print('Failed to configure sensor: $e');
        }
      }

      if (notifyCharacteristic == null) {
        setState(() {
          connectionStatus = 'No notify characteristic found';
        });
        print('WARNING: No notify characteristics found!');
      } else {
        setState(() {
          connectionStatus = 'Connected - Waiting for data...';
        });
        print('Setup complete, waiting for IMU data...');
      }

    } catch (e) {
      print('Connection error: $e');
      setState(() {
        isConnected = false;
        connectionStatus = 'Connection failed: $e';
      });
    }
  }

  void _parseIMUData(List<int> data) {
    print('Parsing IMU data: ${data.length} bytes');
    
    // Handle 40-byte packet (two 20-byte segments)
    if (data.length == 40) {
      print('40-byte packet detected, splitting into two 20-byte segments...');
      List<int> segment1 = data.sublist(0, 20);
      List<int> segment2 = data.sublist(20, 40);
      _parseSinglePacket(segment1);
      _parseSinglePacket(segment2);
      return;
    }
    
    // Handle 20-byte packet
    if (data.length == 20) {
      _parseSinglePacket(data);
      return;
    }
    
    // Handle 11-byte packet
    if (data.length == 11) {
      _parseSinglePacket(data);
      return;
    }
    
    print('Unexpected packet length: ${data.length} bytes');
  }

  void _parseSinglePacket(List<int> data) {
    try {
      Uint8List bytes = Uint8List.fromList(data);
      
      // Check for valid packet header (0x55)
      if (bytes[0] != 0x55) {
        print('Invalid header: 0x${bytes[0].toRadixString(16)} (expected 0x55)');
        return;
      }
      
      int dataType = bytes[1];
      print('Received packet type: 0x${dataType.toRadixString(16)} (${data.length} bytes)');
      bool dataUpdated = false;
      
      // Special handling for 20-byte packets with type 0x61
      if (data.length == 20 && dataType == 0x61) {
        print('20-byte packet with type 0x61: Extracting 9 int16 values');
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
        print('Accel: X=${accelX.toStringAsFixed(3)} Y=${accelY.toStringAsFixed(3)} Z=${accelZ.toStringAsFixed(3)}');
        
        // Parse gyroscope (vals 3-5)
        double gyroRawX = vals[3] / 32768.0 * 2000; // deg/s
        double gyroRawY = vals[4] / 32768.0 * 2000;
        double gyroRawZ = vals[5] / 32768.0 * 2000;
        gyroX = gyroRawX * (3.14159/180); // Convert to rad/s
        gyroY = gyroRawY * (3.14159/180);
        gyroZ = gyroRawZ * (3.14159/180);
        print('Gyro: X=${gyroRawX.toStringAsFixed(2)}°/s Y=${gyroRawY.toStringAsFixed(2)}°/s Z=${gyroRawZ.toStringAsFixed(2)}°/s');
        
        // Parse angles (vals 6-8)
        roll = vals[6] / 32768.0 * 180;
        pitch = vals[7] / 32768.0 * 180;
        yaw = vals[8] / 32768.0 * 180;
        print('Angles: Roll=${roll.toStringAsFixed(2)}° Pitch=${pitch.toStringAsFixed(2)}° Yaw=${yaw.toStringAsFixed(2)}°');
        
        dataUpdated = true;
      }
      // Standard 11-byte packet formats
      else if (data.length == 11) {
        switch (dataType) {
          case 0x51: // Accelerometer data
            accelX = _bytesToInt16(bytes, 2) / 32768.0 * 16; // ±16g range
            accelY = _bytesToInt16(bytes, 4) / 32768.0 * 16;
            accelZ = _bytesToInt16(bytes, 6) / 32768.0 * 16;
            temperature = _bytesToInt16(bytes, 8) / 340.0 + 36.25;
            print('Accel: X=${accelX.toStringAsFixed(3)} Y=${accelY.toStringAsFixed(3)} Z=${accelZ.toStringAsFixed(3)} Temp=${temperature.toStringAsFixed(1)}°C');
            dataUpdated = true;
            break;
            
          case 0x52: // Gyroscope data
            double gyroRawX = _bytesToInt16(bytes, 2) / 32768.0 * 2000; // deg/s
            double gyroRawY = _bytesToInt16(bytes, 4) / 32768.0 * 2000;
            double gyroRawZ = _bytesToInt16(bytes, 6) / 32768.0 * 2000;
            gyroX = gyroRawX * (3.14159/180); // Convert to rad/s
            gyroY = gyroRawY * (3.14159/180);
            gyroZ = gyroRawZ * (3.14159/180);
            print('Gyro: X=${gyroRawX.toStringAsFixed(2)}°/s Y=${gyroRawY.toStringAsFixed(2)}°/s Z=${gyroRawZ.toStringAsFixed(2)}°/s');
            dataUpdated = true;
            break;
            
          case 0x53: // Magnetometer data
            magX = _bytesToInt16(bytes, 2).toDouble();
            magY = _bytesToInt16(bytes, 4).toDouble();
            magZ = _bytesToInt16(bytes, 6).toDouble();
            print('Mag: X=${magX.toStringAsFixed(0)} Y=${magY.toStringAsFixed(0)} Z=${magZ.toStringAsFixed(0)}');
            dataUpdated = true;
            break;
            
          case 0x54: // Euler angles (raw from sensor)
            roll = _bytesToInt16(bytes, 2) / 32768.0 * 180;
            pitch = _bytesToInt16(bytes, 4) / 32768.0 * 180;
            yaw = _bytesToInt16(bytes, 6) / 32768.0 * 180;
            print('Angles: Roll=${roll.toStringAsFixed(2)}° Pitch=${pitch.toStringAsFixed(2)}° Yaw=${yaw.toStringAsFixed(2)}°');
            dataUpdated = true;
            break;
            
          default:
            print('Unknown data type: 0x${dataType.toRadixString(16)}');
        }
      } else {
        print('Unexpected: ${data.length}-byte packet with type 0x${dataType.toRadixString(16)}');
      }
      
      // Apply Kalman filter when we have all sensor data
      if (dataUpdated) {
        print('Data updated! Accel=${accelX.toStringAsFixed(2)}, Gyro=${gyroX.toStringAsFixed(2)}, Roll=${roll.toStringAsFixed(2)}');
        // Update UI immediately when any data is received
        setState(() {
          connectionStatus = 'Connected - Receiving data';
        });
        
        // Run Kalman filter if we have both accel and gyro data
        if (accelX != 0 && gyroX != 0) {
          print('Running Kalman filter...');
          DateTime now = DateTime.now();
          
          if (lastUpdateTime != null) {
            double dt = now.difference(lastUpdateTime!).inMicroseconds / 1000000.0;
            
            // Clamp dt to reasonable values
            if (dt > 0.001 && dt < 0.1) {
              kalmanFilter.dt = dt;
              
              // Predict step with gyroscope data
              kalmanFilter.predict(gyroX, gyroY, gyroZ);
              
              // Update step with accelerometer (and magnetometer if available)
              kalmanFilter.update(accelX, accelY, accelZ, magX, magY, magZ);
              
              // Get filtered values
              filteredRoll = kalmanFilter.roll;
              filteredPitch = kalmanFilter.pitch;
              filteredYaw = kalmanFilter.yaw;
              gyroBiasX = kalmanFilter.gyroBiasX * (180/3.14159); // Convert back to deg/s
              gyroBiasY = kalmanFilter.gyroBiasY * (180/3.14159);
              gyroBiasZ = kalmanFilter.gyroBiasZ * (180/3.14159);
              print('Kalman filtered: Roll=${filteredRoll.toStringAsFixed(2)}° Pitch=${filteredPitch.toStringAsFixed(2)}° Yaw=${filteredYaw.toStringAsFixed(2)}°');
            } else {
              print('dt out of range: $dt seconds');
            }
          } else {
            print('First update, initializing timestamp');
          }
          
          lastUpdateTime = now;
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
    
    // Convert to signed 16-bit
    if (value >= 32768) {
      value -= 65536;
    }
    return value;
  }

  @override
  void dispose() {
    characteristicSubscription?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IMU Data - ${widget.device.platformName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(connectionStatus),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Attitude Indicators
            Row(
              children: [
                Expanded(
                  child: _buildAttitudeIndicator(
                    'Raw Sensor',
                    roll,
                    pitch,
                    yaw,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAttitudeIndicator(
                    'Kalman Filtered',
                    filteredRoll,
                    filteredPitch,
                    filteredYaw,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Accelerometer Data
            _buildDataCard(
              'Accelerometer (g)',
              [
                'X: ${accelX.toStringAsFixed(3)}',
                'Y: ${accelY.toStringAsFixed(3)}',
                'Z: ${accelZ.toStringAsFixed(3)}',
              ],
              Icons.speed,
              Colors.red,
            ),
            
            // Gyroscope Data
            _buildDataCard(
              'Gyroscope (°/s)',
              [
                'X: ${gyroX.toStringAsFixed(2)}',
                'Y: ${gyroY.toStringAsFixed(2)}',
                'Z: ${gyroZ.toStringAsFixed(2)}',
              ],
              Icons.rotate_right,
              Colors.blue,
            ),
            
            // Magnetometer Data
            _buildDataCard(
              'Magnetometer',
              [
                'X: ${magX.toStringAsFixed(0)}',
                'Y: ${magY.toStringAsFixed(0)}',
                'Z: ${magZ.toStringAsFixed(0)}',
              ],
              Icons.explore,
              Colors.green,
            ),
            
            // Euler Angles (Raw from sensor)
            _buildDataCard(
              'Raw Orientation (°)',
              [
                'Roll: ${roll.toStringAsFixed(2)}',
                'Pitch: ${pitch.toStringAsFixed(2)}',
                'Yaw: ${yaw.toStringAsFixed(2)}',
              ],
              Icons.threed_rotation,
              Colors.orange,
            ),
            
            // Kalman Filtered Orientation
            _buildDataCard(
              '🎯 Filtered Orientation (°)',
              [
                'Roll: ${filteredRoll.toStringAsFixed(2)}',
                'Pitch: ${filteredPitch.toStringAsFixed(2)}',
                'Yaw: ${filteredYaw.toStringAsFixed(2)}',
              ],
              Icons.filter_center_focus,
              Colors.purple,
            ),
            
            // Gyroscope Bias (from Kalman filter)
            _buildDataCard(
              'Gyro Bias Correction (°/s)',
              [
                'X Bias: ${gyroBiasX.toStringAsFixed(3)}',
                'Y Bias: ${gyroBiasY.toStringAsFixed(3)}',
                'Z Bias: ${gyroBiasZ.toStringAsFixed(3)}',
              ],
              Icons.tune,
              Colors.teal,
            ),
            
            // Temperature
            _buildDataCard(
              'Temperature',
              ['${temperature.toStringAsFixed(1)}°C'],
              Icons.thermostat,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, List<String> values, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...values.map((value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAttitudeIndicator(String label, double roll, double pitch, double yaw, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
              ),
              child: CustomPaint(
                painter: AirplanePainter(
                  roll: roll,
                  pitch: pitch,
                  yaw: yaw,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'R: ${roll.toStringAsFixed(0)}° P: ${pitch.toStringAsFixed(0)}° Y: ${yaw.toStringAsFixed(0)}°',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for drawing the airplane attitude indicator
class AirplanePainter extends CustomPainter {
  final double roll;
  final double pitch;
  final double yaw;
  final Color color;

  AirplanePainter({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Save canvas state
    canvas.save();
    
    // Move to center
    canvas.translate(center.dx, center.dy);
    
    // Draw horizon line (rotated by roll angle)
    canvas.save();
    canvas.rotate(roll * 3.14159 / 180);
    
    // Draw horizon line shifted by pitch
    final horizonY = pitch * 1.0; // Scale pitch for visibility in smaller view
    final horizonPaint = Paint()
      ..color = Colors.brown.shade300
      ..strokeWidth = 1.5;
    
    canvas.drawLine(
      Offset(-size.width, horizonY),
      Offset(size.width, horizonY),
      horizonPaint,
    );
    
    // Draw sky (above horizon)
    final skyPaint = Paint()
      ..color = Colors.blue.shade100.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(-size.width, -size.height, size.width * 2, size.height + horizonY),
      skyPaint,
    );
    
    // Draw ground (below horizon)
    final groundPaint = Paint()
      ..color = Colors.brown.shade100.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(-size.width, horizonY, size.width * 2, size.height),
      groundPaint,
    );
    
    canvas.restore();
    
    // Draw airplane symbol (rotates with yaw to show heading)
    // Scaled down to fit 100x100 container
    canvas.save();
    canvas.rotate(yaw * 3.14159 / 180); // Rotate airplane by yaw angle
    
    // Draw fuselage (body)
    canvas.drawLine(
      Offset(0, -12),
      Offset(0, 12),
      paint,
    );
    
    // Draw wings
    canvas.drawLine(
      Offset(-25, 0),
      Offset(25, 0),
      paint,
    );
    
    // Draw wing tips (triangles)
    final wingPath = Path();
    wingPath.moveTo(-25, 0);
    wingPath.lineTo(-32, 3);
    wingPath.lineTo(-32, -3);
    wingPath.close();
    canvas.drawPath(wingPath, fillPaint);
    
    final rightWingPath = Path();
    rightWingPath.moveTo(25, 0);
    rightWingPath.lineTo(32, 3);
    rightWingPath.lineTo(32, -3);
    rightWingPath.close();
    canvas.drawPath(rightWingPath, fillPaint);
    
    // Draw tail
    canvas.drawLine(
      Offset(0, 12),
      Offset(-6, 18),
      paint,
    );
    canvas.drawLine(
      Offset(0, 12),
      Offset(6, 18),
      paint,
    );
    
    // Draw vertical stabilizer
    canvas.drawLine(
      Offset(0, 12),
      Offset(0, 20),
      paint,
    );
    
    // Draw nose indicator
    canvas.drawCircle(Offset(0, -12), 3, fillPaint);
    
    // Restore canvas for airplane rotation
    canvas.restore();
    
    // Restore canvas for main transform
    canvas.restore();
  }

  @override
  bool shouldRepaint(AirplanePainter oldDelegate) {
    return oldDelegate.roll != roll || 
           oldDelegate.pitch != pitch || 
           oldDelegate.yaw != yaw || 
           oldDelegate.color != color;
  }
}