import 'dart:convert';
import 'package:vue_sfc_parser/is_identifier_name.dart';
import 'package:vue_sfc_parser/logger.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';
import 'package:vue_sfc_parser/ts_ast.dart';

List<String> collectModelCombinedEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  final props = collectModelPropsEntries(unit, src);
  final mods = collectModelModifiersEntries(unit, src);
  // Build in the order of defineModel statements
  int pi = 0, mi = 0;
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    if (pi < props.length) out.add(props[pi++]);
    if (mi < mods.length) out.add(mods[mi++]);
  }
  return out;
}

List<String> collectModelEmitEvents(CompilationUnit unit) {
  final out = <String>[];
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    final name = firstStringArg(e) ?? '"modelValue"';
    final ev = '"update:${name.replaceAll('"', '')}"';
    out.add(ev);
  }
  return out;
}

List<String> collectModelModifiersEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is! FunctionCallExpression) continue;
    if (e.methodName.name != 'defineModel') continue;
    final name = firstStringArg(e) ?? '"modelValue"';
    final raw = name.replaceAll('"', '');
    final mod = raw == 'modelValue' ? 'modelModifiers' : '${raw}Modifiers';
    out.add('$mod: {}');
  }
  return out;
}

/// 1. `const model= defineModel()` → modelValue with optional defaults
/// 2. `const [model, modelModifiers]= defineModel()` → modelValue with optional defaults
/// 3. `const name = defineModel('name')` → named model with corresponding modifiers entry
///
///
///
/// This function walks the AST `CompilationUnit` to locate `defineModel` macro
/// calls and converts them into a Vue runtime props-object text that can be
/// merged into the component `props` option. It supports:
/// - `const model= defineModel()` → modelValue with optional defaults
/// - `const [model, modelModifiers]= defineModel()` → modelValue with optional defaults
/// - `const name = defineModel('name')` → named model with corresponding modifiers entry
/// - `defineModel()` → modelValue with optional defaults
/// - `defineModel('name')` → named model with corresponding modifiers entry
/// - `defineModel<T>()` → type mapped to Vue runtime constructors
/// - `defineModel('name', { type, default, required, local })` → inline options
/// - `defineModel({ type, default, required, local })` → inline options for default model
///
/// Returned string is an object literal text containing both the model prop
/// entries and the companion modifiers entries, e.g.:
/// `{
///     modelValue: { type: String, default: '' },
///     modelModifiers: {}
///   }`
List<String> collectModelPropsEntries(CompilationUnit unit, String src) {
  final out = <String>[];
  for (final st in unit.statements) {
    final exp = st.expression;
    // TODO: implement e is VariableDeclaration
    if (exp is VariableDeclaration) {
      // String intText = exp.init?.text ?? '';

      BindingPattern? binding = exp.pattern;

      Expression? intExp = exp.init;

      ///  input:
      ///    const [model, modelModifiers] = defineModel();
      ///  output:
      ///     in props:
      ///   props: _mergeModel(definedProps ,{ modelValue:{} ,modelModifiers:{} })
      ///     in setup body
      ///   const [model,modelModifiers] =_useModel(__props,'modelValue')
      /// input:
      ///  const [model, modelModifiers] = defineModel({type:String,default:1});
      ///  output:
      ///     in props:
      ///   props: _mergeModel(definedProps ,{ modelValue:{type:String,default:1} ,modelModifiers:{} })
      ///     in setup body
      ///  const [model,modelModifiers] =_useModel(__props,'modelValue')
      ///
      /// input:
      ///  const [model, modelModifiers] = defineModel('modelName', {type:String,default:1});
      /// output:
      ///     in props:
      ///   props: _mergeModel(definedProps ,{ modelName:{type:String,default:1} ,modelNameModifiers:{} })
      ///     in setup body
      ///  const [model,modelModifiers] =_useModel(__props,'modelName')
      if (binding is ArrayBindingPattern && binding.elements.length == 2) {
        String rawName = 'modelValue';
        String typeText = 'Object';
        if (intExp is FunctionCallExpression &&
            CodegenHelpers.isDefineModel(intExp.methodName.name)) {
          if (intExp.typeArgumentText != null &&
              intExp.typeArgumentText!.isNotEmpty) {
            final tt = intExp.typeArgumentText!
                .replaceAll('<', '')
                .replaceAll('>', '');
            final types = _runtimeTypesFromTypeText(tt);
            typeText = types.length == 1 ? types[0] : '[${types.join(', ')}]';
          } else {
            final obj = firstObjectArg(intExp);
            if (obj != null) {
              for (final m in obj.elements) {
                if (m.keyText == 'type') {
                  typeText = normalizeObjectText(m.value.text);
                }
              }
            }
          }
          final nm = firstStringArg(intExp);
          if (nm != null && nm.isNotEmpty) {
            rawName = nm.replaceAll('"', '');
          }
        } else if (intExp is Identifier &&
            CodegenHelpers.isDefineModel(intExp.name)) {}
        final isIdent = isIdentifierName(rawName);
        final keyText = isIdent ? rawName : '"$rawName"';
        out.add('$keyText: { type: $typeText }');
      }

      // if (intExp is FunctionCallExpression) {
      //   print(intExp.methodName.name);
      // }

      // if (intText.startsWith(CodegenHelpers.defineModel)) {
      //   print(exp.name.name);
      // }

      // print(exp.init?.text);
    }

    if (exp is FunctionCallExpression &&
        CodegenHelpers.isDefineModel(exp.methodName.name)) {
      String name = firstStringArg(exp) ?? '"modelValue"';
      String typeText = 'Object';
      if (exp.typeArgumentText != null && exp.typeArgumentText!.isNotEmpty) {
        final tt = exp.typeArgumentText!
            .replaceAll('<', '')
            .replaceAll('>', '');
        final types = _runtimeTypesFromTypeText(tt);
        typeText = types.length == 1 ? types[0] : '[${types.join(', ')}]';
      } else {
        final obj = firstObjectArg(exp);
        if (obj != null) {
          for (final m in obj.elements) {
            if (m.keyText == 'type') {
              typeText = normalizeObjectText(m.value.text);
            }
          }
        }
      }
      String spread = '';
      String? inlineDefault;
      // first argument object carries extras like default/required/local
      SetOrMapLiteral? obj0;
      if (exp.argumentList.arguments.isNotEmpty &&
          exp.argumentList.arguments[0] is SetOrMapLiteral) {
        obj0 = exp.argumentList.arguments[0] as SetOrMapLiteral;
      }
      // compute raw name once for decision-making
      final rawName = name.replaceAll('"', '');
      if (obj0 != null) {
        final extras = <String>[];
        for (final m in obj0.elements) {
          if (m.keyText == 'type') continue;
          final kv = '${m.keyText}: ${normalizeObjectText(m.value.text)}';
          if (m.keyText == 'default' && rawName == 'modelValue') {
            inlineDefault = normalizeObjectText(m.value.text);
            continue;
          }
          extras.add(kv);
        }
        if (extras.isNotEmpty) {
          spread = ', ...{ ${extras.join(', ')} }';
        }
      }
      // merge second arg limited options into spread (default/required/local)
      if (exp.argumentList.arguments.length >= 2) {
        final a2 = exp.argumentList.arguments[1];
        if (a2 is SetOrMapLiteral) {
          final extras2 = <String>[];
          for (final m in a2.elements) {
            if (m.keyText == 'default' ||
                m.keyText == 'required' ||
                m.keyText == 'local') {
              if (m.keyText == 'default' && rawName == 'modelValue') {
                inlineDefault = normalizeObjectText(m.value.text);
                continue;
              }
              extras2.add('${m.keyText}: ${normalizeObjectText(m.value.text)}');
            }
          }
          if (extras2.isNotEmpty) {
            if (spread.isEmpty) {
              spread = ', ...{ ${extras2.join(', ')} }';
            } else {
              spread = spread.replaceFirst(' }', ', ${extras2.join(', ')} }');
            }
          }
        }
      }
      // inline default for canonical model name "modelValue"
      final defaultPart = (inlineDefault != null && rawName == 'modelValue')
          ? ', default: $inlineDefault'
          : '';
      final isIdent = isIdentifierName(rawName);
      final keyText = isIdent ? rawName : name;
      out.add('$keyText: { type: $typeText$defaultPart$spread }');
    }
  }
  return out;
}

List<String> eventsFromTypeArgs(String raw) {
  final out = <String>[];
  final re = RegExp('\\(\\s*[A-Za-z_\$]\\w*\\s*:\\s*[\'\"]([^\'\"]+)[\'\"]');
  for (final m in re.allMatches(raw)) {
    out.add(m.group(1)!);
  }
  return out;
}

String? extractFirstStringArg(String rhs) {
  final sm = RegExp("\\(\\s*(['\"][^'\"]+['\"])").firstMatch(rhs);
  return sm?.group(1)!.trim();
}

ListLiteral? firstArrayArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is ListLiteral) return a;
  }
  return null;
}

SetOrMapLiteral? firstObjectArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is SetOrMapLiteral) return a;
  }
  return null;
}

String? firstStringArg(FunctionCallExpression call) {
  for (final a in call.argumentList.arguments) {
    if (a is StringLiteral) return '"${a.stringValue}"';
  }
  return null;
}

String fmtImport(String line) {
  var t = line.trim();
  t = t.replaceAll("'", '"');
  if (!t.endsWith(';')) t = '$t;';
  return t;
}

String fmtInlinePropsObject(SetOrMapLiteral obj) {
  // Keep as single-line when possible
  final text = normalizeObjectText(obj.text);
  return text;
}

String fmtPropsFromType(
  List<PropSignature> props,
  Map<String, String> defaults,
) {
  final buf = StringBuffer();
  buf.writeln('{');
  for (var i = 0; i < props.length; i++) {
    final p = props[i];
    final types = _runtimeTypesFromTypeText(p.type ?? '');
    final typeText = types.length == 1 ? types[0] : '[${types.join(', ')}]';
    final required = p.required ? 'true' : 'false';
    final def = defaults.containsKey(p.name)
        ? ", default: ${defaults[p.name]!}"
        : '';
    buf.writeln('    ${p.name}: { type: $typeText, required: $required$def },');
  }
  buf.write('  }');
  return buf.toString();
}

// removed: legacy runtime import ordering helper (not used)

// removed: unused slice helper (duplicate of sfc_compile_script)

String fmtStmt(String line) {
  var t = line.trimRight();
  return t;
}

String fmtStringArray(ListLiteral arr) {
  final items = arr.elements
      .whereType<StringLiteral>()
      .map((s) => '"${s.stringValue}"')
      .join(', ');
  return '[$items]';
}

String normalizeObjectText(String text) {
  var t = text.trim();
  t = t.replaceAll("'", '"');
  t = t.split('\n').map((l) => l.trimLeft()).join('\n');
  return t;
}

String? resolveTypeAliasBodyFromSource(String src, String ident) {
  final re = RegExp(
    r"(^|\n)\s*(export\s+)?type\s+" + ident + r"\s*=\s*([\s\S]+?)\n",
    multiLine: true,
  );
  final m = re.firstMatch(src);
  return m?.group(3);
}

bool shouldUseDefineComponentHeader(CompilationUnit unit) {
  bool hasModel = false;
  bool anyGeneric = false;
  for (final st in unit.statements) {
    final e = st.expression;
    if (e is FunctionCallExpression && e.methodName.name == 'defineModel') {
      hasModel = true;
      if (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty) {
        anyGeneric = true;
      }
    }
  }
  if (hasModel && !anyGeneric) return false;
  return true;
}

// removed: unused slice helper
String sliceWithWordBacktrack(String src, int startByte, int endByte) {
  final bytes = utf8.encode(src);
  int s = startByte.clamp(0, bytes.length);
  final e = endByte.clamp(0, bytes.length);
  // backtrack to include leading word character if needed
  while (s > 0) {
    final prev = bytes[s - 1];
    // A-Z a-z underscore
    final isAlphaNum =
        (prev >= 65 && prev <= 90) || (prev >= 97 && prev <= 122) || prev == 95;
    if (!isAlphaNum) break;
    s -= 1;
  }
  if (e <= s) return '';
  return utf8.decode(bytes.sublist(s, e));
}

String? stripBraces(String? obj) {
  if (obj == null) return null;
  final t = obj.trim();
  if (t.startsWith('{') && t.endsWith('}')) {
    return t.substring(1, t.length - 1);
  }
  return obj;
}

List<String> _runtimeTypesFromTypeText(String t) {
  final parts = t
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String mapType(String s) {
    if (RegExp(r'\w+\[\]').hasMatch(s)) return 'Array';
    switch (s) {
      case 'string':
        return 'String';
      case 'number':
        return 'Number';
      case 'boolean':
        return 'Boolean';
      case 'object':
        return 'Object';
      default:
        return 'Object';
    }
  }

  final mapped = parts.map(mapType).toList();
  // dedupe
  final out = <String>[];
  for (final m in mapped) {
    if (!out.contains(m)) out.add(m);
  }
  return out;
}

final class ScriptCodegen {
  /// Collect declared identifiers from a `CompilationUnit` for use in
  /// returned bindings ordering. Accepts only `CompilationUnit` and returns
  /// a de-duplicated list of names from variable, function and class declarations.
  static List<String> walkDeclarations(CompilationUnit unit) {
    final out = <String>[];
    for (final st in unit.statements) {
      final exp = st.expression;
      if (exp is ExportAllDeclaration) continue;
      if (exp is ExportDefaultDeclaration) continue;
      if (exp is ExportNamedDeclaration) continue;
      if (exp is ImportExpression) continue;
      if (exp is ImportDeclaration) continue;
      //  type A =b
      if (exp is TSTypeAliasDeclaration) continue;
      //  interface A
      if (exp is TSInterfaceDeclaration) continue;
      //  declare function
      if (exp is TSDeclareFunction) continue;
      if (exp is VariableDeclaration) {
        final name = exp.name.name;
        if (name.isNotEmpty && !out.contains(name)) out.add(name);
      }
    }
    return out;
  }

  static String generate({required SetupResult setup}) {
    final buf = StringBuffer();
    final src = setup.source;
    final CompilationUnit compilation = setup.compilation;
    // e.g. _useSlots, _useModel
    final userImports = setup.setupImportLines ?? const <String>[];

    // TODO: 验证使用是否合法
    //  defineOptions / defineEmits / defineProps / defineSlots 只能调用一次
    // validateUsage(unit: setup.compilation, src: src, filename: setup.filename);

    // const a =1
    // fuction b =c

    WalkedSlots slots = CodegenHelpers.walkDefineSlots(setup.compilation);
    WalkedModels models = CodegenHelpers.walkDefineModels(setup.compilation);
    WalkedEmits emits = CodegenHelpers.walkDefineEmits(setup.compilation);
    WalkedExposes exposes = CodegenHelpers.walkDefineExposes(setup.compilation);
    final useDefines = walkDeclarations(compilation);
    bool hasDefineEmits = emits.isNotEmpty;
    bool hasDefineExpose = exposes.isNotEmpty;
    bool hasDefineModels = models.isNotEmpty;
    bool hasDefineProps = CodegenHelpers.hasDefineProps(setup.compilation);
    bool hasDefineSlots = slots.isNotEmpty;
    print(
      'hasDefineModels $hasDefineModels, hasDefineEmits $hasDefineEmits ,hasDefineExpose $hasDefineExpose , $hasDefineModels, hasDefineProps $hasDefineProps ,hasDefineSlots $hasDefineSlots',
    );

    if (slots.length > 1) {
      //
      // SourceLocation loc = slots.last.loc;

      // print(slots.last.loc);
      // print(slots.last);
      // throw ScriptError(
      //   message: '[@vue/compiler-sfc] duplicate defineSlots() call',
      //   locStart: loc.start.line,
      //   locEnd: loc.end.column,
      // );

      // throw SfcError(
      //   message: 'defineSlots can only be called once',
      //   filename: setup.filename,
      // );
    }
    List<String> aliases = setup.isTypescript
        ? [CodegenHelpers.defineComponent]
        : [];
    // Precompute body rewrite to decide header aliases

    final preModelEmits = collectModelEmitEvents(setup.compilation);
    final needsMergeModels =
        hasDefineModels && hasDefineProps || hasDefineEmits;
    // preModelCombined.isNotEmpty || preModelEmits.isNotEmpty;
    if (needsMergeModels) aliases.add(CodegenHelpers.mergeModels);
    // defineModels
    if (hasDefineModels) aliases.add(CodegenHelpers.useModel);
    buf.writeln(CodegenHelpers.importFromVue(aliases));
    buf.writeAll(userImports);
    // Then user imports（仅输出非 vue 源的导入；setup 的 vue 导入由上方按使用输出）
    // Normal <script> imports (e.g., createApp, namespace imports)
    final normalImports = setup.normalScriptImportLines ?? const <String>[];
    for (final line in normalImports) {
      buf.writeln(fmtImport(line));
    }
    // Always include namespace import for full vue access
    final maybeTypeDefs = _collectTypeAliasesFromUnit(setup.compilation);
    if (maybeTypeDefs.isNotEmpty) buf.writeln(maybeTypeDefs);
    final normalScript = setup.normalScriptSpreadText;
    if (normalScript != null) {
      buf.write(CodegenHelpers.defineNormalScriptDefault(normalScript));
    }
    // Component options start
    buf.writeln(CodegenHelpers.exportedLeading(setup.isTypescript));
    // Spread from normal <script> default export first
    if (normalScript != null) {
      buf.writeln('...${CodegenHelpers.normalScriptDefault},');
    }
    ArgumentList? defineOptions = CodegenHelpers.walkDefineOptions(
      setup.compilation,
    );
    if (defineOptions != null) {
      buf.writeln(
        "...${defineOptions.arguments.map((e) => e.text).join(', ')},",
      );
    }
    buf.writeln("  __name: '${setup.name}',");

    List<String> finalProps = [];

    // Props from defineProps
    if (hasDefineProps) {
      String? props = CodegenHelpers.extractDefineProps(setup.compilation);

      if (props != null) {
        finalProps.add(props.substring(1, props.length - 1));
      }
    }
    // Props from defineModel (AST-only via collectModelPropsEntries)
    if (hasDefineModels) {
      final modelPropEntries = collectModelPropsEntries(setup.compilation, src);
      if (modelPropEntries.isNotEmpty) {
        finalProps.add(modelPropEntries.join(', '));
      }
    }
    if (finalProps.isNotEmpty) {
      buf.write(CodegenHelpers.mergeProps(finalProps));
    }
    // emits (use _mergeModels to combine events)
    final modelEmits = preModelEmits;
    var stdEmits = CodegenHelpers.extractDefineEmits(setup.compilation);
    if (stdEmits == null) {
      String? scanEmitsFromSrc(String s) {
        int idxArr = s.indexOf('defineEmits([');
        if (idxArr >= 0) {
          int i = idxArr + 'defineEmits(['.length;
          int depth = 1;
          while (i < s.length) {
            final ch = s[i];
            if (ch == '[') depth++;
            if (ch == ']') {
              depth--;
              if (depth == 0) break;
            }
            i++;
          }
          if (i >= s.length) return null;
          final body = s.substring(idxArr + 'defineEmits(['.length, i);
          final items = body
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (items.isEmpty) return null;
          return '[${items.join(', ')}]';
        }
        int idxObj = s.indexOf('defineEmits({');
        if (idxObj >= 0) {
          int i = idxObj + 'defineEmits({'.length;
          int depth = 1;
          bool inStr = false;
          String quote = '';
          final keys = <String>[];
          String readIdent() {
            final start = i;
            while (i < s.length) {
              final c = s.codeUnitAt(i);
              final ok =
                  (c >= 65 && c <= 90) ||
                  (c >= 97 && c <= 122) ||
                  (c >= 48 && c <= 57) ||
                  c == 95 ||
                  c == 36;
              if (!ok) break;
              i++;
            }
            return s.substring(start, i);
          }

          String? readString() {
            final ch = s[i];
            if (ch != '\'' && ch != '"') return null;
            quote = ch;
            inStr = true;
            i++;
            final start = i;
            while (i < s.length) {
              if (s[i] == quote) {
                inStr = false;
                final v = s.substring(start, i);
                i++;
                return v;
              }
              i++;
            }
            return null;
          }

          void skipWs() {
            while (i < s.length) {
              final c = s.codeUnitAt(i);
              if (c == 32 || c == 9 || c == 10 || c == 13)
                i++;
              else
                break;
            }
          }

          while (i < s.length && depth > 0) {
            skipWs();
            if (i >= s.length) break;
            final ch = s[i];
            if (inStr) {
              if (ch == quote) inStr = false;
              i++;
              continue;
            }
            if (ch == '\'' || ch == '"') {
              final k = readString();
              if (k != null) keys.add(k);
              skipWs();
              // skip possible ':' or '('
              while (i < s.length && s[i] != ',' && s[i] != '}') {
                i++;
              }
              if (i < s.length && s[i] == ',') i++;
              continue;
            }
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
            // identifier key
            final key = readIdent();
            if (key.isNotEmpty) keys.add(key);
            // advance to next comma or closing brace
            while (i < s.length && s[i] != ',' && s[i] != '}') i++;
            if (i < s.length && s[i] == ',') i++;
          }
          if (keys.isNotEmpty) {
            return '[${keys.map((k) => '\'$k\'').join(', ')}]';
          }
        }
        return null;
      }

      stdEmits = scanEmitsFromSrc(src);
    }
    if (hasDefineModels) {
      final left = (stdEmits != null && stdEmits.trim().startsWith('['))
          ? stdEmits.trim()
          : (stdEmits == null ? '[]' : stdEmits.trim());
      final right = '[${modelEmits.join(', ')}]';

      /// model update events are appended to standard emits
      buf.write(CodegenHelpers.mergeEmits([left, right]));
    } else if (stdEmits != null) {
      buf.write(CodegenHelpers.mergeEmits([stdEmits]));
    }
    buf.writeln(CodegenHelpers.setupStart(setup.isTypescript, hasDefineEmits));
    if (exposes.isEmpty) {
      buf.writeln(CodegenHelpers.expose(null));
      buf.writeln('');
    }

    List<String> lines = [];

    //  setup body start
    for (final st in setup.compilation.statements) {
      final exp = st.expression;
      // bool isMacro = false;
      if (exp is FunctionCallExpression) {
        final nm = exp.methodName.name;
        bool isMacro = CodegenHelpers.isVueMacro(nm);
        if (isMacro) continue;
      } else if (exp is VariableDeclaration && exp.init is Identifier) {
        //  const props = defineProps
        //  const emit = defineEmits
        final callee = (exp.init as Identifier).name;
        bool isMacro = CodegenHelpers.isVueMacro(callee);
        if (isMacro) {
          formatMarcosBindings(lines, exp, callee);
          continue;
        }
      }
      final text = sliceWithWordBacktrack(src, st.startByte, st.endByte).trim();
      if (text.isNotEmpty) lines.add(text);
    }

    buf.writeAll(lines);
    buf.writeln('');
    //  setup body end
    // __returned__: appearance-based ordering from declarations and rewrite lines, excluding macro-only bindings
    final ordered = <String>[];
    for (final n in {...useDefines}) {
      if (!ordered.contains(n)) ordered.add(n);
    }

    for (final s in CodegenHelpers.returns(ordered)) {
      buf.writeln(s);
    }
    for (final s in CodegenHelpers.defineProperty()) {
      buf.writeln(s);
    }
    buf.writeln(CodegenHelpers.setupReturns);
    buf.writeln(CodegenHelpers.exportedTrailing(setup.isTypescript));
    return buf.toString();
  }

  static String _collectTypeAliasesFromUnit(CompilationUnit unit) {
    return '';
  }
}

String formaltLine(String kind, String id, String bound) {
  return "$kind $id = $bound;\n";
}

void formatMarcosBindings(
  List<String> lines,
  VariableDeclaration exp,
  String callee,
) {
  switch (callee) {
    case CodegenHelpers.defineEmits:
    case CodegenHelpers.defineProps:
    case CodegenHelpers.withDefaults:
      {
        String setupName = CodegenHelpers.marcoNameToSetup(callee);
        String declKind = exp.declKind!;
        String? bindings;
        if (exp.pattern == null) {
          bindings = exp.name.name;
        } else {
          if (callee == CodegenHelpers.withDefaults) {
            logger.warn("""
[@vue/compiler-sfc] withDefaults() is unnecessary when using destructure with defineProps().
Reactive destructure will be disabled when using withDefaults().
Prefer using destructure default values, e.g. const { foo = 1 } = defineProps(...). 
""");
          }
          if (exp.pattern is ObjectBindingPattern) {
            List<String> properties = (exp.pattern as ObjectBindingPattern)
                .properties
                .map((property) {
                  if (property.defaultValue == null) {
                    return property.key;
                  }
                  String? text = property.defaultValue?.text;
                  if (text == null) return property.key;
                  return "${property.key} = $text";
                })
                .toList();

            bindings = "{${properties.join(',')}}";
          } else if (exp.pattern is ArrayBindingPattern) {
            // const [items = [], config = "dark"] = defineProps<{
            //   title: string;
            //   count?: number;
            //   items: Item[];
            //   config?: { theme: "light" | "dark" };
            // }>();

            List<String> elements = (exp.pattern as ArrayBindingPattern)
                .elements
                .map((element) {
                  if (element.target is Identifier) {
                    String name = (element.target as Identifier).name;
                    String? text = element.defaultValue?.text;
                    if (text == null) return name;
                    return "$name = $text";
                  }
                  return '';
                })
                .toList();
            bindings = "[${elements.join(',')}]";
          }
        }
        lines.add(formaltLine(declKind, bindings!, setupName));
        break;
      }
    case CodegenHelpers.defineModel:
      break;

    case CodegenHelpers.defineSlots:
      break;
  }
}
