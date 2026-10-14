import 'package:flutter/material.dart';

import 'package:closetx/models/garment.dart';

const testGarments = <Garment>[
  Garment(
    id: 'test-garment-1',
    name: 'Test Garment One',
    designer: 'Test Designer',
    price: 1000,
    category: 'T-Shirts',
    imageUrl: 'https://example.com/one.jpg',
    color: Color(0xFFE9DDD0),
    impact: 'Test impact',
    description: 'Test garment fixture.',
  ),
  Garment(
    id: 'test-garment-2',
    name: 'Test Garment Two',
    designer: 'Test Designer',
    price: 2000,
    category: 'T-Shirts',
    imageUrl: 'https://example.com/two.jpg',
    color: Color(0xFFE6E3D8),
    impact: 'Test impact',
    description: 'Test garment fixture.',
  ),
];
