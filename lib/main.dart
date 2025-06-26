import 'package:drawing_app_artify/features/draw/presentation/drawscreen.dart';
import 'package:drawing_app_artify/features/home/presentation/homescreen.dart';
import 'package:drawing_app_artify/features/splash/presentation/splashscreen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp(key: ValueKey('MyApp')));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paint Your Dreams',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(key: ValueKey('splashScreen')),
        '/home': (context) => const HomeScreen(key: ValueKey('homeScreen')),
        '/draw': (context) => const DrawScreen(key: ValueKey('drawScreen')),
      },
    );
  }
}
