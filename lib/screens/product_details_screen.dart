// lib/screens/product_details_screen.dart

import 'package:cropsync/main.dart';
import 'package:cropsync/screens/agri_shop.dart'; // Import the Product model
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page?.round() ?? 0;
        });
      }
    });

    if (widget.product.videoUrl != null) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.product.videoUrl!));
      _videoController!.initialize().then((_) {
        if (mounted) {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: false,
            looping: false,
          );
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<String> get imageUrls => [
        widget.product.imageUrl1,
        widget.product.imageUrl2,
        widget.product.imageUrl3,
      ].whereType<String>().toList();

  bool get hasVideo =>
      _videoController != null && _videoController!.value.isInitialized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildMediaAppBar(),
          _buildProductInfo(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  SliverAppBar _buildMediaAppBar() {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.4,
      pinned: true,
      floating: false,
      stretch: true,
      backgroundColor: Colors.grey.shade100,
      elevation: 0,
      leading: Center(
        child: InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // FIX: Replaced deprecated withOpacity
              color: Colors.white.withAlpha(180),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'product_image_${widget.product.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo)
                Chewie(controller: _chewieController!)
              else if (imageUrls.isNotEmpty)
                PageView.builder(
                  controller: _pageController,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) => CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(Icons.eco_outlined, color: Colors.grey.shade300, size: 80),
              if (imageUrls.length > 1 && !hasVideo)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      imageUrls.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
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

  SliverToBoxAdapter _buildProductInfo() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.category,
              style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.name,
              style: GoogleFonts.lexend(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.store_mall_directory_outlined,
                    color: Colors.grey.shade500, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Sold by: ${widget.product.advertiserName}',
                  style: GoogleFonts.lexend(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.description,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price',
                    style: GoogleFonts.lexend(
                        color: Colors.grey.shade500, fontSize: 12)),
                Text('₹${widget.product.price}',
                    style: GoogleFonts.lexend(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _showPurchaseRequestBottomSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Request Purchase',
                  style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseRequestBottomSheet() {
    int quantity = 1;
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    double totalPrice = double.parse(widget.product.price);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            void updateQuantity(int newQuantity) {
              if (newQuantity < 1) return;
              setSheetState(() {
                quantity = newQuantity;
                totalPrice = quantity * double.parse(widget.product.price);
              });
            }

            // FIX: Refactored to handle BuildContext across async gaps safely
            Future<void> submitRequest() async {
              if (isLoading) return;

              // REASON: Capture Navigator and ScaffoldMessenger BEFORE the async gap.
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              setSheetState(() => isLoading = true);

              try {
                final user = supabase.auth.currentUser;
                if (user == null) throw Exception('User not logged in');

                // This is the async gap
                await supabase.from('purchase_requests').insert({
                  'user_id': user.id,
                  'product_id': widget.product.id,
                  'advertiser_id': widget.product.advertiserId,
                  'quantity': quantity,
                  'total_price': totalPrice,
                  'message': messageController.text.isEmpty
                      ? null
                      : messageController.text,
                });

                // REASON: Now we use the captured variables safely after checking 'mounted'.
                if (!mounted) return;
                navigator.pop(); // Close bottom sheet
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                      content: Text('Request sent successfully!'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red),
                );
              } finally {
                if (mounted) {
                  setSheetState(() => isLoading = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Send Purchase Request',
                          style: GoogleFonts.lexend(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Quantity (${widget.product.unit})',
                              style: GoogleFonts.lexend(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(30)),
                            child: Row(
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.remove,
                                        color: Colors.red),
                                    onPressed: () =>
                                        updateQuantity(quantity - 1)),
                                Text(quantity.toString(),
                                    style: GoogleFonts.lexend(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                    icon: const Icon(Icons.add,
                                        color: Colors.green),
                                    onPressed: () =>
                                        updateQuantity(quantity + 1)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: messageController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add an optional message...',
                          fillColor: Colors.grey.shade100,
                          filled: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ))
                              : Text(
                                  'Send Request • ₹${totalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.lexend(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
