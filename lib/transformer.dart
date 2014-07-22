import 'dart:async';
import 'package:barback/barback.dart';
import 'package:smoke/codegen/recorder.dart';
import 'package:smoke/codegen/generator.dart';
import 'package:code_transformers/resolver.dart';
import 'package:code_transformers/src/dart_sdk.dart';

class SmokeTransformer extends Transformer {
  final BarbackSettings _settings;
  Resolvers _resolvers;
  Transform _transform;
  AssetId _primaryInputId;
  String _fileSuffix = '_bootstrap';

  SmokeTransformer.asPlugin(this._settings);

  @override
  Future apply(Transform transform) {
    _transform = transform;

    return
        _resolve()
        .then(_buildSmokeBootstrap)
        .then(_buildHtmlBootstrap);
  }

  /// Initializes AssetIds and resolvers.
  Future _resolve() {
    return _transform.primaryInput.readAsString().then((content) {
      _primaryInputId = _transform.primaryInput.id;

      _resolvers = new Resolvers(dartSdkDirectory);
    });
  }

  /// Builds a Smoke bootstrapper that intializes static Smoke access
  /// and then calls the actual entry point.
  Future _buildSmokeBootstrap(_) {
    return _resolvers.get(_transform).then((resolver) {
      // Initialize the Smoke generator and recorder
      var generator = new SmokeCodeGenerator();
      Recorder recorder = new Recorder(generator,
          (lib) => resolver.getImportUri(lib, from: _primaryInputId).toString());

      // Record each class in the library for our generator
      var lib = resolver.getLibrary(_primaryInputId);
      var classes = lib.units.expand((u) => u.types);
      for(var clazz in classes) {
        recorder.runQuery(clazz, new QueryOptions(includeProperties: false));
      }

      // Generate the Smoke bootstrapper
      StringBuffer sb = new StringBuffer();
      sb.write('library smoke_bootstrap;\n\n');
      generator.writeImports(sb);
      sb.write('\n');
      generator.writeTopLevelDeclarations(sb);
      sb.write('\nvoid main() {\n');
      generator.writeInitCall(sb);
      // Call the entry point's main method
      sb.write('\n  smoke_0.main();\n}');

      // Add the Smoke bootstrapper to the output files
      var bootstrapId = _primaryInputId.changeExtension('${_fileSuffix}.dart');
      _transform.addOutput(new Asset.fromString(bootstrapId, sb.toString()));

      resolver.release();
    });
  }

  /// Builds an HTML file that is identical to the entry point HTML
  /// but uses our Smoke bootstrap as the Dart entry point
  Future _buildHtmlBootstrap(_) {
    AssetId primaryHtml = _primaryInputId.changeExtension('.html');
    return _transform.getInput(primaryHtml).then((asset) {
      var packageName = _transform.primaryInput.id.package.toLowerCase();

      return asset.readAsString().then((content) {
        AssetId bootstrapHtmlId = _primaryInputId.changeExtension('${_fileSuffix}.html');
        RegExp pattern = new RegExp(packageName);
        String replace = packageName + _fileSuffix;
        _transform.addOutput(new Asset.fromString(bootstrapHtmlId, content.replaceAll(pattern, replace)));
      });
    });
  }

  String get allowedExtensions => '.dart';

}