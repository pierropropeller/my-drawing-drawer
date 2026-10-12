import '../../data/database.dart';
import '../../l10n/l10n.dart';

/// 分類的顯示文字（資料層只給英文 id）。
extension MaterialCategoryLabel on MaterialCategory {
  String label(AppLocalizations l) => switch (this) {
    MaterialCategory.clothing => l.materialCatClothing,
    MaterialCategory.pose => l.materialCatPose,
    MaterialCategory.body => l.materialCatBody,
    MaterialCategory.palette => l.materialCatPalette,
    MaterialCategory.scene => l.materialCatScene,
    MaterialCategory.style => l.materialCatStyle,
    MaterialCategory.sticker => l.materialCatSticker,
  };
}
