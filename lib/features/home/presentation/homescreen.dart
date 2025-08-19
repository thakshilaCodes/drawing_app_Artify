import 'package:drawing_app_artify/features/draw/models/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late Box _drawingBox;
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabScaleAnimation;

  String _searchQuery = '';
  bool _isSearching = false;
  List<String> _filteredDrawings = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    Future.delayed(Duration(milliseconds: 800), () {
      _fabAnimationController.forward();
    });
  }

  Future<void> _initializeHive() async {
    try {
      _drawingBox = Hive.box('drawings');
      _updateFilteredDrawings();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing Hive: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _updateFilteredDrawings() {
    final allDrawings = _drawingBox.keys.cast<String>().toList();
    if (_searchQuery.isEmpty) {
      _filteredDrawings = allDrawings;
    } else {
      _filteredDrawings = allDrawings.where((name) =>
          name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
  }

  void _refreshDrawings() {
    if (mounted) {
      setState(() {
        _updateFilteredDrawings();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshDrawings();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
      _updateFilteredDrawings();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredDrawings();
    });
  }

  Future<void> _shareDrawing(String name) async {
    try {

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Preparing to share...'),
              ],
            ),
          ),
        ),
      );

      final strokes = await _getDrawingStrokes(name);
      print('Sharing drawing: $name with ${strokes.length} strokes');

      if (strokes.isEmpty) {
        print('Warning: No strokes found for drawing: $name');
      }


      final imageBytes = await _createImageFromStrokes(strokes);
      print('Created image with ${imageBytes.length} bytes');

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/${name}_$timestamp.png');
      await file.writeAsBytes(imageBytes);
      print('Saved temp file: ${file.path}');


      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }


      if (await file.exists()) {
        final fileSize = await file.length();
        print('File exists with size: $fileSize bytes');

        if (fileSize > 0) {

          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Check out my artwork: $name',
            subject: 'My Artwork - $name',
          );
          print('Share completed successfully');
        } else {
          throw Exception('Generated image file is empty');
        }
      } else {
        throw Exception('Generated image file does not exist');
      }


      Future.delayed(Duration(seconds: 5), () async {
        try {
          if (await file.exists()) {
            await file.delete();
            print('Temp file cleaned up');
          }
        } catch (e) {
          print('Error cleaning up temp file: $e');
        }
      });

    } catch (e) {
      print('Share error: $e');


      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error sharing artwork: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }



  Future<Uint8List> _createImageFromStrokes(List<Stroke> strokes) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(800, 600);


    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (strokes.isEmpty) {
      final picture = recorder.endRecording();
      final img = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }


    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;


    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dy > maxY) maxY = point.dy;
      }
    }


    if (minX == double.infinity || maxX == double.negativeInfinity) {
      for (final stroke in strokes) {
        final paint = Paint()
          ..color = stroke.strokeColor
          ..strokeWidth = stroke.brushSize
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = Path();
        if (stroke.points.isNotEmpty) {
          final firstPoint = stroke.points.first;
          path.moveTo(firstPoint.dx, firstPoint.dy);

          for (int i = 1; i < stroke.points.length; i++) {
            final point = stroke.points[i];
            path.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(path, paint);
      }
    } else {

      final drawingWidth = maxX - minX;
      final drawingHeight = maxY - minY;
      final padding = 0.1;
      final availableWidth = size.width * (1 - 2 * padding);
      final availableHeight = size.height * (1 - 2 * padding);


      final scaleX = drawingWidth > 0 ? availableWidth / drawingWidth : 1.0;
      final scaleY = drawingHeight > 0 ? availableHeight / drawingHeight : 1.0;
      final scale = math.min(scaleX, scaleY);


      final scaledWidth = drawingWidth * scale;
      final scaledHeight = drawingHeight * scale;
      final offsetX = (size.width - scaledWidth) / 2 - minX * scale;
      final offsetY = (size.height - scaledHeight) / 2 - minY * scale;


      for (final stroke in strokes) {
        if (stroke.points.isEmpty) continue;

        final paint = Paint()
          ..color = stroke.strokeColor
          ..strokeWidth = math.max(1.0, stroke.brushSize * scale)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = Path();
        final firstPoint = stroke.points.first;
        path.moveTo(
          firstPoint.dx * scale + offsetX,
          firstPoint.dy * scale + offsetY,
        );

        for (int i = 1; i < stroke.points.length; i++) {
          final point = stroke.points[i];
          path.lineTo(
            point.dx * scale + offsetX,
            point.dy * scale + offsetY,
          );
        }

        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }



  void _duplicateDrawing(String originalName) {
    TextEditingController controller = TextEditingController(
      text: '$originalName Copy',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Duplicate Artwork'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter a name for the duplicated artwork:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && !_drawingBox.containsKey(newName)) {
                final originalStrokes = _drawingBox.get(originalName);
                if (originalStrokes != null) {
                  _drawingBox.put(newName, originalStrokes);
                  setState(() {
                    _updateFilteredDrawings();
                  });
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Artwork duplicated successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a unique name'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _deleteDrawing(String name) {
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Artwork',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                    children: [
                      TextSpan(text: 'Are you sure you want to delete '),
                      TextSpan(
                        text: '"$name"',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '?'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone!',
                          style: TextStyle(
                            color: Colors.orange.shade800,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _drawingBox.delete(name);
                  _updateFilteredDrawings();
                });
                Navigator.of(context).pop();
                HapticFeedback.heavyImpact();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Artwork "$name" deleted successfully'),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: Icon(Icons.delete_forever, size: 18),
              label: Text('Delete Forever'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allDrawings = _drawingBox.keys.cast<String>().toList();
    final drawingsToShow = _filteredDrawings;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade50,
              Colors.blue.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Column(
                    children: [
                      _buildAppBar(),
                      _buildSearchBar(),
                      Expanded(
                        child: drawingsToShow.isEmpty
                            ? _buildEmptyState(allDrawings.isEmpty)
                            : _buildDrawingGrid(drawingsToShow),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: _buildFloatingActionButton(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Hero(
            tag: 'app_icon',
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.palette,
                color: Colors.purple,
                size: 28,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ArtiFy Gallery',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _buildSubtitle(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _buildStatsCard(),
        ],
      ),
    );
  }

  String _buildSubtitle() {
    final totalCount = _drawingBox.keys.length;
    final filteredCount = _filteredDrawings.length;

    if (_isSearching && _searchQuery.isNotEmpty) {
      return '$filteredCount of $totalCount artworks';
    }

    if (totalCount == 0) {
      return 'Start your creative journey';
    }

    return '$totalCount ${totalCount == 1 ? "masterpiece" : "masterpieces"}';
  }

  Widget _buildStatsCard() {
    final count = _drawingBox.keys.length;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          Text(
            count == 1 ? 'Art' : 'Arts',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onTap: _startSearch,
                decoration: InputDecoration(
                  hintText: 'Search your artworks...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _isSearching && _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400]),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          if (_isSearching)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: _stopSearch,
                child: Text('Cancel'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Transform.rotate(
                      angle: math.sin(value * math.pi * 2) * 0.1,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade200, Colors.pink.shade200],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 25,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          isCompletelyEmpty ? Icons.brush : Icons.search_off,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 32),
              Text(
                isCompletelyEmpty ? 'No artworks yet' : 'No matching artworks',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                isCompletelyEmpty
                    ? 'Start creating your first masterpiece!\nExpress your creativity and bring ideas to life.'
                    : 'Try adjusting your search terms\nor create a new artwork with that name.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/draw');
                  _refreshDrawings();
                },
                icon: Icon(Icons.add, size: 20),
                label: Text(
                  'Create Artwork',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingGrid(List<String> drawings) {
    return GridView.builder(
      padding: EdgeInsets.all(20),
      itemCount: drawings.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) {
        final name = drawings[index];
        return _buildDrawingCard(name);
      },
    );
  }

  Widget _buildDrawingCard(String name) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () async {
                await Navigator.pushNamed(context, '/draw', arguments: name);
                _refreshDrawings();
              },
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildDrawingPreview(name),
                ),
              ),
            ),
          ),

          // Title and action buttons
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),

                  // Action buttons row
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.edit_rounded,
                            color: Colors.blue,
                            onPressed: () async {
                              await Navigator.pushNamed(context, '/draw', arguments: name);
                              _refreshDrawings();
                            },
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.share_rounded,
                            color: Colors.green,
                            onPressed: () => _shareDrawing(name),
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.copy_rounded,
                            color: Colors.orange,
                            onPressed: () => _duplicateDrawing(name),
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.delete_rounded,
                            color: Colors.red,
                            onPressed: () => _deleteDrawing(name),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingPreview(String name) {
    return FutureBuilder<List<Stroke>>(
      future: _getDrawingStrokes(name),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade50,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.purple,
                strokeWidth: 2,
              ),
            ),
          );
        } else if (snapshot.hasError) {
          print('Error loading drawing preview for $name: ${snapshot.error}');
          return Container(
            color: Colors.red.shade50,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 32),
                  SizedBox(height: 4),
                  Text(
                    'Error',
                    style: TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
            child: CustomPaint(
              painter: DrawingPreviewPainter(snapshot.data!),
              child: Container(),
            ),
          );
        } else {
          return Container(
            color: Colors.purple.shade50,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.brush,
                    color: Colors.purple.shade300,
                    size: 28,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Empty',
                    style: TextStyle(
                      color: Colors.purple.shade400,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<List<Stroke>> _getDrawingStrokes(String name) async {
    try {
      final strokesData = _drawingBox.get(name);
      if (strokesData == null) {
        print('No stroke data found for: $name');
        return [];
      }


      print('Loading strokes for $name: ${strokesData.runtimeType}');

      if (strokesData is List) {
        return List<Stroke>.from(strokesData);
      } else {
        print('Unexpected stroke data type: ${strokesData.runtimeType}');
        return [];
      }
    } catch (e) {
      print('Error loading strokes for $name: $e');
      return [];
    }
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.pushNamed(context, '/draw');
        _refreshDrawings();
      },
      icon: Icon(Icons.add),
      label: Text('New Artwork'),
      backgroundColor: Colors.purple,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class DrawingPreviewPainter extends CustomPainter {
  final List<Stroke> strokes;

  DrawingPreviewPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw white background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (strokes.isEmpty) return;

    // Calculate bounds to center the drawing
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;


    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    if (minX == double.infinity || maxX == double.negativeInfinity) return;


    final drawingWidth = maxX - minX;
    final drawingHeight = maxY - minY;

    if (drawingWidth == 0 || drawingHeight == 0) return;


    final padding = 0.1;
    final scaleX = (size.width * (1 - 2 * padding)) / drawingWidth;
    final scaleY = (size.height * (1 - 2 * padding)) / drawingHeight;
    final scale = math.min(scaleX, scaleY);


    final scaledWidth = drawingWidth * scale;
    final scaledHeight = drawingHeight * scale;
    final offsetX = (size.width - scaledWidth) / 2 - minX * scale;
    final offsetY = (size.height - scaledHeight) / 2 - minY * scale;


    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.strokeColor
        ..strokeWidth = math.max(1.0, stroke.brushSize * scale * 0.6)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final firstPoint = stroke.points.first;
      path.moveTo(
        firstPoint.dx * scale + offsetX,
        firstPoint.dy * scale + offsetY,
      );

      for (int i = 1; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        path.lineTo(
          point.dx * scale + offsetX,
          point.dy * scale + offsetY,
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! DrawingPreviewPainter ||
        oldDelegate.strokes != strokes;
  }
}