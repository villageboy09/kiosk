import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/main.dart';
import 'package:shimmer/shimmer.dart';

// Data models for the detail screen
class CropProblem {
  final int id;
  final String name;
  final String? imageUrl1;
  final String? imageUrl2;
  final String? imageUrl3;
  CropProblem(
      {required this.id,
      required this.name,
      this.imageUrl1,
      this.imageUrl2,
      this.imageUrl3});
}

class Advisory {
  final String title;
  final String symptoms;
  final String? notes;
  final List<AdvisoryRecommendation> recommendations;
  Advisory(
      {required this.title,
      required this.symptoms,
      this.notes,
      required this.recommendations});
}

class AdvisoryRecommendation {
  final String type;
  final String name;
  final String? dose;
  final String? method;
  final String? notes;
  AdvisoryRecommendation(
      {required this.type,
      required this.name,
      this.dose,
      this.method,
      this.notes});
}

class AdvisoryDetailScreen extends StatefulWidget {
  final CropProblem problem;
  const AdvisoryDetailScreen({super.key, required this.problem});

  @override
  State<AdvisoryDetailScreen> createState() => _AdvisoryDetailScreenState();
}

class _AdvisoryDetailScreenState extends State<AdvisoryDetailScreen> {
  late Future<Advisory> _advisoryFuture;

  @override
  void initState() {
    super.initState();
    _advisoryFuture = _fetchAdvisoryDetails();
  }

  Future<Advisory> _fetchAdvisoryDetails() async {
    // Fetch the main advisory
    final advisoryData = await supabase
        .from('crop_advisories')
        .select()
        .eq('problem_id', widget.problem.id)
        .single();

    // Fetch the recommendations for that advisory
    final recommendationsData = await supabase
        .from('advisory_recommendations')
        .select()
        .eq('advisory_id', advisoryData['id']);

    final List<AdvisoryRecommendation> recommendations =
        (recommendationsData as List).map((r) {
      return AdvisoryRecommendation(
        type: r['component_type'] ?? 'General',
        name: r['component_name_te'] ?? 'N/A',
        dose: r['dose_te'],
        method: r['application_method_te'],
        notes: r['notes_te'],
      );
    }).toList();

    return Advisory(
      title: advisoryData['advisory_title_te'],
      symptoms: advisoryData['symptoms_te'],
      notes: advisoryData['general_notes_te'],
      recommendations: recommendations,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.problem.name, style: GoogleFonts.lexend()),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: FutureBuilder<Advisory>(
        future: _advisoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
                child: Text('సలహా వివరాలను లోడ్ చేయడంలో విఫలమైంది.',
                    style: GoogleFonts.lexend()));
          }

          final advisory = snapshot.data!;
          final images = [
            widget.problem.imageUrl1,
            widget.problem.imageUrl2,
            widget.problem.imageUrl3
          ].where((url) => url != null && url.isNotEmpty).toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Image Gallery
              if (images.isNotEmpty) _buildImageGallery(images),

              // Sections
              _buildSectionCard(
                  title: 'లక్షణాలు (Symptoms)', content: advisory.symptoms),
              if (advisory.notes != null)
                _buildSectionCard(
                    title: 'గమనికలు (General Notes)', content: advisory.notes!),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text('యాజమాన్య పద్ధతులు (Management)',
                    style: GoogleFonts.lexend(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),

              // Recommendations
              ...advisory.recommendations
                  .map((rec) => _buildRecommendationCard(rec)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageGallery(List<String?> images) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Card(
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: images[index]!,
              width: 250,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String content}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.lexend(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800])),
            const Divider(height: 20),
            Text(content, style: GoogleFonts.lexend(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(AdvisoryRecommendation rec) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.type,
                style:
                    GoogleFonts.lexend(fontSize: 14, color: Colors.grey[600])),
            Text(rec.name,
                style: GoogleFonts.lexend(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            if (rec.dose != null)
              _buildDetailRow(
                  Icons.science_outlined, 'మోతాదు (Dose)', rec.dose!),
            if (rec.method != null)
              _buildDetailRow(
                  Icons.water_drop_outlined, 'విధానం (Method)', rec.method!),
            if (rec.notes != null)
              _buildDetailRow(
                  Icons.notes_outlined, 'గమనికలు (Notes)', rec.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
                Text(value, style: GoogleFonts.lexend()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 16),
          Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 16),
          Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12))),
        ],
      ),
    );
  }
}
