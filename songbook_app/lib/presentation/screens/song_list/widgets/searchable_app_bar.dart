import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// An [AppBar] whose title area morphs into a search field in place.
///
/// Search used to be a separate pushed route, which meant leaving the song
/// list to look through it and losing the bottom navigation on the way. Here
/// the field is revealed from the right edge — where the search icon sits — so
/// the icon reads as becoming the field, and the list underneath filters live.
///
/// The reveal is a width-factor clip rather than a cross-fade: the field keeps
/// its final layout throughout, so the cursor and text never reflow mid-
/// animation.
class SearchableAppBar extends StatefulWidget implements PreferredSizeWidget {
  /// Shown in the title slot while search is closed.
  final String title;

  /// Placed before the title. Ignored while search is open — the close
  /// affordance takes that slot.
  final Widget? leading;

  /// Trailing actions while search is closed. The search button is prepended
  /// to these, so it is the leftmost of the group.
  final List<Widget> actions;

  /// Current query, owned by the caller so it survives this widget's state.
  final String query;

  final ValueChanged<String> onQueryChanged;

  /// Called when the field is dismissed. The caller is expected to clear the
  /// query: a collapsed bar showing no text must not leave a filter applied,
  /// which is how an invisible query silently narrowed results before.
  final VoidCallback onSearchClosed;

  /// Fired when the field expands. The caller needs this to know that the list
  /// area should offer recent searches rather than the whole catalogue: an empty
  /// query while browsing and an empty query while searching are different
  /// states, and only this widget knows which one is in effect.
  final VoidCallback? onSearchOpened;

  /// Nullable so the default can be a *translated* string: a const default in
  /// the constructor cannot reach the localisations.
  final String? hintText;

  const SearchableAppBar({
    required this.title,
    required this.query,
    required this.onQueryChanged,
    required this.onSearchClosed,
    this.onSearchOpened,
    this.leading,
    this.actions = const [],
    this.hintText,
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SearchableAppBar> createState() => SearchableAppBarState();
}

class SearchableAppBarState extends State<SearchableAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  final _fieldController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fieldController.text = widget.query;
  }

  @override
  void didUpdateWidget(covariant SearchableAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The caller owns the query; mirror external resets (clear button, tag
    // navigation) without stomping on what is being typed.
    if (widget.query != _fieldController.text) {
      _fieldController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void open() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _controller.forward();
    widget.onSearchOpened?.call();
    // After the frame, not during it: the field does not exist until the
    // setState above has been built, so focusing here synchronously silently
    // does nothing — you had to tap the field before you could type, and on
    // mobile the keyboard never came up.
    // After the frame, not during it: the field does not exist until the
    // setState above has been built. Combined with `autofocus: true` on the
    // field itself — on Flutter web the framework-level focus alone does not
    // always attach the hidden DOM input, which left the bar open but
    // untypable until you clicked it (and on mobile, no keyboard).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// Puts [query] in the field, for a query chosen rather than typed — tapping a
  /// remembered search. The caller still owns the query; this only makes the field
  /// agree with it, and leaves the caret at the end so the query can be edited.
  void setQuery(String query) {
    _fieldController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  void close() {
    if (!_isOpen) return;
    _focusNode.unfocus();
    _fieldController.clear();
    _controller.reverse().then((_) {
      if (mounted) setState(() => _isOpen = false);
    });
    widget.onSearchClosed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      leading: _isOpen
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: close,
              tooltip: AppLocalizations.of(context).searchClose,
            )
          : widget.leading,
      titleSpacing: _isOpen ? 0 : null,
      title: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final t = _reveal.value;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Title yields early so it is gone well before the field
              // finishes arriving, instead of the two overlapping.
              Opacity(
                opacity: (1 - t * 2).clamp(0.0, 1.0),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (t > 0)
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: t,
                    child: Opacity(
                      opacity: t,
                      child: _buildField(context, theme),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      actions: _isOpen
          ? [
              if (widget.query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _fieldController.clear();
                    widget.onQueryChanged('');
                    _focusNode.requestFocus();
                  },
                  tooltip: AppLocalizations.of(context).actionClear,
                ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: open,
                tooltip: AppLocalizations.of(context).searchTooltip,
              ),
              ...widget.actions,
            ],
    );
  }

  Widget _buildField(BuildContext context, ThemeData theme) {
    return TextField(
      controller: _fieldController,
      focusNode: _focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: widget.hintText ?? AppLocalizations.of(context).searchHint,
        border: InputBorder.none,
        isCollapsed: true,
        hintStyle: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      onChanged: widget.onQueryChanged,
    );
  }
}
