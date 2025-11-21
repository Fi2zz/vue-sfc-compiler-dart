import 'package:vue_sfc_parser/swc_ast.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';

class Walked {
  SourceLocation? loc;
  Identifier? id;
  BindingPattern? bindings;
  bool isFunctionCall;
  Walked(this.loc, this.id, this.bindings, this.isFunctionCall);
}

class Expose {
  ArgumentList? exposed;
  SourceLocation? loc;
  Expose({this.exposed, this.loc});
}

typedef WalkedSlots = List<Walked>;
typedef WalkedModels = List<Walked>;
typedef WalkedEmits = List<Walked>;
typedef WalkedExposes = List<Expose>;

class Prop {
  // TypeAnnotation? type;
}

typedef WalkedProps = List<Expose>;

class CodegenHelpers {
  CodegenHelpers._();
  static const String defineOptions = 'defineOptions';
  static const String defineSlots = 'defineSlots';
  static const String defineModel = 'defineModel';
  static const String defineExpose = 'defineExpose';
  static const String defineEmits = 'defineEmits';
  static const String defineProps = 'defineProps';
  static const String withDefaults = 'withDefaults';

  static const String defineComponent = 'defineComponent as _defineComponent';
  static const String mergeModels = 'mergeModels as _mergeModels';
  static const String useModel = 'useModel as $setupUseModel';
  static const String useAttrs = 'useAttrs as $setupUseAttrs';
  static const String useSlots = 'useSlots as $setupUseSlots';

  // Additional constants needed
  static const String setupUseAttrs = '_useAttrs';
  static const String setupUseModel = '_useModel';
  static const String setupUseSlots = '_useSlots';
  static const String setupProps = '__props';
  static const String setupEmit = '__emit';
  static const String setupReturns = '\nreturn __returned__';
  static const String normalScriptDefault = '__default__';

  static String getModelName(String? modelName) {
    return modelName ?? "modelValue";
  }

  // Helper functions for checking macro types
  static bool isDefineProps(String? name) {
    return name == defineProps;
  }

  static bool isWithDefaults(String? name) {
    return name == withDefaults;
  }

  static bool isDefineEmits(String? name) {
    return name == defineEmits;
  }

  static bool isDefineModel(String? name) {
    return name == defineModel;
  }

  static bool isDefineExpose(String? name) {
    return name == defineExpose;
  }

  static bool shouldSkipCallExpr(dynamic item) {
    // Check if the item is a FunctionCallExpression
    if (item is! FunctionCallExpression) return true;

    final methodName = item.methodName.name;

    return !isVueMacro(methodName);
  }

  // Code generation functions
  static String importFromVue(List<String> aliases) {
    if (aliases.isEmpty) return '';
    return "import { ${aliases.join(', ')} } from 'vue'";
  }

  static String defineNormalScriptDefault(String normalScript) {
    return 'const $normalScriptDefault = $normalScript';
  }

  static String exportedLeading(bool isTypescript) {
    return "export default /*@__PURE__*/_defineComponent({";
  }

  static String exportedTrailing(bool isTypescript) {
    return '}\n\n})';
  }

  static String component(bool isTypescript, List<String> body) {
    String leading = '';
    String trailing = '}';
    if (isTypescript) {
      leading = "export default /*@__PURE__*/_defineComponent({";
      trailing += '});';
    } else {
      leading = '{';
    }
    return leading + body.join('\n') + trailing;
  }

  static String mergeProps(List<String> props) {
    if (props.isEmpty) return '';

    if (props.length > 1) {
      String result =
          "_mergeModels(${props.map((e) => '{${e.trim()}}').join(', ')})";
      return '  props: $result,\n';
    }
    return '  props: { ${props.join(', ')} },\n';
  }

  static String mergeEmits(List<String> props) {
    if (props.isEmpty) return '';

    if (props.length > 1) {
      String result = "_mergeModels(${props.map((e) => e.trim()).join(', ')})";
      return '  emits: $result,\n';
    }
    return '  emits: ${props.first},\n';
  }

  static String setupStart(bool isTypescript, bool hasDefineEmits) {
    final propsType = isTypescript ? ': any' : '';
    final emitPart = hasDefineEmits ? ', emit: __emit' : '';
    return 'setup(__props$propsType, { expose: __expose$emitPart }) {';
  }

  static String expose(String? args) {
    return '  __expose();';
  }

  static List<String> returns(List<String> ordered) {
    return ['const __returned__ = { ${ordered.join(', ')} }'];
  }

  static List<String> defineProperty() {
    return [
      "Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })",
    ];
  }

  static String useModelCall(String modelName, String? modelTypedef) {
    // Remove quotes from modelName if they exist
    final cleanModelName = modelName.replaceAll(RegExp(r'''^["']|["']$'''), '');
    return '_useModel${modelTypedef ?? ""}(__props, \'$cleanModelName\')';
  }

  static bool hasDefineProps(CompilationUnit unit) {
    for (final st in unit.statements) {
      final exp = st.expression;

      if (exp is VariableDeclaration) {
        if (exp.init is Identifier) {
          final id = exp.init as Identifier;
          if (id.name == CodegenHelpers.defineProps ||
              id.name == CodegenHelpers.withDefaults) {
            return true;
          }
        }
      }
      if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineProps) {
        return true;
      }

      if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.withDefaults) {
        if (exp.argumentList.arguments.isNotEmpty) {
          final first = exp.argumentList.arguments.first;
          if (first is FunctionCallExpression &&
              first.methodName.name == CodegenHelpers.defineProps) {
            return true;
          }
        }
      }

      // VariableDeclarator path can be handled via separate FunctionCallExpression statements
    }
    return false;
  }

  /// Extracts props definition from defineProps calls and returns a structured format
  /// that can be used for code generation. Handles various patterns:
  /// - `const props =defineProps<UserDefinedType>()`
  /// - `const {a,b} =defineProps<UserDefinedType>()`
  /// - `const propsWithDefault =withDefault(defineProps<UserDefinedType>() ,{a:1})`
  /// - `const {a ,b} =withDefault(defineProps<UserDefinedType>() ,{a:1,b:2})`
  /// - `defineProps<UserDefinedType>()`
  /// - `defineProps<{ title: string; count?: number; items: Item[]; config?: { theme: "light" | "dark" }; }>()`
  /// - `withDefaults(defineProps<UserDefinedType>(), {})`
  /// - `withDefaults(defineProps<{...}>(), {})`
  ///
  /// Returns a string representation of the props object in format:
  /// `{[key:string]: {type:PropType,default:dynamic, required:bool}}`
  static String? extractDefineProps(CompilationUnit unit) {
    // AST-driven extraction
    for (final st in unit.statements) {
      final exp = st.expression;

      // Variable declaration patterns (fallback minimal handling):
      // - const props = defineProps<...>()
      // - const {a,b} = defineProps<...>()
      // - const propsWithDefault = withDefaults(defineProps<...>(), {...})
      // - const {a,b} = withDefaults(defineProps<...>(), {...})
      // The detailed typed props are still obtained via the FunctionCallExpression path below.
      if (exp is VariableDeclaration) {
        final init = exp.init;
        if (init is Identifier) {
          final nm = init.name;
          final rhs = init.text.trim();
          if (nm == CodegenHelpers.defineProps) {
            final res = extractPropsFromDefineProps(rhs);
            if (res != null) return res;
            return '{}';
          }
          if (nm == CodegenHelpers.withDefaults) {
            final res = extractPropsFromWithDefaults(rhs);
            if (res != null) return res;
            return '{}';
          }
        }
      }

      // defineProps()
      if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineProps) {
        // Runtime object arg
        final obj = _firstObjectArg(exp);
        if (obj != null) {
          return _formatInlinePropsObject(obj);
        }
        // Typed props via typeArgumentProps
        if (exp.typeArgumentProps.isNotEmpty) {
          return _formatPropsFromType(exp.typeArgumentProps);
        }
        return '{}';
      }
      //  withDefaults(defineProps(), {})
      if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.withDefaults) {
        if (exp.argumentList.arguments.length >= 2) {
          final first = exp.argumentList.arguments[0];
          final second = exp.argumentList.arguments[1];
          if (first is FunctionCallExpression &&
              first.methodName.name == CodegenHelpers.defineProps) {
            String base = '{}';
            final obj = _firstObjectArg(first);
            if (obj != null) {
              base = _formatInlinePropsObject(obj);
            } else if (first.typeArgumentProps.isNotEmpty) {
              base = _formatPropsFromType(first.typeArgumentProps);
            }
            if (second is SetOrMapLiteral) {
              final defaults = _parseDefaultsFromObject(second);
              if (defaults.isNotEmpty) {
                if (obj != null) {
                  return _mergeDefaultsWithInlineObject(obj, defaults);
                }
                return mergeDefaultsWithProps(base, defaults);
              }
            }
            return base;
          }
        }
      }
    }
    return null;
  }

  /// Extracts props definition from a defineProps call string
  /// Handles patterns like:
  /// - `defineProps<UserDefinedType>()`
  /// - `defineProps<{ title: string; count?: number; items: Item[]; config?: { theme: "light" | "dark" }; }>()`
  ///
  /// This function parses the TypeScript type information and converts it to a props object format.
  /// Returns a formatted string like: `{ msg: { type: String, required: true }, count: { type: Number, required: false } }`
  static String? extractPropsFromDefineProps(String definePropsCall) {
    // Kept for backward compatibility; prefer AST path above
    final typeMatch = RegExp(
      r'defineProps<([^>]+)>',
    ).firstMatch(definePropsCall);
    if (typeMatch != null) {
      final typeContent = typeMatch.group(1)!.trim();
      return _parseTypeToProps(typeContent);
    }
    final objMatch = RegExp(
      r'defineProps\s*\(\s*(\{[\s\S]*\})\s*\)',
    ).firstMatch(definePropsCall);
    if (objMatch != null) {
      final objText = objMatch.group(1)!;
      final props = _parseRuntimePropsObject(objText);
      if (props.isNotEmpty) {
        final lines = <String>[];
        for (final entry in props.entries) {
          lines.add(
            '    ${entry.key}: { type: ${entry.value}, required: false }',
          );
        }
        return '{\n${lines.join(',\n')}\n  }';
      }
      return '{}';
    }
    if (definePropsCall.startsWith(CodegenHelpers.defineProps)) return '{}';
    return null;
  }

  /// Extracts props definition from a withDefaults call string
  /// Handles patterns like:
  /// - `withDefaults(defineProps<UserDefinedType>(), {})`
  /// - `withDefaults(defineProps<{...}>(), {})`
  ///
  /// This function extracts both the type information and default values,
  /// then combines them into a props object format with default values.
  static String? extractPropsFromWithDefaults(String withDefaultsCall) {
    // Kept for backward compatibility; prefer AST path above
    final definePropsMatch = RegExp(
      r'withDefaults\s*\(\s*(defineProps<[^>]+>\(\s*\))\s*,\s*(\{[^}]*\})',
    ).firstMatch(withDefaultsCall);
    if (definePropsMatch != null) {
      final definePropsPart = definePropsMatch.group(1)!;
      final defaultsPart = definePropsMatch.group(2)!;
      final propsResult = extractPropsFromDefineProps(definePropsPart);
      if (propsResult != null && propsResult != '{}') {
        final defaults = parseDefaultsObject(defaultsPart);
        if (defaults.isNotEmpty) {
          return mergeDefaultsWithProps(propsResult, defaults);
        }
        return propsResult;
      }
    }
    final fallbackMatch = RegExp(
      r'defineProps<([^>]+)>',
    ).firstMatch(withDefaultsCall);
    if (fallbackMatch != null) {
      final typeContent = fallbackMatch.group(1)!.trim();
      return _parseTypeToProps(typeContent);
    }
    return null;
  }

  /// Parses a defaults object like { msg: 'hi', count: 1 }
  /// Returns a map of prop names to their default values
  static Map<String, String> parseDefaultsObject(String defaultsObject) {
    final defaults = <String, String>{};

    // Remove outer braces and trim
    final content = defaultsObject.trim();
    if (content.isEmpty || content == '{}') return defaults;

    // Simple regex to extract key-value pairs
    final keyValuePattern = RegExp(r'(\w+)\s*:\s*([^,}]+)');
    final matches = keyValuePattern.allMatches(content);

    for (final match in matches) {
      final key = match.group(1)!;
      final value = match.group(2)!.trim();
      defaults[key] = value;
    }

    return defaults;
  }

  /// Merges default values with existing props object
  static String mergeDefaultsWithProps(
    String propsResult,
    Map<String, String> defaults,
  ) {
    // Parse the existing props to add default values
    final propPattern = RegExp(
      r'(\w+):\s*\{\s*type:\s*([^,]+),\s*required:\s*([^}]+)\}',
    );
    final matches = propPattern.allMatches(propsResult);

    final mergedProps = <String>[];
    for (final match in matches) {
      final propName = match.group(1)!;
      final propType = match.group(2)!;
      final required = match.group(3)!;

      if (defaults.containsKey(propName)) {
        // Add default value
        mergedProps.add(
          '    $propName: { type: $propType, required: $required, default: ${defaults[propName]} }',
        );
      } else {
        // Keep original without default
        mergedProps.add(
          '    $propName: { type: $propType, required: $required }',
        );
      }
    }

    return '{\n${mergedProps.join(',\n')}\n  }';
  }

  // ---------- AST helpers for props ----------
  static SetOrMapLiteral? _firstObjectArg(FunctionCallExpression call) {
    for (final a in call.argumentList.arguments) {
      if (a is SetOrMapLiteral) return a;
    }
    return null;
  }

  static String _formatInlinePropsObject(SetOrMapLiteral obj) {
    final entries = <String>[];
    for (final m in obj.elements) {
      entries.add('${m.keyText}: ${_normalizeText(m.value.text)}');
    }
    return '{ ${entries.join(', ')} }';
  }

  static String _normalizeText(String text) {
    var t = text.trim();
    t = t.replaceAll("'", '"');
    t = t.split('\n').map((l) => l.trimLeft()).join('\n');
    return t;
  }

  static String _formatPropsFromType(List<PropSignature> props) {
    final buf = StringBuffer();
    buf.writeln('{');
    for (final p in props) {
      final types = _runtimeTypesFromTsType(p.type ?? '');
      final tsType = types.length <= 1
          ? (types.isEmpty ? 'Object' : types.first)
          : '[${types.join(', ')}]';
      final required = p.required ? 'true' : 'false';
      buf.writeln('    ${p.name}: { type: $tsType, required: $required },');
    }
    buf.write('  }');
    return buf.toString();
  }

  static Map<String, String> _parseDefaultsFromObject(SetOrMapLiteral obj) {
    final defaults = <String, String>{};
    for (final m in obj.elements) {
      defaults[m.keyText] = _normalizeText(m.value.text);
    }
    return defaults;
  }

  static Map<String, String> _parseRuntimePropsObject(String objText) {
    final t = objText.trim();
    final content = (t.startsWith('{') && t.endsWith('}'))
        ? t.substring(1, t.length - 1)
        : t;
    final out = <String, String>{};
    final kv = RegExp(r'(\w+)\s*:\s*([^,}]+)');
    for (final m in kv.allMatches(content)) {
      final key = m.group(1)!.trim();
      final val = _normalizeText(m.group(2)!.trim());
      out[key] = val;
    }
    return out;
  }

  static String _mergeDefaultsWithInlineObject(
    SetOrMapLiteral obj,
    Map<String, String> defaults,
  ) {
    final merged = <String>[];
    for (final m in obj.elements) {
      final k = m.keyText;
      final typeText = _normalizeText(m.value.text);
      final def = defaults.containsKey(k) ? ', default: ${defaults[k]!}' : '';
      merged.add('    $k: { type: $typeText, required: false$def }');
    }
    return '{\n${merged.join(',\n')}\n  }';
  }

  // Map TypeScript type text to Vue runtime constructors, supporting simple unions and arrays.
  static List<String> _runtimeTypesFromTsType(String t) {
    String norm(String s) => s.trim().toLowerCase();
    bool isArrayType(String s) {
      final ss = s.trim();
      if (ss.endsWith('[]')) return true;
      if (ss.startsWith('array<') && ss.endsWith('>')) return true;
      if (ss.startsWith('readonly ')) {
        final rest = ss.substring('readonly '.length).trim();
        return rest.endsWith('[]');
      }
      return false;
    }

    String mapOne(String s) {
      final x = norm(s);
      if (isArrayType(x)) return 'Array';
      switch (x) {
        case 'string':
          return 'String';
        case 'number':
          return 'Number';
        case 'boolean':
          return 'Boolean';
        case 'object':
        case 'any':
        case 'unknown':
          return 'Object';
        default:
          // literal unions like 'a' | 'b' should be String, handled at union split level
          return 'Object';
      }
    }

    final parts = t
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return <String>[];
    // If union contains any quoted literal, consider as String
    bool anyStringLiteral = parts.any((p) {
      final pp = p.trim();
      return (pp.startsWith('"') && pp.endsWith('"')) ||
          (pp.startsWith('\'') && pp.endsWith('\''));
    });
    final mapped = <String>[];
    if (anyStringLiteral) {
      mapped.add('String');
    }
    for (final p in parts) {
      final m = mapOne(p);
      if (!mapped.contains(m)) mapped.add(m);
    }
    return mapped;
  }

  /// Parses TypeScript type definition into props object format
  /// Handles basic type patterns like:
  /// - `{ title: string; count?: number; items: Item[] }`
  /// - `UserDefinedType` (returns the type name as reference)
  static String? _parseTypeToProps(String typeContent) {
    typeContent = typeContent.trim();

    // Handle inline object type: { prop1: type1; prop2?: type2; }
    if (typeContent.startsWith('{') && typeContent.endsWith('}')) {
      final propsContent = typeContent
          .substring(1, typeContent.length - 1)
          .trim();
      if (propsContent.isEmpty) return '{}';

      final propMatches = RegExp(
        r'(\w+)\s*\??\s*:\s*([^;]+);?',
      ).allMatches(propsContent);
      if (propMatches.isEmpty) return '{}';

      final props = <String>[];
      for (final match in propMatches) {
        final propName = match.group(1)!;
        final propType = match.group(2)!.trim();
        final isOptional = match.group(0)!.contains('?');

        final tsType = convertTsTypeToRuntimeType(propType);
        final required = isOptional ? 'false' : 'true';
        props.add('    $propName: { type: $tsType, required: $required }');
      }

      return '{\n${props.join(',\n')}\n  }';
    }

    // Handle simple type reference - return as a reference to be resolved later
    if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(typeContent)) {
      // For now, return empty object for referenced types
      // In a full implementation, this would resolve the type definition
      return '{}';
    }

    // Unknown format
    return null;
  }

  /// Converts TypeScript type names to Vue runtime type references
  static String convertTsTypeToRuntimeType(String tsType) {
    tsType = tsType.trim();

    // Basic type mappings
    switch (tsType) {
      case 'string':
        return 'String';
      case 'number':
        return 'Number';
      case 'boolean':
        return 'Boolean';
      case 'Array':
      case 'any[]':
      case 'unknown[]':
        return 'Array';
      case 'Object':
      case 'object':
      case 'any':
      case 'unknown':
        return 'Object';
      case 'Function':
      case 'function':
        return 'Function';
      default:
        // Handle generic types like Item[], Array<Item>, etc.
        if (tsType.endsWith('[]') || tsType.startsWith('Array<')) {
          return 'Array';
        }
        // Handle union types like "light" | "dark"
        if (tsType.contains('|') && tsType.contains('"')) {
          return 'String';
        }

        return 'Object';
    }
  }

  static ArgumentList? walkDefineOptions(CompilationUnit unit) {
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineOptions) {
        return exp.argumentList;
      }
    }
    return null;
  }

  static WalkedSlots walkDefineSlots(CompilationUnit unit) {
    WalkedSlots slots = [];
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is VariableDeclaration) {
        if (exp.init is Identifier) {
          String name = (exp.init as Identifier).name;
          if (name == CodegenHelpers.defineSlots) {
            slots.add(Walked(st.loc, exp.name, exp.pattern, false));
          }
        }
      } else if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineSlots) {
        slots.add(Walked(st.loc, null, null, true));
      }
    }
    return slots;
  }

  static WalkedModels walkDefineModels(CompilationUnit unit) {
    WalkedModels models = [];
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is VariableDeclaration) {
        if (exp.init is Identifier) {
          String name = (exp.init as Identifier).name;
          if (name == CodegenHelpers.defineModel) {
            models.add(Walked(st.loc, exp.name, exp.pattern, false));
          }
        }
      } else if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineModel) {
        models.add(Walked(st.loc, null, null, true));
      }
    }
    return models;
  }

  static WalkedEmits walkDefineEmits(CompilationUnit unit) {
    WalkedEmits emits = [];
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is VariableDeclaration) {
        if (exp.init is Identifier) {
          String name = (exp.init as Identifier).name;
          if (name == CodegenHelpers.defineEmits) {
            emits.add(Walked(st.loc, exp.name, exp.pattern, false));
          }
        }
      } else if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineEmits) {
        emits.add(Walked(st.loc, null, null, true));
      }
    }
    return emits;
  }

  static WalkedExposes walkDefineExposes(CompilationUnit unit) {
    WalkedExposes exposed = [];
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is FunctionCallExpression &&
          exp.methodName.name == CodegenHelpers.defineExpose) {
        exposed.add(Expose(exposed: exp.argumentList, loc: st.loc));
      }
    }
    return exposed;
  }

  // ---------- AST-driven emits extraction ----------
  static String? extractDefineEmits(CompilationUnit unit) {
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is VariableDeclaration &&
          exp.init is FunctionCallExpression &&
          (exp.init as FunctionCallExpression).methodName.name ==
              CodegenHelpers.defineEmits) {
        final call = exp.init as FunctionCallExpression;
        for (final a in call.argumentList.arguments) {
          if (a is ListLiteral) {
            final items = a.elements
                .whereType<StringLiteral>()
                .map((s) => '"${s.stringValue}"')
                .join(', ');
            return '[$items]';
          }
        }
        for (final a in call.argumentList.arguments) {
          if (a is SetOrMapLiteral) {
            final keys = a.elements.map((e) => '"${e.keyText}"').join(', ');
            return '[$keys]';
          }
        }
        if (call.typeArgumentText != null &&
            call.typeArgumentText!.isNotEmpty) {
          final events = _eventsFromTypeArgs(
            call.typeArgumentText!.replaceAll(RegExp(r'[<>]'), ''),
          );
          return events.isNotEmpty
              ? '[${events.map((e) => '"$e"').join(', ')}]'
              : '[]';
        }
        return '[]';
      }
      if (exp is! FunctionCallExpression) continue;
      if (exp.methodName.name != CodegenHelpers.defineEmits) continue;
      // Array arg: ["update","remove"]
      for (final a in exp.argumentList.arguments) {
        if (a is ListLiteral) {
          final items = a.elements
              .whereType<StringLiteral>()
              .map((s) => '\'${s.stringValue}\'')
              .join(', ');
          return '[$items]';
        }
      }
      // Object arg: { event(){...} } → emit keys
      for (final a in exp.argumentList.arguments) {
        if (a is SetOrMapLiteral) {
          final keys = a.elements.map((e) => '\'${e.keyText}\'').join(', ');
          return '[$keys]';
        }
      }
      // Typed args
      if (exp.typeArgumentText != null && exp.typeArgumentText!.isNotEmpty) {
        final events = _eventsFromTypeArgs(
          exp.typeArgumentText!.replaceAll(RegExp(r'[<>]'), ''),
        );
        return events.isNotEmpty
            ? '[${events.map((e) => '\'$e\'').join(', ')}]'
            : '[]';
      }
      return '[]';
    }
    return null;
  }

  static String? extractDefineEmitsFromModule(Module m) {
    for (final it in m.body) {
      if (it is CallExpr && isDefineEmits(it.calleeIdent)) {
        if (it.args.isNotEmpty) {
          final a0 = it.args.first.trim();
          if (a0.startsWith('[')) {
            // normalize quotes to single
            final normalized = _normalizeText(a0).replaceAll('"', '\'');
            return normalized;
          }
        }
        return '[]';
      }
    }
    return null;
  }

  static String? extractDefineEmitsFromVarDecls(Module m) {
    String? firstArg(String callText) {
      final t = callText.trim();
      final i = t.indexOf('(');
      if (i < 0) return null;
      int j = i + 1;
      int depth = 1;
      while (j < t.length) {
        final ch = t[j];
        if (ch == '(') {
          depth++;
        } else if (ch == ')') {
          depth--;
          if (depth == 0) break;
        }
        j++;
      }
      if (j >= t.length) return null;
      return t.substring(i + 1, j).trim();
    }

    for (final it in m.body) {
      if (it is VarDeclItem && isDefineEmits(it.initCalleeIdent)) {
        final call = it.initText;
        if (call == null || call.isEmpty) continue;
        final arg = firstArg(call);
        if (arg == null) continue;
        if (arg.startsWith('[')) {
          final arr = _normalizeText(arg).replaceAll('"', '\'');
          return arr;
        }
        if (arg.startsWith('{')) {
          final keys = <String>[];
          int i = 1; // skip '{'
          int depth = 1;
          String readIdent() {
            final start = i;
            while (i < arg.length) {
              final c = arg.codeUnitAt(i);
              final ok =
                  (c >= 65 && c <= 90) ||
                  (c >= 97 && c <= 122) ||
                  (c >= 48 && c <= 57) ||
                  c == 95 ||
                  c == 36;
              if (!ok) break;
              i++;
            }
            return arg.substring(start, i);
          }

          bool isWs(int c) => c == 32 || c == 9 || c == 10 || c == 13;
          void skipWs() {
            // ignore: curly_braces_in_flow_control_structures
            while (i < arg.length && isWs(arg.codeUnitAt(i))) i++;
          }

          while (i < arg.length && depth > 0) {
            skipWs();
            if (i >= arg.length) break;
            final ch = arg[i];
            if (ch == '{') {
              depth++;
              i++;
              continue;
            }
            if (ch == '}') {
              depth--;
              i++;
              continue;
            }
            final key = readIdent();
            skipWs();
            if (key.isNotEmpty) keys.add(key);
            // advance to next comma or closing brace at same depth
            // ignore: curly_braces_in_flow_control_structures
            while (i < arg.length && arg[i] != ',' && arg[i] != '}') i++;
            if (i < arg.length && arg[i] == ',') i++;
          }
          if (keys.isNotEmpty) {
            return '[${keys.map((k) => '\'$k\'').join(', ')}]';
          }
        }
        return '[]';
      }
    }
    return null;
  }

  static List<String> _eventsFromTypeArgs(String raw) {
    final out = <String>[];
    int i = 0;
    String readIdent() {
      final start = i;
      while (i < raw.length) {
        final c = raw.codeUnitAt(i);
        final ok =
            (c >= 65 && c <= 90) ||
            (c >= 97 && c <= 122) ||
            (c >= 48 && c <= 57) ||
            c == 95 ||
            c == 36;
        if (!ok) break;
        i++;
      }
      return raw.substring(start, i);
    }

    void skipWs() {
      while (i < raw.length) {
        final c = raw.codeUnitAt(i);
        if (c == 32 || c == 9 || c == 10 || c == 13) {
          i++;
        } else {
          break;
        }
      }
    }

    String? readString() {
      if (i >= raw.length) return null;
      final ch = raw[i];
      if (ch != '\'' && ch != '"') return null;
      final quote = ch;
      i++;
      final start = i;
      while (i < raw.length) {
        final c = raw[i];
        if (c == quote) {
          final s = raw.substring(start, i);
          i++;
          return s;
        }
        i++;
      }
      return null;
    }

    while (i < raw.length) {
      skipWs();
      if (i >= raw.length) break;
      if (raw[i] == '(') {
        i++;
        skipWs();
        final ident = readIdent();
        skipWs();
        if (ident == 'e' && i < raw.length && raw[i] == ':') {
          i++;
          skipWs();
          final s = readString();
          if (s != null && s.isNotEmpty) out.add(s);
        }
        // advance to next ')' or ','
        // ignore: curly_braces_in_flow_control_structures
        while (i < raw.length && raw[i] != ')' && raw[i] != ',') i++;
        if (i < raw.length && (raw[i] == ')' || raw[i] == ',')) i++;
        continue;
      }
      i++;
    }
    return out;
  }

  static bool isVueMacro(String name) {
    return name == defineOptions ||
        name == defineSlots ||
        name == defineModel ||
        name == defineExpose ||
        name == defineEmits ||
        name == defineProps ||
        name == withDefaults;
  }

  static String marcoNameToSetup(String name) {
    switch (name) {
      case CodegenHelpers.defineProps:
      case CodegenHelpers.withDefaults:
        return setupProps;
      // return 'propsDefaults';
      case CodegenHelpers.defineEmits:
        return setupEmit;
      // return 'emits';
      default:
        return '';
    }
  }
}
