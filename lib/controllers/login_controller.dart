import 'package:flutter/material.dart';

class LoginController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordVisible = false;

  void togglePasswordVisibility(VoidCallback onUpdate) {
    isPasswordVisible = !isPasswordVisible;
    onUpdate();
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }
}
