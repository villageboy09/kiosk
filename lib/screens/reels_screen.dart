import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:cropsync/models/reel_model.dart';
import 'package:cropsync/services/reels_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/screens/creator/creator_home_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late final PageController _pageController;
  int _focusedIndex = 0;
  List<Reel> _reels = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCreator = false;
  bool _isMuted = false;

  // Video controller pool: caches active index, index+1, and index-1 for instant 0ms playback
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializingIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _checkCreatorStatus();
    _loadReels();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseCurrentVideo();
    } else if (state == AppLifecycleState.resumed) {
      _playCurrentVideo();
    }
  }

  Future<void> _checkCreatorStatus() async {
    final isCreator = await AuthService.isCreator();
    if (mounted) {
      setState(() {
        _isCreator = isCreator;
      });
    }
  }

  Future<void> _loadReels() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final reels = await ReelsService.getReels();
      if (mounted) {
        setState(() {
          _reels = reels;
          _isLoading = false;
        });

        if (_reels.isNotEmpty) {
          _preloadSurrounding(0);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _preloadSurrounding(int centerIndex) {
    if (_reels.isEmpty) return;

    // Indices to keep warm: previous, current, next
    final targetIndices = [
      centerIndex,
      if (centerIndex + 1 < _reels.length) centerIndex + 1,
      if (centerIndex - 1 >= 0) centerIndex - 1,
    ];

    // 1. Initialize needed controllers
    for (final index in targetIndices) {
      if (!_controllers.containsKey(index) && !_initializingIndices.contains(index)) {
        _initControllerForIndex(index);
      }
    }

    // 2. Play active video & pause surrounding preloaded videos
    for (final entry in _controllers.entries) {
      final idx = entry.key;
      final controller = entry.value;

      if (idx == centerIndex) {
        controller.setVolume(_isMuted ? 0.0 : 1.0);
        controller.setLooping(true);
        controller.play();
      } else {
        controller.pause();
        controller.setVolume(0.0);
      }
    }

    // 3. Gracefully dispose distant controllers in background to prevent memory buildup
    final toRemove = _controllers.keys
        .where((key) => (key - centerIndex).abs() > 1)
        .toList();

    for (final key in toRemove) {
      final controller = _controllers.remove(key);
      Future.microtask(() {
        controller?.pause();
        controller?.dispose();
      });
    }
  }

  Future<void> _initControllerForIndex(int index) async {
    if (index < 0 || index >= _reels.length) return;
    _initializingIndices.add(index);

    final reel = _reels[index];
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(reel.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await controller.initialize();
      controller.setLooping(true);

      if (mounted) {
        setState(() {
          _controllers[index] = controller;
          _initializingIndices.remove(index);

          // If this is the active index, start playing immediately
          if (index == _focusedIndex) {
            controller.setVolume(_isMuted ? 0.0 : 1.0);
            controller.play();
          } else {
            controller.pause();
            controller.setVolume(0.0);
          }
        });
      } else {
        controller.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializingIndices.remove(index);
        });
      }
      controller.dispose();
    }
  }

  void _pauseCurrentVideo() {
    final controller = _controllers[_focusedIndex];
    if (controller != null && controller.value.isInitialized) {
      controller.pause();
    }
  }

  void _playCurrentVideo() {
    final controller = _controllers[_focusedIndex];
    if (controller != null && controller.value.isInitialized) {
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      controller.play();
    }
  }

  void _onPageChanged(int index) {
    if (_focusedIndex == index) return;

    // Immediately update index and preload surrounding videos
    setState(() {
      _focusedIndex = index;
    });

    _preloadSurrounding(index);
  }

  void _toggleGlobalMute() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });

    final activeController = _controllers[_focusedIndex];
    activeController?.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _onReelUpdated(int index, Reel updatedReel) {
    if (index >= 0 && index < _reels.length) {
      setState(() {
        _reels[index] = updatedReel;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'reels_loading'.tr(args: [], gender: null) == 'reels_loading'
                    ? 'Loading Agri Reels...'
                    : 'reels_loading'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError || _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white60,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _hasError ? 'reels_error_load'.tr() : 'No Reels Available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore farming tips, pest remedies, and agro machinery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadReels,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('reels_retry'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 500 : double.infinity,
          ),
          child: Stack(
            children: [
              // Snappy, silky-smooth PageView with preloaded buffer items
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const PageScrollPhysics(
                  parent: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                ),
                allowImplicitScrolling: true,
                padEnds: false,
                itemCount: _reels.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return ReelItem(
                    key: ValueKey('reel_${_reels[index].id}'),
                    reel: _reels[index],
                    isActive: index == _focusedIndex,
                    controller: _controllers[index],
                    isMuted: _isMuted,
                    onToggleMute: _toggleGlobalMute,
                    onReelChanged: (updated) => _onReelUpdated(index, updated),
                  );
                },
              ),

              // Header bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Krishi Reels',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isCreator)
                        InkWell(
                          onTap: () => CreatorHomeScreen.navigateToStudio(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.video_call_rounded, color: AppTheme.accentGreen, size: 18),
                                SizedBox(width: 5),
                                Text(
                                  'Studio',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Reel reel;
  final bool isActive;
  final VideoPlayerController? controller;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final ValueChanged<Reel> onReelChanged;

  const ReelItem({
    super.key,
    required this.reel,
    required this.isActive,
    this.controller,
    required this.isMuted,
    required this.onToggleMute,
    required this.onReelChanged,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  bool _showPlayPauseOverlay = false;
  bool _showHeartOverlay = false;
  late Reel _currentReel;
  DateTime? _playStartTime;
  late AnimationController _heartAnimController;

  @override
  void initState() {
    super.initState();
    _currentReel = widget.reel;
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.isActive) {
      _playStartTime = DateTime.now();
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reel != _currentReel) {
      setState(() {
        _currentReel = widget.reel;
      });
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _playStartTime = DateTime.now();
        setState(() {
          _isPlaying = true;
        });
      } else {
        _logWatchDuration();
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _logWatchDuration() {
    if (_playStartTime != null) {
      final seconds = DateTime.now().difference(_playStartTime!).inSeconds;
      if (seconds >= 1) {
        final duration = widget.controller?.value.duration.inSeconds ?? 0;
        final isCompleted = duration > 0 && seconds >= duration;
        ReelsService.logWatch(_currentReel.id, seconds, isCompleted);
      }
      _playStartTime = null;
    }
  }

  @override
  void dispose() {
    _logWatchDuration();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.selectionClick();
    if (controller.value.isPlaying) {
      controller.pause();
      setState(() {
        _isPlaying = false;
        _showPlayPauseOverlay = true;
      });
    } else {
      controller.play();
      setState(() {
        _isPlaying = true;
        _showPlayPauseOverlay = true;
      });
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showPlayPauseOverlay = false;
        });
      }
    });
  }

  Future<void> _handleDoubleTap() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _showHeartOverlay = true;
    });
    _heartAnimController.forward(from: 0.0);

    if (!_currentReel.hasLiked) {
      await _handleLikeToggle();
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeartOverlay = false;
        });
      }
    });
  }

  Future<void> _handleLikeToggle() async {
    HapticFeedback.lightImpact();
    final previousLiked = _currentReel.hasLiked;
    final previousRaw = _currentReel.likesRaw;
    final newLiked = !previousLiked;
    final newRaw = newLiked ? previousRaw + 1 : (previousRaw > 0 ? previousRaw - 1 : 0);

    final updated = _currentReel.copyWith(
      hasLiked: newLiked,
      likesRaw: newRaw,
      likes: _formatCount(newRaw),
    );

    setState(() {
      _currentReel = updated;
    });
    widget.onReelChanged(updated);

    final result = await ReelsService.toggleLike(_currentReel.id);
    if (mounted && result['likes'] != null) {
      final synced = _currentReel.copyWith(
        hasLiked: result['hasLiked'] as bool? ?? newLiked,
        likes: result['likes'].toString(),
        likesRaw: result['likesRaw'] is int ? result['likesRaw'] as int : newRaw,
      );
      setState(() {
        _currentReel = synced;
      });
      widget.onReelChanged(synced);
    }
  }

  Future<void> _handleSaveToggle() async {
    HapticFeedback.lightImpact();
    final previousSaved = _currentReel.hasSaved;
    final previousRaw = _currentReel.savesRaw;
    final newSaved = !previousSaved;
    final newRaw = newSaved ? previousRaw + 1 : (previousRaw > 0 ? previousRaw - 1 : 0);

    final updated = _currentReel.copyWith(
      hasSaved: newSaved,
      savesRaw: newRaw,
      saves: _formatCount(newRaw),
    );

    setState(() {
      _currentReel = updated;
    });
    widget.onReelChanged(updated);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newSaved ? 'reels_saved_snack'.tr() : 'reels_unsaved_snack'.tr()),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await ReelsService.toggleSave(_currentReel.id);
    if (mounted && result['saves'] != null) {
      final synced = _currentReel.copyWith(
        hasSaved: result['hasSaved'] as bool? ?? newSaved,
        saves: result['saves'].toString(),
        savesRaw: result['savesRaw'] is int ? result['savesRaw'] as int : newRaw,
      );
      setState(() {
        _currentReel = synced;
      });
      widget.onReelChanged(synced);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _showCommentsBottomSheet() {
    final TextEditingController commentInputController = TextEditingController();
    List<ReelComment> sheetComments = List.from(_currentReel.comments);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.60,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${'reels_comments'.tr()} (${sheetComments.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    Expanded(
                      child: sheetComments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded,
                                      color: Colors.white30, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No comments yet. Be the first to comment!',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: sheetComments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final comment = sheetComments[index];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.2),
                                      child: Text(
                                        comment.farmerUsername.isNotEmpty
                                            ? comment.farmerUsername[0].toUpperCase()
                                            : 'F',
                                        style: const TextStyle(
                                          color: AppTheme.accentGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                comment.farmerUsername,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '• ${comment.formattedTimeAgo}',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.4),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            comment.commentText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Center(
                                child: TextField(
                                  controller: commentInputController,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'reels_add_comment'.tr(),
                                    hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.accentGreen,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              onPressed: () async {
                                final text = commentInputController.text.trim();
                                if (text.isNotEmpty) {
                                  HapticFeedback.lightImpact();
                                  commentInputController.clear();
                                  final newComment = await ReelsService.addComment(_currentReel.id, text);
                                  if (newComment != null) {
                                    setModalState(() {
                                      sheetComments.add(newComment);
                                    });

                                    final updatedReel = _currentReel.copyWith(
                                      commentsCount: sheetComments.length,
                                      comments: sheetComments,
                                    );

                                    setState(() {
                                      _currentReel = updatedReel;
                                    });
                                    widget.onReelChanged(updatedReel);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isInitialized = controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // High-Performance Smooth Video Surface with Instant Cover
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Placeholder gradient & branding while video buffers
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.15,
                    child: Icon(
                      Icons.agriculture_rounded,
                      size: 120,
                      color: AppTheme.accentGreen.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),

              // 2. Hardware-accelerated Video Player with smooth crossfade
              if (isInitialized)
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),
                )
              else
                const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Gradient overlays for text readability
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black45,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.18, 0.55, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // Animated Heart Overlay on double tap
        if (_showHeartOverlay)
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 1.25).animate(
                CurvedAnimation(
                  parent: _heartAnimController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 110,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 16),
                ],
              ),
            ),
          ),

        // Play/Pause Overlay Indicator on single tap
        if (_showPlayPauseOverlay)
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),

        // Left Information Area (Creator, Caption, Music)
        Positioned(
          left: 16,
          bottom: 28,
          right: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creator Row
              Row(
                children: [
                  ClipOval(
                    child: Container(
                      width: 38,
                      height: 38,
                      color: AppTheme.accentGreen.withValues(alpha: 0.25),
                      alignment: Alignment.center,
                      child: _currentReel.creator.profileImageUrl.isNotEmpty
                          ? Image.network(
                              _currentReel.creator.profileImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                            )
                          : _buildAvatarFallback(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _currentReel.creator.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                                ),
                              ),
                            ),
                            if (_currentReel.creator.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppTheme.accentGreen,
                                size: 15,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@${_currentReel.creator.username}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11.5,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Caption
              Text(
                _currentReel.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 8),
              // Music Title
              Row(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _currentReel.musicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right Floating Action Column (Call, Like, Comment, Share, Sound, Save)
        Positioned(
          right: 14,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call Action
              if (_currentReel.phoneNumber.isNotEmpty || _currentReel.creator.phoneNumber.isNotEmpty) ...[
                _buildActionButton(
                  icon: Icons.call_rounded,
                  iconColor: AppTheme.accentGreen,
                  label: 'reels_call'.tr(),
                  onTap: () async {
                    final phone = _currentReel.phoneNumber.isNotEmpty
                        ? _currentReel.phoneNumber
                        : _currentReel.creator.phoneNumber;
                    if (phone.isNotEmpty) {
                      await ReelsService.logAction(_currentReel.id, 'call');
                      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                      try {
                        await launchUrl(phoneUri);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('reels_dialer_error'.tr())),
                          );
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Like Action
              _buildActionButton(
                icon: _currentReel.hasLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                iconColor: _currentReel.hasLiked ? Colors.redAccent : Colors.white,
                label: _currentReel.likes,
                onTap: _handleLikeToggle,
              ),
              const SizedBox(height: 16),

              // Comment Action
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: Colors.white,
                label: _currentReel.commentsCount.toString(),
                onTap: _showCommentsBottomSheet,
              ),
              const SizedBox(height: 16),

              // Share Action
              _buildActionButton(
                icon: Icons.share_rounded,
                iconColor: Colors.white,
                label: 'reels_share'.tr(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ReelsService.logAction(_currentReel.id, 'share');
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          '🌾 Watch this agro reel by @${_currentReel.creator.username}: "${_currentReel.caption}" on CropSync App!\n\nVideo: ${_currentReel.videoUrl}',
                      subject: 'CropSync Agro Reel',
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Mute/Volume Action
              _buildActionButton(
                icon: widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                iconColor: Colors.white,
                label: widget.isMuted ? 'reels_muted'.tr() : 'reels_sound'.tr(),
                onTap: widget.onToggleMute,
              ),
              const SizedBox(height: 16),

              // Save Action
              _buildActionButton(
                icon: _currentReel.hasSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                iconColor: _currentReel.hasSaved ? Colors.amberAccent : Colors.white,
                label: 'reels_save'.tr(),
                onTap: _handleSaveToggle,
              ),
            ],
          ),
        ),

        // Decoupled Bottom Progress Bar (Prevents full widget tree rebuilds)
        if (isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ReelProgressBar(controller: controller),
          ),
      ],
    );
  }

  Widget _buildAvatarFallback() {
    return Text(
      _currentReel.creator.displayName.isNotEmpty
          ? _currentReel.creator.displayName[0].toUpperCase()
          : 'F',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decoupled Lightweight Progress Bar to prevent rebuilding parent widget on video progress ticks
class _ReelProgressBar extends StatelessWidget {
  final VideoPlayerController controller;

  const _ReelProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (!value.isInitialized || value.duration.inMilliseconds == 0) {
          return const SizedBox.shrink();
        }

        final progress = (value.position.inMilliseconds / value.duration.inMilliseconds)
            .clamp(0.0, 1.0);

        return Container(
          height: 2.5,
          color: Colors.white10,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              color: AppTheme.accentGreen,
            ),
          ),
        );
      },
    );
  }
}


