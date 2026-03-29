import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/screens/character_select.dart';

void main() {
  group('CharacterSelectLayoutSpec', () {
    test('keeps phone widths at 3 columns', () {
      expect(CharacterSelectLayoutSpec.calculateColumns(430), 3);
    });

    test('expands columns on tablet widths', () {
      expect(CharacterSelectLayoutSpec.calculateColumns(800), greaterThan(3));
      expect(CharacterSelectLayoutSpec.calculateColumns(1024), 6);
    });
  });
}
