import 'dart:core';

import 'package:drawing_app_artify/features/draw/models/stroke.dart';
import 'package:flutter/material.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  List<Stroke> _strokes = [];
  List<Stroke> _redoStrokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedColor = Colors.black;
  double _brushSize = 4.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Draw Your Dreams'), centerTitle: true),
      body: Column(
        children: [
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _currentPoints.add(details.localPosition);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentPoints.add(details.localPosition);
              });
            },
            onPanEnd: (details) {
              setState(() {
                _strokes.add(
                  Stroke(
                    points: List.from(_currentPoints),
                    color: _selectedColor,
                    brushSize: _brushSize,
                  ),
                );
                _currentPoints = [];
                _redoStrokes = [];
              });
            },
          ),
        ],
      ),
    );
  }
}
