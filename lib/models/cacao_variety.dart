import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CacaoVariety {
  final String id;
  final String registrationNo;
  final String name;
  final String owner;
  final String description;
  final String nsicStatus;

  final String leafShape;
  final String leafMargin;

  final double averagePodIndex;
  final double averagePodLength;
  final double averagePodWidth;
  final String youngPodColor;
  final String maturePodColor;

  final String podBorerResistance;
  final String diebackBorerResistance;
  final String podRotResistance;

  final List<String> tags;
  final List<String> characteristics;
  final int colorHex;

  const CacaoVariety({
    required this.id,
    required this.registrationNo,
    required this.name,
    required this.owner,
    required this.description,
    required this.nsicStatus,
    required this.leafShape,
    required this.leafMargin,
    required this.averagePodIndex,
    required this.averagePodLength,
    required this.averagePodWidth,
    required this.youngPodColor,
    required this.maturePodColor,
    required this.podBorerResistance,
    required this.diebackBorerResistance,
    required this.podRotResistance,
    required this.tags,
    required this.characteristics,
    required this.colorHex,
  });

  bool get isApproved => nsicStatus == 'Approved';

  String get podIndexRating {
    if (this.averagePodIndex == 0) return 'N.A.';
    if (this.averagePodIndex < 15) return 'Good (< 15)';
    if (this.averagePodIndex < 25) return 'Moderate (15–25)';
    return 'High (> 25)';
  }
}

const List<CacaoVariety> cacaoVarieties = [
  CacaoVariety(
      id: 'BR25',
      registrationNo: 'NSIC 1999 Cc 05',
      name: 'BR 25',
      owner: 'Univeristy of the Philippines - Los Baños (UPLB)',
      description:
        'BR-25 is a robust Philippine cacao clone selected for its disease '
        'resilience and high pod yield. Its beans have a classic cocoa profile '
        'making it suitable for commercial chocolate production.',
      nsicStatus: 'Approved',
      leafShape: 'Elliptical',
      leafMargin: 'Smooth',
      averagePodIndex: 23.10,
      averagePodLength: 17.02,
      averagePodWidth: 7.07,
      youngPodColor: 'Red With Green',
      maturePodColor: 'Yellow',
      podBorerResistance: 'Moderately Resistant',
      diebackBorerResistance: 'Moderately Resistant',
      podRotResistance: 'Moderately Resistant',
      tags: [
        'Disease-resistant',
        'Commercial grade',
        'High pod count'
      ],
      characteristics: [
        'Distinct pod surface for easy identification',
        'Highest disease tolerance among PH registered clones',
        'Dense canopy requires regular pruning',
        'Cocoa flavor ideal for mass-market chocolate',
      ],
      colorHex: 0xFFEF9F27
  ),
  CacaoVariety(
      id: 'UF18',
      registrationNo: 'NSIC 2008 Cc 08',
      name: 'UF 18',
      owner: 'Puentespina Farm',
      description:
        'UF-18 is a fine-flavor Philippine cacao clone prized for its aromatic '
        'bean profile and consistent pod production. Widely planted across '
        'Davao and Mindanao cacao farms.',
      nsicStatus: "Approved",
      leafShape: 'Acute',
      leafMargin: 'Smooth',
      averagePodIndex: 20.00,
      averagePodLength: 19.75,
      averagePodWidth: 9.63,
      youngPodColor: 'Red with Stripe White Ridge',
      maturePodColor: 'Orange Yellow',
      podBorerResistance: 'Susceptible',
      diebackBorerResistance: 'Moderately Resistant',
      podRotResistance: 'Tolerant',
      tags: [
        'Fine flavor',
        'Aromatic'
      ],
      characteristics: [
        'Aromatic beans preferred for specialty chocolate',
        'Moderate canopy, good for intercropping',
        'Performs well in humid conditions',
        'Requires consistent moisture during pod development',
        'Good bean-to-husk ratio',
        'Recommended for lowland to mid-elevation farms',
      ],
      colorHex: 0xFF7F77DD
  ),
  CacaoVariety(
      id: 'W10',
      registrationNo: 'N.A.',
      name: 'W 10',
      owner: 'N.A.',
      description:
          'W-10 is a high-yielding Philippine cacao clone known for its large, '
          'uniformly ribbed pods and excellent bean quality. Recommended by the '
          'Bureau of Plant Industry for commercial cacao farming.',
      nsicStatus: "Not Approved",
      leafShape: 'N.A.',
      leafMargin: 'N.A.',
      averagePodIndex: 0.00,
      averagePodLength: 0.00,
      averagePodWidth: 0.00,
      youngPodColor: 'N.A.',
      maturePodColor: 'N.A.',
      podBorerResistance: 'N.A.',
      diebackBorerResistance: 'N.A.',
      podRotResistance: 'N.A.',
      tags: [

      ],
      characteristics: [

      ],
      colorHex: 0xFF1D9E75
  ),
];

const Map<String, String> yoloClassToVarietyId = {
  'W10': 'W10',
  'w10': 'W10',
  'UF18': 'UF18',
  'uf18': 'UF18',
  'BR25': 'BR25',
  'br25': 'BR25'
};

CacaoVariety? getVarietyById(String id)
{
  try {
    return cacaoVarieties.firstWhere(
        (v) => v.id.toLowerCase() == id.toLowerCase(),
    );
  }
  catch (_) {
    return null;
  }
}

CacaoVariety? getVarietyByYoloClass(String yoloClass) {
  final id = yoloClassToVarietyId[yoloClass] ?? yoloClass;
  return getVarietyById(id);
}