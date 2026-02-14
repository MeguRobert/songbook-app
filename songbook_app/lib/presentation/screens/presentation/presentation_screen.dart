import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/song.dart';
import '../../../data/models/verse.dart';
import '../../providers/providers.dart';
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
    // Load projection mode preference
    _projectionMode = ref.read(settingsRepositoryProvider).getProjectionMode();
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
    // Persist preference
    ref.read(settingsRepositoryProvider).setProjectionMode(_projectionMode);
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
        final totalVerses = song.verses.length;
        final pages = <Widget>[
          // Title card (first page)
          _buildTitleCard(song.title, song.number),
          // Verse pages
          ...song.verses.map((verse) => _buildVersePage(verse, song, totalVerses)),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final orientation = MediaQuery.of(context).orientation;
                        final isLandscape = orientation == Orientation.landscape;

                        return Stack(
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

                            // Page indicator (bottom center in portrait, bottom-right in landscape)
                            Positioned(
                              bottom: 16,
                              left: isLandscape ? null : 0,
                              right: isLandscape ? 16 : 0,
                              child: isLandscape
                                  ? Container(
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
                                    )
                                  : Center(
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
                        );
                      },
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

  Widget _buildVersePage(Verse verse, Song song, int totalVerses) {
    final textColor = _projectionMode ? Colors.white : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final orientation = MediaQuery.of(context).orientation;
        final isLandscape = orientation == Orientation.landscape;

        // Determine screen category for responsive layout
        final isPhone = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;
        // Desktop/Projection: >= 1024

        // Responsive padding
        final horizontalPadding = isPhone ? 16.0 : (isTablet ? 32.0 : 64.0);
        final verticalPadding = isPhone ? 24.0 : (isTablet ? 48.0 : 64.0);

        // Landscape: center text in middle ~60% of width
        final effectivePadding = isLandscape
            ? EdgeInsets.symmetric(
                horizontal: screenWidth * 0.2,
                vertical: verticalPadding,
              )
            : EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              );

        // Calculate available text area
        final availableWidthFactor = isPhone ? 0.9 : (isTablet ? 0.85 : 0.8);
        final availableWidth = (isLandscape ? screenWidth * 0.6 : screenWidth) * availableWidthFactor;

        // Responsive font size clamping
        final minFontSize = isPhone ? 20.0 : (isTablet ? 28.0 : 36.0);
        final maxFontSize = isPhone ? 72.0 : (isTablet ? 96.0 : 120.0);

        final displayText = verse.displayText.isNotEmpty ? verse.displayText : '...';
        final lines = displayText.split('\n');

        // Calculate longest line for auto-scaling
        int maxLineLength = 0;
        for (final line in lines) {
          if (line.length > maxLineLength) {
            maxLineLength = line.length;
          }
        }

        // Auto-scale font based on available width and longest line
        double calculatedFontSize = maxLineLength > 0
            ? availableWidth / (maxLineLength * 0.55)
            : 48.0;
        calculatedFontSize = calculatedFontSize.clamp(minFontSize, maxFontSize);

        // Check if text is too tall and needs scrolling
        final estimatedTextHeight = lines.length * calculatedFontSize * 1.4;
        final needsScrolling = estimatedTextHeight > (screenHeight - verticalPadding * 2 - 80);

        final verseContent = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Song title context (subtle, fades with controls)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                '${song.number}. ${song.title}',
                style: TextStyle(
                  fontSize: verse.number == 1 ? 16.0 : 14.0,
                  fontWeight: verse.number == 1 ? FontWeight.w500 : FontWeight.w400,
                  color: textColor?.withValues(alpha: verse.number == 1 ? 0.7 : 0.5) ??
                         Colors.grey.withValues(alpha: verse.number == 1 ? 0.7 : 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: verse.number == 1 ? 24 : 16),

            // Verse number indicator (subtle) - hide if only 1 verse
            if (totalVerses > 1)
              Padding(
                padding: EdgeInsets.only(
                  bottom: isLandscape ? 8.0 : 16.0,
                ),
                child: Text(
                  '${verse.number}',
                  style: TextStyle(
                    fontSize: calculatedFontSize * 0.4,
                    fontWeight: FontWeight.w300,
                    color: textColor?.withValues(alpha: 0.6) ??
                           Colors.grey.withValues(alpha: 0.6),
                  ),
                ),
              ),

            // Verse text with auto-scaling
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: availableWidth,
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
        );

        return needsScrolling
            ? SingleChildScrollView(
                child: Padding(
                  padding: effectivePadding,
                  child: Center(
                    child: verseContent,
                  ),
                ),
              )
            : Center(
                child: Padding(
                  padding: effectivePadding,
                  child: verseContent,
                ),
              );
      },
    );
  }
}
