import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Disk-cached map tiles for the Rider's route map.
///
/// A tile is written to the app cache the first time it loads, so a road the
/// Rider already viewed still renders when the signal drops — the route line
/// and pins keep drawing on top of it. Tiles are fetched from the same public
/// OpenStreetMap server as before; this only avoids re-downloading.
class OfflineTileProviders {
  static Directory? _directory;

  static Future<void> initialise() async {
    try {
      final base = await getApplicationCacheDirectory();
      final directory = Directory('${base.path}/vendo-tiles');
      if (!await directory.exists()) await directory.create(recursive: true);
      _directory = directory;
    } catch (_) {
      // No cache directory: tiles still load from the network.
      _directory = null;
    }
  }

  static TileProvider create({String userAgent = 'com.example.vendo_rider'}) =>
      _CachedTileProvider(userAgent: userAgent, directory: _directory);
}

class _CachedTileProvider extends TileProvider {
  _CachedTileProvider({required this.userAgent, this.directory});

  final String userAgent;
  final Directory? directory;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _CachedTileImage(
        url: _resolveUrl(coordinates, options),
        userAgent: userAgent,
        directory: directory,
      );

  /// Fills the same placeholders `flutter_map` supports for OSM-style
  /// templates. `{s}` resolves to a single public host and `{r}` is dropped,
  /// which is enough for the road-map layer this app uses.
  String _resolveUrl(TileCoordinates coordinates, TileLayer options) {
    final template = options.urlTemplate ?? '';
    final invertedY = (1 << coordinates.z) - 1 - coordinates.y;
    return template
        .replaceAll('{z}', '${coordinates.z}')
        .replaceAll('{x}', '${coordinates.x}')
        .replaceAll('{y}', '${coordinates.y}')
        .replaceAll('{-y}', '$invertedY')
        .replaceAll('{s}', 'a')
        .replaceAll('{r}', '');
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({
    required this.url,
    required this.userAgent,
    this.directory,
  });

  final String url;
  final String userAgent;
  final Directory? directory;

  File? get cacheFile {
    final base = directory;
    if (base == null) return null;
    return File('${base.path}/${url.hashCode.toUnsigned(32)}.png');
  }

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CachedTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _loadAsync(key, decode),
    scale: 1,
    informationCollector: () => [
      DiagnosticsProperty<ImageProvider>('Tile', this),
    ],
  );

  Future<ui.Codec> _loadAsync(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) async {
    final file = key.cacheFile;
    if (file != null && await file.exists()) {
      final cached = await file.readAsBytes();
      if (cached.isNotEmpty) {
        return decode(await ui.ImmutableBuffer.fromUint8List(cached));
      }
    }

    final response = await http
        .get(Uri.parse(key.url), headers: {'User-Agent': key.userAgent})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.parse(key.url),
      );
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw StateError('Empty map tile from ${key.url}');
    }
    if (file != null) {
      try {
        await file.writeAsBytes(bytes, flush: false);
      } catch (_) {
        // A cache write failure must not stop the tile from drawing.
      }
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage &&
      other.url == url &&
      other.directory?.path == directory?.path;

  @override
  int get hashCode => Object.hash(url, directory?.path);
}
