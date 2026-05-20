import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AwaitingSelectionView extends StatelessWidget {
  final List<dynamic> providers;
  final String counterfactual;
  final bool showAllProviders;
  final VoidCallback onToggleShowAllProviders;
  final Function(BuildContext, Map<String, dynamic>) onShowProviderProfileSheet;
  final Function(String) onConfirmBooking;

  const AwaitingSelectionView({
    super.key,
    required this.providers,
    required this.counterfactual,
    required this.showAllProviders,
    required this.onToggleShowAllProviders,
    required this.onShowProviderProfileSheet,
    required this.onConfirmBooking,
  });

  String _formatRate(Map<String, dynamic> p) {
    final pricingType = (p['pricing_type'] as String?)?.trim() ?? 'hourly';

    int getValidRate(List<String> keys) {
      for (final key in keys) {
        final val = p[key];
        if (val == null) continue;
        final num? n = val is num ? val : num.tryParse(val.toString());
        if (n != null && n > 0) return n.toInt();
      }
      return 0;
    }

    if (pricingType == 'fixed') {
      final rate = getValidRate(['fixed_rate', 'rate', 'per_job_rate', 'hourly_rate']);
      return rate > 0 ? "PKR $rate (Fixed)" : "PKR 1500 (Fixed)";
    } else if (pricingType == 'per_job') {
      final rate = getValidRate(['per_job_rate', 'rate', 'fixed_rate', 'hourly_rate']);
      return rate > 0 ? "PKR $rate/job" : "PKR 1500/job";
    } else {
      final rate = getValidRate(['hourly_rate', 'rate', 'per_job_rate', 'fixed_rate']);
      return rate > 0 ? "PKR $rate/hr" : "PKR 1500/hr";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('AI Booking Selection')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Service unavailable. We are sorry but no provider is giving service in this area",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final bestMatch = providers[0];
    final runnerUps = providers.skip(1).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('AI Smart Match Recommendation', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Greeting / Robot Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.primaryGreen,
                      radius: 18,
                      child: Icon(Icons.psychology, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "AI-Optimized Best Value Choice",
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "AI has evaluated price, rating, and distance to match you with the absolute best choice.",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // Giant glowing premium Best Match Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header badge
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "RECOMMENDED BEST MATCH",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${bestMatch['match_score']?.toStringAsFixed(1) ?? '98.5'}% Match",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile / Info Row (Clickable to view details & reviews)
                          GestureDetector(
                            onTap: () => onShowProviderProfileSheet(context, bestMatch),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              color: Colors.transparent, // increases touch target
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    child: Text(
                                      (bestMatch['name'] != null && bestMatch['name'].toString().isNotEmpty)
                                          ? bestMatch['name'].toString().substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: AppTheme.primaryGreen,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                bestMatch['name'] ?? 'Professional',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: AppTheme.textPrimary,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right, size: 18, color: AppTheme.primaryGreen),
                                            const SizedBox(width: 4),
                                            if (bestMatch['trust_badge'] != null && bestMatch['trust_badge'].toString().isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.blue.shade200),
                                                ),
                                                child: Text(
                                                  bestMatch['trust_badge'],
                                                  style: TextStyle(
                                                    color: Colors.blue.shade800,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, color: Colors.orange, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "${bestMatch['rating'] ?? 5.0} Rating (View Reviews)",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: AppTheme.primaryGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.location_on, color: Colors.grey.shade400, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "${bestMatch['distance_km'] ?? 1.5} km away",
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),

                          // Core specs: Price & ETA
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "ESTIMATED RATE",
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatRate(bestMatch),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 35,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "ESTIMATED ARRIVAL (ETA)",
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${bestMatch['eta_minutes'] ?? 15} minutes",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (counterfactual.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Why this match is the best value:",
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    counterfactual,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Confirm Booking Button
                          ElevatedButton(
                            onPressed: () => onConfirmBooking(bestMatch['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.4),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    "Confirm Recommended Booking",
                                    style: TextStyle(
                                      fontSize: 16,
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
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sub-list section with toggle for other options
              if (runnerUps.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onToggleShowAllProviders,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_outline, color: Colors.grey.shade600),
                            const SizedBox(width: 10),
                            Text(
                              "Show other available specialists (${runnerUps.length})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          showAllProviders ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (showAllProviders) ...[
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: runnerUps.length,
                    itemBuilder: (context, index) {
                      final p = runnerUps[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0.5,
                        color: Colors.white,
                        child: ListTile(
                          onTap: () => onShowProviderProfileSheet(context, p),
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            child: Text(
                              (p['name'] != null && p['name'].toString().isNotEmpty)
                                  ? p['name'].toString().substring(0, 1).toUpperCase()
                                  : 'P',
                              style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p['name'] ?? 'Unknown', 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  )
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryGreen),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text("⭐ ${p['rating']} (View Reviews) • ${p['distance_km']}km away"),
                              Text("${_formatRate(p)} • ETA: ${p['eta_minutes']}m"),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => onConfirmBooking(p['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
