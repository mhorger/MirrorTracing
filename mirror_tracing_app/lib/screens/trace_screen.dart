import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

class TraceScreen extends StatefulWidget {
  final String participantId;
  final String group;
  final String session;
  final List<String> mazeList;

  const TraceScreen({
    super.key,
    required this.participantId,
    required this.group,
    required this.session,
    required this.mazeList,
  });

  @override
  _TraceScreenState createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen> {
  int _currentMazeIndex = 0;

  ui.Image? mazeImage;
  late ByteData mazePixelData;

  // -------------------------------------------------------------
  // PIXEL ACCOUNTING
  // -------------------------------------------------------------

  // Maze-level
  int totalInBoundsPixels = 0;
  int totalOutOfBoundsPixels = 0;

  // Drawing-level (unique pixels)
  final Set<int> drawnInBoundsPixels = {};
  final Set<int> drawnOutOfBoundsPixels = {};

  void _computeMazePixelStats() {
    totalInBoundsPixels = 0;
    totalOutOfBoundsPixels = 0;

    final int width = mazeImage!.width;
    final int height = mazeImage!.height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int offset = (y * width + x) * 4;

        final int r = mazePixelData.getUint8(offset);
        final int g = mazePixelData.getUint8(offset + 1);
        final int b = mazePixelData.getUint8(offset + 2);

        final double brightness = (r + g + b) / 3;

        if (brightness > 200) {
          totalInBoundsPixels++;
        } else {
          totalOutOfBoundsPixels++;
        }
      }
    }
  }

  int _pixelIndexFromPosition(Offset position, Size canvasSize) {
    final img = mazeImage!;
    final double scaleX = img.width / canvasSize.width;
    final double scaleY = img.height / canvasSize.height;

    int px = (position.dx * scaleX).round();
    int py = (position.dy * scaleY).round();

    if (px < 0 || py < 0 || px >= img.width || py >= img.height) {
      return -1;
    }

    return py * img.width + px;
  }

  // -------------------------------------------------------------
  // DRAW PATH
  // -------------------------------------------------------------
  final Path _drawPath = Path();

  final Paint _paint = Paint()
    ..color = Colors.blue
    ..strokeWidth = 6.0
    ..style = PaintingStyle.stroke;

  // -------------------------------------------------------------
  // TIMING
  // -------------------------------------------------------------
  late Stopwatch _mazeLoadStopwatch;
  late Stopwatch _trialStopwatch;
  late Stopwatch _drawStopwatch;
  late Stopwatch _errorStopwatch;

  bool _firstTouchOccurred = false;
  int latencyMs = -1;
  bool drawing = false;

  @override
  void initState() {
    super.initState();
    _mazeLoadStopwatch = Stopwatch();
    _trialStopwatch = Stopwatch();
    _drawStopwatch = Stopwatch();
    _errorStopwatch = Stopwatch();
    _loadMaze();
  }

  // -------------------------------------------------------------
  // LOAD MAZE
  // -------------------------------------------------------------
  Future<void> _loadMaze() async {
    final path = widget.mazeList[_currentMazeIndex];

    final bytes = await rootBundle.load(path);
    final imageBytes = bytes.buffer.asUint8List();
    final image = await decodeImageFromList(imageBytes);

    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    setState(() {
      mazeImage = image;
      mazePixelData = byteData!;
      _drawPath.reset();

      drawnInBoundsPixels.clear();
      drawnOutOfBoundsPixels.clear();

      _computeMazePixelStats();

      _firstTouchOccurred = false;
      latencyMs = -1;
      drawing = false;

      _trialStopwatch.reset();
      _drawStopwatch.reset();
      _errorStopwatch.reset();

      _mazeLoadStopwatch
        ..reset()
        ..start();
    });
  }

  // -------------------------------------------------------------
  // IN-BOUNDS CHECK
  // -------------------------------------------------------------
  bool _isInBounds(Offset position, Size canvasSize) {
    if (mazeImage == null) return true;

    final img = mazeImage!;
    final double scaleX = img.width / canvasSize.width;
    final double scaleY = img.height / canvasSize.height;

    int px = (position.dx * scaleX).round();
    int py = (position.dy * scaleY).round();

    if (px < 0 || py < 0 || px >= img.width || py >= img.height) return false;

    final int offset = (py * img.width + px) * 4;

    int r = mazePixelData.getUint8(offset);
    int g = mazePixelData.getUint8(offset + 1);
    int b = mazePixelData.getUint8(offset + 2);

    return ((r + g + b) / 3) > 200;
  }

  // -------------------------------------------------------------
  // SAVE CSV
  // -------------------------------------------------------------
  Future<void> _saveResultsRecord({
    required int latency,
    required int drawTime,
    required int errorTime,
    required int trialTime,
  }) async {
    final desktop =
        Directory('${Platform.environment['USERPROFILE']}\\Desktop');
    if (!desktop.existsSync()) desktop.createSync();

    final file = File('${desktop.path}/mirror_trace_data.csv');

    final newRow = [
      widget.participantId,
      widget.group,
      widget.session,
      widget.mazeList[_currentMazeIndex],
      latency,
      drawTime,
      errorTime,
      trialTime,
      totalInBoundsPixels,
      totalOutOfBoundsPixels,
      drawnInBoundsPixels.length,
      drawnOutOfBoundsPixels.length,
      DateTime.now().toIso8601String(),
    ];

    if (!file.existsSync()) {
      file.writeAsStringSync(
        const ListToCsvConverter().convert([
              [
                "Participant",
                "Group",
                "Session",
                "Maze",
                "Latency(ms)",
                "DrawTime(ms)",
                "ErrorTime(ms)",
                "TrialTime(ms)",
                "MazeInBoundsPixels",
                "MazeOutOfBoundsPixels",
                "DrawnInBoundsPixels",
                "DrawnOutOfBoundsPixels",
                "Date"
              ],
              newRow
            ]) +
            "\n",
      );
    } else {
      file.writeAsStringSync(
        const ListToCsvConverter().convert([newRow]) + "\n",
        mode: FileMode.append,
      );
    }
  }

  // -------------------------------------------------------------
  // FINISH
  // -------------------------------------------------------------
  Future<void> _finishMaze() async {
    _drawStopwatch.stop();
    _errorStopwatch.stop();
    _trialStopwatch.stop();
    _mazeLoadStopwatch.stop();

    await _saveResultsRecord(
      latency: _firstTouchOccurred ? latencyMs : -1,
      drawTime: _drawStopwatch.elapsedMilliseconds,
      errorTime: _errorStopwatch.elapsedMilliseconds,
      trialTime: _trialStopwatch.elapsedMilliseconds,
    );

    if (_currentMazeIndex < widget.mazeList.length - 1) {
      setState(() => _currentMazeIndex++);
      await _loadMaze();
    } else {
      Navigator.pop(context);
    }
  }

  // -------------------------------------------------------------
  // TOUCH HANDLING
  // -------------------------------------------------------------
  void _handleTouchStart(Offset position, Size size) {
    if (!_firstTouchOccurred) {
      latencyMs = _mazeLoadStopwatch.elapsedMilliseconds;
      _mazeLoadStopwatch.stop();

      _firstTouchOccurred = true;
      _trialStopwatch.start();
    }

    drawing = true;
    _drawPath.moveTo(position.dx, position.dy);
    setState(() {});
  }

  void _handleTouchUpdate(Offset position, Size size) {
    final bool nowInBounds = _isInBounds(position, size);

    if (nowInBounds) {
      _errorStopwatch.stop();
      if (!_drawStopwatch.isRunning) _drawStopwatch.start();
    } else {
      _drawStopwatch.stop();
      if (!_errorStopwatch.isRunning) _errorStopwatch.start();
    }

    final int pixelIndex = _pixelIndexFromPosition(position, size);
    if (pixelIndex >= 0) {
      if (nowInBounds) {
        drawnInBoundsPixels.add(pixelIndex);
      } else {
        drawnOutOfBoundsPixels.add(pixelIndex);
      }
    }

    _drawPath.lineTo(position.dx, position.dy);
    setState(() {});
  }

  void _handleTouchEnd() {
    _drawStopwatch.stop();
    _errorStopwatch.stop();
    drawing = false;
    setState(() {});
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Maze ${_currentMazeIndex + 1}"),
        actions: [
          TextButton(
            onPressed: _finishMaze,
            child: const Text(
              "FINISH",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: mazeImage == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final canvasSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: (d) =>
                    _handleTouchStart(d.localPosition, canvasSize),
                onPanUpdate: (d) =>
                    _handleTouchUpdate(d.localPosition, canvasSize),
                onPanEnd: (_) => _handleTouchEnd(),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TracePainter(mazeImage!, _drawPath, _paint),
                ),
              );
            }),
    );
  }
}

class _TracePainter extends CustomPainter {
  final ui.Image maze;
  final Path path;
  final Paint paintStyle;

  _TracePainter(this.maze, this.path, this.paintStyle);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      maze,
      Rect.fromLTWH(0, 0, maze.width.toDouble(), maze.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
    canvas.drawPath(path, paintStyle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
