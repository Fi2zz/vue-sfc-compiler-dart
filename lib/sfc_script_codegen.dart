import 'dart:convert';
import 'package:vue_sfc_parser/is_identifier_name.dart';
import 'package:vue_sfc_parser/logger.dart';
import 'package:vue_sfc_parser/sfc_ast.dart';
import 'package:vue_sfc_parser/sfc_compiler.dart';
import 'package:vue_sfc_parser/sfc_error.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';

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

  // ignore: unnecessary_string_escapes
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

String fmtExport(String line) {
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
        if (c == 32 || c == 9 || c == 10 || c == 13) {
          i++;
        } else {
          break;
        }
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
      while (i < s.length && s[i] != ',' && s[i] != '}') {
        i++;
      }
      if (i < s.length && s[i] == ',') i++;
    }
    if (keys.isNotEmpty) {
      return '[${keys.map((k) => '\'$k\'').join(', ')}]';
    }
  }
  return null;
}

enum ImportType { import_ns, import_default, import }

class Imported {
  String name;
  String local;
  String source;
  ImportType type;
  Imported(this.name, this.local, this.source, this.type);
  @override
  String toString() {
    if (type == ImportType.import_ns) return '* as  $name';
    if (type == ImportType.import_default) return name;
    if (name == local) return name;
    return "$name as $local";
  }
}

//  Implementation of importedsToCode
//  ImportType.import_ns ->  import * as name from 'source'
//  ImportType.import_default -> import name from 'source'
//  ImportType.import -> import {name as local} from 'source'
//  returns a list of import statements
List<String> importedsToCode(Map<String, List<Imported>> importeds) {
  final out = <String>[];
  String specText(Imported it) {
    if (it.type == ImportType.import_ns) return '* as ${it.local}';
    if (it.type == ImportType.import_default) return it.local;
    // named
    return it.name == it.local ? it.name : '${it.name} as ${it.local}';
  }

  for (final entry in importeds.entries) {
    final source = entry.key;
    final items = entry.value;
    if (items.isEmpty) continue;

    Imported? def = items.firstWhere(
      (e) => e.type == ImportType.import_default,
      orElse: () => Imported('', '', source, ImportType.import),
    );
    if (def.type != ImportType.import_default) def = null;
    Imported? ns = items.firstWhere(
      (e) => e.type == ImportType.import_ns,
      orElse: () => Imported('', '', source, ImportType.import),
    );
    if (ns.type != ImportType.import_ns) ns = null;
    final named = items.where((e) => e.type == ImportType.import).toList();

    String quoteSrc(String s) => '"$s"';

    // Compose statements respecting ES module syntax
    // Do not merge namespace with default: emit as separate lines
    if (ns != null && def != null) {
      out.add('import * as ${ns.local} from ${quoteSrc(source)};');
      out.add('import ${def.local} from ${quoteSrc(source)};');
      if (named.isNotEmpty) {
        final specs = named.map(specText).join(', ');
        out.add('import { $specs } from ${quoteSrc(source)};');
      }
      continue;
    }
    if (ns != null) {
      out.add('import * as ${ns.local} from ${quoteSrc(source)};');
      // If named also present, emit separate named import
      if (named.isNotEmpty) {
        final specs = named.map(specText).join(', ');
        out.add('import { $specs } from ${quoteSrc(source)};');
      }
      continue;
    }
    if (def != null && named.isNotEmpty) {
      final specs = named.map(specText).join(', ');
      out.add('import ${def.local}, { $specs } from ${quoteSrc(source)};');
      continue;
    }
    if (def != null) {
      out.add('import ${def.local} from ${quoteSrc(source)};');
      continue;
    }
    if (named.isNotEmpty) {
      final specs = named.map(specText).join(', ');
      out.add('import { $specs } from ${quoteSrc(source)};');
      continue;
    }
  }
  return out;
}

/// Generate import statements from module declarations while preserving original order.
/// This function emits one statement per `ImportDeclaration` encountered, without
/// merging across different declarations, thereby respecting user input order.
List<String> moduleImportsToCode(List<Declaration> modules) {
  final out = <String>[];
  String quoteSrc(String s) => '"$s"';
  for (final decl in modules) {
    if (decl is! ImportDeclaration) continue;
    final source = decl.source.stringValue;
    String? defLocal;
    String? nsLocal;
    final namedSpecs = <String>[];
    for (final spec in decl.specifiers) {
      if (spec is ImportDefaultSpecifier) {
        defLocal = spec.local.name;
      } else if (spec is ImportNamespaceSpecifier) {
        nsLocal = spec.local.name;
      } else if (spec is ImportSpecifier) {
        final imported = spec.imported;
        if (imported is Identifier) {
          final name = imported.name;
          final local = spec.local.name;
          namedSpecs.add(name == local ? name : '$name as $local');
        } else if (imported is StringLiteral) {
          // e.g., default as foo
          final name = imported.stringValue;
          final local = spec.local.name;
          namedSpecs.add(name == local ? name : '$name as $local');
        }
      }
    }
    if (nsLocal != null && defLocal != null) {
      // Both namespace and default in same declaration: emit a combined line (user input style)
      out.add('import $defLocal, * as $nsLocal from ${quoteSrc(source)};');
      if (namedSpecs.isNotEmpty) {
        out.add(
          'import { ${namedSpecs.join(', ')} } from ${quoteSrc(source)};',
        );
      }
      continue;
    }
    if (nsLocal != null) {
      out.add('import * as $nsLocal from ${quoteSrc(source)};');
      if (namedSpecs.isNotEmpty) {
        out.add(
          'import { ${namedSpecs.join(', ')} } from ${quoteSrc(source)};',
        );
      }
      continue;
    }
    if (defLocal != null && namedSpecs.isNotEmpty) {
      out.add(
        'import $defLocal, { ${namedSpecs.join(', ')} } from ${quoteSrc(source)};',
      );
      continue;
    }
    if (defLocal != null) {
      out.add('import $defLocal from ${quoteSrc(source)};');
      continue;
    }
    if (namedSpecs.isNotEmpty) {
      out.add('import { ${namedSpecs.join(', ')} } from ${quoteSrc(source)};');
      continue;
    }
  }
  return out;
}

/// Convert module-level export declarations into code strings (ESM only), preserving order.
List<String> moduleExportsToCode(List<Declaration> userDefinedExports) {
  final out = <String>[];
  String quoteSrc(String s) => '"$s"';
  for (final decl in userDefinedExports) {
    if (decl is ExportDefaultDeclaration) {
      final text = (decl.declaration is Expression)
          ? (decl.declaration as Expression).text
          : null;
      if (text != null && text.isNotEmpty) {
        out.add(fmtExport('export default $text'));
      } else {
        out.add(fmtExport('export default'));
      }
    } else {
      // logger.log('[ExportNamedDeclaration] hello $decl');
      if (decl is ExportNamedDeclaration) {
        final specs = decl.specifiers;
        final src = decl.source;
        if (specs.isNotEmpty && src == null) {
          final parts = <String>[];
          for (final s in specs) {
            if (s is ExportSpecifier) {
              final local = s.local.name;
              final exported = s.exported is Identifier
                  ? (s.exported as Identifier).name
                  : (s.exported as StringLiteral).stringValue;
              parts.add(local == exported ? local : '$local as $exported');
            } else if (s is ExportNamespaceSpecifier) {
              parts.add('* as ${s.exported.name}');
            }
          }
          out.add(fmtExport('export { ${parts.join(', ')} }'));
          // continue;
        }
        if (specs.isNotEmpty && src != null) {
          final parts = <String>[];
          for (final s in specs) {
            if (s is ExportSpecifier) {
              final local = s.local.name;
              final exported = s.exported is Identifier
                  ? (s.exported as Identifier).name
                  : (s.exported as StringLiteral).stringValue;
              parts.add(local == exported ? local : '$local as $exported');
            } else if (s is ExportNamespaceSpecifier) {
              parts.add('* as ${s.exported.name}');
            }
          }
          out.add(
            fmtExport(
              'export { ${parts.join(', ')} } from ${quoteSrc(src.stringValue)}',
            ),
          );
        }
      } else if (decl is ExportAllDeclaration) {
        final src = decl.source.stringValue;
        out.add(fmtExport('export * from ${quoteSrc(src)}'));
      }
    }
  }
  return out;
}

/// Collect declared identifiers from a `CompilationUnit` for use in
/// returned bindings ordering. Accepts only `CompilationUnit` and returns
/// a de-duplicated list of names from variable, function and class declarations.
//  exclude export * from 'x'
//  exclude export default
//  exclude export { a, b as c } from 'x'

List<String> walkUserDefines(CompilationUnit unit) {
  final out = <String>[];

  List<ExpressionStatement> statements = unit.statements
      .whereType<ExpressionStatement>()
      .where(
        (unit) =>
            unit.expression is VariableDeclaration ||
            unit.expression is FunctionDeclaration,
      )
      .toList();

  for (final st in statements) {
    final exp = st.expression;
    // if (exp is ExportAllDeclaration) continue;
    // if (exp is ExportDefaultDeclaration) continue;
    // if (exp is ExportNamedDeclaration) continue;
    // if (exp is ImportExpression) continue;
    // if (exp is ImportDeclaration) continue;
    // //  type A =b
    // if (exp is TSTypeAliasDeclaration) continue;
    // //  interface A
    // if (exp is TSInterfaceDeclaration) continue;
    // //  declare function
    // if (exp is TSDeclareFunction) continue;
    if (exp is VariableDeclaration) {
      final name = exp.name.name;
      if (name.isNotEmpty && !out.contains(name)) out.add(name);
    }
    if (exp is FunctionDeclaration) {
      // final name = exp.name.name;
      // if (name.isNotEmpty && !out.contains(name)) out.add(name);
    }
  }
  logger.warn("$out");
  // print(ou8)
  return out;
}

final class ScriptCodegen {
  // static walkModulesExports(List<Declaration> modules) {}

  static String generate({
    required Prepared prepared,
    bool useAstPrinter = true,
  }) {
    List<String> generated = [];
    List<String> body = [];
    final src = prepared.source;
    final CompilationUnit unit = prepared.setup;

    // normal script
    final scriptExports = prepared.normal != null
        ? moduleExportsToCode(prepared.normal!.exported)
        : [];
    WalkedSlots slots = CodegenHelpers.walkDefineSlots(unit);
    WalkedModels models = CodegenHelpers.walkDefineModels(unit);
    WalkedEmits emits = CodegenHelpers.walkDefineEmits(unit);
    WalkedExposes exposes = CodegenHelpers.walkDefineExposes(unit);
    final useDefines = walkUserDefines(unit);
    bool hasDefineEmits = emits.isNotEmpty;
    bool hasDefineModels = models.isNotEmpty;
    bool hasDefineProps = CodegenHelpers.hasDefineProps(unit);
    // unit.userVariables

    // print(useDefines.length - unit.userVariables.length);

    final userVars = unit.userVariables
        .map((e) => e.name)
        .where((n) => n.isNotEmpty)
        .where((n) => !CodegenHelpers.isVueMacro(n))
        .toList();

    // print(unit.userVariables);
    // if(setupExports .isNotEmpty)
    //   {
    //     throw ScriptError(
    //       message: '[@vue/compiler-sfc] duplicate defineSlots() call',
    //       locStart: slots.last.loc.start.line,
    //       locEnd: slots.last.loc.end.column,
    //     );
    //   }

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
    List<String> aliases = prepared.isTypescript
        ? [CodegenHelpers.defineComponent]
        : [];
    // Precompute body rewrite to decide header aliases

    final preModelEmits = collectModelEmitEvents(unit);
    final needsMergeModels =
        hasDefineModels && hasDefineProps || hasDefineEmits;
    // preModelCombined.isNotEmpty || preModelEmits.isNotEmpty;
    if (needsMergeModels) aliases.add(CodegenHelpers.mergeModels);
    // defineModels
    if (hasDefineModels) aliases.add(CodegenHelpers.useModel);
    generated.add(CodegenHelpers.importFromVue(aliases));

    if (scriptExports.isNotEmpty) {
      for (final line in scriptExports) {
        if (line.trim().startsWith('export default')) continue;
        generated.add(fmtExport(line));
      }
    }

    // normal <script> named exports are emitted via prepared.normal.exported only

    final setupImports = moduleImportsToCode(prepared.setup.imported);
    if (setupImports.isNotEmpty) {
      for (final line in setupImports) {
        generated.add(fmtImport(line));
      }
    }

    final normal = prepared.normal;
    if (normal != null) {
      final normalImports = moduleImportsToCode(normal.imported);
      if (normalImports.isNotEmpty) {
        for (final line in normalImports) {
          generated.add(fmtImport(line));
        }
      }
    }

    // if(n)

    // headers.addAll(userImports);
    logger.log('[codegen] headers imports=${generated.length}');
    // Then user imports（仅输出非 vue 源的导入；setup 的 vue 导入由上方按使用输出）
    // Always include namespace import for full vue access
    final maybeTypeDefs = _collectTypeAliasesFromUnit(unit);
    if (maybeTypeDefs.isNotEmpty) generated.add(maybeTypeDefs);
    // derive normal <script> default export object from prepared.normal AST
    String? normalScript;
    if (prepared.normal != null) {
      for (final d in prepared.normal!.exported) {
        if (d is ExportDefaultDeclaration) {
          final text = (d.declaration is Expression)
              ? (d.declaration as Expression).text
              : null;
          if (text != null && text.isNotEmpty) {
            normalScript = text;
            break;
          }
        }
      }
    }
    if (normalScript != null && normalScript.isNotEmpty) {
      generated.add(CodegenHelpers.defineNormalScriptDefault(normalScript));
    }
    // Component options start
    // body.add(CodegenHelpers.exportedLeading(setup.isTypescript));
    // Spread from normal <script> default export first
    if (normalScript != null && normalScript.isNotEmpty) {
      body.add('...${CodegenHelpers.normalScriptDefault},');
    }
    ArgumentList? defineOptions = CodegenHelpers.walkDefineOptions(unit);
    if (defineOptions != null) {
      body.add("...${defineOptions.arguments.map((e) => e.text).join(', ')},");
    }
    // removed __name to align with official output for complex sample

    List<String> finalProps = [];

    // Props from defineProps
    if (hasDefineProps) {
      String? props = CodegenHelpers.extractDefineProps(unit);
      if (props != null) {
        finalProps.add(props.substring(1, props.length - 1));
      }
    }
    // Props from defineModel (AST-only via collectModelPropsEntries)
    if (hasDefineModels) {
      final modelPropEntries = collectModelPropsEntries(unit, src);
      if (modelPropEntries.isNotEmpty) {
        finalProps.add(modelPropEntries.join(', '));
      }
    }
    if (finalProps.isNotEmpty) {
      body.add(CodegenHelpers.mergeProps(finalProps));
    }
    logger.log('[codegen] props merged=${finalProps.isNotEmpty}');
    // emits (use _mergeModels to combine events)
    final modelEmits = preModelEmits;
    var stdEmits = CodegenHelpers.extractDefineEmits(unit);
    stdEmits ??= scanEmitsFromSrc(src);
    if (hasDefineModels) {
      final left = (stdEmits != null && stdEmits.trim().startsWith('['))
          ? stdEmits.trim()
          : (stdEmits == null ? '[]' : stdEmits.trim());
      final right = '[${modelEmits.join(', ')}]';

      /// model update events are appended to standard emits
      body.add(CodegenHelpers.mergeEmits([left, right]));
    } else if (stdEmits != null) {
      body.add(CodegenHelpers.mergeEmits([stdEmits]));
    }
    body.add(CodegenHelpers.setupStart(prepared.isTypescript, hasDefineEmits));
    if (exposes.isEmpty) {
      body.add(CodegenHelpers.expose(null));
    }

    List<String> lines = [];

    //  setup body start
    for (final st in unit.statements) {
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
      final text = _printStatement(
        st,
        src,
      ).trimRight(); //sliceWithWordBacktrack(src, st.startByte, st.endByte).trim();
      if (text.isNotEmpty) lines.add(text);
    }

    body.addAll(lines);

    // __returned__: appearance-based ordering from declarations and rewrite lines, excluding macro-only bindings
    final ordered = <String>[];
    for (final n in {...useDefines}) {
      if (!ordered.contains(n)) ordered.add(n);
    }
    for (final n in userVars) {
      if (!ordered.contains(n)) ordered.add(n);
    }

    for (final s in CodegenHelpers.returns(ordered)) {
      body.add(s);
    }
    for (final s in CodegenHelpers.defineProperty()) {
      body.add(s);
    }
    body.add(CodegenHelpers.setupReturns);
    String component = (CodegenHelpers.component(prepared.isTypescript, body));

    generated.add(component);

    return generated.join('\n');
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

String _printStatement(ExpressionStatement st, String src) {
  final e = st.expression;
  final t = _printExpression(e, src);
  // if (t.isEmpty) {
  //   final raw = sliceWithWordBacktrack(src, st.startByte, st.endByte).trim();
  //   return raw;
  // }
  final trimmed = t.trimRight();
  if (trimmed.endsWith(';')) return trimmed;
  return '$trimmed;';
}

String _printExpression(Expression e, String src) {
  if ((e.text).isNotEmpty) return fmtStmt(e.text);
  if (e is VariableDeclaration) return _printVariableDeclaration(e, src);
  if (e is FunctionCallExpression) {
    final name = e.methodName.name;
    final typeArgs =
        (e.typeArgumentText != null && e.typeArgumentText!.isNotEmpty)
        ? e.typeArgumentText!
        : '';
    final args = e.argumentList.arguments
        .map((a) => _printExpression(a, src))
        .join(', ');
    return '$name$typeArgs($args)';
  }
  if (e is Identifier) return e.name;
  if (e is StringLiteral) return '"${e.stringValue}"';
  if (e is NumberLiteral) return e.value.toString();
  if (e is BooleanLiteral) return e.value.toString();
  if (e is ListLiteral) return fmtStringArray(e);
  if (e is SetOrMapLiteral) return fmtInlinePropsObject(e);
  return '';
}

String _printVariableDeclaration(VariableDeclaration v, String src) {
  final kind = v.declKind ?? 'const';
  String left;
  if (v.pattern is ObjectBindingPattern) {
    left = _printObjectBindingPattern(v.pattern as ObjectBindingPattern);
  } else if (v.pattern is ArrayBindingPattern) {
    left = _printArrayBindingPattern(v.pattern as ArrayBindingPattern);
  } else {
    left = v.name.name;
  }
  if (v.init == null) return '$kind $left';
  final right = _printExpression(v.init as Expression, src);
  if (right.isEmpty) {
    final raw = sliceWithWordBacktrack(src, v.startByte, v.endByte).trim();
    return raw;
  }
  return '$kind $left = $right';
}

String _printObjectBindingPattern(ObjectBindingPattern p) {
  final parts = p.properties.map((prop) {
    final key = prop.key;
    final dv = prop.defaultValue;
    if (dv == null) return key;
    final v = _printExpression(dv, '');
    return '$key = $v';
  }).toList();
  return '{${parts.join(', ')}}';
}

String _printArrayBindingPattern(ArrayBindingPattern p) {
  final parts = p.elements.map((el) {
    if (el.target is Identifier) {
      final n = (el.target as Identifier).name;
      final dv = el.defaultValue;
      if (dv == null) return n;
      final v = _printExpression(dv, '');
      return '$n = $v';
    }
    return '';
  }).toList();
  return '[${parts.join(', ')}]';
}
