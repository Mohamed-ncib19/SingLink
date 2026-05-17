import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

Future<Uint8List?> captureCenteredVideoSquare(double outputSize) async {
  html.VideoElement? video;
  final videoElements = html.document.querySelectorAll('video');
  for (final element in videoElements) {
    if (element is html.VideoElement &&
        element.videoWidth > 0 &&
        element.videoHeight > 0) {
      if (video == null ||
          element.videoWidth * element.videoHeight >
              video.videoWidth * video.videoHeight) {
        video = element;
      }
    }
  }

  if (video == null || video.videoWidth == 0 || video.videoHeight == 0) {
    return null;
  }

  final sourceSize = video.videoWidth < video.videoHeight
      ? video.videoWidth
      : video.videoHeight;
  final sourceX = ((video.videoWidth - sourceSize) / 2).round();
  final sourceY = ((video.videoHeight - sourceSize) / 2).round();
  final canvasSize = outputSize.round();
  final canvas = html.CanvasElement(width: canvasSize, height: canvasSize);
  final context = canvas.context2D;

  context.drawImageScaledFromSource(
    video,
    sourceX,
    sourceY,
    sourceSize,
    sourceSize,
    0,
    0,
    canvasSize,
    canvasSize,
  );

  final blob = await canvas.toBlob('image/png');

  final reader = html.FileReader();
  final completer = Completer<Uint8List?>();
  reader.onLoad.first.then((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(result.asUint8List());
    } else {
      completer.complete(null);
    }
  });
  reader.onError.first.then((_) => completer.complete(null));
  reader.readAsArrayBuffer(blob);

  return completer.future;
}
