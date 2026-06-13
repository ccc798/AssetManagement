import '../database/category_dao.dart';
import '../models/category.dart';

class CategoryRepository {
  final CategoryDao _categoryDao;

  CategoryRepository({CategoryDao? categoryDao})
      : _categoryDao = categoryDao ?? CategoryDao();

  Future<List<CategoryItem>> getAllCategories() async {
    return _categoryDao.getActive();
  }

  Future<List<String>> getAllCategoryNames() async {
    final categories = await _categoryDao.getActive();
    return categories.map((c) => c.name).toList();
  }

  Future<int> getCategoryCount() async {
    final categories = await _categoryDao.getActive();
    return categories.length;
  }

  Future<CategoryItem> createCategory(CategoryItem category) async {
    return _categoryDao.add(
      category.name,
      category.icon,
      category.colorHex,
    );
  }

  Future<CategoryItem> updateCategory(CategoryItem category) async {
    if (category.id == 0) {
      throw Exception('Cannot update category with id 0');
    }
    return _categoryDao.update(
      category.id,
      name: category.name,
      icon: category.icon,
      colorHex: category.colorHex,
    );
  }

  Future<void> deleteCategory(String name) async {
    final category = await _categoryDao.getByName(name);
    if (category != null) {
      await _categoryDao.delete(category.id);
    }
  }

  Future<CategoryItem?> getCategoryByName(String name) async {
    return _categoryDao.getByName(name);
  }

  Future<bool> categoryExists(String name) async {
    final category = await _categoryDao.getByName(name);
    return category != null;
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final category = await _categoryDao.getByName(oldName);
    if (category != null) {
      await _categoryDao.update(
        category.id,
        name: newName,
      );
    }
  }

  Future<void> setCategoryIcon(String name, String icon) async {
    final category = await _categoryDao.getByName(name);
    if (category != null) {
      await _categoryDao.update(category.id, icon: icon);
    }
  }

  Future<void> setCategoryColor(String name, String colorHex) async {
    final category = await _categoryDao.getByName(name);
    if (category != null) {
      await _categoryDao.update(category.id, colorHex: colorHex);
    }
  }
}