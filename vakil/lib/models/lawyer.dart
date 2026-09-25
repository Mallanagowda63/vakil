enum LawyerStatus { live, connected, offline }

class Lawyer {
  const Lawyer({
    required this.name,
    required this.specialty,
    required this.experience,
    required this.rating,
    required this.reviews,
    required this.rate,
    required this.status,
    this.paid = true,
  });

  final String name;
  final String specialty;
  final String experience;
  final double rating;
  final int reviews;
  final String rate;
  final LawyerStatus status;
  final bool paid;

  String get statusLabel {
    switch (status) {
      case LawyerStatus.live:
        return 'Live';
      case LawyerStatus.connected:
        return 'Connected';
      case LawyerStatus.offline:
        return 'Offline';
    }
  }

  /// Parses the "₹420/min" style [rate] string into a plain number.
  double get ratePerMinute {
    final digits = rate.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(digits) ?? 0;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

const availableLawyers = <Lawyer>[
  Lawyer(
    name: 'Michael Chen',
    specialty: 'Corporate Law',
    experience: '8 yrs exp',
    rating: 4.8,
    reviews: 93,
    rate: '₹420/min',
    status: LawyerStatus.connected,
  ),
  Lawyer(
    name: 'Sarah Jenkins',
    specialty: 'Criminal Defense',
    experience: '12 yrs exp',
    rating: 4.9,
    reviews: 124,
    rate: '₹560/min',
    status: LawyerStatus.live,
  ),
  Lawyer(
    name: 'Emily Rodriguez',
    specialty: 'Family Law',
    experience: '10 yrs exp',
    rating: 5.0,
    reviews: 210,
    rate: '₹680/min',
    status: LawyerStatus.live,
  ),
  Lawyer(
    name: 'Olivia Patel',
    specialty: 'Employment Law',
    experience: '6 yrs exp',
    rating: 4.9,
    reviews: 156,
    rate: '₹540/min',
    status: LawyerStatus.live,
  ),
  Lawyer(
    name: 'Noah Kim',
    specialty: 'Real Estate Law',
    experience: '9 yrs exp',
    rating: 4.7,
    reviews: 88,
    rate: '₹390/min',
    status: LawyerStatus.connected,
  ),
];

const featuredLawyers = <Lawyer>[
  Lawyer(
    name: 'Maya Thompson',
    specialty: 'Corporate Law',
    experience: '7 yrs exp',
    rating: 4.8,
    reviews: 142,
    rate: '₹350/min',
    status: LawyerStatus.live,
  ),
  Lawyer(
    name: 'Maya Sharma',
    specialty: 'Family Law',
    experience: '9 yrs exp',
    rating: 4.9,
    reviews: 178,
    rate: '₹410/min',
    status: LawyerStatus.live,
  ),
  Lawyer(
    name: 'David Okafor',
    specialty: 'Criminal Defense',
    experience: '11 yrs exp',
    rating: 4.8,
    reviews: 203,
    rate: '₹480/min',
    status: LawyerStatus.connected,
  ),
];
