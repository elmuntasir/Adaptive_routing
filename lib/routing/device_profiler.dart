import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Device tier for wattage priors in the CSE451 client-side energy model.
/// Budget Android devices are central to the paper's fairness argument.
enum DeviceTier { budget, mid, flagship }

class DeviceProfiler {
  static final DeviceProfiler instance = DeviceProfiler._internal();
  DeviceProfiler._internal();

  DeviceTier? _cachedTier;

  /// Called once at startup; result is cached for the session.
  Future<void> init() async {
    await getDeviceTier();
  }

  Future<String> getDeviceSignature() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return '${info.brand} ${info.model} (${info.hardware}, ${(info.physicalRamSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB RAM)';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return 'iPhone ${info.utsname.machine}';
    }
    return 'Generic Device';
  }

  Future<DeviceTier> getDeviceTier() async {
    if (_cachedTier != null) return _cachedTier!;

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      final ramMb = androidInfo.physicalRamSize;
      
      if (ramMb <= 0) {
        _cachedTier = DeviceTier.mid;
      } else {
        final totalRamGb = ramMb / (1024.0 * 1024.0 * 1024.0);
        if (totalRamGb < 4) {
          _cachedTier = DeviceTier.budget;
        } else if (totalRamGb <= 8) {
          _cachedTier = DeviceTier.mid;
        } else {
          _cachedTier = DeviceTier.flagship;
        }
      }
    } else if (Platform.isIOS) {
      _cachedTier = DeviceTier.flagship; // Assume high-end for iOS generally
    } else {
      _cachedTier = DeviceTier.mid;
    }

    return _cachedTier!;
  }
}
