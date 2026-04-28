import '../routing/device_profiler.dart';

class EnergyEstimator {
  static final EnergyEstimator instance = EnergyEstimator._internal();
  EnergyEstimator._internal();

  /// Estimates energy consumption in Joules based on duration and device tier.
  /// PowerAPI labels: budget: 0.8W, mid: 0.6W, flagship: 0.45W
  Future<double> estimateJoules(int durationMs) async {
    final tier = await DeviceProfiler.instance.getDeviceTier();
    double wattage;
    switch (tier) {
      case DeviceTier.budget:
        wattage = 0.8;
        break;
      case DeviceTier.mid:
        wattage = 0.6;
        break;
      case DeviceTier.flagship:
        wattage = 0.45;
        break;
    }

    // Joules = Watts * Seconds
    return wattage * (durationMs / 1000.0);
  }
}
