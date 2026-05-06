/// Local UI enums shared across product screens. The actual product model
/// comes from `lib/api/akhiyan_api.dart` (see `Product` there). These enums
/// just make widget code easier to read at call sites — derive them from the
/// API model with helpers like `stockStateOf()` in `products_screen.dart`.
enum ProductStatus { active, draft, archived }

enum StockState { healthy, low, out }
