import 'dart:core';

import 'package:drawing_app_artify/features/draw/models/stroke.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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
  late Box<List<Stroke>> _drawingBox;

  String? _drawingName;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHive();
    });
    super.initState();
  }

  Future<void> _initializeHive() async {
    _drawingBox = Hive.box('drawings');

    final name = ModalRoute.of(context)?.settings.arguments as String?;
    if (name != null) {
      setState(() {
        _drawingName = name;
        _strokes = _drawingBox.get(name) ?? [];
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveDrawing(String name) async {
    await _drawingBox.put(name, _strokes);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Drawing $name saved Successfully')));
  }

  void _showSaveDialog() {
    TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Save Your Drawing'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Give a name to your drawing',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final name = _controller.text.trim();

                if (name.isNotEmpty) {
                  setState(() {
                    _drawingName = name;
                  });
                  _saveDrawing(name);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a name before saving your drawing',
                      ),
                    ),
                  );
                }
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_drawingName ?? 'Draw Your Dreams'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
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
                      Stroke.fromOffsets(
                        points: List.from(_currentPoints),
                        color: _selectedColor,
                        brushSize: _brushSize,
                      ),
                    );
                    _currentPoints = [];
                    _redoStrokes = [];
                  });
                },
                child: CustomPaint(
                  painter: DrawPainter(
                    strokes: _strokes,
                    currentPoints: _currentPoints,
                    currentColor: _selectedColor,
                    currentBrushSize: _brushSize,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(child: _buildToolBar()),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSaveDialog,
        child: const Icon(Icons.save_as),
      ),
    );
  }

  Widget _buildToolBar() {
    return Container(
      height: 56,
      color: Colors.grey[200],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: _strokes.isNotEmpty
                ? () {
                    setState(() {
                      _redoStrokes.add(_strokes.removeLast());
                    });
                  }
                : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: _redoStrokes.isNotEmpty
                ? () {
                    setState(() {
                      _strokes.add(_redoStrokes.removeLast());
                    });
                  }
                : null,
            icon: const Icon(Icons.redo),
          ),

          DropdownButton(
            value: _brushSize,
            items: [
              DropdownMenuItem(child: Text('Small'), value: 2.0),
              DropdownMenuItem(child: Text('Medium'), value: 4.0),
              DropdownMenuItem(child: Text('Large'), value: 8.0),
            ],
            onChanged: (value) {
              setState(() {
                _brushSize = value!;
              });
            },
          ),

          Row(
            children: [
              _buildColorButton(Colors.black),
              _buildColorButton(Colors.pink),
              _buildColorButton(Colors.red),
              _buildColorButton(Colors.green),
              _buildColorButton(Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        width: 24,
        height: 24,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color ? Colors.grey : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class DrawPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentBrushSize;

  DrawPainter({
    super.repaint,
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentBrushSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.strokeColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.brushSize;

      final points = stroke.offsetPoints;

      for (int i = 0; i < points.length - 1; i++) {
        if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
          canvas.drawLine(points[i], points[i + 1], paint);
        }
      }
    }

    final paint = Paint()
      ..color = currentColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = currentBrushSize;

    for (int i = 0; i < currentPoints.length - 1; i++) {
      if (currentPoints[i] != Offset.zero &&
          currentPoints[i + 1] != Offset.zero) {
        canvas.drawLine(currentPoints[i], currentPoints[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
