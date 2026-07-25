import 'dart:async';
import 'dart:math' show sqrt, min;
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
  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  bool _controlsVisible = true;
  bool _projectionMode = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _projectionMode = ref.read(settingsRepositoryProvider).getProjectionMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    _hideTimer?.cancel();
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
    ref.read(settingsRepositoryProvider).setProjectionMode(_projectionMode);
    _showControls();
  }

  void _goToPage(int page) {
    final total = _totalPages;
    if (total == null || page < 0 || page >= total) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

  // Map digit keys to LogicalKeyboardKey
  static final _digitKeys = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final totalPages = _totalPages;
    if (totalPages == null) return KeyEventResult.ignored;

    // Number keys: jump to slide (1 = title/first page, 2 = verse 1, etc.)
    final digit = _digitKeys[event.logicalKey];
    if (digit != null) {
      _goToPage(digit - 1); // 1-indexed for user, 0-indexed internally
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _nextPage(totalPages);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
               event.logicalKey == LogicalKeyboardKey.pageUp) {
      _previousPage();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      _goToPage(0);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _goToPage(totalPages - 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int? _totalPages;

  /// Compute a consistent font size across all verses that maximizes text size.
  ///
  /// For multi-line verses (with \n breaks): constrained by longest line width + total height.
  /// For single-paragraph verses (no breaks): uses area formula accounting for text wrapping.
  /// Returns the minimum across all verses so every verse fits at the same size.
  double _computeConsistentFontSize(
    List<Verse> verses,
    double availableWidth,
    double availableHeight,
    double minFont,
    double maxFont,
    int totalVerses,
  ) {
    const charWidthFactor = 0.48;
    const lineHeightFactor = 1.3;
    double result = maxFont;

    for (final verse in verses) {
      final text = verse.displayText.isNotEmpty ? verse.displayText : '...';
      final lines = text.split('\n');
      final prefixChars = totalVerses > 1 ? '${verse.number}. '.length : 0;

      double verseFontSize;

      if (lines.length > 1) {
        // Multi-line verse with explicit breaks: width + height constraints
        int maxLineLen = 0;
        for (int i = 0; i < lines.length; i++) {
          int len = lines[i].length;
          if (i == 0) len += prefixChars;
          if (len > maxLineLen) maxLineLen = len;
        }
        if (maxLineLen == 0) continue;

        final fWidth = availableWidth / (maxLineLen * charWidthFactor);
        final fHeight = availableHeight / (lines.length * lineHeightFactor);
        verseFontSize = min(fWidth, fHeight);
      } else {
        // Single paragraph (no line breaks): area formula for wrapping text
        // At font f, chars per visual line = availableWidth / (f * charWidth)
        // Visual lines = totalChars / charsPerLine = totalChars * f * charWidth / availableWidth
        // Total height = visualLines * f * lineHeight
        // Solving: totalChars * f^2 * charWidth * lineHeight / availableWidth <= availableHeight
        // f <= sqrt(availableWidth * availableHeight / (totalChars * charWidth * lineHeight))
        final totalChars = text.length + prefixChars;
        if (totalChars == 0) continue;
        verseFontSize = sqrt(
          availableWidth * availableHeight / (totalChars * charWidthFactor * lineHeightFactor),
        );
      }

      if (verseFontSize < result) result = verseFontSize;
    }

    return result.clamp(minFont, maxFont);
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByNumberProvider(widget.songNumber));
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    final Color bgColor;
    final Color textColor;
    if (_projectionMode) {
      bgColor = Colors.black;
      textColor = Colors.white;
    } else {
      bgColor = theme.scaffoldBackgroundColor;
      textColor = theme.textTheme.bodyLarge?.color ?? (isDarkTheme ? Colors.white : Colors.black);
    }

    return songAsync.when(
      data: (song) {
        if (song == null) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(child: Text('Song not found', style: TextStyle(color: textColor))),
          );
        }

        final totalVerses = song.verses.length;
        final pages = <Widget>[
          _buildTitleCard(song.title, song.number, textColor),
          ...song.verses.map((verse) => _buildVersePage(
            verse, song, totalVerses, textColor,
          )),
        ];

        final totalPages = pages.length;
        _totalPages = totalPages;

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Stack(
                children: [
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

                          if (tapX < screenWidth / 3) {
                            _previousPage();
                          } else if (tapX > 2 * screenWidth / 3) {
                            _nextPage(totalPages);
                          } else {
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
                      child: _buildControlsOverlay(song, totalPages),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error', style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(Song song, int totalPages) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Stack(
      children: [
        // Top bar: Exit + Title + Projection toggle
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Exit (Esc)',
                ),
                Expanded(
                  child: Text(
                    '${song.number}. ${song.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _projectionMode ? Icons.wb_sunny : Icons.nightlight_round,
                    color: Colors.white,
                  ),
                  onPressed: _toggleProjectionMode,
                  tooltip: _projectionMode ? 'Normal mode' : 'Projection mode',
                ),
              ],
            ),
          ),
        ),

        // Page indicator (bottom)
        if (totalPages > 1)
          Positioned(
            bottom: 16,
            left: isLandscape ? null : 0,
            right: isLandscape ? 16 : 0,
            child: isLandscape
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentPage + 1} / $totalPages',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  )
                : Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentPage + 1} / $totalPages',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildTitleCard(String title, int number, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number.',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w300, color: textColor),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersePage(Verse verse, Song song, int totalVerses, Color textColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final orientation = MediaQuery.of(context).orientation;
        final isLandscape = orientation == Orientation.landscape;

        // Minimal padding to maximize text area
        final horizontalPadding = isLandscape ? screenWidth * 0.08 : 12.0;

        // Use nearly all available width
        final availableWidth = screenWidth - (horizontalPadding * 2);
        // Reserve space for top controls bar (~60px) + bottom indicator (~50px) + margins
        final availableHeight = screenHeight - 130;

        final minFontSize = screenWidth < 600 ? 24.0 : 36.0;
        final maxFontSize = screenWidth < 600 ? 96.0 : 160.0;

        // Consistent font size across all verses
        final fontSize = _computeConsistentFontSize(
          song.verses, availableWidth, availableHeight, minFontSize, maxFontSize, totalVerses,
        );

        final displayText = verse.displayText.isNotEmpty ? verse.displayText : '...';
        final lines = displayText.split('\n');

        // Prepend verse number to first line
        final formattedLines = <String>[];
        for (int i = 0; i < lines.length; i++) {
          if (i == 0 && totalVerses > 1) {
            formattedLines.add('${verse.number}. ${lines[i]}');
          } else {
            formattedLines.add(lines[i]);
          }
        }
        final formattedText = formattedLines.join('\n');

        final verseContent = FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: availableWidth),
            child: Text(
              formattedText,
              style: TextStyle(fontSize: fontSize, height: 1.3, color: textColor),
              textAlign: TextAlign.center,
            ),
          ),
        );

        // Top padding avoids overlap with controls bar
        return Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: 60,
            bottom: 50,
          ),
          child: Center(child: verseContent),
        );
      },
    );
  }
}
