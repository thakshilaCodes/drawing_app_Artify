import 'dart:core';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:drawing_app_artify/features/draw/models/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> with TickerProviderStateMixin {
  List<Stroke> _strokes = [];
  List<Stroke> _redoStrokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedColor = Colors.black;
  double _brushSize = 4.0;
  late Box _drawingBox;
  bool _isErasing = false;
  String? _drawingName;
  bool _isToolbarExpanded = false;
  bool _hasUnsavedChanges = false;

  // Animation controllers
  late AnimationController _toolbarAnimationController;
  late AnimationController _brushPreviewController;
  late Animation<double> _toolbarAnimation;
  late Animation<double> _brushPreviewAnimation;

  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.white,
  ];

  final List<double> _brushSizes = [1.0, 2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 20.0];

  @override
  void initState() {
    super.initState();

    _toolbarAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _brushPreviewController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _toolbarAnimation = CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeInOut,
    );

    _brushPreviewAnimation = CurvedAnimation(
      parent: _brushPreviewController,
      curve: Curves.elasticOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHive();
    });
  }

  Future<void> _initializeHive() async {
    try {
      _drawingBox = Hive.box('drawings');

      final name = ModalRoute.of(context)?.settings.arguments as String?;
      if (name != null) {
        final dynamic rawStrokes = _drawingBox.get(name);
        List<Stroke> loadedStrokes = [];

        if (rawStrokes != null && rawStrokes is List) {
          for (var item in rawStrokes) {
            if (item is Stroke) {
              loadedStrokes.add(item);
            }
          }
        }

        setState(() {
          _drawingName = name;
          _strokes = loadedStrokes;
        });
      }
    } catch (e) {
      print('Error initializing Hive: $e');
      setState(() {
        _strokes = [];
      });
    }
  }

  Future<void> _saveDrawing(String name) async {
    try {
      await _drawingBox.put(name, _strokes);
      setState(() {
        _drawingName = name;
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Drawing "$name" saved successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving drawing: $e');
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Error saving drawing. Please try again.')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showSaveDialog() {
    TextEditingController controller = TextEditingController(text: _drawingName ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.save_as,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Save Your Masterpiece',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Artwork name',
                  hintText: 'My Amazing Drawing',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.palette),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () => controller.clear(),
                  )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {}); // Trigger rebuild for suffix icon
                },
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Choose a memorable name to find your artwork later!',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  _saveDrawing(name);
                  Navigator.of(context).pop();
                } else {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a name for your drawing'),
                      backgroundColor: Colors.orange.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: Icon(Icons.save, size: 18),
              label: Text(
                'Save Artwork',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
              ),
              SizedBox(width: 12),
              Text('Clear Canvas'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to clear the entire canvas?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone!',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Keep Drawing'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _strokes.clear();
                  _redoStrokes.clear();
                  _hasUnsavedChanges = true;
                });
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges && _strokes.isNotEmpty) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.save_outlined, color: Colors.orange),
                SizedBox(width: 8),
                Text('Unsaved Changes'),
              ],
            ),
            content: Text(
              'You have unsaved changes. What would you like to do?',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Discard', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Keep Drawing'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  _showSaveDialog();
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      );
      return result ?? false;
    }
    return true;
  }

  @override
  void dispose() {
    _toolbarAnimationController.dispose();
    _brushPreviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              _buildCanvasHeader(),
              Expanded(child: _buildCanvas()),
            ],
          ),
        ),
        bottomNavigationBar: _buildEnhancedToolBar(),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _drawingName ?? 'New Artwork',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (_hasUnsavedChanges)
            Text(
              'Unsaved changes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      actions: [
        IconButton(
          onPressed: _clearCanvas,
          icon: Icon(Icons.clear_all_rounded),
          tooltip: 'Clear Canvas',
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _isToolbarExpanded = !_isToolbarExpanded;
            });
            if (_isToolbarExpanded) {
              _toolbarAnimationController.forward();
            } else {
              _toolbarAnimationController.reverse();
            }
          },
          icon: AnimatedRotation(
            turns: _isToolbarExpanded ? 0.5 : 0,
            duration: Duration(milliseconds: 300),
            child: Icon(Icons.expand_more),
          ),
          tooltip: 'Toggle Tools',
        ),
      ],
    );
  }

  Widget _buildCanvasHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Icon(Icons.palette, color: Colors.grey[600], size: 16),
          SizedBox(width: 8),
          Text(
            'Canvas - ${_strokes.length} strokes',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Spacer(),
          if (_isErasing)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 12, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'Eraser Mode',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _currentPoints.add(details.localPosition);
              _redoStrokes.clear();
              _hasUnsavedChanges = true;
            });
            HapticFeedback.selectionClick();
          },
          onPanUpdate: (details) {
            setState(() {
              _currentPoints.add(details.localPosition);
            });
          },
          onPanEnd: (details) {
            if (_currentPoints.isNotEmpty) {
              setState(() {
                _strokes.add(
                  Stroke.fromOffsets(
                    points: List.from(_currentPoints),
                    color: _isErasing ? Colors.white : _selectedColor,
                    brushSize: _isErasing ? _brushSize * 1.5 : _brushSize,
                  ),
                );
                _currentPoints.clear();
              });
              HapticFeedback.lightImpact();
            }
          },
          child: CustomPaint(
            painter: DrawPainter(
              strokes: _strokes,
              currentPoints: _currentPoints,
              currentColor: _isErasing ? Colors.white : _selectedColor,
              currentBrushSize: _isErasing ? _brushSize * 1.5 : _brushSize,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 100), // Space from top
        FloatingActionButton.extended(
          onPressed: _showSaveDialog,
          icon: Icon(Icons.save_rounded),
          label: Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          heroTag: "save",
        ),
        SizedBox(height: 8),
        if (_strokes.isNotEmpty)
          FloatingActionButton(
            mini: true,
            onPressed: () {
              setState(() {
                if (_redoStrokes.isNotEmpty) {
                  _strokes.add(_redoStrokes.removeLast());
                  _hasUnsavedChanges = true;
                }
              });
              HapticFeedback.lightImpact();
            },
            child: Icon(Icons.redo, size: 18),
            backgroundColor: _redoStrokes.isNotEmpty ? Colors.green : Colors.grey[300],
            heroTag: "redo",
          ),
        SizedBox(height: 4),
        if (_strokes.isNotEmpty)
          FloatingActionButton(
            mini: true,
            onPressed: () {
              setState(() {
                if (_strokes.isNotEmpty) {
                  _redoStrokes.add(_strokes.removeLast());
                  _hasUnsavedChanges = true;
                }
              });
              HapticFeedback.lightImpact();
            },
            child: Icon(Icons.undo, size: 18),
            backgroundColor: Colors.orange,
            heroTag: "undo",
          ),
      ],
    );
  }

  Widget _buildEnhancedToolBar() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _isToolbarExpanded ? 280 : 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),

              // Quick action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickActionButton(
                    icon: _isErasing ? Icons.brush : Icons.auto_fix_high,
                    label: _isErasing ? 'Brush' : 'Eraser',
                    onPressed: () {
                      setState(() {
                        _isErasing = !_isErasing;
                      });
                      HapticFeedback.selectionClick();
                      _brushPreviewController.forward().then((_) {
                        _brushPreviewController.reverse();
                      });
                    },
                    isSelected: _isErasing,
                    color: _isErasing ? Colors.red : Colors.blue,
                  ),
                  _buildQuickActionButton(
                    icon: Icons.undo,
                    label: 'Undo',
                    onPressed: _strokes.isNotEmpty ? () {
                      setState(() {
                        _redoStrokes.add(_strokes.removeLast());
                        _hasUnsavedChanges = true;
                      });
                      HapticFeedback.lightImpact();
                    } : null,
                    color: Colors.orange,
                  ),
                  _buildQuickActionButton(
                    icon: Icons.redo,
                    label: 'Redo',
                    onPressed: _redoStrokes.isNotEmpty ? () {
                      setState(() {
                        _strokes.add(_redoStrokes.removeLast());
                        _hasUnsavedChanges = true;
                      });
                      HapticFeedback.lightImpact();
                    } : null,
                    color: Colors.green,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Brush size with visual preview
              _buildBrushSizeSection(),

              if (_isToolbarExpanded) ...[
                SizedBox(height: 24),

                // Quick brush sizes
                _buildQuickBrushSizes(),

                SizedBox(height: 20),

                // Color palette
                _buildColorPalette(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isSelected = false,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: onPressed != null
                  ? (isSelected ? color : Colors.grey[700])
                  : Colors.grey[400],
              size: 24,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: onPressed != null ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildBrushSizeSection() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.brush, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Text(
              'Brush Size',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Spacer(),
            ScaleTransition(
              scale: _brushPreviewAnimation,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _isErasing ? Colors.red[100] : _selectedColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isErasing ? Colors.red : _selectedColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: _brushSize.clamp(2, 16),
                    height: _brushSize.clamp(2, 16),
                    decoration: BoxDecoration(
                      color: _isErasing ? Colors.red : _selectedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _isErasing ? Colors.red : Theme.of(context).primaryColor,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: _isErasing ? Colors.red : Theme.of(context).primaryColor,
            overlayColor: (_isErasing ? Colors.red : Theme.of(context).primaryColor).withOpacity(0.2),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _brushSize,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            label: _brushSize.round().toString(),
            onChanged: (value) {
              setState(() {
                _brushSize = value;
              });
              HapticFeedback.selectionClick();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickBrushSizes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Sizes',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _brushSizes.map((size) => _buildBrushSizeButton(size)).toList(),
        ),
      ],
    );
  }

  Widget _buildBrushSizeButton(double size) {
    final isSelected = _brushSize == size;
    return GestureDetector(
      onTap: () {
        setState(() {
          _brushSize = size;
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: size.clamp(2, 16),
            height: size.clamp(2, 16),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colors',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((color) => _buildColorButton(color)).toList(),
        ),
      ],
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color && !_isErasing;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _isErasing = false;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: isSelected ? 42 : 36,
        height: isSelected ? 42 : 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: color == Colors.white ? Icon(
          Icons.palette,
          size: isSelected ? 18 : 16,
          color: Colors.grey[600],
        ) : null,
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
    // Fill background with white
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw subtle grid for better drawing experience
    _drawGrid(canvas, size);

    // Draw existing strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke
    if (currentPoints.isNotEmpty) {
      _drawCurrentStroke(canvas);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[100]!
      ..strokeWidth = 0.5;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = gridSize; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = gridSize; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    final points = stroke.offsetPoints;
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.brushSize
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      // Draw a dot for single point
      canvas.drawCircle(points.first, stroke.brushSize / 2,
          paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    // Use quadratic bezier curves for smoother lines
    for (int i = 1; i < points.length; i++) {
      if (i == 1) {
        path.lineTo(points[i].dx, points[i].dy);
      } else {
        final p1 = points[i - 1];
        final p2 = points[i];
        final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawCurrentStroke(Canvas canvas) {
    final paint = Paint()
      ..color = currentColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = currentBrushSize
      ..style = PaintingStyle.stroke;

    if (currentPoints.length == 1) {
      canvas.drawCircle(currentPoints.first, currentBrushSize / 2,
          paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(currentPoints.first.dx, currentPoints.first.dy);

    for (int i = 1; i < currentPoints.length; i++) {
      if (i == 1) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      } else {
        final p1 = currentPoints[i - 1];
        final p2 = currentPoints[i];
        final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}