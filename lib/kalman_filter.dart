import 'dart:math' as math;

class KalmanFilter {
  // State vector: [roll, pitch, yaw, gyro_bias_x, gyro_bias_y, gyro_bias_z]
  late List<double> x; // State vector
  late List<List<double>> P; // Error covariance matrix
  late List<List<double>> Q; // Process noise covariance
  late List<List<double>> R; // Measurement noise covariance
  
  final int stateSize = 6;
  final int measurementSize = 3;  // Roll, pitch, and yaw (yaw from magnetometer)
  
  double dt = 0.01; // Time step (100Hz)
  
  KalmanFilter() {
    _initialize();
  }
  
  void _initialize() {
    // Initialize state vector [roll, pitch, yaw, bias_x, bias_y, bias_z]
    x = List.filled(stateSize, 0.0);
    
    // Initialize error covariance matrix (6x6)
    P = List.generate(stateSize, (i) => List.filled(stateSize, 0.0));
    for (int i = 0; i < stateSize; i++) {
      P[i][i] = i < 3 ? 0.1 : 0.01; // Smaller initial uncertainty for biases
    }
    
    // Process noise covariance (6x6)
    Q = List.generate(stateSize, (i) => List.filled(stateSize, 0.0));
    // Angular rate noise - reduced to trust gyro more
    Q[0][0] = Q[1][1] = Q[2][2] = 0.0003;  // Was 0.001
    // Gyro bias noise  
    Q[3][3] = Q[4][4] = Q[5][5] = 0.00003;  // Was 0.0001
    
    // Measurement noise covariance (3x3) for accelerometer + magnetometer
    R = List.generate(measurementSize, (i) => List.filled(measurementSize, 0.0));
    R[0][0] = R[1][1] = 0.2; // Roll and pitch from accelerometer
    R[2][2] = 0.5; // Yaw from magnetometer (even if currently 0,0,0)
  }
  
  void predict(double gyroX, double gyroY, double gyroZ) {
    // Remove gyroscope bias
    double wx = gyroX - x[3];
    double wy = gyroY - x[4]; 
    double wz = gyroZ - x[5];
    
    // Current angles
    double roll = x[0];
    double pitch = x[1];
    
    // Compute trigonometric values
    double sr = math.sin(roll);
    double cr = math.cos(roll);
    double sp = math.sin(pitch);
    double cp = math.cos(pitch);
    double tp = math.tan(pitch);
    
    // State transition (integrate angular rates)
    List<double> xNew = List.from(x);
    xNew[0] = roll + dt * (wx + wy * sr * tp + wz * cr * tp);
    xNew[1] = pitch + dt * (wy * cr - wz * sr);
    xNew[2] = x[2] + dt * (wy * sr / cp + wz * cr / cp);  // Reverted: gyro direction was correct
    // Biases remain constant in prediction
    xNew[3] = x[3];
    xNew[4] = x[4];
    xNew[5] = x[5];
    
    // State transition matrix F
    List<List<double>> F = List.generate(stateSize, (i) => List.generate(stateSize, (j) => i == j ? 1.0 : 0.0));
    
    // Partial derivatives for F matrix
    F[0][1] = dt * (wy * sr / (cp * cp) + wz * cr / (cp * cp));
    F[0][3] = -dt;
    F[0][4] = -dt * sr * tp;
    F[0][5] = -dt * cr * tp;
    
    F[1][0] = dt * (-wy * sr - wz * cr);
    F[1][4] = -dt * cr;
    F[1][5] = dt * sr;
    
    F[2][0] = dt * (wy * cr / cp - wz * sr / cp);  // Reverted
    F[2][1] = dt * (wy * sr * sp / (cp * cp) + wz * cr * sp / (cp * cp));  // Reverted
    F[2][4] = -dt * sr / cp;
    F[2][5] = -dt * cr / cp;  // Reverted
    
    // Update state
    x = xNew;
    
    // Predict error covariance: P = F*P*F' + Q
    P = _matrixAdd(_matrixMultiply(_matrixMultiply(F, P), _matrixTranspose(F)), Q);
  }
  
  void update(double accelX, double accelY, double accelZ, double magX, double magY, double magZ) {
    // Calculate roll and pitch from accelerometer
    double rollAcc = math.atan2(accelY, math.sqrt(accelX * accelX + accelZ * accelZ));
    double pitchAcc = math.atan2(-accelX, math.sqrt(accelY * accelY + accelZ * accelZ));
    
    // Calculate yaw from magnetometer (even if currently reading 0,0,0)
    // Compensate for tilt using roll and pitch
    double cr = math.cos(rollAcc);
    double sr = math.sin(rollAcc);
    double cp = math.cos(pitchAcc);
    double sp = math.sin(pitchAcc);
    
    double magXComp = magX * cp + magY * sp * sr + magZ * sp * cr;
    double magYComp = magY * cr - magZ * sr;
    double yawMag = math.atan2(-magYComp, magXComp);
    
    // Measurement vector - roll, pitch, yaw from sensors
    List<double> z = [rollAcc, pitchAcc, yawMag];
    
    // Measurement matrix H (3x6) - observe roll, pitch, and yaw
    List<List<double>> H = List.generate(measurementSize, (i) => List.filled(stateSize, 0.0));
    H[0][0] = 1.0; // Roll
    H[1][1] = 1.0; // Pitch  
    H[2][2] = 1.0; // Yaw from magnetometer
    
    // Innovation: y = z - H*x
    List<double> hx = List.filled(measurementSize, 0.0);
    for (int i = 0; i < measurementSize; i++) {
      for (int j = 0; j < stateSize; j++) {
        hx[i] += H[i][j] * x[j];
      }
    }
    
    List<double> y = List.generate(measurementSize, (i) => z[i] - hx[i]);
    
    // Angle wrapping for yaw innovation
    while (y[2] > math.pi) y[2] -= 2 * math.pi;
    while (y[2] < -math.pi) y[2] += 2 * math.pi;
    
    // Innovation covariance: S = H*P*H' + R
    List<List<double>> HPH = _matrixMultiply(_matrixMultiply(H, P), _matrixTranspose(H));
    List<List<double>> S = _matrixAdd(HPH, R);
    
    // Kalman gain: K = P*H'*inv(S)
    List<List<double>> K = _matrixMultiply(_matrixMultiply(P, _matrixTranspose(H)), _matrixInverse(S));
    
    // Update state: x = x + K*y
    for (int i = 0; i < stateSize; i++) {
      for (int j = 0; j < measurementSize; j++) {
        x[i] += K[i][j] * y[j];
      }
    }
    
    // Update error covariance: P = (I - K*H)*P
    List<List<double>> KH = _matrixMultiply(K, H);
    List<List<double>> I = List.generate(stateSize, (i) => List.generate(stateSize, (j) => i == j ? 1.0 : 0.0));
    List<List<double>> IKH = _matrixSubtract(I, KH);
    P = _matrixMultiply(IKH, P);
  }
  
  // Getters for filtered values
  double get roll => x[0] * 180.0 / math.pi;
  double get pitch => x[1] * 180.0 / math.pi;  
  double get yaw => x[2] * 180.0 / math.pi;
  double get gyroBiasX => x[3];
  double get gyroBiasY => x[4];
  double get gyroBiasZ => x[5];
  
  // Matrix operations
  List<List<double>> _matrixMultiply(List<List<double>> A, List<List<double>> B) {
    int rowsA = A.length;
    int colsA = A[0].length;
    int colsB = B[0].length;
    
    List<List<double>> C = List.generate(rowsA, (i) => List.filled(colsB, 0.0));
    
    for (int i = 0; i < rowsA; i++) {
      for (int j = 0; j < colsB; j++) {
        for (int k = 0; k < colsA; k++) {
          C[i][j] += A[i][k] * B[k][j];
        }
      }
    }
    return C;
  }
  
  List<List<double>> _matrixAdd(List<List<double>> A, List<List<double>> B) {
    int rows = A.length;
    int cols = A[0].length;
    
    return List.generate(rows, (i) => 
        List.generate(cols, (j) => A[i][j] + B[i][j]));
  }
  
  List<List<double>> _matrixSubtract(List<List<double>> A, List<List<double>> B) {
    int rows = A.length;
    int cols = A[0].length;
    
    return List.generate(rows, (i) => 
        List.generate(cols, (j) => A[i][j] - B[i][j]));
  }
  
  List<List<double>> _matrixTranspose(List<List<double>> A) {
    int rows = A.length;
    int cols = A[0].length;
    
    return List.generate(cols, (i) => 
        List.generate(rows, (j) => A[j][i]));
  }
  
  List<List<double>> _matrixInverse(List<List<double>> A) {
    // Matrix inverse for 2x2 (roll/pitch) or 3x3 (if mag re-enabled)
    int n = A.length;
    
    if (n == 2) {
      // 2x2 matrix inverse
      double det = A[0][0] * A[1][1] - A[0][1] * A[1][0];
      
      if (det.abs() < 1e-10) {
        // Matrix is singular, return identity matrix
        return List.generate(2, (i) => List.generate(2, (j) => i == j ? 1.0 : 0.0));
      }
      
      List<List<double>> inv = List.generate(2, (i) => List.filled(2, 0.0));
      inv[0][0] = A[1][1] / det;
      inv[0][1] = -A[0][1] / det;
      inv[1][0] = -A[1][0] / det;
      inv[1][1] = A[0][0] / det;
      
      return inv;
    }
    
    // Simple 3x3 matrix inverse for measurement update (if mag re-enabled)
    if (n != 3) {
      throw ArgumentError('Matrix inverse only implemented for 2x2 and 3x3 matrices');
    }
    
    double det = A[0][0] * (A[1][1] * A[2][2] - A[1][2] * A[2][1]) -
                 A[0][1] * (A[1][0] * A[2][2] - A[1][2] * A[2][0]) +
                 A[0][2] * (A[1][0] * A[2][1] - A[1][1] * A[2][0]);
    
    if (det.abs() < 1e-10) {
      // Matrix is singular, return identity matrix
      return List.generate(3, (i) => List.generate(3, (j) => i == j ? 1.0 : 0.0));
    }
    
    List<List<double>> inv = List.generate(3, (i) => List.filled(3, 0.0));
    
    inv[0][0] = (A[1][1] * A[2][2] - A[1][2] * A[2][1]) / det;
    inv[0][1] = (A[0][2] * A[2][1] - A[0][1] * A[2][2]) / det;
    inv[0][2] = (A[0][1] * A[1][2] - A[0][2] * A[1][1]) / det;
    
    inv[1][0] = (A[1][2] * A[2][0] - A[1][0] * A[2][2]) / det;
    inv[1][1] = (A[0][0] * A[2][2] - A[0][2] * A[2][0]) / det;
    inv[1][2] = (A[0][2] * A[1][0] - A[0][0] * A[1][2]) / det;
    
    inv[2][0] = (A[1][0] * A[2][1] - A[1][1] * A[2][0]) / det;
    inv[2][1] = (A[0][1] * A[2][0] - A[0][0] * A[2][1]) / det;
    inv[2][2] = (A[0][0] * A[1][1] - A[0][1] * A[1][0]) / det;
    
    return inv;
  }
}