/// Visual vocabulary for canonical grocery categories.
///
/// Categories come from the bundled grocery reference, so this never guesses
/// from item copy. The icon names resolve through the app icon system and the
/// seed keeps every category on one stable palette accent.
class GroceryCategoryVisual {
  const GroceryCategoryVisual._();

  static String seed(String? category, String fallback) {
    final value = category?.trim().toLowerCase();
    return value == null || value.isEmpty ? fallback : 'grocery:$value';
  }

  static String iconName(String? category) {
    return switch (category?.trim().toLowerCase()) {
      'produce' => 'groceryProduce',
      'dairy' => 'groceryDairy',
      'bakery' => 'groceryBakery',
      'meat' => 'groceryMeat',
      'fish' => 'groceryFish',
      'frozen' => 'groceryFrozen',
      'beverages' => 'groceryBeverages',
      'pantry' || 'international' || 'spreads' => 'groceryPantry',
      'snacks' => 'grocerySnacks',
      'household' => 'cleaningServices',
      'personal care' => 'groceryPersonalCare',
      'baby' => 'groceryBaby',
      'pet' => 'paw',
      'flowers' => 'groceryFlowers',
      _ => 'shoppingBagOutline',
    };
  }
}
