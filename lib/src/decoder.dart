library eventsource3.src.decoder;

import "dart:async";
import "dart:convert";

import "event.dart";

typedef RetryIndicator = void Function(Duration retry);

class EventSourceDecoder implements StreamTransformer<List<int>, Event> {
  final RetryIndicator? retryIndicator;

  EventSourceDecoder({this.retryIndicator});

  @override
  Stream<Event> bind(Stream<List<int>> stream) {
    late StreamController<Event> controller;

    controller = StreamController<Event>(onListen: () {
      Event currentEvent = Event();

      stream
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen(
        (String line) {
          if (line.isEmpty) {
            if (currentEvent.data != null) {
              currentEvent.data = currentEvent.data!.trimRight();
            }
            controller.add(currentEvent);
            currentEvent = Event();
            return;
          }

          if (line.startsWith(':')) {
            return;
          }

          final int colonIndex = line.indexOf(':');
          String field;
          String value;

          if (colonIndex == -1) {
            field = line;
            value = '';
          } else {
            field = line.substring(0, colonIndex);
            int startIndex = colonIndex + 1;
            if (startIndex < line.length && line[startIndex] == ' ') {
              startIndex++;
            }
            value = line.substring(startIndex);
          }

          switch (field) {
            case 'event':
              currentEvent.event = value;
              break;
            case 'data':
              currentEvent.data = (currentEvent.data ?? '') + value + '\n';
              break;
            case 'id':
              currentEvent.id = value;
              break;
            case 'retry':
              final retryMs = int.tryParse(value);
              if (retryMs != null) {
                retryIndicator?.call(Duration(milliseconds: retryMs));
              }
              break;
            default:
              break;
          }
        },
        onError: (e, st) {
          print('[EventSourceDecoder] Stream error: $e');
          controller.addError(e, st);
        },
        onDone: () {
          controller.close();
        },
        cancelOnError: false,
      );
    });

    return controller.stream;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<List<int>, Event, RS, RT>(this);
}
