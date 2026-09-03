import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:cropsync/models/reel_model.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/reels_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/screens/creator/creator_home_screen.dart';

/// Ultra-Smooth, Instagram Reels / TikTok Style Fullscreen Feed
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  /// Static notifier so parent screens (HomeScreen) can notify tab visibility
  static final ValueNotifier<bool> isTabActive = ValueNotifier<bool>(false);

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
  bool _isVisible = false;

  // Video controller pool: only current ± 1 are kept alive
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializingIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _checkCreatorStatus();

    // 1. Instant Cache-First Load
    _loadReelsCacheFirst();

    // 2. Tab visibility listener
    _isVisible = ReelsScreen.isTabActive.value;
    ReelsScreen.isTabActive.addListener(_onTabVisibilityChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAllVideos();
    } else if (state == AppLifecycleState.resumed && _isVisible) {
      _playCurrentVideo();
    }
  }

  void _onTabVisibilityChanged() {
    final nowVisible = ReelsScreen.isTabActive.value;
    if (_isVisible == nowVisible) return;
    _isVisible = nowVisible;

    if (nowVisible) {
      // Warm up current and next immediately
      _preloadSurrounding(_focusedIndex);
      _playCurrentVideo();
    } else {
      _pauseAllVideos();
    }
  }

  @override
  void deactivate() {
    _pauseAllVideos();
    super.deactivate();
  }

  Future<void> _checkCreatorStatus() async {
    try {
      final isCreator = await AuthService.isCreator();
      if (mounted) {
        setState(() {
          _isCreator = isCreator;
        });
      }
    } catch (_) {}
  }

  void _handleReelDeleted(int index) {
    setState(() {
      final oldController = _controllers.remove(index);
      oldController?.dispose();
      _reels.removeAt(index);
      if (_focusedIndex >= _reels.length && _reels.isNotEmpty) {
        _focusedIndex = _reels.length - 1;
      }
    });
    if (_reels.isNotEmpty) {
      _preloadSurrounding(_focusedIndex);
      _playCurrentVideo();
    }
  }

  /// Instant display from cache, followed by silent network sync
  Future<void> _loadReelsCacheFirst() async {
    // Step 1: Load offline cache instantly (0ms render)
    final cached = await ReelsService.getCachedReels();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _reels = cached;
        _isLoading = false;
      });
      // Warm up controller 0 immediately
      _preloadSurrounding(0);
    }

    // Step 2: Fetch fresh data from backend
    try {
      final fresh = await ReelsService.getReels();
      if (!mounted) return;

      if (fresh.isNotEmpty) {
        setState(() {
          _reels = fresh;
          _isLoading = false;
          _hasError = false;
        });
        _preloadSurrounding(_focusedIndex);
      } else if (_reels.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (_reels.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Maintain an efficient sliding window of controllers (center ± 1)
  void _preloadSurrounding(int centerIndex) {
    if (_reels.isEmpty) return;

    final targetIndices = <int>[
      centerIndex,
      if (centerIndex + 1 < _reels.length) centerIndex + 1,
      if (centerIndex - 1 >= 0) centerIndex - 1,
    ];

    // Initialize required controllers
    for (final index in targetIndices) {
      if (!_controllers.containsKey(index) && !_initializingIndices.contains(index)) {
        _initControllerForIndex(index);
      }
    }

    // Play active controller, pause others
    for (final entry in _controllers.entries) {
      final idx = entry.key;
      final controller = entry.value;

      if (idx == centerIndex && _isVisible) {
        controller.setVolume(_isMuted ? 0.0 : 1.0);
        controller.setLooping(true);
        if (!controller.value.isPlaying) {
          controller.play();
        }
      } else {
        if (controller.value.isPlaying) {
          controller.pause();
        }
        controller.setVolume(0.0);
      }
    }

    // Clean up distant controllers (2+ pages away) to prevent memory leaks
    final toRemove = _controllers.keys
        .where((key) => (key - centerIndex).abs() > 1)
        .toList();

    for (final key in toRemove) {
      final controller = _controllers.remove(key);
      if (controller != null) {
        controller.pause();
        controller.dispose();
      }
    }
  }

  Future<void> _initControllerForIndex(int index) async {
    if (index < 0 || index >= _reels.length) return;
    if (_initializingIndices.contains(index)) return;
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
        _controllers[index] = controller;
        _initializingIndices.remove(index);

        if (index == _focusedIndex && _isVisible) {
          controller.setVolume(_isMuted ? 0.0 : 1.0);
          controller.play();
        } else {
          controller.pause();
          controller.setVolume(0.0);
        }

        // Only trigger rebuild if this is the active video needing presentation
        if (index == _focusedIndex) {
          setState(() {});
        }
      } else {
        controller.dispose();
      }
    } catch (_) {
      _initializingIndices.remove(index);
      controller.dispose();
    }
  }

  void _pauseAllVideos() {
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void _playCurrentVideo() {
    final controller = _controllers[_focusedIndex];
    if (controller != null && controller.value.isInitialized) {
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      controller.play();
    } else {
      _initControllerForIndex(_focusedIndex);
    }
  }

  void _onPageChanged(int index) {
    if (_focusedIndex == index) return;
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
    ReelsScreen.isTabActive.removeListener(_onTabVisibilityChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.pause();
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
              const SizedBox(height: 16),
              Text(
                'reels_loading'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError && _reels.isEmpty) {
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
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'reels_empty_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'reels_empty_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadReelsCacheFirst,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 480 : double.infinity,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Snappy, Smooth Page Snapping Physics
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const PageScrollPhysics(),
                  itemCount: _reels.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _AuthenticReelItem(
                    key: ValueKey('reel_${_reels[index].id}'),
                    reel: _reels[index],
                    isActive: index == _focusedIndex,
                    controller: _controllers[index],
                    isMuted: _isMuted,
                    onToggleMute: _toggleGlobalMute,
                    onReelChanged: (updated) => _onReelUpdated(index, updated),
                    onDeleteReel: () => _handleReelDeleted(index),
                  );
                },
              ),
            ),

              // Minimalist Top Bar (Transparent & Uncluttered)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Tag
                      Row(
                        children: [
                          Text(
                            'reels_tab'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.flash_on_rounded, color: Color(0xFF10B981), size: 18),
                        ],
                      ),

                      Row(
                        children: [
                          // Audio Mute Quick Toggle
                          IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                            onPressed: _toggleGlobalMute,
                            splashRadius: 20,
                          ),

                          // Creator Studio shortcut (if creator)
                          if (_isCreator) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => CreatorHomeScreen.navigateToStudio(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.video_call_rounded, color: Color(0xFF10B981), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Studio',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
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

/// Single Reel Presentation Unit with Authentic Instagram / TikTok Aesthetics
class _AuthenticReelItem extends StatefulWidget {
  final Reel reel;
  final bool isActive;
  final VideoPlayerController? controller;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final ValueChanged<Reel> onReelChanged;
  final VoidCallback? onDeleteReel;

  const _AuthenticReelItem({
    super.key,
    required this.reel,
    required this.isActive,
    this.controller,
    required this.isMuted,
    required this.onToggleMute,
    required this.onReelChanged,
    this.onDeleteReel,
  });

  @override
  State<_AuthenticReelItem> createState() => _AuthenticReelItemState();
}

class _AuthenticReelItemState extends State<_AuthenticReelItem> with TickerProviderStateMixin {
  bool _isPlaying = true;
  bool _showPlayPauseOverlay = false;
  bool _showHeartOverlay = false;
  bool _isCaptionExpanded = false;
  late Reel _currentReel;
  DateTime? _playStartTime;
  User? _currentUser;

  late AnimationController _heartAnimController;
  late AnimationController _discRotateController;

  @override
  void initState() {
    super.initState();
    _currentReel = widget.reel;
    _checkCurrentUser();

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _discRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (widget.isActive) {
      _playStartTime = DateTime.now();
    }
  }

  Future<void> _checkCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) setState(() => _currentUser = user);
    } catch (_) {}
  }

  bool _isOwnerOfCurrentReel() {
    if (_currentUser == null) return false;
    final currentPhone = (_currentUser!.phoneNumber ?? _currentUser!.userId).trim();
    final reelPhone = _currentReel.phoneNumber.trim();
    if (reelPhone.isNotEmpty && (reelPhone == currentPhone || currentPhone.endsWith(reelPhone) || reelPhone.endsWith(currentPhone))) return true;
    final creatorUser = _currentReel.creator.username.toLowerCase().trim();
    final myName = _currentUser!.name.toLowerCase().trim();
    final myId = _currentUser!.userId.toLowerCase().trim();
    if (creatorUser.isNotEmpty && (creatorUser == myName || creatorUser == myId)) return true;
    if (_currentUser!.isCreator && _currentReel.creator.displayName.toLowerCase().trim() == myName) return true;
    return false;
  }

  Future<void> _handleDeleteCurrentReel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Reel?'),
        content: const Text('Are you sure you want to delete this reel? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reelId = _currentReel.id;
      final success = await ReelsService.deleteReel(reelId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reel deleted successfully')),
          );
          if (widget.onDeleteReel != null) {
            widget.onDeleteReel!();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete reel. Try again.')),
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant _AuthenticReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reel != _currentReel) {
      _currentReel = widget.reel;
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _playStartTime = DateTime.now();
        _isPlaying = true;
        if (!_discRotateController.isAnimating) {
          _discRotateController.repeat();
        }
      } else {
        _logWatchDuration();
        _isPlaying = false;
        if (_discRotateController.isAnimating) {
          _discRotateController.stop();
        }
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
    _discRotateController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.lightImpact();
    if (controller.value.isPlaying) {
      controller.pause();
      setState(() {
        _isPlaying = false;
        _showPlayPauseOverlay = true;
      });
      _discRotateController.stop();
    } else {
      controller.play();
      setState(() {
        _isPlaying = true;
        _showPlayPauseOverlay = true;
      });
      _discRotateController.repeat();
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showPlayPauseOverlay = false;
        });
      }
    });
  }

  Future<void> _handleDoubleTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _showHeartOverlay = true);
    _heartAnimController.forward(from: 0.0);

    if (!_currentReel.hasLiked) {
      await _handleLikeToggle();
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _showHeartOverlay = false);
      }
    });
  }

  Future<void> _handleLikeToggle() async {
    HapticFeedback.lightImpact();
    final prevLiked = _currentReel.hasLiked;
    final prevRaw = _currentReel.likesRaw;
    final newLiked = !prevLiked;
    final newRaw = newLiked ? prevRaw + 1 : (prevRaw > 0 ? prevRaw - 1 : 0);

    final updated = _currentReel.copyWith(
      hasLiked: newLiked,
      likesRaw: newRaw,
      likes: _formatCount(newRaw),
    );

    setState(() => _currentReel = updated);
    widget.onReelChanged(updated);

    final result = await ReelsService.toggleLike(_currentReel.id);
    if (mounted && result['likes'] != null) {
      final synced = _currentReel.copyWith(
        hasLiked: result['hasLiked'] as bool? ?? newLiked,
        likes: result['likes'].toString(),
      );
      setState(() => _currentReel = synced);
      widget.onReelChanged(synced);
    }
  }

  Future<void> _handleSaveToggle() async {
    HapticFeedback.lightImpact();
    final prevSaved = _currentReel.hasSaved;
    final prevRaw = _currentReel.savesRaw;
    final newSaved = !prevSaved;
    final newRaw = newSaved ? prevRaw + 1 : (prevRaw > 0 ? prevRaw - 1 : 0);

    final updated = _currentReel.copyWith(
      hasSaved: newSaved,
      savesRaw: newRaw,
      saves: _formatCount(newRaw),
    );

    setState(() => _currentReel = updated);
    widget.onReelChanged(updated);

    await ReelsService.toggleSave(_currentReel.id);
  }

  Future<void> _handleWhatsAppShare() async {
    HapticFeedback.selectionClick();
    await ReelsService.logAction(_currentReel.id, 'share');

    final text = '🌾 *Watch this agri video by @${_currentReel.creator.username} on CropSync:*\n\n'
        '${_currentReel.caption.isNotEmpty ? _currentReel.caption : "Agricultural knowledge update"}\n\n'
        '📲 *Watch video:* ${_currentReel.videoUrl}';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          await SharePlus.instance.share(ShareParams(text: text));
        }
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  void _showCommentsBottomSheet() {
    HapticFeedback.lightImpact();
    final TextEditingController commentController = TextEditingController();
    List<ReelComment> comments = [];
    bool isLoadingComments = true;
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Load comments once
            if (isLoadingComments) {
              ReelsService.getComments(_currentReel.id).then((items) {
                if (context.mounted) {
                  setModalState(() {
                    comments = items;
                    isLoadingComments = false;
                  });
                }
              });
            }

            final sheetHeight = (comments.isEmpty && !isLoadingComments)
                ? 340.0
                : MediaQuery.of(context).size.height * 0.52;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: sheetHeight,
                decoration: const BoxDecoration(
                  color: Color(0xFF18181B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              child: Column(
                children: [
                  // Minimalist Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header with Count Badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Comments',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27272A),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                '${comments.length}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // Comment List or Refined Empty State
                  Expanded(
                    child: isLoadingComments
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          )
                        : comments.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Color(0xFF10B981),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No comments yet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Be the first to share your thoughts!',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: comments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final c = comments[index];
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        child: Text(
                                          c.farmerUsername.isNotEmpty ? c.farmerUsername[0].toUpperCase() : 'F',
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
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
                                                  c.farmerUsername,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  c.formattedTimeAgo,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.4),
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              c.commentText,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontSize: 13,
                                                height: 1.35,
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

                  // Quick Reaction Emoji Bar
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['❤️', '🌾', '👏', '🌱', '👍', '🔥'].map((emoji) {
                        return InkWell(
                          onTap: () {
                            commentController.text += emoji;
                            commentController.selection = TextSelection.fromPosition(
                              TextPosition(offset: commentController.text.length),
                            );
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // Unified Dark Capsule Input Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                          child: const Text(
                            'F',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.only(left: 14, right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: commentController,
                                    onChanged: (_) => setModalState(() {}),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    cursorColor: const Color(0xFF10B981),
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 13,
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: (isPosting || commentController.text.trim().isEmpty)
                                      ? null
                                      : () async {
                                          final text = commentController.text.trim();
                                          if (text.isEmpty) return;

                                          setModalState(() => isPosting = true);
                                          final newComment = await ReelsService.addComment(_currentReel.id, text);
                                          if (!context.mounted) return;

                                          setModalState(() {
                                            isPosting = false;
                                            if (newComment != null) {
                                              comments.insert(0, newComment);
                                              commentController.clear();
                                            }
                                          });

                                          if (newComment != null) {
                                            final updated = _currentReel.copyWith(
                                              commentsCount: comments.length,
                                            );
                                            setState(() => _currentReel = updated);
                                            widget.onReelChanged(updated);
                                          }
                                        },
                                  icon: isPosting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF10B981),
                                          ),
                                        )
                                      : Icon(
                                          Icons.arrow_upward_rounded,
                                          color: commentController.text.trim().isNotEmpty
                                              ? const Color(0xFF10B981)
                                              : Colors.white24,
                                          size: 20,
                                        ),
                                  splashRadius: 18,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
          },
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isInitialized = controller != null && controller.value.isInitialized;
    final hasContactPhone = _currentReel.phoneNumber.isNotEmpty || _currentReel.creator.phoneNumber.isNotEmpty;
    final contactNumber = _currentReel.phoneNumber.isNotEmpty ? _currentReel.phoneNumber : _currentReel.creator.phoneNumber;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Hardware-Accelerated Video Surface
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dark Background placeholder
              Container(color: Colors.black),

              // Fitted Fullscreen Video Player
              if (isInitialized)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              else
                const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Cinematic Vignette Gradients for Text Contrast
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.15, 0.50, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // 3. Elastic Heart Burst Overlay on Double Tap
        if (_showHeartOverlay)
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.3).animate(
                CurvedAnimation(
                  parent: _heartAnimController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFEF4444),
                size: 110,
                shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
              ),
            ),
          ),

        // 4. Play/Pause Overlay Indicator on Single Tap
        if (_showPlayPauseOverlay)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
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

        // 5. Bottom-Left Details Area (Creator, Contact Chip, Caption, Audio Track)
        Positioned(
          left: 14,
          bottom: 24,
          right: 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creator Row + Call Chip
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF10B981),
                    backgroundImage: _currentReel.creator.profileImageUrl.isNotEmpty
                        ? NetworkImage(_currentReel.creator.profileImageUrl)
                        : null,
                    child: _currentReel.creator.profileImageUrl.isEmpty
                        ? Text(
                            _currentReel.creator.displayName.isNotEmpty
                                ? _currentReel.creator.displayName[0].toUpperCase()
                                : 'F',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '@${_currentReel.creator.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                  if (_currentReel.creator.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Caption with clean expand toggle
              if (_currentReel.caption.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _isCaptionExpanded = !_isCaptionExpanded),
                  child: Text(
                    _currentReel.caption,
                    maxLines: _isCaptionExpanded ? 8 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Audio Track Indicator
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
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

        // 6. Right-side Floating Actions (Clean Instagram/TikTok layout)
        Positioned(
          right: 12,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call Button
              if (hasContactPhone) ...[
                _buildModernAction(
                  icon: Icons.call_rounded,
                  color: const Color(0xFF10B981),
                  label: 'Call',
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await ReelsService.logAction(_currentReel.id, 'call');
                    final Uri phoneUri = Uri(scheme: 'tel', path: contactNumber);
                    try {
                      await launchUrl(phoneUri);
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Like Button
              _buildModernAction(
                icon: _currentReel.hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _currentReel.hasLiked ? const Color(0xFFEF4444) : Colors.white,
                label: _currentReel.likes,
                onTap: _handleLikeToggle,
              ),

              const SizedBox(height: 16),

              // Comment Button
              _buildModernAction(
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                label: _currentReel.commentsCount.toString(),
                onTap: _showCommentsBottomSheet,
              ),

              const SizedBox(height: 16),

              // WhatsApp Share Button (Direct 1-tap green)
              _buildModernAction(
                icon: Icons.share_rounded,
                color: const Color(0xFF25D366),
                label: 'Share',
                onTap: _handleWhatsAppShare,
              ),

              const SizedBox(height: 16),

              // Save / Bookmark Button
              _buildModernAction(
                icon: _currentReel.hasSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _currentReel.hasSaved ? const Color(0xFFFBBF24) : Colors.white,
                label: 'Save',
                onTap: _handleSaveToggle,
              ),

              if (_isOwnerOfCurrentReel()) ...[
                const SizedBox(height: 16),
                _buildModernAction(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                  label: 'Delete',
                  onTap: _handleDeleteCurrentReel,
                ),
              ],

              const SizedBox(height: 16),

              // Rotating Music Disc
              AnimatedBuilder(
                animation: _discRotateController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _discRotateController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, size: 15, color: Color(0xFF10B981)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 7. Ultra-thin Non-blocking Bottom Progress Bar
        if (isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SlimReelProgressBar(controller: controller),
          ),
      ],
    );
  }

  Widget _buildModernAction({
    required IconData icon,
    required Color color,
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
            Icon(
              icon,
              color: color,
              size: 27,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ultra-Thin (1.5dp) Non-Rebuilding Progress Bar
class _SlimReelProgressBar extends StatelessWidget {
  final VideoPlayerController controller;

  const _SlimReelProgressBar({required this.controller});

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
          height: 1.8,
          color: Colors.white10,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              color: const Color(0xFF10B981),
            ),
          ),
        );
      },
    );
  }
}
