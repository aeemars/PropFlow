import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../services/firestore_service.dart';
import '../services/contract_service.dart';
import '../services/cloud_function_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isClaiming = false;
  BigInt _claimableRent = BigInt.zero;
  BigInt _expiredRent = BigInt.zero;
  bool _isLoadingRent = false;

  @override
  void initState() {
    super.initState();
    _loadRentDetails();
  }

  Future<void> _loadRentDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (mounted) setState(() => _isLoadingRent = true);

    try {
      final firestoreService = context.read<FirestoreService>();
      final contractService = context.read<ContractService>();
      final user = await firestoreService.getUser(uid);

      if (user?.walletAddress != null && user!.walletAddress!.isNotEmpty) {
        final claimable = await contractService.getClaimableRent(
          user.walletAddress!,
        );
        final expired = await contractService.getExpiredRent(
          user.walletAddress!,
        );
        if (mounted) {
          setState(() {
            _claimableRent = claimable;
            _expiredRent = expired;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load rent details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRent = false);
    }
  }

  Future<void> _claimRent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isClaiming = true);

    try {
      final cloudFunctions = context.read<CloudFunctionService>();
      final txHash = await cloudFunctions.claimRent(userId: uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rent claimed successfully! TX: ${txHash.substring(0, 16)}...',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }

      await _loadRentDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: StreamBuilder<UserProfile?>(
        stream: firestoreService.streamUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                backgroundColor: AppTheme.background,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    'My Profile',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // User Info Header
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.displayName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        profile.email,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Rent Collection Section ──
                      _buildRentCollectionCard(),
                      const SizedBox(height: 20),

                      // ── Profile Details Section ──
                      _buildDetailsCard(profile),
                      const SizedBox(height: 20),

                      // ── Wallet Details Section ──
                      _buildWalletCard(profile),
                      const SizedBox(height: 32),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(
                              color: AppTheme.error,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _logout,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Log Out',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRentCollectionCard() {
    final claimableDouble = ContractService.fromUsdc(_claimableRent);
    final expiredDouble = ContractService.fromUsdc(_expiredRent);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.accentCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rent Collection',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              if (_isLoadingRent)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                  onPressed: _loadRentDetails,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${claimableDouble.toStringAsFixed(2)} USDC',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Available Claimable Rent',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (expiredDouble > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Expired: ${expiredDouble.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: const Color(0xFF0A0E17),
              ),
              onPressed: (_isClaiming || _claimableRent == BigInt.zero)
                  ? null
                  : _claimRent,
              child: _isClaiming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0A0E17),
                      ),
                    )
                  : Text(
                      'Claim Earned Rent',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(UserProfile profile) {
    String kycLabel = 'Pending';
    Color kycColor = AppTheme.warning;
    if (profile.kycStatus == KycStatus.approved) {
      kycLabel = 'Approved';
      kycColor = AppTheme.success;
    } else if (profile.kycStatus == KycStatus.rejected) {
      kycLabel = 'Rejected';
      kycColor = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Divider(height: 24),
          _buildRow('Full Name', profile.fullName ?? 'Not Provided'),
          const SizedBox(height: 12),
          _buildRow('National ID (NIN)', profile.nin ?? 'Not Provided'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KYC Status',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kycColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kycColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  kycLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kycColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Credentials',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Divider(height: 24),
          _buildRow('Wallet Provider', 'Circle'),
          // const SizedBox(height: 12),
          // _buildRow('Wallet ID', profile.walletId ?? 'Not Generated'),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet Address',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      profile.walletAddress ?? 'Not Generated',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile.walletAddress != null)
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: profile.walletAddress!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Address copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
