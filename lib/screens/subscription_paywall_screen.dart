import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/design_system.dart';
import '../providers/access_provider.dart';
import 'privacy_policy_screen.dart';

class SubscriptionPaywallScreen extends StatelessWidget {
  const SubscriptionPaywallScreen({
    super.key,
    this.allowClose = false,
    this.onSignOut,
  });

  final bool allowClose;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final packages = access.offering?.availablePackages ?? const <Package>[];
    final package = packages.isEmpty ? null : packages.first;
    final price = package?.storeProduct.priceString;

    return Scaffold(
      appBar: allowClose
          ? AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: DesignSystem.accent,
            ),
            const SizedBox(height: 22),
            Text(
              'Your wardrobe.\nYour personal stylist.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try StyleStack Premium free for 7 days. Build stronger outfits, connect your calendar and enjoy an ad-free styling experience.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignSystem.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 28),
            const _Benefit(
              icon: Icons.checkroom_outlined,
              title: 'Personal styling from your real wardrobe',
            ),
            const _Benefit(
              icon: Icons.calendar_month_outlined,
              title: 'Event-aware outfits with Google Calendar',
            ),
            const _Benefit(
              icon: Icons.block_outlined,
              title: 'No rewarded ads',
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: access.loading || package == null
                  ? null
                  : () async {
                      final purchased = await access.purchase(package);
                      if (!context.mounted) return;
                      if (purchased && allowClose) Navigator.pop(context);
                    },
              child: Text(
                access.loading
                    ? 'Checking…'
                    : package == null
                    ? 'Subscription unavailable'
                    : 'Start 7-day free trial',
              ),
            ),
            if (price != null) ...[
              const SizedBox(height: 9),
              Text(
                'Then $price per ${_periodLabel(package!)} unless cancelled. Trial eligibility is determined by your app store.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (access.error != null) ...[
              const SizedBox(height: 12),
              Text(
                access.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DesignSystem.error),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: access.loading ? null : access.restore,
              child: const Text('Restore purchases'),
            ),
            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
              child: const Text('Privacy Policy'),
            ),
            if (!allowClose && onSignOut != null)
              TextButton(
                onPressed: access.loading ? null : onSignOut,
                child: const Text('Sign out'),
              ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(Package package) => switch (package.packageType) {
    PackageType.weekly => 'week',
    PackageType.monthly => 'month',
    PackageType.twoMonth => '2 months',
    PackageType.threeMonth => '3 months',
    PackageType.sixMonth => '6 months',
    PackageType.annual => 'year',
    _ => 'billing period',
  };
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: DesignSystem.editorialMint,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: DesignSystem.primary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
