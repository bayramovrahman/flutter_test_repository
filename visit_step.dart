import 'package:flutter/foundation.dart';
import 'package:shaylan_agent/database/config.dart';
import 'package:shaylan_agent/models/visit_step.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> createVisitStep(VisitStepModel visitStep) async {
  if (db.isOpen) {
    await db.insert(
      'visit_steps',
      visitStep.toJsonForDB(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

Future<int> createParentVisitStep(VisitStepModel visitStep) async {
  if (db.isOpen) {
    await db.insert(
      'visit_steps',
      visitStep.toJsonForDB(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final List<Map<String, dynamic>> result = await db
        .rawQuery('SELECT id FROM visit_steps ORDER BY id DESC LIMIT 1');
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return 0;
  }
  return 0;
}

Future<int> getVisitStepIfExist(String name, int visitId) async {
  final List<Map<String, dynamic>> result = await db.query(
    'visit_steps',
    columns: ['id'],
    where: 'name = ? AND visit_id = ?',
    whereArgs: [name, visitId],
    limit: 1,
  );

  if (result.isNotEmpty) {
    return result.first['id'] as int;
  }
  return 0; // Return 0 if not found
}

Future<int> updateVisitStep(
     int id, VisitStepModel updatedStep) async {
  return await db.update(
    'visit_steps',
    updatedStep.toJsonForDB(),
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> setEndTimeToVisitStep(
    int visitID, String stepName, String currentTime) async {
  if (db.isOpen) {
    await db.rawUpdate(
      'UPDATE visit_steps SET end_time = ? WHERE name = ? AND visit_id = ?',
      [currentTime, stepName, visitID],
    );
  }
}

Future<void> setNextVisitTimeAndEndTimeToVisitStep(
    int visitID, String stepName, String nextVisitTime) async {
  if (db.isOpen) {
    debugPrint("----------------setting next visit time to $nextVisitTime");
    await db.rawUpdate(
      '''
          UPDATE visit_steps SET next_visit_time = ? 
          WHERE id = (SELECT id FROM visit_steps WHERE name = ? AND visit_id = ? ORDER BY id DESC);
       ''',
      [nextVisitTime, stepName, visitID],
    );
  }
}

Future<void> setNextVisitTimeForTraders(
    int visitID, String nextVisitTime) async {
  if (db.isOpen) {
    debugPrint(visitID.toString());
    await db.rawUpdate(
      '''
          UPDATE visit_steps SET next_visit_time = ? , name = "traderVisitended", description = "Trader Visit Succeed"
          WHERE visit_id = ?;
       ''',
      [nextVisitTime, visitID],
    );
  }
}

Future<void> setCanPayToVisitStep(
    int visitID, String stepName, String canPay) async {
  if (db.isOpen) {
    await db.rawUpdate(
      '''
          UPDATE visit_steps SET can_pay = ? 
          WHERE id = (SELECT id FROM visit_steps WHERE name = ? AND visit_id = ? ORDER BY id DESC);
       ''',
      [canPay, stepName, visitID],
    );
  }
}

Future<List<VisitStepModel>> getVisitStepsByVisitID(int visitID) async {
  if (db.isOpen) {
    List<Map<String, dynamic>> result = await db.query(
      'visit_steps',
      where: 'visit_id = ? AND end_time != "" ORDER BY name ASC',
      whereArgs: [visitID],
    );

    return result.map((json) => VisitStepModel.fromJson(json)).toList();
  }
  return [];
}

Future<List<VisitStepModel>> getVerificationSteps(
    int visitID, String name) async {
  if (db.isOpen) {
    List<Map<String, dynamic>> result = await db.query(
      'visit_steps',
      where: 'visit_id = ? AND end_time != "" AND name = ? ORDER BY name ASC',
      whereArgs: [visitID, name],
    );

    return result.map((json) => VisitStepModel.fromJson(json)).toList();
  }
  return [];
}

Future<List<VisitStepModel>> getVisitSteps(
    int visitId, int parentStepId) async {
  if (db.isOpen) {
    List<Map<String, dynamic>> result = await db.query(
      'visit_steps',
      where:
          'visit_id = ? AND end_time != "" AND parent_step_id = ? ORDER BY name ASC',
      whereArgs: [visitId, parentStepId],
    );

    return result.map((json) => VisitStepModel.fromJson(json)).toList();
  }
  return [];
}

Future<int> getParentStepId(int visitId, String name) async {
  if (db.isOpen) {
    List<Map<String, dynamic>> result = await db.query(
      'visit_steps',
      where:
          'visit_id = ? AND end_time IS NOT NULL AND end_time != ? AND name = ?',
      whereArgs: [visitId, '', name],
      orderBy: 'name ASC', // Correctly placed ORDER BY clause
    );

    if (result.isNotEmpty) {
      return result.first['id'] as int; // Return the first matching ID
    }
  }
  return 0; // Default if no results or database is not open
}
