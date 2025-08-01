class UnitConverter {
  // Supported unit groups
  static const Map<String, List<String>> unitGroups = {
    'weight': ['kg', 'g'],
    'volume': ['L', 'ml'],
    'count': ['pcs', 'dozen'],
  };

  // Get supported units for a given unit
  static List<String> getSupportedUnits(String baseUnit) {
    for (var group in unitGroups.values) {
      if (group.contains(baseUnit)) {
        return group;
      }
    }
    return [baseUnit]; // Return only the base unit if no group found
  }

  // Get unit group for a given unit
  static String? getUnitGroup(String unit) {
    for (var entry in unitGroups.entries) {
      if (entry.value.contains(unit)) {
        return entry.key;
      }
    }
    return null;
  }

  // Convert between units
  static double convertUnit(double quantity, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return quantity;

    // Weight conversions
    if (fromUnit == 'kg' && toUnit == 'g') {
      return quantity * 1000;
    }
    if (fromUnit == 'g' && toUnit == 'kg') {
      return quantity / 1000;
    }

    // Volume conversions
    if (fromUnit == 'L' && toUnit == 'ml') {
      return quantity * 1000;
    }
    if (fromUnit == 'ml' && toUnit == 'L') {
      return quantity / 1000;
    }

    // Count conversions
    if (fromUnit == 'dozen' && toUnit == 'pcs') {
      return quantity * 12;
    }
    if (fromUnit == 'pcs' && toUnit == 'dozen') {
      return quantity / 12;
    }

    // If no conversion found, return original quantity
    return quantity;
  }

  // Convert quantity to base unit (kg for weight, L for volume, pcs for count)
  static double convertToBaseUnit(double quantity, String unit) {
    switch (unit) {
      case 'g':
        return convertUnit(quantity, 'g', 'kg');
      case 'ml':
        return convertUnit(quantity, 'ml', 'L');
      case 'dozen':
        return convertUnit(quantity, 'dozen', 'pcs');
      default:
        return quantity;
    }
  }

  // Convert quantity from base unit to target unit
  static double convertFromBaseUnit(double quantity, String targetUnit) {
    switch (targetUnit) {
      case 'g':
        return convertUnit(quantity, 'kg', 'g');
      case 'ml':
        return convertUnit(quantity, 'L', 'ml');
      case 'dozen':
        return convertUnit(quantity, 'pcs', 'dozen');
      default:
        return quantity;
    }
  }

  // Get base unit for a unit group
  static String getBaseUnit(String unit) {
    String? group = getUnitGroup(unit);
    switch (group) {
      case 'weight':
        return 'kg';
      case 'volume':
        return 'L';
      case 'count':
        return 'pcs';
      default:
        return unit;
    }
  }

  // Format quantity with appropriate decimal places
  static String formatQuantity(double quantity, String unit) {
    // For small units (g, ml), show more precision
    if (unit == 'g' || unit == 'ml') {
      return quantity.toStringAsFixed(0);
    }
    // For larger units, show 2 decimal places
    return quantity.toStringAsFixed(2);
  }

  // Check if two units are compatible (can be converted)
  static bool areUnitsCompatible(String unit1, String unit2) {
    return getSupportedUnits(unit1).contains(unit2);
  }
}