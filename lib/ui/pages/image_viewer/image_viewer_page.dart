import 'dart:io';
import 'package:flutter/material.dart';

class ImageViewerPage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getController(int index) {
    return _controllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _resetZoom(int index) {
    _getController(index).value = Matrix4.identity();
  }

  void _handleBackgroundTap() {
    final controller = _getController(_currentIndex);
    if (controller.value == Matrix4.identity()) {
      Navigator.pop(context);
    } else {
      _resetZoom(_currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.imagePaths.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _resetZoom(_currentIndex),
            tooltip: '重置缩放',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _handleBackgroundTap,
        behavior: HitTestBehavior.translucent,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.imagePaths.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final path = widget.imagePaths[index];
            final file = File(path);
            
            if (!file.existsSync()) {
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              );
            }

            return Center(
              child: Hero(
                tag: 'image_$index',
                child: InteractiveViewer(
                  transformationController: _getController(index),
                  minScale: 0.5,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: GestureDetector(
                    onTap: () {
                      final controller = _getController(index);
                      if (controller.value == Matrix4.identity()) {
                        Navigator.pop(context);
                      } else {
                        _resetZoom(index);
                      }
                    },
                    onDoubleTap: () {
                      final controller = _getController(index);
                      if (controller.value != Matrix4.identity()) {
                        _resetZoom(index);
                      } else {
                        controller.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
                      }
                    },
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: widget.imagePaths.length > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imagePaths.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}