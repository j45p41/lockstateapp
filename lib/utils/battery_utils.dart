/// Utility functions for battery-related calculations
class BatteryUtils {
  /// Converts raw battery voltage to percentage based on calibration
  ///
  /// Battery calibration: 90% above 3800, 80% above 3750, then linear down to 0% at 3400
  ///
  /// @param rawBatVolts The raw battery voltage value from the device
  /// @return The calculated battery percentage (0-90)
  static int calculateBatteryPercentage(int rawBatVolts) {
    if (rawBatVolts >= 3800) {
      return 90;
    } else if (rawBatVolts >= 3750) {
      return 80;
    } else if (rawBatVolts <= 3400) {
      return 0;
    } else {
      // Linear scale from 3750 to 3400 (350 point range)
      final range = 3750 - 3400; // 350
      final currentRange = rawBatVolts - 3400;
      return ((currentRange / range) * 80).round();
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
