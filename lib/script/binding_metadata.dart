// Build the official-style bindingMetadata map from a compiled setup
// context, following compiler-sfc's registration rules:
// imports -> setup-const / setup-maybe-ref, script+setup bindings merged,
// defineModel names -> props, aliased prop destructure -> props-aliased.
import 'setup_context.dart';

/// Produce the `Map<String, String>` consumed by compileTemplate's
/// `compilerOptions.bindingMetadata`.
Map<String, String> buildBindingMetadata(SetupContext ctx) {
  final bindings = <String, String>{};
  _registerImports(ctx, bindings);
  _mergeKinds(ctx.scriptBindings, bindings);
  _mergeKinds(ctx.setupBindings, bindings);
  _registerDestructuredProps(ctx, bindings);
  // 官方在宏处理期登记 models/props 键、随后被 script/setup bindings 覆盖；
  // 等价于合并之后 putIfAbsent。
  _registerModels(ctx, bindings);
  for (final key in ctx.propsKeys) {
    bindings.putIfAbsent(key, () => 'props');
  }
  // 官方以不可枚举属性挂在 bindings 上；Dart 侧用普通键表达。
  bindings['__isScriptSetup'] = 'true';
  return bindings;
}

void _registerImports(SetupContext ctx, Map<String, String> out) {
  for (final entry in ctx.userImports.entries) {
    final b = entry.value;
    if (b.typeOnly) continue;
    final isConst =
        b.imported == '*' ||
        (b.imported == 'default' && b.source.endsWith('.vue')) ||
        b.source == 'vue';
    out[entry.key] = isConst ? 'setup-const' : 'setup-maybe-ref';
  }
}

void _mergeKinds(Map<String, BindingKind> src, Map<String, String> out) {
  for (final e in src.entries) {
    out[e.key] = _kindName(e.value);
  }
}

String _kindName(BindingKind kind) => switch (kind) {
  BindingKind.literalConst => 'literal-const',
  BindingKind.setupConst => 'setup-const',
  BindingKind.setupLet => 'setup-let',
  BindingKind.setupMaybeRef => 'setup-maybe-ref',
  BindingKind.setupRef => 'setup-ref',
  BindingKind.setupReactiveConst => 'setup-reactive-const',
  BindingKind.props => 'props',
};

void _registerModels(SetupContext ctx, Map<String, String> out) {
  for (final name in ctx.modelDecls.keys) {
    out.putIfAbsent(name, () => 'props');
  }
}

void _registerDestructuredProps(SetupContext ctx, Map<String, String> out) {
  for (final e in ctx.propsDestructuredBindings.entries) {
    if (e.value.local != e.key) {
      out[e.value.local] = 'props-aliased';
      // 官方是嵌套对象 __propsAliases[local]；Dart 侧约定扁平键。
      out['__propsAliases:${e.value.local}'] = e.key;
    }
  }
  final rest = ctx.propsDestructureRestId;
  if (rest != null) out[rest] = 'setup-reactive-const';
}
