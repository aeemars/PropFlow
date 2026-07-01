import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a listed real-estate property.
///
/// Maps to Firestore collection: `/properties/{propertyId}`
class Property {
  final String id;
  final String reraNumber;
  final String name;
  final String location;
  final double valuationUSD;
  final int totalShares;
  final double pricePerShare;
  final double monthlyRent;
  final String propTokenAddress;
  final String? coverImageUrl;
  final bool active;

  Property({
    required this.id,
    required this.reraNumber,
    required this.name,
    required this.location,
    required this.valuationUSD,
    required this.totalShares,
    required this.pricePerShare,
    required this.monthlyRent,
    required this.propTokenAddress,
    this.coverImageUrl,
    this.active = true,
  });

  /// Monthly yield percentage = (monthlyRent * 12 / valuationUSD) * 100
  double get annualYieldPercent =>
      valuationUSD > 0 ? (monthlyRent * 12 / valuationUSD) * 100 : 0;

  /// Per-token monthly rent = monthlyRent / totalShares
  double get rentPerToken =>
      totalShares > 0 ? monthlyRent / totalShares : 0;

  factory Property.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Property(
      id: doc.id,
      reraNumber: data['reraNumber'] ?? '',
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      valuationUSD: (data['valuationUSD'] ?? 0).toDouble(),
      totalShares: data['totalShares'] ?? 0,
      pricePerShare: (data['pricePerShare'] ?? 0).toDouble(),
      monthlyRent: (data['monthlyRent'] ?? 0).toDouble(),
      propTokenAddress: data['propTokenAddress'] ?? '',
      coverImageUrl: data['coverImage'],
      active: data['active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'reraNumber': reraNumber,
        'name': name,
        'location': location,
        'valuationUSD': valuationUSD,
        'totalShares': totalShares,
        'pricePerShare': pricePerShare,
        'monthlyRent': monthlyRent,
        'propTokenAddress': propTokenAddress,
        'coverImage': coverImageUrl,
        'active': active,
      };

  /// Hardcoded demo property for the hackathon MVP.
  static Property demoProperty() => Property(
        id: 'lekki-heights-lagos',
        reraNumber: 'LASRERA-LAG-2024-00891',
        name: 'Lekki Heights — Lagos',
        location: 'Lekki Phase 1, Lagos, Nigeria',
        valuationUSD: 200000,
        totalShares: 100000,
        pricePerShare: 2.0,
        monthlyRent: 1200,
        propTokenAddress: '', // Set after deployment
        coverImageUrl:
            'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800&q=80',
        active: true,
      );

  /// A small curated set of Nigerian demo listings shown when Firestore
  /// has no live properties yet. All use the same PropToken contract
  /// address for the hackathon MVP — in production each property would
  /// have its own token contract.
  static List<Property> demoProperties() => [
        demoProperty(),
        Property(
          id: 'oniru-residences-vi',
          reraNumber: 'LASRERA-LAG-2024-00892',
          name: 'Oniru Residences — Victoria Island',
          location: 'Oniru, Victoria Island, Lagos, Nigeria',
          valuationUSD: 350000,
          totalShares: 175000,
          pricePerShare: 2.0,
          monthlyRent: 2100,
          propTokenAddress: '',
          coverImageUrl:
              'https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800&q=80',
          active: true,
        ),
        Property(
          id: 'maitama-court-abuja',
          reraNumber: 'AGIS-ABJ-2024-00341',
          name: 'Maitama Court — Abuja',
          location: 'Maitama District, Abuja, Nigeria',
          valuationUSD: 280000,
          totalShares: 140000,
          pricePerShare: 2.0,
          monthlyRent: 1680,
          propTokenAddress: '',
          coverImageUrl:
              'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800&q=80',
          active: true,
        ),
        Property(
          id: 'gra-terraces-portharcourt',
          reraNumber: 'RVSG-PHC-2024-00127',
          name: 'GRA Terraces — Port Harcourt',
          location: 'Old GRA, Port Harcourt, Rivers, Nigeria',
          valuationUSD: 150000,
          totalShares: 75000,
          pricePerShare: 2.0,
          monthlyRent: 950,
          propTokenAddress: '',
          coverImageUrl:
              'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&q=80',
          active: true,
        ),
      ];
}
