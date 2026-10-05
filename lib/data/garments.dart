import 'package:flutter/material.dart';

import '../models/garment.dart';

const sampleGarments = <Garment>[
  Garment(
    id: 'modern-terno',
    name: 'The Modern Terno',
    designer: 'Studio Sinta',
    price: 4800,
    category: 'Dresses',
    imageUrl:
        'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=800&auto=format&fit=crop&q=85',
    color: Color(0xFFE9DDD0),
    impact: 'Made in the Philippines',
    description:
        'A contemporary take on a Filipino classic, cut for a confident silhouette and made in a small local atelier.',
  ),
  Garment(
    id: 'manila-linen-set',
    name: 'Manila Linen Set',
    designer: 'HABI Atelier',
    price: 3200,
    category: 'Sets',
    imageUrl:
        'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=800&auto=format&fit=crop&q=85',
    color: Color(0xFFE6E3D8),
    impact: 'Natural linen',
    description:
        'A breathable two-piece in natural linen, designed for easy layering through warm days and cool evenings.',
  ),
  Garment(
    id: 'sunday-silk-top',
    name: 'Sunday Silk Top',
    designer: 'Amihan Studio',
    price: 2450,
    category: 'Tops',
    imageUrl:
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&auto=format&fit=crop&q=85',
    color: Color(0xFFE8DCD5),
    impact: 'Small-batch made',
    description:
        'A softly draped everyday top from a limited small-batch run by Amihan Studio.',
  ),
  Garment(
    id: 'everyday-wrap-dress',
    name: 'Everyday Wrap Dress',
    designer: 'Studio Sinta',
    price: 3950,
    category: 'Dresses',
    imageUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=85',
    color: Color(0xFFE4E2DA),
    impact: 'Designed to last',
    description:
        'An effortless wrap dress with an adjustable fit and timeless shape, made to be worn on repeat.',
  ),
  Garment(
    id: 'habagat-overshirt',
    name: 'Habagat Overshirt',
    designer: 'HABI Atelier',
    price: 2850,
    category: 'Tops',
    imageUrl:
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=800&auto=format&fit=crop&q=85',
    color: Color(0xFFD8D0C4),
    impact: 'Locally woven fabric',
    description:
        'An easy, roomy layer made with locally woven fabric and finished with understated details.',
  ),
  Garment(
    id: 'isla-tailored-trousers',
    name: 'Isla Tailored Trousers',
    designer: 'Amihan Studio',
    price: 3600,
    category: 'Bottoms',
    imageUrl:
        'https://images.unsplash.com/photo-1506629905607-d9a9a5b2e5c9?w=800&auto=format&fit=crop&q=85',
    color: Color(0xFFDCD8D0),
    impact: 'Made in small batches',
    description:
        'Relaxed, tailored trousers with a clean line, cut and sewn in small batches in Manila.',
  ),
];
