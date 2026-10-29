// Renders the example UI frame by frame and writes PNGs for doc/demo.gif and
// the screenshots. Not part of the normal test run (it lives outside test/).
//
//   cd example
//   flutter test tool/capture_demo_test.dart
//   tool/make_gif.sh
//
// Frames are real renders of the example widgets in the test engine with
// bundled Roboto and the SDK's Material Icons font; they are not a device
// recording.
@Tags(['demo'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:entity_text_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _frameMs = 66; // ~15 fps
const _docDir = '../doc';
final _framesDir = Directory('build/demo_frames');

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Italic']) {
    final data = File('tool/fonts/Roboto-$f.ttf').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(data)));
  }
  await roboto.load();
  final root = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File(
            '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytesSync())));
  await icons.load();
}

class _Harness extends StatelessWidget {
  const _Harness(
      {required this.boundary, required this.tap, required this.child});

  final GlobalKey boundary;
  final ValueNotifier<Offset?> tap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            child,
            ValueListenableBuilder<Offset?>(
              valueListenable: tap,
              builder: (context, o, _) => o == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: o.dx - 20,
                      top: o.dy - 20,
                      child: IgnorePointer(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x553B5BDB),
                            border: Border.all(
                                color: const Color(0xFF3B5BDB), width: 2),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Offset _centerOf(WidgetTester tester, String needle) {
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final plain = w.text.toPlainText(includePlaceholders: false);
    final i = plain.indexOf(needle);
    if (i < 0) continue;
    final render = tester.renderObject<RenderParagraph>(find.byWidget(w));
    final boxes = render.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + needle.length));
    return render.localToGlobal(boxes.first.toRect().center);
  }
  throw StateError('"$needle" not on screen');
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('capture demo frames and screenshots', (tester) async {
    tester.view
      ..physicalSize = const Size(840, 1300)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    if (_framesDir.existsSync()) _framesDir.deleteSync(recursive: true);
    _framesDir.createSync(recursive: true);
    Directory(_docDir).createSync(recursive: true);

    final boundary = GlobalKey();
    final tap = ValueNotifier<Offset?>(null);
    var frame = 0;

    Future<void> shoot(String path) async {
      await tester.runAsync(() async {
        final b = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> advance(int ms) async {
      for (var t = 0; t < ms; t += _frameMs) {
        await tester.pump(const Duration(milliseconds: _frameMs));
        await shoot(
            '${_framesDir.path}/f_${(frame++).toString().padLeft(4, '0')}.png');
      }
    }

    await tester.pumpWidget(_Harness(
      boundary: boundary,
      tap: tap,
      child: const ExampleApp(flatShadows: true),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await advance(600);

    // 1. Tap entities in a post.
    Future<void> tapOn(String needle) async {
      final p = _centerOf(tester, needle);
      tap.value = p;
      await advance(200);
      await tester.tapAt(p);
      await advance(500);
      tap.value = null;
    }

    await tapOn('https://example.com/releases/2.0');
    await tapOn('@Arjun Mehta');
    await tapOn('#flutter');
    await shoot('$_docDir/screenshot_post.png');
    // Expand the second post.
    await tapOn('Read more');
    await advance(700);

    // 2. Composer: type @, pick a suggestion, hashtag highlight live.
    tester.state<HomeShellState>(find.byType(HomeShell)).select(1);
    await advance(400);
    final field = find.byKey(const ValueKey('composer-field'));
    final p = tester.getCenter(field);
    tap.value = p;
    await advance(200);
    await tester.tapAt(p);
    await advance(300);
    tap.value = null;

    var typed = '';
    Future<void> type(String s, {int perChar = 90}) async {
      for (final ch in s.characters) {
        typed += ch;
        await tester.enterText(field, typed);
        await advance(perChar);
      }
    }

    await type('Great launch with @as');
    await advance(1100); // debounce + "network"
    await shoot('$_docDir/screenshot_composer.png');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await advance(500);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await advance(400);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await advance(600);
    typed = tester.widget<TextField>(field).controller!.text;
    await type('great work! #fl');
    await advance(500);
    await type('utter and https://example.com/v2.', perChar: 60);
    await advance(1800);
  });

  testWidgets('dark screenshot', (tester) async {
    tester.view
      ..physicalSize = const Size(840, 1300)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(_Harness(
      boundary: boundary,
      tap: ValueNotifier(null),
      child: const ExampleApp(initialTab: 1, dark: true, flatShadows: true),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final field = find.byKey(const ValueKey('composer-field'));
    await tester.enterText(field,
        'Thanks @Asha Rao for the review! #flutter https://example.com/pr/42');
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      final b =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_docDir/screenshot_dark.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
