import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'kalman_filter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Witmotion IMU with Kalman Filter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const IMUSimulatorPage(),
    );
  }
}

class IMUSimulatorPage extends StatefulWidget {
  const IMUSimulatorPage({super.key});

  @override
  State<IMUSimulatorPage> createState() => _IMUSimulatorPageState();
}

class _IMUSimulatorPageState extends State<IMUSimulatorPage> {
  // Raw simulated IMU data
  double accelX = 0, accelY = 0, accelZ = 0;
  double gyroX = 0, gyroY = 0, gyroZ = 0;
  double magX = 0, magY = 0, magZ = 0;
  double rawRoll = 0, rawPitch = 0, rawYaw = 0;
  double temperature = 23.5;

  // Filtered IMU data (from Kalman filter)
  double filteredRoll = 0, filteredPitch = 0, filteredYaw = 0;
  double gyroBiasX = 0, gyroBiasY = 0, gyroBiasZ = 0;

  // Kalman filter instance
  final KalmanFilter kalmanFilter = KalmanFilter();
  Timer? simulationTimer;
  int sampleCount = 0;
  
  // Simulation parameters
  double time = 0;
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
  }

  void _startSimulation() {
    if (isRunning) return;
    
    setState(() {
      isRunning = true;
      time = 0;
      sampleCount = 0;
    });

    // Simulate IMU data at 100Hz
    simulationTimer = Timer.periodic(Duration(milliseconds: 10), (timer) {
      time += 0.01;
      sampleCount++;
      
      _simulateIMUData();
      _updateKalmanFilter();
    });
  }

  void _stopSimulation() {
    simulationTimer?.cancel();
    setState(() {
      isRunning = false;
    });
  }

  void _simulateIMUData() {
    // Simulate realistic IMU data with noise
    // True motion: slow oscillations in roll and pitch
    double trueRoll = 15 * math.sin(time * 0.5) * (math.pi / 180);
    double truePitch = 10 * math.cos(time * 0.3) * (math.pi / 180);
    double trueYaw = 0.0; // Keep yaw stable for this demo

    // Add gyroscope bias (drift)
    double gyroBiasSimX = 0.02 * (math.pi / 180); // 0.02 deg/s bias
    double gyroBiasSimY = -0.015 * (math.pi / 180);
    double gyroBiasSimZ = 0.01 * (math.pi / 180);

    // True angular velocities (derivatives of true angles)
    double trueGyroX = 15 * 0.5 * math.cos(time * 0.5) * (math.pi / 180);
    double trueGyroY = -10 * 0.3 * math.sin(time * 0.3) * (math.pi / 180);
    double trueGyroZ = 0.0;

    // Add noise and bias to gyroscope
    gyroX = trueGyroX + gyroBiasSimX + _gaussianNoise(0.01);
    gyroY = trueGyroY + gyroBiasSimY + _gaussianNoise(0.01);
    gyroZ = trueGyroZ + gyroBiasSimZ + _gaussianNoise(0.01);

    // Simulate accelerometer (with gravity and noise)
    accelX = -math.sin(truePitch) + _gaussianNoise(0.05);
    accelY = math.sin(trueRoll) * math.cos(truePitch) + _gaussianNoise(0.05);
    accelZ = math.cos(trueRoll) * math.cos(truePitch) + _gaussianNoise(0.05);

    // Simulate magnetometer (simplified, pointing north with noise)
    magX = math.cos(trueYaw) * 100 + _gaussianNoise(5);
    magY = math.sin(trueYaw) * 100 + _gaussianNoise(5);
    magZ = math.sin(truePitch) * 50 + _gaussianNoise(3);

    // Calculate raw angles from accelerometer (noisy)
    rawRoll = math.atan2(accelY, math.sqrt(accelX * accelX + accelZ * accelZ)) * (180 / math.pi);
    rawPitch = math.atan2(-accelX, math.sqrt(accelY * accelY + accelZ * accelZ)) * (180 / math.pi);
    rawYaw = math.atan2(-magY, magX) * (180 / math.pi);

    setState(() {
      // Update temperature with small variation
      temperature = 23.5 + 2 * math.sin(time * 0.1);
    });
  }

  void _updateKalmanFilter() {
    // Set appropriate time step
    kalmanFilter.dt = 0.01; // 100Hz

    // Predict step with gyroscope data
    kalmanFilter.predict(gyroX, gyroY, gyroZ);

    // Update step with accelerometer and magnetometer data
    kalmanFilter.update(accelX, accelY, accelZ, magX, magY, magZ);

    // Get filtered values
    filteredRoll = kalmanFilter.roll;
    filteredPitch = kalmanFilter.pitch;
    filteredYaw = kalmanFilter.yaw;
    gyroBiasX = kalmanFilter.gyroBiasX * (180/math.pi);
    gyroBiasY = kalmanFilter.gyroBiasY * (180/math.pi);
    gyroBiasZ = kalmanFilter.gyroBiasZ * (180/math.pi);
  }

  double _gaussianNoise(double stdDev) {
    // Box-Muller transform for Gaussian noise
    static double? spare;
    if (spare != null) {
      double result = spare! * stdDev;
      spare = null;
      return result;
    }
    
    double u = math.Random().nextDouble();
    double v = math.Random().nextDouble();
    double mag = stdDev * math.sqrt(-2.0 * math.log(u));
    spare = mag * math.cos(2.0 * math.pi * v);
    return mag * math.sin(2.0 * math.pi * v);
  }

  @override
  void dispose() {
    simulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎯 Kalman Filter IMU Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
            onPressed: isRunning ? _stopSimulation : _startSimulation,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Control Panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRunning ? Icons.sensors : Icons.sensors_off,
                          color: isRunning ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRunning ? 'Simulation Running' : 'Simulation Stopped',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Spacer(),
                        Text('Samples: $sampleCount'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This demo simulates noisy IMU data and shows how the Kalman filter provides smooth, accurate orientation estimates',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Raw Sensor Data
            _buildDataCard(
              '📊 Accelerometer (g)',
              [
                'X: ${accelX.toStringAsFixed(3)}',
                'Y: ${accelY.toStringAsFixed(3)}',
                'Z: ${accelZ.toStringAsFixed(3)}',
              ],
              Icons.speed,
              Colors.red,
            ),

            _buildDataCard(
              '🌀 Gyroscope (rad/s)',
              [
                'X: ${gyroX.toStringAsFixed(4)}',
                'Y: ${gyroY.toStringAsFixed(4)}',
                'Z: ${gyroZ.toStringAsFixed(4)}',
              ],
              Icons.rotate_right,
              Colors.blue,
            ),

            _buildDataCard(
              '🧭 Magnetometer',
              [
                'X: ${magX.toStringAsFixed(1)}',
                'Y: ${magY.toStringAsFixed(1)}',
                'Z: ${magZ.toStringAsFixed(1)}',
              ],
              Icons.explore,
              Colors.green,
            ),
            
            // Raw vs Filtered Comparison
            _buildComparisonCard(
              '📐 Raw vs Filtered Orientation (°)',
              [
                'Roll: ${rawRoll.toStringAsFixed(1)} → ${filteredRoll.toStringAsFixed(1)}',
                'Pitch: ${rawPitch.toStringAsFixed(1)} → ${filteredPitch.toStringAsFixed(1)}',
                'Yaw: ${rawYaw.toStringAsFixed(1)} → ${filteredYaw.toStringAsFixed(1)}',
              ],
              Icons.compare_arrows,
              Colors.orange,
            ),
            
            // Kalman Filter Outputs
            _buildDataCard(
              '🎯 Kalman Filter Bias Estimates (°/s)',
              [
                'X Bias: ${gyroBiasX.toStringAsFixed(3)}',
                'Y Bias: ${gyroBiasY.toStringAsFixed(3)}',
                'Z Bias: ${gyroBiasZ.toStringAsFixed(3)}',
              ],
              Icons.tune,
              Colors.purple,
            ),

            _buildDataCard(
              '🌡️ Temperature',
              ['${temperature.toStringAsFixed(1)}°C'],
              Icons.thermostat,
              Colors.teal,
            ),
            
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔗 Connect to Real Witmotion IMU:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Turn on your WT9011DCL IMU\n'
                      '2. Replace this demo with the Bluetooth scanner\n'
                      '3. Look for device named "Witmotion" or similar\n'
                      '4. The Kalman filter will provide smooth, drift-free orientation!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
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

  Widget _buildComparisonCard(String title, List<String> values, IconData icon, Color color) {
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
            const SizedBox(height: 8),
            Text(
              'Noisy → Filtered',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
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
}