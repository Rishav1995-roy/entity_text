import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EntityType compares by name and works as a const map key', () {
    expect(const EntityType('x'), const EntityType('x'));
    const styles = {EntityType.hashtag: TextStyle(color: Color(0xFF000000))};
    expect(styles[const EntityType('hashtag')], isNotNull);
  });

  test('Entity and Mention basics', () {
    const e = Entity(type: EntityType.url, start: 1, end: 4, text: 'abc');
    expect(e.value, 'abc');
    expect(e.length, 3);
    expect(
        e, const Entity(type: EntityType.url, start: 1, end: 4, text: 'abc'));
    expect(e.toString(), contains('abc'));

    const m = Mention(id: '1', display: 'Bo', start: 2);
    expect(m.text, '@Bo');
    expect(m.end, 5);
    expect(m.type, EntityType.mention);
    expect(m.copyWith(trigger: '#').type, EntityType.hashtag);
    expect(m.copyWith(display: 'Xy').display, 'Xy');
    expect(m.toEntity().value, '1');
    expect(m.toEntity().data, m);
    expect(
        m.hashCode, const Mention(id: '1', display: 'Bo', start: 2).hashCode);
  });

  test('TextEdit computes insertions, deletions and replacements', () {
    TextEdit? edit(String a, String b, int caret) => TextEdit.compute(
          a,
          TextEditingValue(
              text: b, selection: TextSelection.collapsed(offset: caret)),
        );
    final del = edit('aaa', 'aa', 1)!;
    expect((del.start, del.oldEnd, del.isDeletion), (1, 2, true));
    final ins = edit('ab', 'aXb', 2)!;
    expect((ins.start, ins.isInsertion, ins.delta), (1, true, 1));
    final rep = TextEdit.compute(
        'hello world', const TextEditingValue(text: 'hello there'))!;
    expect(rep.insertedLength > 0 && rep.oldEnd > rep.start, isTrue);
    expect(edit('same', 'same', 0), isNull);
  });

  test('ActiveQuery equality and suggestion fields', () {
    const t = EntityTrigger.mention();
    const a = ActiveQuery(trigger: t, query: 'a', start: 0, end: 2);
    expect(a, const ActiveQuery(trigger: t, query: 'a', start: 0, end: 2));
    expect(a.toString(), contains('@a'));
    expect(t.effectiveType, EntityType.mention);
    expect(const EntityTrigger.hashtag().structured, isFalse);
  });

  test('EntityParser ignores overlapping lower-priority matches', () {
    final p = EntityParser([MentionMatcher(), HashtagMatcher()]);
    expect(p.parse('@a #b').map((e) => e.text), ['@a', '#b']);
  });
}
