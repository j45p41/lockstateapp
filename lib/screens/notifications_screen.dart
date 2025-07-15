import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/history.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;
import 'package:fl_chart/fl_chart.dart';

class WeekData {
  final DateTime startDate;
  final DateTime endDate;
  Duration duration = Duration.zero;

  WeekData({
    required this.startDate,
    required this.endDate,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  dynamic rssi;
  dynamic historyItemPrevious;
  int doorReport = 0;
  bool doorSignalMissed = false;

  @override
  Widget build(BuildContext context) {
    print("user id ${FirebaseAuth.instance.currentUser!.uid}");
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 43, 43, 43),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 43, 43, 43),
        title: const Text(
          'History',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(ColorUtils.colorWhite),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            width: 140,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(5)),
            child: Image.asset(
              "assets/images/logo.png",
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10)
        ],
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .orderBy('received_at', descending: true)
              .where("userId",
                  isEqualTo: FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text("No notifications", style: TextStyle()),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var length = snapshot.data!.docs.length;
            var data = snapshot.data!.docs;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    itemCount: length,
                    itemBuilder: (context, index) {
                      var historyItem =
                          historyFromJson(json.encode(data[index].data()));

                      // Ensure historyItemPrevious is not null before accessing it
                      if (length == index + 1) {
                        historyItemPrevious = historyItem;
                      } else {
                        for (int j = 1; j < length - index; j += 1) {
                          var nextHistoryItem = historyFromJson(
                              json.encode(data[index + j].data()));

// if(historyItemPrevious.message.uplinkMessage.decodedPayload.lockState < 2)

                          if (historyItem.roomId == nextHistoryItem.roomId
                              // &&
                              // historyItemPrevious.message.uplinkMessage.decodedPayload.lockState < 2

                              ) {
                            historyItemPrevious = nextHistoryItem;

                            // Handle RSSI
                            if (historyItem.radioPowerLevel < -500) {
                              rssi = ' [${historyItem.radioPowerLevel + 500}R]';
                            } else if (!globals.showSignalStrength) {
                              rssi = "";
                            } else {
                              rssi = ' [${historyItem.radioPowerLevel}]';
                            }

                            // Implement entry/exit logic
                            if (historyItem.isIndoor == true &&
                                historyItemPrevious.isIndoor == false) {
                              doorReport = 1; // Entry
                            } else if (historyItem.isIndoor == false &&
                                historyItemPrevious.isIndoor == true) {
                              doorReport = 2; // Exit
                            }

                            // Check if signal has been repeated
                            if (historyItem.message.uplinkMessage.decodedPayload
                                    .lockState ==
                                historyItemPrevious.message.uplinkMessage
                                    .decodedPayload.lockState) {
                              doorSignalMissed = true;
                            }

                            break;
                          }
                        }
                      }

                      // Check if historyItemPrevious is null
                      if (historyItemPrevious == null) {
                        return const SizedBox
                            .shrink(); // Skip this item if null
                      }

                      // Battery calibration: 90% above 3800, 80% above 3750, then linear down to 0% at 3400
                      var batVolts;
                      final rawBatVolts = historyItem
                          .message.uplinkMessage.decodedPayload.batVolts;
                      if (rawBatVolts >= 3800) {
                        batVolts = 90;
                      } else if (rawBatVolts >= 3750) {
                        batVolts = 80;
                      } else if (rawBatVolts <= 3400) {
                        batVolts = 0;
                      } else {
                        // Linear scale from 3750 to 3400 (350 point range)
                        final range = 3750 - 3400; // 350
                        final currentRange = rawBatVolts - 3400;
                        batVolts = ((currentRange / range) * 80).round();
                      }

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.grey,
                              offset: Offset(4.0, 10.0), //(x,y)
                              blurRadius: 8.0,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        margin: EdgeInsets.only(
                            top: (index == 0
                                ? 15
                                : index % 2 == 1
                                    ? 15
                                    : 50)),
                        child: Row(
                          children: [
                            // First column (Lock State)
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(historyItem.message.uplinkMessage
                                              .decodedPayload.lockState ==
                                          0
                                      ? ColorUtils.colorGrey
                                      : historyItem.message.uplinkMessage.decodedPayload.lockState ==
                                                  2 &&
                                              globals.lightSetting == 1
                                          ? ColorUtils.colorRed
                                          : historyItem
                                                          .message
                                                          .uplinkMessage
                                                          .decodedPayload
                                                          .lockState ==
                                                      1 &&
                                                  globals.lightSetting == 1
                                              ? ColorUtils.colorGreen
                                              : historyItem
                                                              .message
                                                              .uplinkMessage
                                                              .decodedPayload
                                                              .lockState ==
                                                          2 &&
                                                      globals.lightSetting == 2
                                                  ? ColorUtils.colorAmber
                                                  : historyItem
                                                                  .message
                                                                  .uplinkMessage
                                                                  .decodedPayload
                                                                  .lockState ==
                                                              1 &&
                                                          globals.lightSetting == 3
                                                      ? ColorUtils.colorCyan
                                                      : historyItem.message.uplinkMessage.decodedPayload.lockState == 2 && globals.lightSetting == 3
                                                          ? ColorUtils.colorAmber
                                                          : historyItem.message.uplinkMessage.decodedPayload.lockState == 1 && globals.lightSetting == 2
                                                              ? ColorUtils.colorBlue
                                                              : historyItem.message.uplinkMessage.decodedPayload.lockState == 3
                                                                  ? ColorUtils.colorRed
                                                                  : ColorUtils.colorGreen),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                                height: 62,
                                child: Center(
                                  child: Text(
                                    historyItem.message.uplinkMessage
                                                .decodedPayload.lockState ==
                                            0
                                        ? "Not Set"
                                        : historyItem.message.uplinkMessage
                                                    .decodedPayload.lockState ==
                                                2
                                            ? "Unlocked"
                                            : historyItem
                                                        .message
                                                        .uplinkMessage
                                                        .decodedPayload
                                                        .lockState ==
                                                    1
                                                ? doorReport == 1
                                                    ? "Locked\n[ENTRY]"
                                                    : doorReport == 2
                                                        ? "Locked\n  [EXIT]"
                                                        : "Locked"
                                                : historyItem
                                                            .message
                                                            .uplinkMessage
                                                            .decodedPayload
                                                            .lockState ==
                                                        3
                                                    ? "Opened"
                                                    : "Closed",
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Second column (Date, Time & RSSI)
                            Expanded(
                              flex: 4,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7.2),
                                  color: const Color.fromARGB(255, 64, 64, 64),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // First row: Time
                                      Text(
                                        historyItem.message.receivedAt
                                            .toLocal()
                                            .toString()
                                            .split(' ')[1]
                                            .substring(0, 8), // Get HH:MM:SS
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // SizedBox(height: 1.0),
                                      // Second row: Date
                                      Text(
                                        historyItem.message.receivedAt
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0]
                                            .replaceFirst(
                                                '2024-', ''), // Get YYYY-MM-DD
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // Third row: RSSI
                                      if (rssi != null && rssi != "") ...[
                                        const SizedBox(height: 1.0),
                                        Text(
                                          rssi.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Third column (Device name & Battery)
                            Expanded(
                              flex: 6,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // First row: Device name with Battery
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          historyItem.deviceName,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Icon(
                                        batVolts > 90
                                            ? Icons.battery_full_rounded
                                            : batVolts > 75
                                                ? Icons.battery_5_bar_rounded
                                                : Icons.battery_alert_rounded,
                                        size: 18,
                                        color: batVolts > 75
                                            ? Colors.greenAccent[400]
                                            : Colors.amber,
                                      ),
                                      if (globals.showBatteryPercentage)
                                        Text(
                                          ' $batVolts%',
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // Second row: Duration with icon
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.lock_clock,
                                        size: 18,
                                        color:
                                            Color.fromARGB(255, 205, 176, 13),
                                      ),
                                      Text(
                                        _formatDuration(historyItem
                                            .message.receivedAt
                                            .difference(historyItemPrevious
                                                .message.receivedAt)),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Third row: Suffix only
                                  if (historyItem.deviceName.length > 15)
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final suffix = _getTimeSuffix(
                                            historyItemPrevious
                                                .message
                                                .uplinkMessage
                                                .decodedPayload
                                                .lockState);

                                        final textPainter = TextPainter(
                                          text: TextSpan(
                                            text: suffix,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          maxLines: 1,
                                          textDirection: TextDirection.ltr,
                                        )..layout();

                                        if (textPainter.width <=
                                            constraints.maxWidth - 40) {
                                          return Text(
                                            suffix,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    )
                                  else
                                    Text(
                                      _getTimeSuffix(historyItemPrevious
                                          .message
                                          .uplinkMessage
                                          .decodedPayload
                                          .lockState),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(5),
                    child: Builder(
                      builder: (context) {
                        // Create list of week data
                        List<WeekData> weeks = [
                          WeekData(
                            startDate: DateTime.now()
                                .subtract(const Duration(days: 28)),
                            endDate: DateTime.now()
                                .subtract(const Duration(days: 21)),
                          ),
                          WeekData(
                            startDate: DateTime.now()
                                .subtract(const Duration(days: 21)),
                            endDate: DateTime.now()
                                .subtract(const Duration(days: 14)),
                          ),
                          WeekData(
                            startDate: DateTime.now()
                                .subtract(const Duration(days: 14)),
                            endDate: DateTime.now()
                                .subtract(const Duration(days: 7)),
                          ),
                          WeekData(
                            startDate: DateTime.now()
                                .subtract(const Duration(days: 7)),
                            endDate: DateTime.now(),
                          ),
                        ];

                        // Calculate durations and filter out weeks with no data
                        List<WeekData> weeksWithData = weeks.where((week) {
                          week.duration = _calculateDuration(
                              data, 2, week.startDate, week.endDate);
                          return week.duration.inSeconds > 0;
                        }).toList();

                        if (weeksWithData.isEmpty) {
                          return const SizedBox
                              .shrink(); // Hide entire container if no data
                        }

                        return Row(
                          children: [
                            // Rotated "Unlocked Statistics" label
                            Container(
                              width: 50,
                              height: 80,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Color(ColorUtils.colorAmber),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const RotatedBox(
                                quarterTurns:
                                    3, // Rotate 90 degrees counter-clockwise
                                child: Center(
                                  child: Text(
                                    'Unlocked by Week',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Statistics boxes container
                            Expanded(
                              child: Container(
                                height: 100,
                                padding: const EdgeInsets.all(5),
                                child: Builder(
                                  builder: (context) {
                                    final now = DateTime.now();
                                    // Define the four week periods
                                    final weekPeriods = [
                                      // // 21-28 days ago
                                      // WeekData(
                                      //   startDate: now.subtract(const Duration(days: 28)),
                                      //   endDate: now.subtract(const Duration(days: 21)),
                                      // ),
                                      // 14-21 days ago
                                      WeekData(
                                        startDate: now
                                            .subtract(const Duration(days: 21)),
                                        endDate: now
                                            .subtract(const Duration(days: 14)),
                                      ),
                                      // 7-14 days ago
                                      WeekData(
                                        startDate: now
                                            .subtract(const Duration(days: 14)),
                                        endDate: now
                                            .subtract(const Duration(days: 7)),
                                      ),
                                      // Current 7 days
                                      WeekData(
                                        startDate: now
                                            .subtract(const Duration(days: 7)),
                                        endDate: now,
                                      ),
                                    ];

                                    // Calculate durations and filter out periods with no data
                                    List<WeekData> periodsWithData = [];

                                    for (var period in weekPeriods) {
                                      Duration duration = Duration.zero;

                                      // Calculate total duration for unlocked state (state 2) in this period
                                      for (int i = 0;
                                          i < data.length - 1;
                                          i++) {
                                        var currentItem = historyFromJson(
                                            json.encode(data[i].data()));
                                        var nextItem = historyFromJson(
                                            json.encode(data[i + 1].data()));

                                        // Skip if event is outside our period
                                        if (nextItem.message.receivedAt
                                            .isBefore(period.startDate)) {
                                          break;
                                        }
                                        if (currentItem.message.receivedAt
                                            .isAfter(period.endDate)) {
                                          continue;
                                        }

                                        // Add duration if state is unlocked (2)
                                        if (nextItem.message.uplinkMessage
                                                .decodedPayload.lockState ==
                                            2) {
                                          var eventStart =
                                              nextItem.message.receivedAt;
                                          var eventEnd =
                                              currentItem.message.receivedAt;

                                          // Clip duration to period boundaries
                                          if (eventStart
                                              .isBefore(period.startDate)) {
                                            eventStart = period.startDate;
                                          }
                                          if (eventEnd
                                              .isAfter(period.endDate)) {
                                            eventEnd = period.endDate;
                                          }

                                          duration +=
                                              eventEnd.difference(eventStart);
                                        }
                                      }

                                      if (duration.inSeconds > 0) {
                                        period.duration = duration;
                                        periodsWithData.add(period);
                                      }
                                    }

                                    if (periodsWithData.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Row(
                                      children: [
                                        for (int i = 0;
                                            i < periodsWithData.length;
                                            i++) ...[
                                          if (i > 0) const SizedBox(width: 5),
                                          Expanded(
                                            child: _buildWeekDurationSummary(
                                              data,
                                              2,
                                              "Unlocked",
                                              ColorUtils.colorAmber,
                                              startDate:
                                                  periodsWithData[i].startDate,
                                              endDate:
                                                  periodsWithData[i].endDate,
                                              duration:
                                                  periodsWithData[i].duration,
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }

  String _formatTimeDifference(DateTime current, DateTime previous,
      History currentItem, History previousItem) {
    Duration difference = current.difference(previous);

    int totalMinutes = difference.inMinutes;
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    int seconds = difference.inSeconds % 60;

    List<String> parts = [];

    if (totalMinutes >= 60) {
      parts.add('${hours}h');
      parts.add('${minutes}m');
    } else if (minutes > 0) {
      parts.add('${minutes}m');
    }

    if (seconds > 0 || parts.isEmpty) {
      parts.add('${seconds}s');
    }

    // Add state suffix based on previous item's state
    String timePart = parts.join(' ');
    int previousState =
        previousItem.message.uplinkMessage.decodedPayload.lockState;

    switch (previousState) {
      case 1:
        return '$timePart since locked';
      case 2:
        return '$timePart since unlocked';
      case 3:
        return '$timePart since opened';
      default:
        return timePart;
    }
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _getTimeSuffix(int lockState) {
    switch (lockState) {
      case 1:
        return 'since locked';
      case 2:
        return 'since unlocked';
      case 3:
        return 'since opened';
      default:
        return '';
    }
  }

  Widget _buildWeekDurationSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> data,
    int stateType,
    String label,
    int color, {
    required DateTime startDate,
    required DateTime endDate,
    required Duration duration,
  }) {
    // Calculate previous period duration
    DateTime previousStart = startDate.subtract(endDate.difference(startDate));
    DateTime previousEnd = startDate;
    Duration previousDuration =
        _calculateDuration(data, stateType, previousStart, previousEnd);

    // Determine if current duration is higher or lower than previous period
    bool isIncreased = duration.inMinutes > previousDuration.inMinutes;
    double percentChange = previousDuration.inMinutes > 0
        ? ((duration.inMinutes - previousDuration.inMinutes) /
                previousDuration.inMinutes *
                100)
            .abs()
        : 0;

    // Check if this is the earliest period (28-21 days ago)
    bool isEarliestPeriod =
        startDate.difference(DateTime.now()).inDays.abs() > 21;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        border: Border.all(color: Color(color).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _formatTotalDuration(duration),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (previousDuration.inMinutes > 0 && !isEarliestPeriod) ...[
                const SizedBox(width: 4),
                Icon(
                  isIncreased ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: isIncreased ? Colors.red : Colors.green,
                ),
                Text(
                  '${percentChange.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: isIncreased ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateRange(startDate, endDate),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatTotalDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = (duration.inMinutes % 60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatDateRange(DateTime start, DateTime end) {
    String startDate = "${start.day}/${start.month}";
    String endDate = "${end.day}/${end.month}";
    return "$startDate-$endDate";
  }

  void _showDistributionDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> data,
    int stateType,
    String label,
    int color,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Initialize hourly durations map (0-23 hours)
    Map<int, Duration> hourlyDurations = Map.fromIterable(
      List.generate(24, (i) => i),
      key: (i) => i,
      value: (_) => Duration.zero,
    );

    // Process each unlock-lock pair
    for (int i = 0; i < data.length - 1; i++) {
      var currentItem = historyFromJson(json.encode(data[i].data()));
      var nextItem = historyFromJson(json.encode(data[i + 1].data()));

      // Skip if outside our date range
      if (nextItem.message.receivedAt.isBefore(startDate)) continue;
      if (currentItem.message.receivedAt.isAfter(endDate)) continue;

      // Look for unlock events (state 2)
      if (nextItem.message.uplinkMessage.decodedPayload.lockState == 2) {
        var unlockTime = nextItem.message.receivedAt;
        var lockTime = currentItem.message.receivedAt;

        // Clip times to our date range
        if (unlockTime.isBefore(startDate)) unlockTime = startDate;
        if (lockTime.isAfter(endDate)) lockTime = endDate;

        // Calculate duration for each hour this event spans
        var currentTime = unlockTime;
        while (currentTime.isBefore(lockTime)) {
          final hour = currentTime.hour;

          // Calculate end of current hour or lock time, whichever comes first
          final hourEnd = DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            hour + 1,
          );
          final endTime = lockTime.isBefore(hourEnd) ? lockTime : hourEnd;

          // Add duration to appropriate hour
          final duration = endTime.difference(currentTime);
          hourlyDurations[hour] = hourlyDurations[hour]! + duration;

          // Move to next hour
          currentTime = hourEnd;
        }
      }
    }

    // Convert durations to hours for display
    final hourlyHours = hourlyDurations
        .map((hour, duration) => MapEntry(hour, duration.inMinutes / 60.0));

    // Filter out hours with no data
    final activeHours = hourlyHours.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList()
      ..sort();

    if (activeHours.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unlocked events in this period')),
      );
      return;
    }

    // Find the maximum duration in minutes
    final maxMinutes = hourlyDurations.values
        .map((duration) => duration.inMinutes)
        .reduce(max)
        .toDouble();

    // Calculate appropriate Y-axis scale
    final yAxisMax = _calculateYAxisMax(maxMinutes);
    final yAxisInterval = _calculateYAxisInterval(yAxisMax);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text(
                'Unlocked Time Distribution\n${_formatDateRange(startDate, endDate)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: yAxisMax,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.grey[800]!,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final hour = activeHours[groupIndex];
                          final duration = hourlyDurations[hour]!;
                          return BarTooltipItem(
                            '${hour.toString().padLeft(2, '0')}:00\n${_formatDuration(duration)}',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final hour = activeHours[value.toInt()];
                            return Text(
                              '${hour.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _formatAxisLabel(value.toInt()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            );
                          },
                          interval: yAxisInterval,
                          reservedSize: 40,
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: yAxisInterval,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[300],
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                        left: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    barGroups: List.generate(
                      activeHours.length,
                      (index) => BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: hourlyDurations[activeHours[index]]!
                                .inMinutes
                                .toDouble(),
                            color: Color(color),
                            width: 16,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hours (24-hour format)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Duration _calculateDuration(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> data,
    int stateType,
    DateTime startDate,
    DateTime endDate,
  ) {
    Duration totalDuration = Duration.zero;

    for (int i = 0; i < data.length - 1; i++) {
      var currentItem = historyFromJson(json.encode(data[i].data()));
      var nextItem = historyFromJson(json.encode(data[i + 1].data()));

      if (nextItem.message.receivedAt.isBefore(startDate)) {
        break;
      }

      if (nextItem.message.receivedAt.isAfter(endDate)) {
        continue;
      }

      if (nextItem.message.uplinkMessage.decodedPayload.lockState ==
          stateType) {
        totalDuration += currentItem.message.receivedAt
            .difference(nextItem.message.receivedAt);
      }
    }

    return totalDuration;
  }

  double _calculateYAxisMax(double maxMinutes) {
    if (maxMinutes <= 60) {
      return ((maxMinutes / 15).ceil() * 15).toDouble();
    } else if (maxMinutes <= 120) {
      return ((maxMinutes / 30).ceil() * 30).toDouble();
    } else {
      return ((maxMinutes / 60).ceil() * 60).toDouble();
    }
  }

  double _calculateYAxisInterval(double yAxisMax) {
    if (yAxisMax <= 60) {
      return 15;
    } else if (yAxisMax <= 120) {
      return 30;
    } else {
      return 60;
    }
  }

  String _formatAxisLabel(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h${remainingMinutes}m';
      }
    }
  }
}
