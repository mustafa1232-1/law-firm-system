import 'package:flutter/material.dart';

void showFeatureInProgress(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('ميزة "$featureName" قيد التطوير وسيتم ربطها بالكامل في المرحلة التالية.'),
    ),
  );
}
