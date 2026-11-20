import 'package:flutter/foundation.dart';

/// ما يحتاجه شريط الأدوات من محرر نص السؤال الأصلي.
abstract class RichActions {
  /// يتغير رقمه عند أي تغيير في التركيز/التحديد/التنسيق (لتظليل الأزرار).
  ValueListenable<int> get revision;

  bool get hasImage;
  bool get hasTable;

  /// مفاتيح: bold italic underline strike sup sub right center left justify ul ol
  bool isOn(String key);

  Future<void> undo();
  Future<void> redo();

  void toggle(String key);
  void setColor(String? hex);
  void setBg(String? hex);
  void setSize(String? size);
  void clearFormat();
  void setAlign(String align);
  void toggleList(String kind);
  void indent(int delta);

  Future<void> paste();
  void copy();
  void cut();
  void selectAll();
  void deleteSelection();

  Future<void> insertHtml(String html);
  void insertAnswerLine();
  void insertBox();
  void insertTable(int rows, int cols, String style);
  Future<void> insertImages(bool grid);

  void imgWrap(String v);
  void imgSize(String v);
  void imgShape(String v);
  void imgArrow(String dir, String color, int x, int y, String label);
  void imgClearArrows();
  void imgDelete();

  void tableOp(String action);
  void tableBorder(String mode);

  void say(String message);
}
