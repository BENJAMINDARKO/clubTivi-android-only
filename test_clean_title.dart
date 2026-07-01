import 'dart:core';

void main() {
  String cleanTitle(String title) {
    var clean = title.replaceFirst(RegExp(r'^.*?\s+-\s+'), '');
    clean = clean.replaceAll('-', ' ');
    clean = clean.replaceAll(RegExp(r'\(\d{4}\)'), '');
    clean = clean.replaceAll(RegExp(r'\[.*?\]'), '');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    return clean.trim();
  }

  print(cleanTitle('Michael'));
  print(cleanTitle('4K ULTRA HD - Michael'));
}
