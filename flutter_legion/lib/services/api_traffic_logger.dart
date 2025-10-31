import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// High-fidelity capture of outbound HTTP traffic so API calls can be
/// inspected in DevTools or replayed in the UI diagnostics panels.
class ApiTrafficRecorder {
  ApiTrafficRecorder({this.maxEvents = 200});

  final int maxEvents;
  final _events = <ApiTrafficEvent>[];
  final _controller = StreamController<ApiTrafficEvent>.broadcast();
  int _counter = 0;

  /// Stream of individual events for live dashboards.
  Stream<ApiTrafficEvent> get stream => _controller.stream;

  /// Snapshot of the most recent events (bounded by [maxEvents]).
  List<ApiTrafficEvent> get recentEvents => List.unmodifiable(_events);

  /// Generates monotonically increasing request identifiers for correlation.
  String nextRequestId() {
    _counter = (_counter + 1) % 0xFFFFFF;
    return _counter.toRadixString(16).padLeft(6, '0');
  }

  void recordRequest({
    required String requestId,
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
  }) {
    _push(ApiTrafficEvent(
      kind: ApiTrafficEventKind.request,
      requestId: requestId,
      method: method,
      url: url,
      requestHeaders: headers,
      payload: body,
    ));
  }

  void recordResponseChunk({
    required String requestId,
    required Uri url,
    required String method,
    required String chunk,
  }) {
    _push(ApiTrafficEvent(
      kind: ApiTrafficEventKind.responseChunk,
      requestId: requestId,
      method: method,
      url: url,
      payload: chunk,
    ));
  }

  void recordResponseComplete({
    required String requestId,
    required Uri url,
    required String method,
    required int statusCode,
    required Map<String, String> headers,
    required Duration elapsed,
    String? body,
  }) {
    _push(ApiTrafficEvent(
      kind: ApiTrafficEventKind.responseComplete,
      requestId: requestId,
      method: method,
      url: url,
      statusCode: statusCode,
      responseHeaders: headers,
      elapsed: elapsed,
      payload: body,
    ));
  }

  void recordError({
    required String requestId,
    required Uri url,
    required String method,
    required Object error,
    StackTrace? stackTrace,
  }) {
    _push(ApiTrafficEvent(
      kind: ApiTrafficEventKind.error,
      requestId: requestId,
      method: method,
      url: url,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  void _push(ApiTrafficEvent event) {
    _events
      ..add(event)
      ..whileLengthExceeds(maxEvents, (list) => list.removeAt(0));

    if (!_controller.isClosed) {
      _controller.add(event);
    }

    // Emit structured payloads into DevTools logging.
    developer.log(
      jsonEncode(event.toLogPayload()),
      name: 'api.traffic',
    );
  }
}

/// Correlated event for either the outbound request or inbound response.
class ApiTrafficEvent {
  ApiTrafficEvent({
    required this.kind,
    required this.requestId,
    required this.method,
    required this.url,
    this.requestHeaders = const {},
    this.responseHeaders,
    this.statusCode,
    this.elapsed,
    this.payload,
    this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  final ApiTrafficEventKind kind;
  final String requestId;
  final String method;
  final Uri url;
  final Map<String, String> requestHeaders;
  final Map<String, String>? responseHeaders;
  final int? statusCode;
  final Duration? elapsed;
  final Object? payload;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  Map<String, dynamic> toLogPayload() => {
        'ts': timestamp.toIso8601String(),
        'id': requestId,
        'kind': kind.name,
        'method': method,
        'url': url.toString(),
        if (requestHeaders.isNotEmpty) 'requestHeaders': requestHeaders,
        if (responseHeaders != null) 'responseHeaders': responseHeaders,
        if (statusCode != null) 'statusCode': statusCode,
        if (elapsed != null) 'elapsedMs': elapsed!.inMilliseconds,
        if (payload != null) 'payload': payload,
        if (error != null)
          'error': {
            'message': error.toString(),
            if (stackTrace != null) 'stackTrace': stackTrace.toString(),
          },
      };
}

enum ApiTrafficEventKind {
  request,
  responseChunk,
  responseComplete,
  error,
}

extension _ListTrimExtension on List<ApiTrafficEvent> {
  void whileLengthExceeds(int max, void Function(List<ApiTrafficEvent>) trim) {
    while (length > max) {
      trim(this);
    }
  }
}

/// HTTP client wrapper that mirrors traffic into the [ApiTrafficRecorder].
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient({
    http.Client? inner,
    required ApiTrafficRecorder recorder,
    this.captureResponseChunks = true,
  })  : _inner = inner ?? http.Client(),
        _recorder = recorder;

  final http.Client _inner;
  final ApiTrafficRecorder _recorder;
  final bool captureResponseChunks;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestId = _recorder.nextRequestId();
    final method = request.method;
    final uri = request.url;
    final requestHeaders = Map<String, String>.from(request.headers);
    final requestBody = _extractRequestBody(request);

    _recorder.recordRequest(
      requestId: requestId,
      method: method,
      url: uri,
      headers: requestHeaders,
      body: requestBody,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final streamedResponse = await _inner.send(request);
      final capturedStream = _captureStream(
        streamedResponse,
        requestId: requestId,
        method: method,
        uri: uri,
        start: stopwatch,
      );

      return http.StreamedResponse(
        capturedStream,
        streamedResponse.statusCode,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
        contentLength: streamedResponse.contentLength,
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      _recorder.recordError(
        requestId: requestId,
        url: uri,
        method: method,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<List<int>> _captureStream(
    http.StreamedResponse response, {
    required String requestId,
    required String method,
    required Uri uri,
    required Stopwatch start,
  }) {
    final buffer = BytesBuilder(copy: false);
    final headers = Map<String, String>.from(response.headers);

    return response.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          buffer.add(chunk);
          if (captureResponseChunks) {
            final text = _decodeChunk(chunk, headers);
            if (text != null && text.isNotEmpty) {
              _recorder.recordResponseChunk(
                requestId: requestId,
                url: uri,
                method: method,
                chunk: text,
              );
            }
          }
          sink.add(chunk);
        },
        handleDone: (sink) {
          start.stop();
          final bodyText = _decodeBody(buffer.takeBytes(), headers);
          _recorder.recordResponseComplete(
            requestId: requestId,
            url: uri,
            method: method,
            statusCode: response.statusCode,
            headers: headers,
            elapsed: start.elapsed,
            body: bodyText,
          );
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          start.stop();
          _recorder.recordError(
            requestId: requestId,
            url: uri,
            method: method,
            error: error,
            stackTrace: stackTrace,
          );
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  static String? _extractRequestBody(http.BaseRequest request) {
    if (request is http.Request) {
      return request.body;
    }
    return null;
  }

  static String? _decodeChunk(List<int> chunk, Map<String, String> headers) {
    if (chunk.isEmpty) return null;
    try {
      return utf8.decode(chunk, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static String? _decodeBody(List<int> bytes, Map<String, String> headers) {
    if (bytes.isEmpty) return null;
    final contentType = headers['content-type'] ?? headers['Content-Type'];
    if (contentType != null &&
        contentType.contains('application/octet-stream')) {
      return '<<${bytes.length} bytes binary>>';
    }
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '<<${bytes.length} bytes>>';
    }
  }

  @override
  void close() {
    _inner.close();
  }
}
