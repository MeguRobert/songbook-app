import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/verse.dart';
import '../../providers/song_provider.dart';

/// Full-screen immersive presentation mode for displaying song lyrics verse-by-verse
class PresentationScreen extends ConsumerStatefulWidget {
  final int songNumber;

  const PresentationScreen({
    required this.songNumber,
    super.key,
  });

  @override
  ConsumerState<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends ConsumerState<PresentationScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _controlsVisible = true;
  bool _projectionMode = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Start timer to hide controls after 3 seconds
    _startHideTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideTimer?.cancel();
    // Restore normal system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _showControls() {
    setState(() {
      _controlsVisible = true;
    });
    _startHideTimer();
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _toggleProjectionMode() {
    setState(() {
      _projectionMode = !_projectionMode;
    });
    _showControls();
  }

  void _nextPage(int totalPages) {
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _showControls();
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByNumberProvider(widget.songNumber));

    return songAsync.when(
      data: (song) {
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('Song not found')),
          );
        }

        // Build page content: title card + verses
        final pages = <Widget>[
          // Title card (first page)
          _buildTitleCard(song.title, song.number),
          // Verse pages
          ...song.verses.map((verse) => _buildVersePage(verse)),
        ];

        final totalPages = pages.length;

        return Scaffold(
          backgroundColor: _projectionMode ? Colors.black : null,
          body: SafeArea(
            child: Stack(
              children: [
                // PageView for verse-by-verse display
                PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _showControls();
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTapUp: (details) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final tapX = details.globalPosition.dx;

                        // Divide screen into thirds
                        if (tapX < screenWidth / 3) {
                          // Left third - previous
                          _previousPage();
                        } else if (tapX > 2 * screenWidth / 3) {
                          // Right third - next
                          _nextPage(totalPages);
                        } else {
                          // Center third - toggle controls
                          _toggleControls();
                        }
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: pages[index],
                      ),
                    );
                  },
                ),

                // Controls overlay
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Stack(
                      children: [
                        // Exit button (top-left)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Exit',
                            ),
                          ),
                        ),

                        // Projection mode toggle (top-right)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _projectionMode ? Icons.wb_sunny : Icons.nightlight_round,
                                color: Colors.white,
                              ),
                              onPressed: _toggleProjectionMode,
                              tooltip: _projectionMode ? 'Normal mode' : 'Projection mode',
                            ),
                          ),
                        ),

                        // Page indicator (bottom center)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${_currentPage + 1} / $totalPages',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleCard(String title, int number) {
    final textColor = _projectionMode ? Colors.white : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number.',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersePage(Verse verse) {
    final textColor = _projectionMode ? Colors.white : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayText = verse.displayText;
        final lines = displayText.split('\n');

        // Calculate longest line for auto-scaling
        int maxLineLength = 0;
        for (final line in lines) {
          if (line.length > maxLineLength) {
            maxLineLength = line.length;
          }
        }

        // Auto-scale font based on available width and longest line
        // Heuristic: fontSize = availableWidth / (longestLineCharCount * 0.55)
        // Clamped between 24 and 120
        final availableWidth = constraints.maxWidth * 0.9; // Leave some margin
        double calculatedFontSize = maxLineLength > 0
            ? availableWidth / (maxLineLength * 0.55)
            : 48.0;
        calculatedFontSize = calculatedFontSize.clamp(24.0, 120.0);

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Verse number indicator (subtle)
                Text(
                  '${verse.number}',
                  style: TextStyle(
                    fontSize: calculatedFontSize * 0.4,
                    fontWeight: FontWeight.w300,
                    color: textColor?.withValues(alpha: 0.6) ??
                           Colors.grey.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),

                // Verse text with auto-scaling
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.9,
                    ),
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: calculatedFontSize,
                        height: 1.4,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
