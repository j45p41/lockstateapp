/// Utility functions for battery-related calculations
class BatteryUtils {
  /// Converts raw battery voltage to percentage based on calibration
  ///
  /// Battery calibration based on experimental discharge curve:
  /// - 100% for voltages >= 4000
  /// - 90% for voltages >= 3800 (stable operating range)
  /// - Linear scale from 3800 to 3400 (400 point range)
  /// - 0% for voltages <= 3400
  ///
  /// @param rawBatVolts The raw battery voltage value from the device
  /// @return The calculated battery percentage (0-100)
  static int calculateBatteryPercentage(int rawBatVolts) {
    if (rawBatVolts >= 4000) {
      return 100;
    } else if (rawBatVolts >= 3800) {
      return 90;
    } else if (rawBatVolts <= 3400) {
      return 0;
    } else {
      // Linear scale from 3800 to 3400 (400 point range)
      final range = 3800 - 3400; // 400
      final currentRange = rawBatVolts - 3400;
      return ((currentRange / range) * 90).round();
    }
  }

  /// Gets the appropriate battery icon based on battery percentage
  ///
  /// @param batteryPercentage The battery percentage (0-100)
  /// @return The battery icon name
  static String getBatteryIcon(int batteryPercentage) {
    if (batteryPercentage > 90) {
      return 'battery_full_rounded';
    } else if (batteryPercentage > 75) {
      return 'battery_5_bar_rounded';
    } else {
      return 'battery_alert_rounded';
    }
  }

  /// Gets the appropriate battery color based on battery percentage
  ///
  /// @param batteryPercentage The battery percentage (0-100)
  /// @return The battery color
  static String getBatteryColor(int batteryPercentage) {
    if (batteryPercentage > 75) {
      return 'greenAccent[400]';
    } else {
      return 'amber';
    }
  }
}
