use anyhow::Result;
use serde_json::{json, Value};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_uchar};
use swc_common::comments::SingleThreadedComments;
use swc_common::sync::Lrc;
use swc_common::{FileName, SourceMap, SourceMapper, Span, Spanned};
use swc_ecma_ast::EsVersion;
use swc_ecma_ast::*;
use swc_ecma_parser::{lexer::Lexer, EsSyntax, Parser, StringInput, Syntax, TsSyntax};
fn json_node(cm: &SourceMap, span: Span) -> Value {
    let start = cm.lookup_char_pos(span.lo());
    let end = cm.lookup_char_pos(span.hi());
    let start_off = if span.lo.0 > 0 {
        span.lo.0 - 1
    } else {
        span.lo.0
    };
    let end_off = span.hi.0;
    let filename = match &*start.file.name {
        FileName::Custom(s) => s.clone(),
        _ => "input.ts".to_string(),
    };
    json!({
        "start": start_off,
        "end": end_off,
        "loc": {
            "start": {"line": start.line as u32, "column": start.col.0 as u32},
            "end": {"line": end.line as u32, "column": end.col.0 as u32},
            "filename": filename,
            "identifierName": Value::Null,
        }
    })
}

fn json_span(cm: &SourceMap, span: Span) -> Value {
    let start = cm.lookup_char_pos(span.lo());
    let end = cm.lookup_char_pos(span.hi());
    json!({
        "start": if span.lo.0 > 0 { span.lo.0 - 1 } else { span.lo.0 },
        "end": span.hi.0,
        "loc_start": {"line": start.line as u32, "column": start.col.0 as u32},
        "loc_end": {"line": end.line as u32, "column": end.col.0 as u32}
    })
}

fn module_to_json(cm: &SourceMap, module: &swc_ecma_ast::Module) -> Vec<Value> {
    let mut body: Vec<Value> = Vec::new();
    for item in &module.body {
        match item {
            ModuleItem::ModuleDecl(decl) => match decl {
                ModuleDecl::Import(import) => {
                    let src = import.src.value.as_str().unwrap_or_default().to_string();
                    let mut specs_json: Vec<Value> = Vec::new();
                    for s in &import.specifiers {
                        match s {
                            ImportSpecifier::Named(named) => {
                                let local = named.local.sym.to_string();
                                let mut imported_ident: Option<String> = None;
                                let mut imported_str: Option<String> = None;
                                match &named.imported {
                                    Some(ModuleExportName::Ident(i)) => {
                                        imported_ident = Some(i.sym.to_string());
                                    }
                                    Some(ModuleExportName::Str(st)) => {
                                        imported_str =
                                            Some(st.value.as_str().unwrap_or_default().to_string());
                                    }
                                    None => {}
                                }
                                let import_kind = if import.type_only {
                                    Some("type".to_string())
                                } else {
                                    None
                                };
                                specs_json.push(json!({
                                    "kind": "Named",
                                    "local": local,
                                    "imported_ident": imported_ident,
                                    "imported_str": imported_str,
                                    "import_kind": import_kind,
                                    "span": json_span(cm, named.span),
                                }));
                            }
                            ImportSpecifier::Default(def) => {
                                specs_json.push(json!({
                                    "kind": "Default",
                                    "local": def.local.sym.to_string(),
                                    "span": json_span(cm, def.span),
                                }));
                            }
                            ImportSpecifier::Namespace(ns) => {
                                specs_json.push(json!({
                                    "kind": "Namespace",
                                    "local": ns.local.sym.to_string(),
                                    "span": json_span(cm, ns.span),
                                }));
                            }
                        }
                    }
                    body.push(json!({
                        "type": "ImportDeclaration",
                        "start": json_node(cm, import.span)["start"],
                        "end": json_node(cm, import.span)["end"],
                        "loc": json_node(cm, import.span)["loc"],
                        "src": src,
                        "specifiers": specs_json,
                        "text": cm.span_to_snippet(import.span).ok(),
                    }));
                }
                ModuleDecl::ExportDefaultDecl(ed) => {
                    body.push(json!({
                        "type": "ExportDefaultDeclaration",
                        "start": json_node(cm, ed.span)["start"],
                        "end": json_node(cm, ed.span)["end"],
                        "loc": json_node(cm, ed.span)["loc"],
                        "obj_span": Value::Null,
                        "text": cm.span_to_snippet(ed.span).ok(),
                    }));
                }
                ModuleDecl::ExportDefaultExpr(ee) => {
                    let mut obj_span: Option<Value> = None;
                    let mut obj_props: Option<Vec<Value>> = None;
                    if let Expr::Object(obj) = &*ee.expr {
                        let start = cm.lookup_char_pos(obj.span.lo());
                        let end = cm.lookup_char_pos(obj.span.hi());
                        obj_span = Some(json!({
                            "start": if obj.span.lo.0 > 0 { obj.span.lo.0 - 1 } else { obj.span.lo.0 },
                            "end": obj.span.hi.0,
                            "loc_start": {"line": start.line as u32, "column": start.col.0 as u32},
                            "loc_end": {"line": end.line as u32, "column": end.col.0 as u32}
                        }));
                        let mut props: Vec<Value> = Vec::new();
                        for p in &obj.props {
                            match p {
                                PropOrSpread::Prop(pp) => match &**pp {
                                    Prop::KeyValue(kv) => {
                                        let (key_kind, key_text, computed, key_span, key_expr_text) = match &kv.key {
                                            PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                            PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                                            PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                            PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                            PropName::Computed(c) => {
                                                let t = cm.span_to_snippet(c.span).ok();
                                                ("Computed", String::new(), true, json_span(cm, c.span), t)
                                            }
                                        };
                                        let mut entry = json!({
                                            "kind": "KeyValue",
                                            "key_kind": key_kind,
                                            "key_text": key_text,
                                            "key_expr_text": key_expr_text,
                                            "computed": computed,
                                            "key_span": key_span,
                                            "span": json_span(cm, kv.value.span()),
                                        });
                                        match &*kv.value {
                                            Expr::Lit(Lit::Str(s)) => {
                                                entry["value_kind"] = json!("String");
                                                entry["value_text"] = json!(s.value.as_str().unwrap_or_default().to_string());
                                            }
                                            Expr::Lit(Lit::Num(n)) => {
                                                entry["value_kind"] = json!("Number");
                                                entry["value_text"] = json!(cm.span_to_snippet(n.span).unwrap_or_default());
                                            }
                                            Expr::Lit(Lit::Bool(b)) => {
                                                entry["value_kind"] = json!("Boolean");
                                                entry["value_text"] = json!(if b.value {"true"} else {"false"});
                                            }
                                            Expr::Lit(Lit::Null(_)) => {
                                                entry["value_kind"] = json!("Null");
                                                entry["value_text"] = json!("null");
                                            }
                                            Expr::Arrow(a) => {
                                                entry["func"] = json!({
                                                    "async": a.is_async,
                                                    "generator": false,
                                                    "params": serialize_pat_list(cm, &a.params),
                                                    "text": cm.span_to_snippet(a.span).ok(),
                                                });
                                            }
                                            Expr::Fn(f) => {
                                                let params = serialize_fn_params(cm, &f.function.params);
                                                entry["func"] = json!({
                                                    "async": f.function.is_async,
                                                    "generator": f.function.is_generator,
                                                    "params": params,
                                                    "return_type": f.function.return_type.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                                    "text": cm.span_to_snippet(f.function.span).ok(),
                                                });
                                            }
                                            _ => {}
                                        }
                                        props.push(entry);
                                    }
                                    Prop::Method(m) => {
                                        let (key_kind, key_text, computed, key_span, key_expr_text) = match &m.key {
                                            PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                            PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                                            PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                            PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                            PropName::Computed(c) => {
                                                let t = cm.span_to_snippet(c.span).ok();
                                                ("Computed", String::new(), true, json_span(cm, c.span), t)
                                            }
                                        };
                                        let params = serialize_fn_params(cm, &m.function.params);
                                        let body_stmts = serialize_block_stmts(cm, m.function.body.as_ref());
                                        props.push(json!({
                                            "kind": "Method",
                                            "key_kind": key_kind,
                                            "key_text": key_text,
                                            "key_expr_text": key_expr_text,
                                            "computed": computed,
                                            "key_span": key_span,
                                            "func": {
                                                "async": m.function.is_async,
                                                "generator": m.function.is_generator,
                                                "params": serialize_fn_params(cm, &m.function.params),
                                                "return_type": m.function.return_type.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                                "text": cm.span_to_snippet(m.function.span).ok(),
                                                "body_stmts": body_stmts,
                                            }
                                        }));
                                    }
                                    Prop::Getter(g) => {
                                        let (key_kind, key_text, computed, key_span, key_expr_text) = match &g.key {
                                            PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                            PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                                            PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                            PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                            PropName::Computed(c) => {
                                                let t = cm.span_to_snippet(c.span).ok();
                                                ("Computed", String::new(), true, json_span(cm, c.span), t)
                                            }
                                        };
                                        let body_stmts = serialize_block_stmts(cm, g.body.as_ref());
                                        props.push(json!({
                                            "kind": "Getter",
                                            "key_kind": key_kind,
                                            "key_text": key_text,
                                            "key_expr_text": key_expr_text,
                                            "computed": computed,
                                            "key_span": key_span,
                                            "func": {
                                                "async": false,
                                                "generator": false,
                                                "params": [],
                                                "return_type": g.type_ann.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                                "text": g.body.as_ref().and_then(|b| cm.span_to_snippet(b.span()).ok()),
                                                "body_stmts": body_stmts,
                                            }
                                        }));
                                    }
                                    Prop::Setter(s) => {
                                        let (key_kind, key_text, computed, key_span, key_expr_text) = match &s.key {
                                            PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                            PropName::Str(st) => ("String", st.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, st.span), None),
                                            PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                            PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                            PropName::Computed(c) => {
                                                let t = cm.span_to_snippet(c.span).ok();
                                                ("Computed", String::new(), true, json_span(cm, c.span), t)
                                            }
                                        };
                                        let params = serialize_pat(cm, &s.param);
                                        let body_stmts = serialize_block_stmts(cm, s.body.as_ref());
                                        props.push(json!({
                                            "kind": "Setter",
                                            "key_kind": key_kind,
                                            "key_text": key_text,
                                            "key_expr_text": key_expr_text,
                                            "computed": computed,
                                            "key_span": key_span,
                                            "func": {
                                                "async": false,
                                                "generator": false,
                                                "params": [params],
                                                "text": s.body.as_ref().and_then(|b| cm.span_to_snippet(b.span()).ok()),
                                                "body_stmts": body_stmts,
                                            }
                                        }));
                                    }
                                    Prop::Shorthand(id) => {
                                        props.push(json!({
                                            "kind": "KeyValue",
                                            "key_kind": "Ident",
                                            "key_text": id.sym.to_string(),
                                            "key_expr_text": Value::Null,
                                            "computed": false,
                                            "key_span": json_span(cm, id.span),
                                            "value_kind": "Ident",
                                            "value_text": id.sym.to_string(),
                                        }));
                                    }
                                    Prop::Assign(ap) => {
                                        let key = ap.key.sym.to_string();
                                        let val_text = cm.span_to_snippet(ap.value.span()).unwrap_or_default();
                                        props.push(json!({
                                            "kind": "KeyValue",
                                            "key_kind": "Ident",
                                            "key_text": key,
                                            "key_expr_text": Value::Null,
                                            "computed": false,
                                            "key_span": json_span(cm, ap.key.span),
                                            "value_text": val_text,
                                        }));
                                    }
                                },
                                PropOrSpread::Spread(se) => {
                                    props.push(json!({
                                        "kind": "Spread",
                                        "arg_text": cm.span_to_snippet(se.expr.span()).unwrap_or_default(),
                                        "span": json_span(cm, se.span()),
                                    }));
                                }
                            }
                        }
                        obj_props = Some(props);
                    }
                    body.push(json!({
                        "type": "ExportDefaultDeclaration",
                        "start": json_node(cm, ee.span)["start"],
                        "end": json_node(cm, ee.span)["end"],
                        "loc": json_node(cm, ee.span)["loc"],
                        "obj_span": obj_span,
                        "obj_props": obj_props,
                        "text": cm.span_to_snippet(ee.span).ok(),
                    }));
                }
                ModuleDecl::ExportNamed(en) => {
                    let mut specs_json: Vec<Value> = Vec::new();
                    for s in &en.specifiers {
                        match s {
                            ExportSpecifier::Named(named) => {
                                let local_ident = match &named.orig {
                                    ModuleExportName::Ident(i) => Some(i.sym.to_string()),
                                    ModuleExportName::Str(_) => None,
                                };
                                let mut exported_ident: Option<String> = None;
                                let mut exported_str: Option<String> = None;
                                match &named.exported {
                                    Some(ModuleExportName::Ident(i)) => {
                                        exported_ident = Some(i.sym.to_string());
                                    }
                                    Some(ModuleExportName::Str(st)) => {
                                        exported_str =
                                            Some(st.value.as_str().unwrap_or_default().to_string());
                                    }
                                    None => {}
                                }
                                let export_kind = if en.type_only {
                                    Some("type".to_string())
                                } else {
                                    None
                                };
                                specs_json.push(json!({
                                    "kind": "Named",
                                    "local_ident": local_ident,
                                    "exported_ident": exported_ident,
                                    "exported_str": exported_str,
                                    "export_kind": export_kind,
                                    "span": json_span(cm, named.span),
                                }));
                            }
                            ExportSpecifier::Namespace(ns) => {
                                let exported_ident = match &ns.name {
                                    ModuleExportName::Ident(i) => i.sym.to_string(),
                                    ModuleExportName::Str(st) => {
                                        st.value.as_str().unwrap_or_default().to_string()
                                    }
                                };
                                specs_json.push(json!({
                                    "kind": "NamespaceAlias",
                                    "exported_ident": exported_ident,
                                    "span": json_span(cm, ns.span),
                                }));
                            }
                            ExportSpecifier::Default(def) => {
                                let exported_ident = def.exported.sym.to_string();
                                let export_kind = if en.type_only {
                                    Some("type".to_string())
                                } else {
                                    None
                                };
                                specs_json.push(json!({
                                    "kind": "Named",
                                    "local_ident": Value::Null,
                                    "exported_ident": exported_ident,
                                    "exported_str": "default",
                                    "export_kind": export_kind,
                                    "span": json_span(cm, def.span()),
                                }));
                            }
                        }
                    }
                    let source = en
                        .src
                        .as_ref()
                        .map(|s| s.value.as_str().unwrap_or_default().to_string());
                    body.push(json!({
                        "type": "ExportNamedDeclaration",
                        "start": json_node(cm, en.span)["start"],
                        "end": json_node(cm, en.span)["end"],
                        "loc": json_node(cm, en.span)["loc"],
                        "specifiers": specs_json,
                        "source": source,
                        "text": cm.span_to_snippet(en.span).ok(),
                    }));
                }
                ModuleDecl::ExportAll(ea) => {
                    let src = ea.src.value.as_str().unwrap_or_default().to_string();
                    body.push(json!({
                        "type": "ExportAllDeclaration",
                        "start": json_node(cm, ea.span)["start"],
                        "end": json_node(cm, ea.span)["end"],
                        "loc": json_node(cm, ea.span)["loc"],
                        "src": src,
                        "exported_ident": Value::Null,
                        "text": cm.span_to_snippet(ea.span).ok(),
                    }));
                }
                ModuleDecl::ExportDecl(ed) => match &ed.decl {
                    Decl::Fn(f) => {
                        let name = f.ident.sym.to_string();
                        body.push(json!({
                            "type": "ExportFunctionDeclaration",
                            "start": json_node(cm, f.function.span)["start"],
                            "end": json_node(cm, f.function.span)["end"],
                            "loc": json_node(cm, f.function.span)["loc"],
                            "name": name,
                        }));
                    }
                    Decl::Class(c) => {
                        let name = c.ident.sym.to_string();
                        body.push(json!({
                            "type": "ExportClassDeclaration",
                            "start": json_node(cm, c.class.span)["start"],
                            "end": json_node(cm, c.class.span)["end"],
                            "loc": json_node(cm, c.class.span)["loc"],
                            "name": name,
                        }));
                    }
                    Decl::TsInterface(ii) => {
                        body.push(json!({
                            "type": "ExportNamedDeclaration",
                            "start": json_node(cm, ii.span)["start"],
                            "end": json_node(cm, ii.span)["end"],
                            "loc": json_node(cm, ii.span)["loc"],
                            "specifiers": [],
                            "source": Value::Null,
                            "text": cm.span_to_snippet(ii.span).ok(),
                        }));
                    }
                    Decl::TsTypeAlias(ta) => {
                        body.push(json!({
                            "type": "ExportNamedDeclaration",
                            "start": json_node(cm, ta.span)["start"],
                            "end": json_node(cm, ta.span)["end"],
                            "loc": json_node(cm, ta.span)["loc"],
                            "specifiers": [],
                            "source": Value::Null,
                            "text": cm.span_to_snippet(ta.span).ok(),
                        }));
                    }
                    Decl::TsEnum(en) => {
                        body.push(json!({
                            "type": "ExportNamedDeclaration",
                            "start": json_node(cm, en.span)["start"],
                            "end": json_node(cm, en.span)["end"],
                            "loc": json_node(cm, en.span)["loc"],
                            "specifiers": [],
                            "source": Value::Null,
                            "text": cm.span_to_snippet(en.span).ok(),
                        }));
                    }
                    Decl::Var(v) => {
                        let mut specs: Vec<Value> = Vec::new();
                        for d in &v.decls {
                            let mut names: Vec<String> = Vec::new();
                            collect_pat_idents(&d.name, &mut names);
                            for nm in names {
                                specs.push(json!({
                                    "kind": "Named",
                                    "local_ident": nm,
                                    "exported_ident": nm,
                                    "exported_str": Value::Null,
                                    "export_kind": Value::Null,
                                    "span": json_span(cm, d.name.span()),
                                }));
                            }
                        }
                        body.push(json!({
                            "type": "ExportNamedDeclaration",
                            "start": json_node(cm, v.span)["start"],
                            "end": json_node(cm, v.span)["end"],
                            "loc": json_node(cm, v.span)["loc"],
                            "specifiers": specs,
                            "source": Value::Null,
                            "text": cm.span_to_snippet(v.span).ok(),
                        }));
                    }
                    _ => {}
                },
                ModuleDecl::TsImportEquals(_)
                | ModuleDecl::TsExportAssignment(_)
                | ModuleDecl::TsNamespaceExport(_) => {}
            },
            ModuleItem::Stmt(stmt) => match stmt {
                Stmt::Decl(Decl::Var(v)) => {
                    for d in &v.decls {
                        let mut names: Vec<String> = Vec::new();
                        collect_pat_idents(&d.name, &mut names);
                        let decl_kind = match v.kind {
                            swc_ecma_ast::VarDeclKind::Var => "var",
                            swc_ecma_ast::VarDeclKind::Let => "let",
                            swc_ecma_ast::VarDeclKind::Const => "const",
                        }
                        .to_string();
                        let name = names.first().cloned().unwrap_or_default();
                        let mut init_text: Option<String> = None;
                        let mut init_callee_ident: Option<String> = None;
                        let mut init_type_args: Option<Vec<String>> = None;
                        let mut init_type_argument_text: Option<String> = None;
                        let mut init_type_arg_kinds: Option<Vec<String>> = None;
                        let mut init_type_ref_idents: Option<Vec<String>> = None;
                        let mut init_type_literal_props: Option<Vec<Vec<Value>>> = None;
                        let mut init_type_union_components: Option<Vec<Vec<String>>> = None;
                        let mut init_type_union_components_struct: Option<Vec<Vec<Value>>> = None;
                        let mut init_args: Option<Vec<String>> = None;
                        let mut init_arg_object_props: Option<Vec<Vec<Value>>> = None;
                        let mut init_object_props: Option<Vec<Value>> = None;
                        let mut init_span: Option<Value> = None;
                        let mut init_expr_kind: Option<String> = None;
                        let inited = d.init.is_some();
                        if let Some(init) = &d.init {
                            init_text = cm.span_to_snippet(init.span()).ok();
                            let sp = init.span();
                            let ns = cm.lookup_char_pos(sp.lo());
                            let ne = cm.lookup_char_pos(sp.hi());
                            init_span = Some(json!({
                                "start": if sp.lo.0 > 0 { sp.lo.0 - 1 } else { sp.lo.0 },
                                "end": sp.hi.0,
                                "loc_start": {"line": ns.line as u32, "column": ns.col.0 as u32},
                                "loc_end": {"line": ne.line as u32, "column": ne.col.0 as u32}
                            }));
                            if let Expr::Object(obj) = &**init {
                                init_expr_kind = Some("Object".to_string());
                                let mut props: Vec<Value> = Vec::new();
                                for p in &obj.props {
                                    match p {
                                        PropOrSpread::Prop(pp) => match &**pp {
                                            Prop::KeyValue(kv) => {
                                                let (key_kind, key_text, computed, key_span, key_expr_text) = match &kv.key {
                                                    PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                                    PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                                                    PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                                    PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                                    PropName::Computed(c) => {
                                                        let t = cm.span_to_snippet(c.span).ok();
                                                        ("Computed", String::new(), true, json_span(cm, c.span), t)
                                                    }
                                                };
                                                let mut entry = json!({
                                                    "kind": "KeyValue",
                                                    "key_kind": key_kind,
                                                    "key_text": key_text,
                                                    "key_expr_text": key_expr_text,
                                                    "computed": computed,
                                                    "key_span": key_span,
                                                    "span": json_span(cm, kv.value.span()),
                                                });
                                                match &*kv.value {
                                                    Expr::Lit(Lit::Str(s)) => {
                                                        entry["value_kind"] = json!("String");
                                                        entry["value_text"] = json!(s.value.as_str().unwrap_or_default().to_string());
                                                    }
                                                    Expr::Lit(Lit::Num(n)) => {
                                                        entry["value_kind"] = json!("Number");
                                                        entry["value_text"] = json!(cm.span_to_snippet(n.span).unwrap_or_default());
                                                    }
                                                    Expr::Lit(Lit::Bool(b)) => {
                                                        entry["value_kind"] = json!("Boolean");
                                                        entry["value_text"] = json!(if b.value {"true"} else {"false"});
                                                    }
                                                    Expr::Lit(Lit::Null(_)) => {
                                                        entry["value_kind"] = json!("Null");
                                                        entry["value_text"] = json!("null");
                                                    }
                                            Expr::Arrow(a) => {
                                                let body_stmts = match &*a.body {
                                                    swc_ecma_ast::BlockStmtOrExpr::BlockStmt(b) => serialize_block_stmts(cm, Some(b)),
                                                    swc_ecma_ast::BlockStmtOrExpr::Expr(_e) => Vec::new(),
                                                };
                                                entry["func"] = json!({
                                                    "async": a.is_async,
                                                    "generator": false,
                                                    "params": serialize_pat_list(cm, &a.params),
                                                    "text": cm.span_to_snippet(a.span).ok(),
                                                    "body_stmts": body_stmts,
                                                    "body_expr_text": match &*a.body { swc_ecma_ast::BlockStmtOrExpr::Expr(e) => cm.span_to_snippet(e.span()).ok(), _ => None },
                                                });
                                            }
                                            Expr::Fn(f) => {
                                                let body_stmts = serialize_block_stmts(cm, f.function.body.as_ref());
                                                entry["func"] = json!({
                                                    "async": f.function.is_async,
                                                    "generator": f.function.is_generator,
                                                    "params": serialize_fn_params(cm, &f.function.params),
                                                    "return_type": f.function.return_type.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                                    "text": cm.span_to_snippet(f.function.span).ok(),
                                                    "body_stmts": body_stmts,
                                                });
                                            }
                                                    _ => {}
                                                }
                                                props.push(entry);
                                            }
                                            Prop::Method(m) => {
                                                let (key_kind, key_text, computed, key_span, key_expr_text) = match &m.key {
                                                    PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                                    PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                                                    PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                                    PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                                    PropName::Computed(c) => {
                                                        let t = cm.span_to_snippet(c.span).ok();
                                                        ("Computed", String::new(), true, json_span(cm, c.span), t)
                                                    }
                                                };
                                                let params = serialize_fn_params(cm, &m.function.params);
                                                props.push(json!({
                                                    "kind": "Method",
                                                    "key_kind": key_kind,
                                                    "key_text": key_text,
                                                    "key_expr_text": key_expr_text,
                                                    "computed": computed,
                                                    "key_span": key_span,
                                                    "func": {
                                                        "async": m.function.is_async,
                                                        "generator": m.function.is_generator,
                                                        "params": params,
                                                        "return_type": m.function.return_type.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                                        "text": cm.span_to_snippet(m.function.span).ok(),
                                                    }
                                                }));
                                            }
                                            Prop::Getter(g) => {
                                                let (key_kind, key_text, computed, key_span, key_expr_text) = match &g.key {
                                                    PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                                    PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                                                    PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                                    PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                                    PropName::Computed(c) => {
                                                        let t = cm.span_to_snippet(c.span).ok();
                                                        ("Computed", String::new(), true, json_span(cm, c.span), t)
                                                    }
                                                };
                                                props.push(json!({
                                                    "kind": "Getter",
                                                    "key_kind": key_kind,
                                                    "key_text": key_text,
                                                    "key_expr_text": key_expr_text,
                                                    "computed": computed,
                                                    "key_span": key_span,
                                                    "func": {
                                                        "async": false,
                                                        "generator": false,
                                                        "params": [],
                                                        "return_type": g.type_ann.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                                        "text": g.body.as_ref().and_then(|b| cm.span_to_snippet(b.span()).ok()),
                                                    }
                                                }));
                                            }
                                            Prop::Setter(s) => {
                                                let (key_kind, key_text, computed, key_span, key_expr_text) = match &s.key {
                                                    PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                                                    PropName::Str(st) => ("String", st.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, st.span), None),
                                                    PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                                                    PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                                                    PropName::Computed(c) => {
                                                        let t = cm.span_to_snippet(c.span).ok();
                                                        ("Computed", String::new(), true, json_span(cm, c.span), t)
                                                    }
                                                };
                                                let params = serialize_pat(cm, &s.param);
                                                props.push(json!({
                                                    "kind": "Setter",
                                                    "key_kind": key_kind,
                                                    "key_text": key_text,
                                                    "key_expr_text": key_expr_text,
                                                    "computed": computed,
                                                    "key_span": key_span,
                                                    "func": {
                                                        "async": false,
                                                        "generator": false,
                                                        "params": [params],
                                                        "text": s.body.as_ref().and_then(|b| cm.span_to_snippet(b.span()).ok()),
                                                    }
                                                }));
                                            }
                                            Prop::Shorthand(id) => {
                                                props.push(json!({
                                                    "kind": "KeyValue",
                                                    "key_kind": "Ident",
                                                    "key_text": id.sym.to_string(),
                                                    "key_expr_text": Value::Null,
                                                    "computed": false,
                                                    "key_span": json_span(cm, id.span),
                                                    "value_kind": "Ident",
                                                    "value_text": id.sym.to_string(),
                                                }));
                                            }
                                            Prop::Assign(ap) => {
                                                let key = ap.key.sym.to_string();
                                                let val_text = cm.span_to_snippet(ap.value.span()).unwrap_or_default();
                                                props.push(json!({
                                                    "kind": "KeyValue",
                                                    "key_kind": "Ident",
                                                    "key_text": key,
                                                    "key_expr_text": Value::Null,
                                                    "computed": false,
                                                    "key_span": json_span(cm, ap.key.span),
                                                    "value_text": val_text,
                                                }));
                                            }
                                        },
                                        PropOrSpread::Spread(se) => {
                                            props.push(json!({
                                                "kind": "Spread",
                                                "arg_text": cm.span_to_snippet(se.expr.span()).unwrap_or_default(),
                                                "span": json_span(cm, se.span()),
                                            }));
                                        }
                                    }
                                }
                                init_object_props = Some(props);
                            }
                            if let Expr::Call(c) = &**init {
                                init_expr_kind = Some("Call".to_string());
                                if let Callee::Expr(expr) = &c.callee {
                                    if let Expr::Ident(i) = &**expr {
                                        init_callee_ident = Some(i.sym.to_string());
                                    }
                                }
                                if let Some(t) = &c.type_args {
                                    let mut names_t = Vec::new();
                                    for p in &t.params {
                                        let s = cm.span_to_snippet(p.span()).unwrap_or_default();
                                        names_t.push(s);
                                    }
                                    init_type_args = Some(names_t);
                                    if !t.params.is_empty() {
                                        let mut parts: Vec<String> = Vec::new();
                                        for p in &t.params {
                                            let s =
                                                cm.span_to_snippet(p.span()).unwrap_or_default();
                                            parts.push(s);
                                        }
                                        let txt = format!("<{}>", parts.join(", "));
                                        if !txt.is_empty() {
                                            init_type_argument_text = Some(txt);
                                        }
                                    }
                                    let mut kinds: Vec<String> = Vec::new();
                                    let mut ref_idents: Vec<String> = Vec::new();
                                    let mut lit_props_list: Vec<Vec<Value>> = Vec::new();
                                    let mut union_components: Vec<Vec<String>> = Vec::new();
                                    let mut union_struct: Vec<Vec<Value>> = Vec::new();
                                    for p in &t.params {
                                        match &**p {
                                            TsType::TsTypeRef(tr) => {
                                                kinds.push("type_ref".to_string());
                                                let name = match &tr.type_name {
                                                    TsEntityName::Ident(i) => i.sym.to_string(),
                                                    TsEntityName::TsQualifiedName(q) => {
                                                        match &q.left {
                                                            TsEntityName::Ident(i) => format!(
                                                                "{}.{}",
                                                                i.sym.to_string(),
                                                                q.right.sym.to_string()
                                                            ),
                                                            TsEntityName::TsQualifiedName(_) => cm
                                                                .span_to_snippet(q.span())
                                                                .unwrap_or_default(),
                                                        }
                                                    }
                                                };
                                                ref_idents.push(name);
                                                lit_props_list.push(Vec::new());
                                                union_components.push(Vec::new());
                                                union_struct.push(Vec::new());
                                            }
                                            TsType::TsTypeLit(lit) => {
                                                kinds.push("type_literal".to_string());
                                                let members = serialize_ts_type_lit_members(cm, lit);
                                                ref_idents.push(String::new());
                                                lit_props_list.push(members);
                                                union_components.push(Vec::new());
                                                union_struct.push(Vec::new());
                                            }
                                            _ => {
                                                let whole = cm
                                                    .span_to_snippet(p.span())
                                                    .unwrap_or_default();
                                                if whole.contains('|') {
                                                    kinds.push("union".to_string());
                                                    ref_idents.push(String::new());
                                                    lit_props_list.push(Vec::new());
                                                    let comps: Vec<String> = whole
                                                        .split('|')
                                                        .map(|x| x.trim().to_string())
                                                        .collect();
                                                    union_components.push(comps.clone());
                                                    let mut comp_struct: Vec<Value> = Vec::new();
                                                    for s in comps.iter() {
                                                        let st = s.trim();
                                                        comp_struct.push(classify_union_component_text(st));
                                                    }
                                                    union_struct.push(comp_struct);
                                                } else {
                                                    kinds.push("other".to_string());
                                                    ref_idents.push(String::new());
                                                    lit_props_list.push(Vec::new());
                                                    union_components.push(Vec::new());
                                                    union_struct.push(Vec::new());
                                                }
                                            }
                                        }
                                    }
                                    init_type_arg_kinds = Some(kinds);
                                    init_type_ref_idents = Some(ref_idents);
                                    init_type_literal_props = Some(lit_props_list);
                                    init_type_union_components = Some(union_components);
                                    init_type_union_components_struct = Some(union_struct);
                                }
                                let mut args_txt: Vec<String> = Vec::new();
                                let mut all_props: Vec<Vec<Value>> = Vec::new();
                                for a in &c.args {
                                    let s = cm.span_to_snippet(a.span()).unwrap_or_default();
                                    args_txt.push(s);
                                    let mut props: Vec<Value> = Vec::new();
                                    if let Expr::Object(obj) = &*a.expr {
                                        props = serialize_object_expr_props(cm, obj);
                                    }
                                    all_props.push(props);
                                }
                                init_args = Some(args_txt);
                                init_arg_object_props = Some(all_props);
                            }
                        }
                        let ns = cm.lookup_char_pos(d.name.span().lo());
                        let ne = cm.lookup_char_pos(d.name.span().hi());
                        let name_span = json!({
                            "start": if d.name.span().lo.0 > 0 { d.name.span().lo.0 - 1 } else { d.name.span().lo.0 },
                            "end": d.name.span().hi.0,
                            "loc_start": {"line": ns.line as u32, "column": ns.col.0 as u32},
                            "loc_end": {"line": ne.line as u32, "column": ne.col.0 as u32}
                        });
                        body.push(json!({
                            "type": "VariableDeclaration",
                            "start": json_node(cm, v.span)["start"],
                            "end": json_node(cm, v.span)["end"],
                            "loc": json_node(cm, v.span)["loc"],
                            "decl_kind": decl_kind,
                            "name": name,
                            "name_span": name_span,
                            "names": names,
                            "inited": inited,
                            "init_text": init_text,
                            "init_callee_ident": init_callee_ident,
                            "init_span": init_span,
                            "type_parameters": init_type_args,
                            "init_type_argument_text": init_type_argument_text,
                            "init_type_arg_kinds": init_type_arg_kinds,
                            "init_type_ref_idents": init_type_ref_idents,
                            "init_type_literal_props": init_type_literal_props,
                            "init_type_union_components": init_type_union_components,
                            "init_type_union_components_struct": init_type_union_components_struct,
                            "init_args": init_args,
                            "init_arg_object_props": init_arg_object_props,
                            "init_expr_kind": init_expr_kind,
                            "init_object_props": init_object_props,
                            "array_pattern": Value::Null,
                            "object_pattern": Value::Null,
                        }));
                    }
                }
                Stmt::Decl(Decl::Fn(f)) => {
                    let name = f.ident.sym.to_string();
                    let text = cm.span_to_snippet(f.function.span).ok();
                    body.push(json!({
                            "type": "FunctionDeclaration",
                            "start": json_node(cm, f.function.span)["start"],
                            "end": json_node(cm, f.function.span)["end"],
                            "loc": json_node(cm, f.function.span)["loc"],
                            "name": name,
                            "text": text,
                            "async": f.function.is_async,
                            "generator": f.function.is_generator,
                            "params": [],
                            "return_type": f.function.return_type.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                        }));
                }
                Stmt::Decl(Decl::Class(c)) => {
                    body.push(json!({
                            "type": "ClassDeclaration",
                            "start": json_node(cm, c.class.span)["start"],
                            "end": json_node(cm, c.class.span)["end"],
                            "loc": json_node(cm, c.class.span)["loc"],
                            "name": c.ident.sym.to_string(),
                            "super_class": c.class.super_class.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok()),
                            "implements": c.class.implements.iter().map(|im| cm.span_to_snippet(im.span()).unwrap_or_default()).collect::<Vec<String>>(),
                            "decorators": c.class.decorators.iter().map(|d| cm.span_to_snippet(d.span()).unwrap_or_default()).collect::<Vec<String>>(),
                            "members": [],
                        }));
                }
                Stmt::Expr(expr_stmt) => {
                    if let Expr::Call(c) = &*expr_stmt.expr {
                        let mut callee_ident: Option<String> = None;
                        if let Callee::Expr(expr) = &c.callee {
                            if let Expr::Ident(i) = &**expr {
                                callee_ident = Some(i.sym.to_string());
                            }
                        }
                        let mut args = Vec::new();
                        for a in &c.args {
                            let s = cm.span_to_snippet(a.span()).unwrap_or_default();
                            args.push(s);
                        }
                        let arg_object_props: Vec<Vec<Value>> = {
                            let mut all: Vec<Vec<Value>> = Vec::new();
                            for a in &c.args {
                                let props = if let Expr::Object(obj) = &*a.expr {
                                    serialize_object_expr_props(cm, obj)
                                } else {
                                    Vec::new()
                                };
                                all.push(props);
                            }
                            all
                        };
                        let mut type_args: Option<Vec<String>> = None;
                        let mut type_argument_text: Option<String> = None;
                        let mut type_arg_kinds: Option<Vec<String>> = None;
                        let mut type_ref_idents: Option<Vec<String>> = None;
                        let mut type_literal_props: Option<Vec<Vec<Value>>> = None;
                        let mut type_union_components: Option<Vec<Vec<String>>> = None;
                        let mut type_union_components_struct: Option<Vec<Vec<Value>>> = None;
                        if let Some(t) = &c.type_args {
                            let mut names = Vec::new();
                            for p in &t.params {
                                let s = cm.span_to_snippet(p.span()).unwrap_or_default();
                                names.push(s);
                            }
                            type_args = Some(names);
                            if !t.params.is_empty() {
                                let mut parts: Vec<String> = Vec::new();
                                for p in &t.params {
                                    let s = cm.span_to_snippet(p.span()).unwrap_or_default();
                                    parts.push(s);
                                }
                                let txt = format!("<{}>", parts.join(", "));
                                if !txt.is_empty() {
                                    type_argument_text = Some(txt);
                                }
                            }
                            let mut kinds: Vec<String> = Vec::new();
                            let mut ref_idents: Vec<String> = Vec::new();
                            let mut lit_props_list: Vec<Vec<Value>> = Vec::new();
                            let mut union_components: Vec<Vec<String>> = Vec::new();
                            let mut union_struct: Vec<Vec<Value>> = Vec::new();
                            for p in &t.params {
                                match &**p {
                                    TsType::TsTypeRef(tr) => {
                                        kinds.push("type_ref".to_string());
                                        let name = match &tr.type_name {
                                            TsEntityName::Ident(i) => i.sym.to_string(),
                                            TsEntityName::TsQualifiedName(q) => match &q.left {
                                                TsEntityName::Ident(i) => format!(
                                                    "{}.{}",
                                                    i.sym.to_string(),
                                                    q.right.sym.to_string()
                                                ),
                                                TsEntityName::TsQualifiedName(_) => {
                                                    cm.span_to_snippet(q.span()).unwrap_or_default()
                                                }
                                            },
                                        };
                                        ref_idents.push(name);
                                        lit_props_list.push(Vec::new());
                                        union_components.push(Vec::new());
                                        union_struct.push(Vec::new());
                                    }
                                    TsType::TsTypeLit(lit) => {
                                        kinds.push("type_literal".to_string());
                                        let members = serialize_ts_type_lit_members(cm, lit);
                                        ref_idents.push(String::new());
                                        lit_props_list.push(members);
                                        union_components.push(Vec::new());
                                        union_struct.push(Vec::new());
                                    }
                                    // Fallback: treat union types by text when detected
                                    // Some versions do not expose a distinct TsUnion variant
                                    _ => {
                                        let whole = cm.span_to_snippet(p.span()).unwrap_or_default();
                                        if whole.contains('|') {
                                            kinds.push("union".to_string());
                                            ref_idents.push(String::new());
                                            lit_props_list.push(Vec::new());
                                            let comps: Vec<String> = whole
                                                .split('|')
                                                .map(|x| x.trim().to_string())
                                                .collect();
                                            union_components.push(comps.clone());
                                            let mut comp_struct: Vec<Value> = Vec::new();
                                            for s in comps.iter() {
                                                let st = s.trim();
                                                comp_struct.push(classify_union_component_text(st));
                                            }
                                            union_struct.push(comp_struct);
                                        } else {
                                            kinds.push("other".to_string());
                                            ref_idents.push(String::new());
                                            lit_props_list.push(Vec::new());
                                            union_components.push(Vec::new());
                                            union_struct.push(Vec::new());
                                        }
                                    }
                                }
                            }
                            type_arg_kinds = Some(kinds);
                            type_ref_idents = Some(ref_idents);
                            type_literal_props = Some(lit_props_list);
                            type_union_components = Some(union_components);
                            type_union_components_struct = Some(union_struct);
                        }
                        let text = cm.span_to_snippet(c.span).ok();
                        body.push(json!({
                            "type": "CallExpression",
                            "start": json_node(cm, c.span)["start"],
                            "end": json_node(cm, c.span)["end"],
                            "loc": json_node(cm, c.span)["loc"],
                            "callee_ident": callee_ident,
                            "args": args,
                            "arg_object_props": arg_object_props,
                            "type_parameters": type_args,
                            "text": text,
                            "type_argument_text": type_argument_text,
                            "type_arg_kinds": type_arg_kinds,
                            "type_ref_idents": type_ref_idents,
                            "type_literal_props": type_literal_props,
                            "type_union_components": type_union_components,
                            "type_union_components_struct": type_union_components_struct,
                        }));
                    }
                }
                _ => {}
            },
        }
    }
    body
}


fn parse_nested_object_ann_text(type_ann: &str) -> Value {
    let s = type_ann.trim();
    if !s.starts_with('{') {
        return Value::Null;
    }
    let ninner = s.trim_start_matches('{').trim_end_matches('}');
    let mut nmembers: Vec<Value> = Vec::new();
    for npart in ninner.split(';') {
        let ntxt = npart.trim();
        if ntxt.is_empty() {
            continue;
        }
        let mut nkey = String::new();
        let mut ntype_ann = String::new();
        let mut noptional = false;
        if let Some(ncolon_pos) = ntxt.find(':') {
            let (nlhs, nrhs) = ntxt.split_at(ncolon_pos);
            let mut nlhs_trim = nlhs.trim().to_string();
            if nlhs_trim.ends_with('?') {
                noptional = true;
                nlhs_trim.pop();
            }
            nkey = nlhs_trim.trim().to_string();
            ntype_ann = nrhs.trim_start_matches(':').trim().to_string();
        } else {
            nkey = ntxt.to_string();
        }
        nmembers.push(json!({"key": nkey, "optional": noptional, "type_ann": if ntype_ann.is_empty() { Value::Null } else { Value::String(ntype_ann) }}));
    }
    json!({"kind":"object_literal","members": nmembers})
}

fn parse_object_literal_members_text(inner: &str) -> Vec<Value> {
    let mut members: Vec<Value> = Vec::new();
    for part in inner.split(';') {
        let ptxt = part.trim();
        if ptxt.is_empty() {
            continue;
        }
        let mut key = String::new();
        let mut type_ann = String::new();
        let mut optional = false;
        if let Some(colon_pos) = ptxt.find(':') {
            let (lhs, rhs) = ptxt.split_at(colon_pos);
            let mut lhs_trim = lhs.trim().to_string();
            if lhs_trim.ends_with('?') {
                optional = true;
                lhs_trim.pop();
            }
            key = lhs_trim.trim().to_string();
            type_ann = rhs.trim_start_matches(':').trim().to_string();
        } else {
            key = ptxt.to_string();
        }
        let type_ann_struct = if type_ann.starts_with('{') {
            parse_nested_object_ann_text(&type_ann)
        } else {
            Value::Null
        };
        members.push(json!({
            "key": key,
            "optional": optional,
            "type_ann": if type_ann.is_empty() { Value::Null } else { Value::String(type_ann) },
            "type_ann_struct": type_ann_struct
        }));
    }
    members
}

fn classify_union_component_text(st: &str) -> Value {
    let s = st.trim();
    if s.starts_with("keyof ") {
        let arg = s[6..].trim().to_string();
        return json!({"kind":"keyof","arg_text": arg});
    }
    if s.contains(" extends ") && s.contains(" ? ") && s.contains(" : ") {
        if let Some(ext_pos) = s.find(" extends ") {
            let check = s[..ext_pos].trim().to_string();
            let rest = &s[ext_pos + 9..];
            if let Some(qpos) = rest.find(" ? ") {
                let ext = rest[..qpos].trim().to_string();
                let tail = &rest[qpos + 3..];
                if let Some(cpos) = tail.rfind(" : ") {
                    let tru = tail[..cpos].trim().to_string();
                    let fal = tail[cpos + 3..].trim().to_string();
                    return json!({
                        "kind":"conditional",
                        "check_text": check,
                        "extends_text": ext,
                        "true_text": tru,
                        "false_text": fal,
                    });
                }
            }
        }
    }
    if s.starts_with("infer ") {
        let tail = s[6..].trim();
        let mut name = tail.to_string();
        let mut constraint = String::new();
        if let Some(epos) = tail.find(" extends ") {
            name = tail[..epos].trim().to_string();
            constraint = tail[epos + 9..].trim().to_string();
        }
        return json!({
            "kind":"infer",
            "param_name": name,
            "constraint_text": constraint,
        });
    }
    if s.ends_with("[]") {
        let elem = s.trim_end_matches("[]").trim().to_string();
        let ro = s.trim_start().starts_with("readonly ");
        return json!({"kind":"array","element_text": elem, "readonly": ro});
    }
    if s.starts_with("ReadonlyArray<") && s.ends_with('>') {
        let inner = s.trim().trim_start_matches("ReadonlyArray<").trim_end_matches('>').to_string();
        return json!({"kind":"array","element_text": inner, "readonly": true});
    }
    if s.starts_with("Array<") && s.ends_with('>') {
        let inner = s.trim().trim_start_matches("Array<").trim_end_matches('>').to_string();
        return json!({"kind":"array","element_text": inner, "readonly": false});
    }
    if s.contains('&') && !s.contains('|') {
        let elems: Vec<String> = s.split('&').map(|x| x.trim().to_string()).collect();
        return json!({"kind":"intersection","elements": elems});
    }
    if s.starts_with('[') && s.ends_with(']') && s.contains(',') {
        let inner = s.trim().trim_start_matches('[').trim_end_matches(']');
        let elems: Vec<String> = inner.split(',').map(|x| x.trim().to_string()).collect();
        return json!({"kind":"tuple","elements": elems});
    }
    if s.contains('[') && s.ends_with(']') && !s.starts_with('[') {
        if let Some(pos) = s.find('[') {
            let obj = s[..pos].trim().to_string();
            let idx = s[pos + 1..s.len() - 1].trim().to_string();
            return json!({"kind":"indexed_access","object_text": obj, "index_text": idx});
        }
    }
    if s == "string" {
        return json!({"kind":"string_keyword"});
    }
    if s == "number" {
        return json!({"kind":"number_keyword"});
    }
    if s == "boolean" {
        return json!({"kind":"boolean_keyword"});
    }
    if s == "null" {
        return json!({"kind":"null_keyword"});
    }
    if s == "undefined" {
        return json!({"kind":"undefined_keyword"});
    }
    if s.starts_with('{') {
        let inner = s.trim().trim_start_matches('{').trim_end_matches('}');
        let members = parse_object_literal_members_text(inner);
        return json!({"kind":"object_literal","text": s, "members": members});
    }
    if (s.starts_with('"') && s.ends_with('"')) || (s.starts_with('\'') && s.ends_with('\'')) {
        return json!({"kind":"string_literal","text": s});
    }
    if s == "true" || s == "false" {
        return json!({"kind":"boolean_literal","text": s});
    }
    if s.chars().all(|ch| ch.is_ascii_digit()) {
        return json!({"kind":"number_literal","text": s});
    }
    json!({"kind":"type_ref","name": s})
}

fn serialize_ts_type_lit_members(cm: &SourceMap, lit: &TsTypeLit) -> Vec<Value> {
    let mut members: Vec<Value> = Vec::new();
    for m in &lit.members {
        match m {
            TsTypeElement::TsPropertySignature(ps) => {
                let key = match &*ps.key {
                    Expr::Ident(i) => i.sym.to_string(),
                    Expr::Lit(Lit::Str(s)) => s.value.as_str().unwrap_or_default().to_string(),
                    _ => cm.span_to_snippet(ps.span).unwrap_or_default(),
                };
                let type_ann = ps
                    .type_ann
                    .as_ref()
                    .map(|ta| cm.span_to_snippet(ta.span).unwrap_or_default());
                let optional = ps.optional;
                members.push(json!({"key": key, "type_ann": type_ann, "optional": optional}));
            }
            TsTypeElement::TsIndexSignature(is) => {
                let mut idx_name = String::new();
                let mut idx_ann = String::new();
                if let Some(params) = is.params.first() {
                    if let TsFnParam::Ident(ident) = params {
                        idx_name = ident.id.sym.to_string();
                        if let Some(ann) = &ident.type_ann {
                            idx_ann = cm.span_to_snippet(ann.span).unwrap_or_default();
                        }
                    }
                }
                let type_ann = is
                    .type_ann
                    .as_ref()
                    .map(|ta| cm.span_to_snippet(ta.span).unwrap_or_default());
                members.push(json!({
                    "key": "[index]",
                    "optional": false,
                    "type_ann": type_ann,
                    "index_key_name": idx_name,
                    "index_key_ann": idx_ann,
                }));
            }
            _ => {}
        }
    }
    members
}

fn serialize_object_expr_props(cm: &SourceMap, obj: &ObjectLit) -> Vec<Value> {
    let mut props: Vec<Value> = Vec::new();
    let mut existing_keys: Vec<String> = Vec::new();
    for p in &obj.props {
        match p {
            PropOrSpread::Prop(pp) => match &**pp {
                Prop::KeyValue(kv) => {
                    let (key_kind, key_text, computed, key_span, key_expr_text) = match &kv.key {
                        PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                        PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                        PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                        PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                        PropName::Computed(c) => {
                            let t = cm.span_to_snippet(c.span).ok();
                            ("Computed", String::new(), true, json_span(cm, c.span), t)
                        }
                    };
                    let mut entry = json!({
                        "kind": "KeyValue",
                        "key_kind": key_kind,
                        "key_text": key_text,
                        "key_expr_text": key_expr_text,
                        "computed": computed,
                        "key_span": key_span,
                        "span": json_span(cm, kv.value.span()),
                    });
                    match &*kv.value {
                        Expr::Lit(Lit::Str(s)) => {
                            entry["value_kind"] = json!("String");
                            entry["value_text"] = json!(s.value.as_str().unwrap_or_default().to_string());
                        }
                        Expr::Lit(Lit::Num(n)) => {
                            entry["value_kind"] = json!("Number");
                            entry["value_text"] = json!(cm.span_to_snippet(n.span).unwrap_or_default());
                        }
                        Expr::Lit(Lit::Bool(b)) => {
                            entry["value_kind"] = json!("Boolean");
                            entry["value_text"] = json!(if b.value {"true"} else {"false"});
                        }
                        Expr::Lit(Lit::Null(_)) => {
                            entry["value_kind"] = json!("Null");
                            entry["value_text"] = json!("null");
                        }
                        Expr::Arrow(a) => {
                            entry["func"] = json!({
                                "async": a.is_async,
                                "generator": false,
                                "params": serialize_pat_list(cm, &a.params),
                                "text": cm.span_to_snippet(a.span).ok(),
                            });
                        }
                        Expr::Fn(f) => {
                            let params = serialize_fn_params(cm, &f.function.params);
                            entry["func"] = json!({
                                "async": f.function.is_async,
                                "generator": f.function.is_generator,
                                "params": params,
                                "return_type": f.function.return_type.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok()),
                                "text": cm.span_to_snippet(f.function.span).ok(),
                            });
                        }
                        _ => {}
                    }
                    existing_keys.push(key_text.clone());
                    props.push(entry);
                }
                Prop::Method(m) => {
                    let (key_kind, key_text, computed, key_span, key_expr_text) = match &m.key {
                        PropName::Ident(i) => ("Ident", i.sym.to_string(), false, json_span(cm, i.span), None),
                        PropName::Str(s) => ("String", s.value.as_str().unwrap_or_default().to_string(), false, json_span(cm, s.span), None),
                        PropName::Num(n) => ("Numeric", cm.span_to_snippet(n.span).unwrap_or_default(), false, json_span(cm, n.span), None),
                        PropName::BigInt(b) => ("BigInt", cm.span_to_snippet(b.span()).unwrap_or_default(), false, json_span(cm, b.span()), None),
                        PropName::Computed(c) => {
                            let t = cm.span_to_snippet(c.span).ok();
                            ("Computed", String::new(), true, json_span(cm, c.span), t)
                        }
                    };
                    existing_keys.push(key_text.clone());
                    props.push(json!({
                        "kind": "Method",
                        "key_kind": key_kind,
                        "key_text": key_text,
                        "key_expr_text": key_expr_text,
                        "computed": computed,
                        "key_span": key_span,
                        "func": {
                            "async": m.function.is_async,
                            "generator": m.function.is_generator,
                            "params": serialize_fn_params(cm, &m.function.params),
                            "text": cm.span_to_snippet(m.function.span).ok(),
                        }
                    }));
                }
                Prop::Getter(g) => {
                    let key_text = match &g.key {
                        PropName::Ident(i) => i.sym.to_string(),
                        PropName::Str(s) => s.value.as_str().unwrap_or_default().to_string(),
                        _ => cm.span_to_snippet(g.key.span()).unwrap_or_default(),
                    };
                    existing_keys.push(key_text.clone());
                    props.push(json!({
                        "kind": "Getter",
                        "key_kind": "Ident",
                        "key_text": key_text,
                        "computed": false,
                        "func": {
                            "async": false,
                            "generator": false,
                            "params": Vec::<Value>::new(),
                            "text": cm.span_to_snippet(g.span).ok(),
                        }
                    }));
                }
                Prop::Setter(s) => {
                    let key_text = match &s.key {
                        PropName::Ident(i) => i.sym.to_string(),
                        PropName::Str(st) => st.value.as_str().unwrap_or_default().to_string(),
                        _ => cm.span_to_snippet(s.key.span()).unwrap_or_default(),
                    };
                    let mut one: Vec<Pat> = Vec::new();
                    one.push((*s.param).clone());
                    existing_keys.push(key_text.clone());
                    props.push(json!({
                        "kind": "Setter",
                        "key_kind": "Ident",
                        "key_text": key_text,
                        "computed": false,
                        "func": {
                            "async": false,
                            "generator": false,
                            "params": serialize_pat_list(cm, &one),
                            "text": cm.span_to_snippet(s.span).ok(),
                        }
                    }));
                }
                _ => {}
            },
            PropOrSpread::Spread(sp) => {
                let at = cm.span_to_snippet(sp.expr.span()).unwrap_or_default();
                props.push(json!({"kind":"Spread","arg_text": at}));
            }
        }
    }
    // Fallback: tolerate `name = function (...) {}` within object literal text
    if let Ok(whole) = cm.span_to_snippet(obj.span) {
        let mut t = whole.trim().to_string();
        if t.starts_with('{') && t.ends_with('}') {
            t = t.trim_start_matches('{').trim_end_matches('}').to_string();
            for seg in t.split(',') {
                let part = seg.trim();
                if part.is_empty() { continue; }
                if let Some(eqpos) = part.find('=') {
                    let lhs = part[..eqpos].trim().to_string();
                    let rhs = part[eqpos+1..].trim().to_string();
                    if rhs.starts_with("function") {
                        // avoid duplicate keys
                        if !existing_keys.iter().any(|k| k == &lhs) {
                            let func_text = rhs;
                            props.push(json!({
                                "kind": "KeyValue",
                                "key_kind": "Ident",
                                "key_text": lhs,
                                "computed": false,
                                "key_span": json_span(cm, obj.span),
                                "span": json_span(cm, obj.span),
                                "func": {
                                    "async": false,
                                    "generator": false,
                                    "params": Vec::<Value>::new(),
                                    "text": func_text,
                                }
                            }));
                        }
                    }
                }
            }
        }
    }
    props
}

fn collect_pat_idents(pat: &Pat, out: &mut Vec<String>) {
    match pat {
        Pat::Ident(bi) => {
            out.push(bi.id.sym.to_string());
        }
        Pat::Array(arr) => {
            for e in &arr.elems {
                if let Some(p) = e {
                    collect_pat_idents(p, out);
                }
            }
        }
        Pat::Object(obj) => {
            for prop in &obj.props {
                match prop {
                    ObjectPatProp::KeyValue(kv) => {
                        collect_pat_idents(&kv.value, out);
                    }
                    ObjectPatProp::Assign(assign) => {
                        out.push(assign.key.sym.to_string());
                    }
                    ObjectPatProp::Rest(rest) => {
                        collect_pat_idents(&rest.arg, out);
                    }
                }
            }
        }
        Pat::Rest(rest) => {
            collect_pat_idents(&rest.arg, out);
        }
        Pat::Assign(assign) => {
            collect_pat_idents(&assign.left, out);
        }
        Pat::Expr(_) => {}
        Pat::Invalid(_) => {}
    }
}

fn serialize_pat(cm: &SourceMap, pat: &Pat) -> Value {
    match pat {
        Pat::Ident(bi) => json!({"param_kind": "ident", "name": bi.id.sym.to_string(), "span": json_span(cm, bi.id.span)}),
        Pat::Rest(rest) => json!({"param_kind": "rest", "name": match &*rest.arg { Pat::Ident(bi) => bi.id.sym.to_string(), _ => cm.span_to_snippet(rest.span()).unwrap_or_default() }, "span": json_span(cm, rest.span())}),
        Pat::Object(obj) => {
            let mut props: Vec<Value> = Vec::new();
            for prop in &obj.props {
                match prop {
                    ObjectPatProp::KeyValue(kv) => {
                        let key = match &kv.key {
                            PropName::Ident(i) => i.sym.to_string(),
                            PropName::Str(s) => s.value.as_str().unwrap_or_default().to_string(),
                            PropName::Num(n) => cm.span_to_snippet(n.span).unwrap_or_default(),
                            PropName::BigInt(b) => cm.span_to_snippet(b.span()).unwrap_or_default(),
                            PropName::Computed(c) => cm.span_to_snippet(c.span).unwrap_or_default(),
                        };
                        props.push(json!({"key": key, "nested": serialize_pat(cm, &kv.value)}));
                    }
                    ObjectPatProp::Assign(assign) => {
                        let def_text = assign.value.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                        props.push(json!({"key": assign.key.sym.to_string(), "alias": assign.key.sym.to_string(), "default_text": def_text}));
                    }
                    ObjectPatProp::Rest(r) => {
                        props.push(json!({"key": "...", "nested": serialize_pat(cm, &r.arg)}));
                    }
                }
            }
            json!({"param_kind": "object", "properties": props, "span": json_span(cm, obj.span)})
        }
        Pat::Array(arr) => {
            let mut elements: Vec<Value> = Vec::new();
            for e in &arr.elems {
                if let Some(p) = e { elements.push(serialize_pat(cm, p)); } else { elements.push(json!({"param_kind":"other"})); }
            }
            json!({"param_kind": "array", "elements": elements, "span": json_span(cm, arr.span)})
        }
        Pat::Assign(assign) => {
            let def_text = cm.span_to_snippet(assign.right.span()).ok();
            json!({"param_kind": "assign", "left": serialize_pat(cm, &assign.left), "default_text": def_text, "span": json_span(cm, assign.span)})
        }
        Pat::Expr(e) => json!({"param_kind": "other", "text": cm.span_to_snippet(e.span()).ok()}),
        Pat::Invalid(_) => json!({"param_kind": "other"}),
    }
}

fn serialize_pat_list(cm: &SourceMap, params: &Vec<Pat>) -> Vec<Value> {
    let mut out: Vec<Value> = Vec::new();
    for p in params { out.push(serialize_pat(cm, p)); }
    out
}

fn serialize_fn_params(cm: &SourceMap, params: &Vec<Param>) -> Vec<Value> {
    let mut out: Vec<Value> = Vec::new();
    for p in params {
        out.push(serialize_pat(cm, &p.pat));
    }
    out
}

fn serialize_block_stmts(cm: &SourceMap, body: Option<&BlockStmt>) -> Vec<Value> {
    let mut out: Vec<Value> = Vec::new();
    if let Some(b) = body {
        for st in &b.stmts {
            if let Some(v) = stmt_to_json(cm, st) { out.push(v); }
        }
    }
    out
}

fn stmt_to_json(cm: &SourceMap, st: &Stmt) -> Option<Value> {
    match st {
        Stmt::Decl(Decl::Var(v)) => {
            let mut o: Vec<Value> = Vec::new();
            for d in &v.decls {
                let mut names: Vec<String> = Vec::new();
                collect_pat_idents(&d.name, &mut names);
                let decl_kind = match v.kind {
                    swc_ecma_ast::VarDeclKind::Var => "var",
                    swc_ecma_ast::VarDeclKind::Let => "let",
                    swc_ecma_ast::VarDeclKind::Const => "const",
                }
                .to_string();
                let name = names.first().cloned().unwrap_or_default();
                let mut init_text: Option<String> = None;
                if let Some(init) = &d.init { init_text = cm.span_to_snippet(init.span()).ok(); }
                o.push(json!({
                    "type": "VariableDeclaration",
                    "decl_kind": decl_kind,
                    "name": name,
                    "init_text": init_text,
                }));
            }
            if o.is_empty() { None } else { Some(json!(o)).map(|_| o.into_iter().next().unwrap()) }
        }
        Stmt::Expr(es) => {
            if let Expr::Call(c) = &*es.expr {
                let mut callee_ident: Option<String> = None;
                if let Callee::Expr(expr) = &c.callee { if let Expr::Ident(i) = &**expr { callee_ident = Some(i.sym.to_string()); } }
                let mut args = Vec::new();
                for a in &c.args { args.push(cm.span_to_snippet(a.span()).unwrap_or_default()); }
                let arg_object_props: Vec<Vec<Value>> = {
                    let mut all: Vec<Vec<Value>> = Vec::new();
                    for a in &c.args {
                        let props = if let Expr::Object(obj) = &*a.expr { serialize_object_expr_props(cm, obj) } else { Vec::new() };
                        all.push(props);
                    }
                    all
                };
                Some(json!({
                    "type": "CallExpression",
                    "callee_ident": callee_ident,
                    "args": args,
                    "arg_object_props": arg_object_props,
                }))
            } else {
                if let Some(expr_json) = serialize_expr(cm, &es.expr) {
                    Some(json!({"type":"ExpressionStatement","expr": expr_json}))
                } else {
                    let text = cm.span_to_snippet(es.span()).ok();
                    Some(json!({"type":"ExpressionStatement","text": text}))
                }
            }
        }
        Stmt::Return(r) => {
            let arg_text = r.arg.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
            Some(json!({"type":"ReturnStatement", "arg_text": arg_text}))
        }
        Stmt::If(i) => {
            let test_text = cm.span_to_snippet(i.test.span()).ok();
            let cons = match &*i.cons { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
            let alt = match &i.alt { Some(s) => match &**s { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() }, None => Vec::new() };
            Some(json!({"type":"IfStatement","test_text": test_text,"consequent_stmts": cons,"alternate_stmts": alt}))
        }
        Stmt::For(f) => {
            let init_text = match &f.init { Some(VarDeclOrExpr::VarDecl(vd)) => cm.span_to_snippet(vd.span).ok(), Some(VarDeclOrExpr::Expr(e)) => cm.span_to_snippet(e.span()).ok(), None => None };
            let test_text = f.test.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
            let update_text = f.update.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
            let body_stmts = match &*f.body { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
            Some(json!({"type":"ForStatement","init_text":init_text,"test_text":test_text,"update_text":update_text,"body_stmts":body_stmts}))
        }
        Stmt::While(w) => {
            let test_text = cm.span_to_snippet(w.test.span()).ok();
            let body_stmts = match &*w.body { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
            Some(json!({"type":"WhileStatement","test_text":test_text,"body_stmts":body_stmts}))
        }
        Stmt::Break(bk) => {
            let label = bk.label.as_ref().map(|id| id.sym.to_string());
            Some(json!({"type":"BreakStatement","label":label}))
        }
        Stmt::Continue(ct) => {
            let label = ct.label.as_ref().map(|id| id.sym.to_string());
            Some(json!({"type":"ContinueStatement","label":label}))
        }
        Stmt::Try(tr) => {
            let block_stmts = serialize_block_stmts(cm, Some(&tr.block));
            let handler_param = tr.handler.as_ref().and_then(|h| h.param.as_ref().and_then(|p| { match p { Pat::Ident(bi) => Some(bi.id.sym.to_string()), _ => cm.span_to_snippet(p.span()).ok(), } }));
            let handler_stmts = tr.handler.as_ref().map(|h| serialize_block_stmts(cm, Some(&h.body))).unwrap_or_default();
            let finalizer_stmts = tr.finalizer.as_ref().map(|f| serialize_block_stmts(cm, Some(f))).unwrap_or_default();
            Some(json!({"type":"TryStatement","block_stmts":block_stmts,"handler_param":handler_param,"handler_stmts":handler_stmts,"finalizer_stmts":finalizer_stmts}))
        }
        Stmt::Switch(sw) => {
            let test_text = cm.span_to_snippet(sw.discriminant.span()).ok();
            let mut cases: Vec<Value> = Vec::new();
            for c in &sw.cases {
                let test_text_case = c.test.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                let cons = serialize_stmts(cm, &c.cons);
                cases.push(json!({"test_text": test_text_case, "consequent_stmts": cons}));
            }
            Some(json!({"type":"SwitchStatement","test_text": test_text, "cases": cases}))
        }
        Stmt::Throw(th) => {
            let arg_text = cm.span_to_snippet(th.arg.span()).ok();
            Some(json!({"type":"ThrowStatement","arg_text":arg_text}))
        }
        Stmt::DoWhile(dw) => {
            let test_text = cm.span_to_snippet(dw.test.span()).ok();
            let body_stmts = match &*dw.body { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
            let text = cm.span_to_snippet(dw.span()).ok();
            Some(json!({"type":"DoWhileStatement","test_text":test_text,"body_stmts":body_stmts,"text":text}))
        }
        _ => None,
    }
}

fn serialize_expr(cm: &SourceMap, e: &Box<Expr>) -> Option<Value> {
    match &**e {
        Expr::Bin(b) => Some(json!({
            "expr_type": "BinaryExpression",
            "operator": format!("{}", b.op),
            "left_text": cm.span_to_snippet(b.left.span()).ok(),
            "right_text": cm.span_to_snippet(b.right.span()).ok(),
        })),
        Expr::Assign(a) => Some(json!({
            "expr_type": "AssignmentExpression",
            "operator": format!("{}", a.op),
            "left_text": cm.span_to_snippet(a.left.span()).ok(),
            "right_text": cm.span_to_snippet(a.right.span()).ok(),
        })),
        Expr::Cond(c) => Some(json!({
            "expr_type": "ConditionalExpression",
            "test_text": cm.span_to_snippet(c.test.span()).ok(),
            "cons_text": cm.span_to_snippet(c.cons.span()).ok(),
            "alt_text": cm.span_to_snippet(c.alt.span()).ok(),
        })),
        Expr::Member(m) => {
            let obj_text = cm.span_to_snippet(m.obj.span()).ok();
            let (computed, prop_text) = match &m.prop {
                swc_ecma_ast::MemberProp::Ident(i) => (false, Some(i.sym.to_string())),
                swc_ecma_ast::MemberProp::PrivateName(p) => (false, Some(format!("#{}", p.name))),
                swc_ecma_ast::MemberProp::Computed(c) => (true, cm.span_to_snippet(c.span()).ok()),
            };
            Some(json!({
                "expr_type": "MemberExpression",
                "object_text": obj_text,
                "property_text": prop_text,
                "computed": computed,
            }))
        }
        Expr::New(n) => {
            let callee_text = cm.span_to_snippet(n.callee.span()).ok();
            let mut args: Vec<String> = Vec::new();
            if let Some(list) = &n.args { for a in list { args.push(cm.span_to_snippet(a.span()).unwrap_or_default()); } }
            Some(json!({
                "expr_type": "NewExpression",
                "callee_text": callee_text,
                "args": args,
            }))
        }
        Expr::Unary(u) => Some(json!({
            "expr_type": "UnaryExpression",
            "operator": format!("{}", u.op),
            "argument_text": cm.span_to_snippet(u.arg.span()).ok(),
        })),
        Expr::Update(up) => Some(json!({
            "expr_type": "UpdateExpression",
            "operator": format!("{}", up.op),
            "argument_text": cm.span_to_snippet(up.arg.span()).ok(),
            "prefix": up.prefix,
        })),
        _ => None,
    }
}

fn serialize_stmts(cm: &SourceMap, stmts: &Vec<Stmt>) -> Vec<Value> {
    let mut out: Vec<Value> = Vec::new();
    for st in stmts {
        match st {
            Stmt::Decl(Decl::Var(v)) => {
                for d in &v.decls {
                    let mut names: Vec<String> = Vec::new();
                    collect_pat_idents(&d.name, &mut names);
                    let decl_kind = match v.kind {
                        swc_ecma_ast::VarDeclKind::Var => "var",
                        swc_ecma_ast::VarDeclKind::Let => "let",
                        swc_ecma_ast::VarDeclKind::Const => "const",
                    }
                    .to_string();
                    let name = names.first().cloned().unwrap_or_default();
                    let mut init_text: Option<String> = None;
                    if let Some(init) = &d.init { init_text = cm.span_to_snippet(init.span()).ok(); }
                    out.push(json!({
                        "type": "VariableDeclaration",
                        "decl_kind": decl_kind,
                        "name": name,
                        "init_text": init_text,
                    }));
                }
            }
            Stmt::Expr(es) => {
                if let Expr::Call(c) = &*es.expr {
                    let mut callee_ident: Option<String> = None;
                    if let Callee::Expr(expr) = &c.callee { if let Expr::Ident(i) = &**expr { callee_ident = Some(i.sym.to_string()); } }
                    let mut args = Vec::new();
                    for a in &c.args { args.push(cm.span_to_snippet(a.span()).unwrap_or_default()); }
                    let arg_object_props: Vec<Vec<Value>> = {
                        let mut all: Vec<Vec<Value>> = Vec::new();
                        for a in &c.args {
                            let props = if let Expr::Object(obj) = &*a.expr { serialize_object_expr_props(cm, obj) } else { Vec::new() };
                            all.push(props);
                        }
                        all
                    };
                    out.push(json!({
                        "type": "CallExpression",
                        "callee_ident": callee_ident,
                        "args": args,
                        "arg_object_props": arg_object_props,
                    }));
                } else {
                    let text = cm.span_to_snippet(es.span()).ok();
                    out.push(json!({"type":"ExpressionStatement","text": text}));
                }
            }
            Stmt::Return(r) => {
                let arg_text = r.arg.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                out.push(json!({"type":"ReturnStatement", "arg_text": arg_text}));
            }
            Stmt::If(i) => {
                let test_text = cm.span_to_snippet(i.test.span()).ok();
                let cons = match &*i.cons { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
                let alt = match &i.alt { Some(s) => match &**s { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() }, None => Vec::new() };
                out.push(json!({
                    "type": "IfStatement",
                    "test_text": test_text,
                    "consequent_stmts": cons,
                    "alternate_stmts": alt,
                }));
            }
            Stmt::For(f) => {
                let init_text = match &f.init { Some(VarDeclOrExpr::VarDecl(vd)) => cm.span_to_snippet(vd.span).ok(), Some(VarDeclOrExpr::Expr(e)) => cm.span_to_snippet(e.span()).ok(), None => None };
                let test_text = f.test.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                let update_text = f.update.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                let body_stmts = match &*f.body { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
                out.push(json!({
                    "type": "ForStatement",
                    "init_text": init_text,
                    "test_text": test_text,
                    "update_text": update_text,
                    "body_stmts": body_stmts,
                }));
            }
            Stmt::While(w) => {
                let test_text = cm.span_to_snippet(w.test.span()).ok();
                let body_stmts = match &*w.body { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
                out.push(json!({
                    "type": "WhileStatement",
                    "test_text": test_text,
                    "body_stmts": body_stmts,
                }));
            }
            Stmt::Break(bk) => {
                let label = bk.label.as_ref().map(|id| id.sym.to_string());
                out.push(json!({"type":"BreakStatement","label":label}));
            }
            Stmt::Continue(ct) => {
                let label = ct.label.as_ref().map(|id| id.sym.to_string());
                out.push(json!({"type":"ContinueStatement","label":label}));
            }
            Stmt::Try(tr) => {
                let block_stmts = serialize_block_stmts(cm, Some(&tr.block));
                let handler_param = tr.handler.as_ref().and_then(|h| h.param.as_ref().and_then(|p| {
                    match p { Pat::Ident(bi) => Some(bi.id.sym.to_string()), _ => cm.span_to_snippet(p.span()).ok(), }
                }));
                let handler_stmts = tr.handler.as_ref().map(|h| serialize_block_stmts(cm, Some(&h.body))).unwrap_or_default();
                let finalizer_stmts = tr.finalizer.as_ref().map(|f| serialize_block_stmts(cm, Some(f))).unwrap_or_default();
                out.push(json!({
                    "type": "TryStatement",
                    "block_stmts": block_stmts,
                    "handler_param": handler_param,
                    "handler_stmts": handler_stmts,
                    "finalizer_stmts": finalizer_stmts,
                }));
            }
            Stmt::Switch(sw) => {
                let test_text = cm.span_to_snippet(sw.discriminant.span()).ok();
                let mut cases: Vec<Value> = Vec::new();
                for c in &sw.cases {
                    let test_text_case = c.test.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                    let cons = serialize_stmts(cm, &c.cons);
                    cases.push(json!({"test_text": test_text_case, "consequent_stmts": cons}));
                }
                out.push(json!({"type":"SwitchStatement","test_text": test_text, "cases": cases}));
            }
            Stmt::Throw(th) => {
                let arg_text = cm.span_to_snippet(th.arg.span()).ok();
                out.push(json!({"type":"ThrowStatement","arg_text":arg_text}));
            }
            Stmt::DoWhile(dw) => {
                let test_text = cm.span_to_snippet(dw.test.span()).ok();
                let body_stmts = match &*dw.body { Stmt::Block(b) => serialize_block_stmts(cm, Some(b)), _ => Vec::new() };
                let text = cm.span_to_snippet(dw.span()).ok();
                out.push(json!({"type":"DoWhileStatement","test_text":test_text,"body_stmts":body_stmts,"text":text}));
            }
            _ => {
                let text = cm.span_to_snippet(st.span()).ok();
                out.push(json!({"type":"ExpressionStatement","text": text}));
            }
        }
    }
    out
}

fn parse_to_json(src: &str, language: &str, keep_comments: bool) -> Result<String> {
    let is_typescript = language == "typescript" || language == "ts" || language == "tsx";
    let is_tsx = language == "tsx" || language == "jsx";

    let cm = SourceMap::default();
    let fm = cm.new_source_file(
        Lrc::new(FileName::Custom(if is_typescript {
            "input.ts".into()
        } else {
            "input.js".into()
        })),
        src.to_owned(),
    );

    let syntax_primary = if is_typescript {
        Syntax::Typescript(TsSyntax {
            tsx: is_tsx,
            decorators: true,
            ..Default::default()
        })
    } else {
        Syntax::Es(EsSyntax {
            jsx: is_tsx,
            decorators: false,
            ..Default::default()
        })
    };
    let mut comments_primary = SingleThreadedComments::default();
    let lexer = Lexer::new(
        syntax_primary,
        EsVersion::Es2022,
        StringInput::from(&*fm),
        Some(&mut comments_primary),
    );
    let mut parser = Parser::new_from(lexer);
    let module_result = parser.parse_module();
    let (module, comments_used) = match module_result {
        Ok(m) => (m, comments_primary),
        Err(e) => {
            let syntax_fb = if is_typescript {
                Syntax::Es(EsSyntax {
                    jsx: is_tsx,
                    decorators: false,
                    ..Default::default()
                })
            } else {
                Syntax::Typescript(TsSyntax {
                    tsx: is_tsx,
                    decorators: true,
                    ..Default::default()
                })
            };
            let mut comments_fb = SingleThreadedComments::default();
            let f_lexer = Lexer::new(
                syntax_fb,
                EsVersion::Es2022,
                StringInput::from(&*fm),
                Some(&mut comments_fb),
            );
            let mut f_parser = Parser::new_from(f_lexer);
            let m = f_parser
                .parse_module()
                .map_err(|_| anyhow::anyhow!("parse error: {:?}", e))?;
            (m, comments_fb)
        }
    };

    let body = module_to_json(&cm, &module);
    let comments = if keep_comments {
        comments_to_json(&cm, &module, &comments_used)
    } else {
        Vec::new()
    };
    let json = serde_json::to_string(&serde_json::json!({
        "body": body,
        "comments": comments,
    }))?;
    Ok(json)
}

#[no_mangle]
pub extern "C" fn swc_parse(
    src: *const c_char,
    language: *const c_char,
    keep_comments: c_uchar,
) -> *mut c_char {
    if src.is_null() {
        return std::ptr::null_mut();
    }
    let c_str = unsafe { CStr::from_ptr(src) };
    let s = match c_str.to_str() {
        Ok(v) => v,
        Err(_) => return std::ptr::null_mut(),
    };
    let c_language = unsafe { CStr::from_ptr(language) };
    let language = match c_language.to_str() {
        Ok(v) => v,
        Err(_) => return std::ptr::null_mut(),
    };

    match parse_to_json(s, language, keep_comments != 0) {
        Ok(json) => {
            let c = CString::new(json).unwrap_or_else(|_| CString::new("{}").unwrap());
            c.into_raw()
        }
        Err(e) => {
            let msg = format!("{{\"error\":\"{}\"}}", e.to_string().replace('"', "\""));
            let c = CString::new(msg)
                .unwrap_or_else(|_| CString::new("{\"error\":\"parse failed\"}").unwrap());
            c.into_raw()
        }
    }
}
// removed: swc_parse_expr FFI (no longer needed)
#[no_mangle]
pub extern "C" fn swc_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}
fn comments_to_json(
    cm: &SourceMap,
    module: &swc_ecma_ast::Module,
    comments: &SingleThreadedComments,
) -> Vec<Value> {
    use swc_common::comments::Comments as _;
    let mut out: Vec<Value> = Vec::new();
    let mut seen: std::collections::HashSet<(u32, u32)> = std::collections::HashSet::new();
    for item in &module.body {
        let span = item.span();
        if let Some(list) = comments.get_leading(span.lo()) {
            for c in list {
                let ls = cm.lookup_char_pos(c.span.lo());
                let le = cm.lookup_char_pos(c.span.hi());
                let kind = match c.kind {
                    swc_common::comments::CommentKind::Line => "Line",
                    swc_common::comments::CommentKind::Block => "Block",
                };
                let start = c.span.lo.0.saturating_sub(1);
                let end = c.span.hi.0;
                if seen.insert((start, end)) {
                    out.push(json!({
                        "kind": kind,
                        "text": c.text.to_string(),
                        "span": {
                            "start": start,
                            "end": end,
                            "loc_start": {"line": ls.line as u32, "column": ls.col.0 as u32},
                            "loc_end": {"line": le.line as u32, "column": le.col.0 as u32}
                        }
                    }));
                }
            }
        }
        if let Some(list) = comments.get_trailing(span.hi()) {
            for c in list {
                let ls = cm.lookup_char_pos(c.span.lo());
                let le = cm.lookup_char_pos(c.span.hi());
                let kind = match c.kind {
                    swc_common::comments::CommentKind::Line => "Line",
                    swc_common::comments::CommentKind::Block => "Block",
                };
                let start = c.span.lo.0.saturating_sub(1);
                let end = c.span.hi.0;
                if seen.insert((start, end)) {
                    out.push(json!({
                        "kind": kind,
                        "text": c.text.to_string(),
                        "span": {
                            "start": start,
                            "end": end,
                            "loc_start": {"line": ls.line as u32, "column": ls.col.0 as u32},
                            "loc_end": {"line": le.line as u32, "column": le.col.0 as u32}
                        }
                    }));
                }
            }
        }
    }
    out
}
