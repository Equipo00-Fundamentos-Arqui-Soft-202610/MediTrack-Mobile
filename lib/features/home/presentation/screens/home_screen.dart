import 'package:flutter/material.dart';
class Screen extends StatelessWidget {
  const Screen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screen')),
    body: const Center(child: Text('Screen')),
  );
}
