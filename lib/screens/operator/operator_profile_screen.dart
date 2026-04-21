import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:cropsync/models/chc_operator.dart';

class OperatorProfileScreen extends StatelessWidget {
  final ChcOperator? operator;
  final VoidCallback onLogout;
  const OperatorProfileScreen(
      {super.key, required this.operator, required this.onLogout});

  static const Color _accent = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final op = operator;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileCard(context, op),
          const SizedBox(height: 20),
          if (op != null) ...[
            _buildInfoCard(context, op),
            const SizedBox(height: 20),
          ],
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, ChcOperator? op) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              image: op?.profileImage != null && op!.profileImage!.isNotEmpty
                  ? DecorationImage(
                      image: op.profileImage!.startsWith('http')
                          ? NetworkImage(op.profileImage!)
                          : NetworkImage(
                              'https://kiosk.cropsync.in/${op.profileImage!}'),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: op?.profileImage == null || op!.profileImage!.isEmpty
                ? Text(
                    op?.initial ?? 'O',
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            op?.name ?? 'operator_label'.tr(),
            style: AppTheme.getTextStyle(
              context,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'operator_zone'
                .tr(namedArgs: {'zone': op?.zoneDisplay ?? 'not_set'.tr()}),
            style: AppTheme.getTextStyle(
              context,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          if (op?.rating != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    op!.rating!,
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ChcOperator op) {
    final rows = [
      if (op.phoneNumber.isNotEmpty)
        _InfoRow(
            icon: Icons.phone_rounded,
            label: 'phone_number'.tr(),
            value: op.phoneNumber),
      if (op.baseVillage != null)
        _InfoRow(
            icon: Icons.location_on_rounded,
            label: 'operator_base_village'.tr(),
            value: op.baseVillage!),
      if (op.equipmentType != null)
        _InfoRow(
            icon: Icons.agriculture_rounded,
            label: 'chc_equipment'.tr(),
            value: op.equipmentType!),
      _InfoRow(
          icon: Icons.check_circle_outline_rounded,
          label: 'Total Jobs Completed',
          value: op.jobsCompleted.toString()),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('details'.tr(),
              style: AppTheme.getTextStyle(context,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 16),
          ...rows.map((r) => _buildInfoRow(context, r)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, _InfoRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(r.icon, color: _accent, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.label,
                  style: AppTheme.getTextStyle(context,
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500)),
              Text(r.value,
                  style: AppTheme.getTextStyle(context,
                      fontSize: 14,
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onLogout,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded,
                  color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 10),
              Text(
                'operator_sign_out'.tr(),
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
}
