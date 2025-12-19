
class IntakeCalculator {
  // Conditions that INCREASE need (+10ml/kg on average)
  static const List<String> conditionsIncrease = [
    'Diabetes', // Covers Mellitus & Insipidus
    'Diare',
    'Demam',
    'Infeksi',
    'Muntah',
    'Luka bakar',
    'Sembelit', // Added based on context often implying need for water
    'Batu ginjal',
    'Infeksi saluran kemih', // ISK
    'Hamil/Menyusui', // Generally increases need
    // Add others from prompt mapping if exact strings match
  ];

  // Conditions that LIMIT need (-7.5ml/kg on average)
  static const List<String> conditionsLimit = [
    'Masalah Ginjal', // Chronic/Acute Kidney Disease
    'Gagal jantung',
    'Sirosis hati',
    'Hipertensi',
    'Stroke',
    'Edema',
    'Bengkak',
  ];

  /// Calculates Daily Goal in mL
  /// 
  /// Priority:
  /// 1. Weight-based logic (if weight > 0)
  ///    - Base: Weight * 33 (avg of 30-35)
  ///    - Adjust: +10ml/kg for 'Increase' conditions
  ///    - Adjust: -7.5ml/kg for 'Limit' conditions
  /// 2. Age-based logic (fallback)
  static int calculateDailyGoal({
    required int age,
    required String gender, // 'Laki-laki' or 'Perempuan' / 'Male' or 'Female'
    required int weight,
    List<String> conditions = const [],
  }) {
    // Standardize gender
    final bool isMale = gender.toLowerCase().contains('laki') || gender.toLowerCase() == 'male';

    // Strategy 1: Weight Based
    if (weight > 0) {
      double baseRate = 33.0; // Average of 30-35
      double adjustment = 0.0;

      for (var cond in conditions) {
        // Simple string matching, assuming inputs are trimmed
        // In a real app we might want IDs, but string matching works for this scope
        if (_containsCondition(conditionsIncrease, cond)) {
          adjustment += 10.0; 
        } else if (_containsCondition(conditionsLimit, cond)) {
          adjustment -= 7.5;
        }
      }

      // Cap adjustment to avoid extreme values? 
      // For now, let it stack as requested "Faktor Penyakit += ..."
      // But usually we don't stack multiple +10s indefinitely.
      // Let's take the MAX increase or limit if multiple present to be safe, 
      // or just sum them as requested "± 5–15 mL/kg".
      // Let's treat it as: IF any increase condition -> +10. IF any limit -> -7.5.
      // If BOTH present, they might cancel out or take priority. 
      // Usually "Limit" is a strict medical constraint (e.g. Kidney failure). 
      // Safe default: If limit exists, prioritize limit or consult doctor. 
      // For this algorithm, we will apply the net sum but ensure min safety.
      
      bool hasIncrease = conditions.any((c) => _containsCondition(conditionsIncrease, c));
      bool hasLimit = conditions.any((c) => _containsCondition(conditionsLimit, c));

      double diseaseFactor = 0.0;
      if (hasLimit) {
        diseaseFactor -= 7.5; 
      } else if (hasIncrease) {
         diseaseFactor += 10.0;
      }
      // If both? Limit usually overrides, so we stick to -7.5 or 0. Let's say Limit wins for safety.

      double finalRate = baseRate + diseaseFactor;
      // Safety bounds
      if (finalRate < 20) finalRate = 20; // Absolute minimum 20ml/kg
      
      return (weight * finalRate).round();
    }

    // Strategy 2: Age Based (Fallback)
    // •	Balita 1-3 1200-1300ml/d (all gender)
    // •	Anak 4-8 1600 ml/d (all gender)
    // •	praRemaja 9-13 2100 ml/d (Laki-laki) 2000 ml/d (Perempuan)
    // •	Remaja 14-18 2500 ml/d (Laki-laki) 2000 ml/d (Perempuan)
    // •	Dewasa 19-64 2500 ml/d (Laki-laki) 2000 ml/d (Perempuan)
    // •	Lansia >64 2200 ml/d (all gender)
    
    if (age >= 1 && age <= 3) return 1250;
    if (age >= 4 && age <= 8) return 1600;
    
    if (age >= 9 && age <= 13) {
      return isMale ? 2100 : 2000;
    }
    
    if (age >= 14 && age <= 18) {
      return isMale ? 2500 : 2000;
    }
    
    if (age >= 19 && age <= 64) {
      return isMale ? 2500 : 2000;
    }
    
    if (age > 64) return 2200;

    // Default Fallback
    return 2000;
  }

  static bool _containsCondition(List<String> list, String condition) {
    // Case insensitive partial match
    return list.any((item) => condition.toLowerCase().contains(item.toLowerCase()) || 
                              item.toLowerCase().contains(condition.toLowerCase()));
  }
}
