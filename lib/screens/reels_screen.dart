import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  int _focusedIndex = 0;

  final List<Map<String, String>> _reelsData = [
    {
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'username': 'ramesh_kalyan',
      'caption': 'Harvesting organic rice using modern machinery. Crop yield is exceptional this season! 🌾 #organicfarming #riceharvest #agritech',
      'music': 'Original Audio - Ramesh Kalyan',
      'likes': '1.2K',
      'commentsCount': '45',
      'phone': '+919876543210',
    },
    {
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      'username': 'agri_tech_india',
      'caption': 'Drip irrigation system setup in my tomato field. Highly water-efficient! 🍅💧 #savewater #irrigation #tomatofarming',
      'music': 'Nature Sounds - Water Flow',
      'likes': '890',
      'commentsCount': '28',
      'phone': '+919876543211',
    },
    {
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      'username': 'suresh_village_boy',
      'caption': 'Best organic pest control spray demo using neem oil. Safe and chemical-free! 🌱🐛 #organicpestcontrol #sustainableagri',
      'music': 'Original Audio - Suresh Kumar',
      'likes': '2.1K',
      'commentsCount': '98',
      'phone': '+919876543212',
    },
    {
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      'username': 'organic_ananya',
      'caption': 'Preparing natural compost manure using cow dung and leaves. Farm prep is in full swing! 🚜🍂 #composting #organicfertilizer',
      'music': 'Morning Flute Melody',
      'likes': '1.5K',
      'commentsCount': '64',
      'phone': '+919876543213',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reelsData.length,
        onPageChanged: (index) {
          setState(() {
            _focusedIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return ReelItem(
            data: _reelsData[index],
            isActive: index == _focusedIndex,
          );
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, String> data;
  final bool isActive;

  const ReelItem({
    super.key,
    required this.data,
    required this.isActive,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _showPlayPauseOverlay = false;
  bool _showHeartOverlay = false;
  bool _hasError = false;

  final List<String> _comments = [
    'Super helpful video! 🌾',
    'Which fertilizer did you use?',
    'Good work brother 👍',
    'Where is this machine available?',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _hasError = false;
      _isInitialized = false;
    });
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.data['videoUrl']!));
    _videoController.addListener(_videoListener);
    try {
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _videoController.setLooping(true);
          if (widget.isActive) {
            _videoController.play();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _videoListener() {
    if (_videoController.value.hasError && mounted) {
      setState(() => _hasError = true);
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized && !_hasError) {
      if (widget.isActive) {
        _videoController.play();
        setState(() => _isPlaying = true);
      } else {
        _videoController.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _videoController.pause();
        _isPlaying = false;
      } else {
        _videoController.play();
        _isPlaying = true;
      }
      _showPlayPauseOverlay = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showPlayPauseOverlay = false;
        });
      }
    });
  }

  void _toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _handleDoubleTap() {
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        _showHeartOverlay = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showHeartOverlay = false;
          });
        }
      });
    } else {
      setState(() {
        _showHeartOverlay = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showHeartOverlay = false;
          });
        }
      });
    }
  }

  void _showCommentsBottomSheet() {
    final TextEditingController commentInputController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              _comments[index],
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentInputController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.white30),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.green),
                            onPressed: () {
                              if (commentInputController.text.trim().isNotEmpty) {
                                setState(() {
                                  _comments.add(commentInputController.text.trim());
                                });
                                setModalState(() {
                                  commentInputController.clear();
                                });
                              }
                            },
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player Background
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _handleDoubleTap,
          child: _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('reels_error_load'),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _initializeVideo,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.tr('reels_retry')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                )
              : _isInitialized
                  ? SizedOverflowBox(
                      size: Size.infinite,
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController.value.size.width,
                          height: _videoController.value.size.height,
                          child: VideoPlayer(_videoController),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    ),
        ),

        // Gradient overlay for better text readability
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
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 300),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.red,
                    size: 100,
                  ),
                );
              },
            ),
          ),

        // Play/Pause Overlay Indicator on single tap
        if (_showPlayPauseOverlay)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),

        // Left Information Area
        Positioned(
          left: 16,
          bottom: 24,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '@${widget.data['username']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.tr('reels_follow'),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.data['caption']!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),

        // Right Floating Action Column
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call Action
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.call_rounded,
                  color: Colors.greenAccent,
                  size: 32,
                ),
                onPressed: () async {
                  final String? phone = widget.data['phone'];
                  if (phone != null && phone.isNotEmpty) {
                    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                    try {
                      await launchUrl(phoneUri);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open dialer: $e')),
                        );
                      }
                    }
                  }
                },
              ),
              Text(context.tr('reels_call'), style: const TextStyle(color: Colors.white, fontSize: 11)),
              const SizedBox(height: 20),

              // Like Action
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  color: _isLiked ? Colors.red : Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _isLiked = !_isLiked;
                  });
                },
              ),
              Text(
                _isLiked ? '1.3K' : widget.data['likes']!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              const SizedBox(height: 20),

              // Comment Action
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _showCommentsBottomSheet,
              ),
              Text(
                widget.data['commentsCount']!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              const SizedBox(height: 20),

              // Share Action
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  // ignore: deprecated_member_use
                  Share.share('Check out this agro reel by @${widget.data['username']}: ${widget.data['videoUrl']}');
                },
              ),
              Text(context.tr('reels_share'), style: const TextStyle(color: Colors.white, fontSize: 11)),
              const SizedBox(height: 20),

              // Mute/Volume Action
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _toggleMute,
              ),
              Text(
                _isMuted ? context.tr('reels_muted') : context.tr('reels_sound'),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              const SizedBox(height: 20),

              // Save Action
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isSaved ? Colors.yellow : Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _isSaved = !_isSaved;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isSaved ? context.tr('reels_saved_snack') : context.tr('reels_unsaved_snack')),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              Text(context.tr('reels_save'), style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}
