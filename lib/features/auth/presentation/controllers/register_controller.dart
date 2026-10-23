import 'package:flutter/material.dart';

class RegisterController {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Helper para formatar a meta diária
  String formatDailyGoal(double ml) {
    if (ml >= 1000) {
      double liters = ml / 1000;
      // Remove o .0 se for inteiro (ex: 2.0L -> 2L)
      String formattedLiters = liters % 1 == 0
          ? liters.toInt().toString()
          : liters.toStringAsFixed(1);
      return "${ml.toInt()} ml (${formattedLiters}L)";
    }
    return "${ml.toInt()} ml";
  }

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }
}
