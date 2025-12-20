import 'package:flutter/material.dart';

class ReminderModel {
  final String id;
  String time;
  int amount;
  String status; // 'Selesai', 'Terlewat', 'Nanti'
  String icon;
  String? intakeId;

  ReminderModel({
    required this.id,
    required this.time,
    required this.amount,
    this.status = 'Nanti',
    this.icon = 'Cup_Filled.svg',
    this.intakeId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'amount': amount,
    'status': status,
    'icon': icon,
    'intakeId': intakeId,
  };

  factory ReminderModel.fromJson(Map<String, dynamic> json) => ReminderModel(
    id: json['id'],
    time: json['time'],
    amount: json['amount'],
    status: json['status'],
    icon: json['icon'],
    intakeId: json['intakeId'],
  );
}

class ReminderService {
  static const int minReminders = 8;
  static const int minAmount = 50;
  static const int maxAmount = 1000;

  /// Generates initial list of reminders
  List<ReminderModel> generateReminders(int dailyGoal, int currentWater, TimeOfDay wakeTime, TimeOfDay sleepTime, {int? intervalMinutes}) {
    List<ReminderModel> reminders = [];
    
    // Calculate total minutes available
    int wakeMinutes = wakeTime.hour * 60 + wakeTime.minute;
    int sleepMinutes = sleepTime.hour * 60 + sleepTime.minute;
    
    if (sleepMinutes <= wakeMinutes) {
      sleepMinutes += 24 * 60; // Assume next day
    }
    
    int totalMinutes = sleepMinutes - wakeMinutes;
    
    int count;
    int actualInterval;

    if (intervalMinutes != null) {
      // Manual interval logic
      count = (totalMinutes ~/ intervalMinutes) + 1;
      
      // Minimum 8 reminders enforcement
      if (count < minReminders) {
        count = minReminders;
        actualInterval = totalMinutes ~/ (count - 1);
      } else {
        actualInterval = intervalMinutes;
      }
    } else {
      // Auto logic
      count = minReminders;
      actualInterval = totalMinutes ~/ (count - 1);
    }
    
    int remainingGoal = dailyGoal - currentWater;
    if (remainingGoal < 0) remainingGoal = 0;

    int baseAmount = remainingGoal ~/ count;
    int remainder = remainingGoal % count;

    for (int i = 0; i < count; i++) {
      int currentTotalMinutes = wakeMinutes + (i * actualInterval);
      
      // Safety check: don't exceed sleep time for the last ones if interval was manual
      if (currentTotalMinutes > sleepMinutes) {
        currentTotalMinutes = sleepMinutes;
      }

      int hour = (currentTotalMinutes ~/ 60) % 24;
      int minute = currentTotalMinutes % 60;
      
      String timeStr = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      int amount = baseAmount + (i < remainder ? 1 : 0);
      
      reminders.add(ReminderModel(
        id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
        time: timeStr,
        amount: amount,
        icon: getIconForAmount(amount),
      ));
    }
    
    return reminders;
  }


  /// Rebalances reminders after one is edited manually
  List<ReminderModel> rebalanceReminders(List<ReminderModel> currentReminders, int dailyGoal, int editedIndex) {
    if (currentReminders.isEmpty) return currentReminders;

    // Fixed amount = sum of all finished reminders + the one just edited
    int editedAmount = currentReminders[editedIndex].amount;
    
    // We treat everything BEFORE or equal to editedIndex as "fixed" for this rebalance,
    // OR just the ones that are 'Selesai'. 
    // User said "auto rebalance" - usually means adjust remaining ones.
    
    int fixedSum = 0;
    for (int i = 0; i <= editedIndex; i++) {
      fixedSum += currentReminders[i].amount;
    }
    
    int remainingGoal = dailyGoal - fixedSum;
    int remainingCount = currentReminders.length - 1 - editedIndex;
    
    if (remainingCount > 0) {
      // If remaining goal is negative, we have a problem. Cap fixed at dailyGoal.
      if (remainingGoal < remainingCount * minAmount) {
          // This case means the user assigned too much to previous ones.
          // We might need to reduce the edited amount or previous ones, 
          // but for now let's just push minAmount to remaining.
          remainingGoal = remainingCount * minAmount;
      }

      int newBase = remainingGoal ~/ remainingCount;
      int newRemainder = remainingGoal % remainingCount;

      for (int i = editedIndex + 1; i < currentReminders.length; i++) {
        int idxInRemaining = i - (editedIndex + 1);
        currentReminders[i].amount = newBase + (idxInRemaining < newRemainder ? 1 : 0);
        currentReminders[i].icon = getIconForAmount(currentReminders[i].amount);
      }
    } else {
        // Last one edited, nothing to rebalance forward.
        // To satisfy "Total air = dailyGoal", we might need to adjust the edited one 
        // to match EXACTLY if it's the last one.
        int precedingSum = 0;
        for (int i = 0; i < editedIndex; i++) {
          precedingSum += currentReminders[i].amount;
        }
        currentReminders[editedIndex].amount = dailyGoal - precedingSum;
        currentReminders[editedIndex].icon = getIconForAmount(currentReminders[editedIndex].amount);
    }

    return currentReminders;
  }

  String getIconForAmount(int amount) {
    if (amount <= 150) return 'Cup_Filled.svg';
    if (amount <= 300) return 'Glass_Filled.svg';
    if (amount <= 500) return 'Mug_Filled.svg';
    return 'Bottle_Filled.svg';
  }
}
