import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../state/closet_store.dart';
import '../theme.dart';

class FashionImage extends StatelessWidget {
  const FashionImage({
    required this.imageUrl,
    required this.background,
    super.key,
  });

  final String imageUrl;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: background,
        alignment: Alignment.center,
        child: const Icon(
          Icons.checkroom_outlined,
          color: Colors.white70,
          size: 42,
        ),
      ),
    );
  }
}

class GarmentCard extends StatelessWidget {
  const GarmentCard({
    required this.garment,
    required this.isSaved,
    required this.onSave,
    required this.onTap,
    super.key,
  });

  final Garment garment;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: FashionImage(
                    imageUrl: garment.imageUrl,
                    background: garment.color,
                  ),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onSave,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved ? accent : ink,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 9,
                  bottom: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: paper.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco_outlined, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          garment.impact,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            garment.designer.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            garment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            garment.formattedPrice,
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: accent),
            const SizedBox(height: 12),
            Text(title, style: headingStyle(19), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class ClosetLogo extends StatelessWidget {
  const ClosetLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'closet',
          style: TextStyle(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        Text(
          'X',
          style: TextStyle(
            color: accent,
            fontSize: 25,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class CartCountButton extends StatelessWidget {
  const CartCountButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = ClosetStoreScope.of(context).cartCount;
    return IconButton(
      tooltip: 'Shopping bag',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
