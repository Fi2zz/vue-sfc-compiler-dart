use anyhow::Result;
use serde::Serialize;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_uchar};
use swc_common::{FileName, SourceMap, Span, SourceMapper, Spanned};
use swc_common::sync::Lrc;
use swc_ecma_ast::*;
use swc_ecma_parser::{lexer::Lexer, Parser, StringInput, Syntax, TsSyntax};
use swc_ecma_ast::EsVersion;
use swc_ecma_visit::{Visit, VisitWith};

#[derive(Serialize)]
struct Loc {
    line: u32,
    column: u32,
}

#[derive(Serialize)]
struct SourceLocationOut {
    start: Loc,
    end: Loc,
    filename: String,
    #[serde(rename = "identifierName")]
    identifier_name: Option<String>,
}

#[derive(Serialize)]
struct NodeOut {
    start: u32,
    end: u32,
    loc: SourceLocationOut,
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

#[derive(Serialize)]
struct SpanOut {
    start: u32,
    end: u32,
    loc_start: Loc,
    loc_end: Loc,
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum ModuleItemOut {
    ImportDeclaration { #[serde(flatten)] node: NodeOut, src: String, specifiers: Vec<ImportSpecifierOut> },
    ExportDefaultDeclaration { #[serde(flatten)] node: NodeOut, obj_span: Option<SpanOut> },
    ExportNamedDeclaration { #[serde(flatten)] node: NodeOut, specifiers: Vec<ExportSpecifierOut>, source: Option<String> },
    ExportAllDeclaration { #[serde(flatten)] node: NodeOut, src: String, exported_ident: Option<String> },
    ExportDeclFn { #[serde(flatten)] node: NodeOut, name: String },
    ExportDeclClass { #[serde(flatten)] node: NodeOut, name: String },
    CallExpression { #[serde(flatten)] node: NodeOut, callee_ident: Option<String>, args: Vec<String>, type_parameters: Option<Vec<String>>, text: Option<String>, type_argument_text: Option<String>, type_arg_kinds: Option<Vec<String>>, type_ref_idents: Option<Vec<String>>, type_literal_props: Option<Vec<Vec<TSPropSigOut>>> },
    TSTypeAliasDeclaration { #[serde(flatten)] node: NodeOut, id: String, members: Vec<TSPropSigOut> },
    TSInterfaceDeclaration { #[serde(flatten)] node: NodeOut, id: String, members: Vec<TSPropSigOut> },
    VariableDeclaration { #[serde(flatten)] node: NodeOut, decl_kind: String, name: String, name_span: SpanOut, names: Vec<String>, inited: bool, init_text: Option<String>, init_callee_ident: Option<String>, init_span: Option<SpanOut>, type_parameters: Option<Vec<String>>, array_pattern: Option<ArrayBindingPatternOut>, object_pattern: Option<ObjectBindingPatternOut> },
    FunctionDeclaration { #[serde(flatten)] node: NodeOut, name: String, text: Option<String>, r#async: bool, generator: bool, params: Vec<FnParamOut>, return_type: Option<String> },
    ClassDeclaration { #[serde(flatten)] node: NodeOut, name: String, super_class: Option<String>, implements: Vec<String>, decorators: Vec<String>, members: Vec<ClassMemberOut> },
}

#[derive(Serialize)]
struct FnParamOut {
    name: Option<String>,
    default_text: Option<String>,
    is_rest: bool,
    type_ann_text: Option<String>,
}

#[derive(Serialize)]
#[serde(tag = "kind")]
enum ClassMemberOut {
    Constructor { #[serde(flatten)] node: NodeOut },
    Method { #[serde(flatten)] node: NodeOut, key: String, is_static: bool, r#async: bool, generator: bool },
    Getter { #[serde(flatten)] node: NodeOut, key: String, is_static: bool },
    Setter { #[serde(flatten)] node: NodeOut, key: String, is_static: bool },
    Property { #[serde(flatten)] node: NodeOut, key: String, is_static: bool },
    StaticBlock { #[serde(flatten)] node: NodeOut },
}

#[derive(Serialize)]
#[serde(tag = "kind")]
enum ImportSpecifierOut {
    Default { local: String, span: SpanOut },
    Namespace { local: String, span: SpanOut },
    Named { local: String, imported_ident: Option<String>, imported_str: Option<String>, import_kind: Option<String>, span: SpanOut },
}

#[derive(Serialize)]
#[serde(tag = "kind")]
enum ExportSpecifierOut {
    Named { local_ident: Option<String>, exported_ident: Option<String>, exported_str: Option<String>, export_kind: Option<String>, span: SpanOut },
    NamespaceAlias { exported_ident: String, span: SpanOut },
}

#[derive(Serialize, Clone)]
struct TSPropSigOut {
    key: String,
    type_ann: Option<String>,
    optional: bool,
}

#[derive(Serialize)]
struct ArrayBindingElementOut {
    name: Option<String>,
    default_text: Option<String>,
    is_rest: bool,
    index: u32,
}

#[derive(Serialize)]
struct ArrayBindingPatternOut {
    elements: Vec<ArrayBindingElementOut>,
    pattern_type_ann_text: Option<String>,
}

#[derive(Serialize)]
struct ObjectBindingPropertyOut {
    key: String,
    alias: Option<String>,
    default_text: Option<String>,
    nested: Option<ObjectBindingPatternOut>,
}

#[derive(Serialize)]
struct ObjectBindingPatternOut {
    properties: Vec<ObjectBindingPropertyOut>,
    pattern_type_ann_text: Option<String>,
}

#[derive(Serialize)]
struct ModuleOut {
    body: Vec<ModuleItemOut>,
}

struct Collector<'a> {
    cm: &'a SourceMap,
    body: Vec<ModuleItemOut>,
    type_aliases: std::collections::HashMap<String, Vec<TSPropSigOut>>,
    interfaces: std::collections::HashMap<String, Vec<TSPropSigOut>>,
}

impl<'a> Collector<'a> {
    fn new(cm: &'a SourceMap) -> Self {
        Self { cm, body: Vec::new(), type_aliases: std::collections::HashMap::new(), interfaces: std::collections::HashMap::new() }
    }

    fn s(&self, span: Span) -> NodeOut {
        let start = self.cm.lookup_char_pos(span.lo());
        let end = self.cm.lookup_char_pos(span.hi());
        let start_off = if span.lo.0 > 0 { span.lo.0 - 1 } else { span.lo.0 };
        let end_off = span.hi.0;
        NodeOut {
            start: start_off,
            end: end_off,
            loc: SourceLocationOut {
                start: Loc { line: start.line as u32, column: start.col.0 as u32 },
                end: Loc { line: end.line as u32, column: end.col.0 as u32 },
                filename: match &*start.file.name { FileName::Custom(s) => s.clone(), _ => "input.ts".to_string() },
                identifier_name: None,
            },
        }
    }

    fn sp(&self, span: Span) -> SpanOut {
        let start = self.cm.lookup_char_pos(span.lo());
        let end = self.cm.lookup_char_pos(span.hi());
        SpanOut {
            start: if span.lo.0 > 0 { span.lo.0 - 1 } else { span.lo.0 },
            end: span.hi.0,
            loc_start: Loc { line: start.line as u32, column: start.col.0 as u32 },
            loc_end: Loc { line: end.line as u32, column: end.col.0 as u32 },
        }
    }
}

impl<'a> Visit for Collector<'a> {
    fn visit_module_item(&mut self, n: &ModuleItem) {
        match n {
            ModuleItem::ModuleDecl(decl) => {
                match decl {
                    ModuleDecl::Import(import) => {
                        let src = import.src.value.as_str().unwrap_or_default().to_string();
                        let mut specs: Vec<ImportSpecifierOut> = Vec::new();
                        for s in &import.specifiers {
                            match s {
                                ImportSpecifier::Named(named) => {
                                    let local = named.local.sym.to_string();
                                    let mut imported_ident: Option<String> = None;
                                    let mut imported_str: Option<String> = None;
                                    match &named.imported {
                                        Some(ModuleExportName::Ident(i)) => { imported_ident = Some(i.sym.to_string()); }
                                        Some(ModuleExportName::Str(st)) => { imported_str = Some(st.value.as_str().unwrap_or_default().to_string()); }
                                        None => {}
                                    }
                                    let import_kind = if import.type_only { Some("type".to_string()) } else { None };
                                    specs.push(ImportSpecifierOut::Named { local, imported_ident, imported_str, import_kind, span: self.sp(named.span) });
                                }
                                ImportSpecifier::Default(def) => {
                                    let local = def.local.sym.to_string();
                                    specs.push(ImportSpecifierOut::Default { local, span: self.sp(def.span) });
                                }
                                ImportSpecifier::Namespace(ns) => {
                                    let local = ns.local.sym.to_string();
                                    specs.push(ImportSpecifierOut::Namespace { local, span: self.sp(ns.span) });
                                }
                            }
                        }
                        self.body.push(ModuleItemOut::ImportDeclaration { node: self.s(import.span), src, specifiers: specs });
                    }
                    ModuleDecl::ExportDefaultDecl(ed) => {
                        self.body.push(ModuleItemOut::ExportDefaultDeclaration { node: self.s(ed.span), obj_span: None });
                    }
                    ModuleDecl::ExportDefaultExpr(ee) => {
                        let mut obj_span: Option<SpanOut> = None;
                        if let Expr::Object(obj) = &*ee.expr {
                            let start = self.cm.lookup_char_pos(obj.span.lo());
                            let end = self.cm.lookup_char_pos(obj.span.hi());
                            obj_span = Some(SpanOut {
                                start: if obj.span.lo.0 > 0 { obj.span.lo.0 - 1 } else { obj.span.lo.0 },
                                end: obj.span.hi.0,
                                loc_start: Loc { line: start.line as u32, column: start.col.0 as u32 },
                                loc_end: Loc { line: end.line as u32, column: end.col.0 as u32 },
                            });
                        }
                        self.body.push(ModuleItemOut::ExportDefaultDeclaration { node: self.s(ee.span), obj_span });
                    }
                    ModuleDecl::ExportNamed(en) => {
                        let mut specs: Vec<ExportSpecifierOut> = Vec::new();
                        for s in &en.specifiers {
                            match s {
                                ExportSpecifier::Named(named) => {
                                    let mut local_ident: Option<String> = None;
                                    match &named.orig { ModuleExportName::Ident(i) => { local_ident = Some(i.sym.to_string()); }, ModuleExportName::Str(_) => { local_ident = None; } }
                                    let mut exported_ident: Option<String> = None;
                                    let mut exported_str: Option<String> = None;
                                    match &named.exported {
                                        Some(ModuleExportName::Ident(i)) => { exported_ident = Some(i.sym.to_string()); }
                                        Some(ModuleExportName::Str(st)) => { exported_str = Some(st.value.as_str().unwrap_or_default().to_string()); }
                                        None => {}
                                    }
                                    let export_kind = if en.type_only { Some("type".to_string()) } else { None };
                                    specs.push(ExportSpecifierOut::Named { local_ident, exported_ident, exported_str, export_kind, span: self.sp(named.span) });
                                }
                                ExportSpecifier::Namespace(ns) => {
                                    let exported_ident = match &ns.name {
                                        ModuleExportName::Ident(i) => i.sym.to_string(),
                                        ModuleExportName::Str(st) => st.value.as_str().unwrap_or_default().to_string(),
                                    };
                                    specs.push(ExportSpecifierOut::NamespaceAlias { exported_ident, span: self.sp(ns.span) });
                                }
                                ExportSpecifier::Default(def) => {
                                    let exported_ident = def.exported.sym.to_string();
                                    let export_kind = if en.type_only { Some("type".to_string()) } else { None };
                                    specs.push(ExportSpecifierOut::Named { local_ident: None, exported_ident: Some(exported_ident), exported_str: Some("default".to_string()), export_kind, span: self.sp(def.span()) });
                                }
                            }
                        }
                        let source = en.src.as_ref().map(|s| s.value.as_str().unwrap_or_default().to_string());
                        self.body.push(ModuleItemOut::ExportNamedDeclaration { node: self.s(en.span), specifiers: specs, source });
                    }
                    ModuleDecl::ExportAll(ea) => {
                        let src = ea.src.value.as_str().unwrap_or_default().to_string();
                        self.body.push(ModuleItemOut::ExportAllDeclaration { node: self.s(ea.span), src, exported_ident: None });
                    }
                    ModuleDecl::ExportDecl(ed) => {
                        match &ed.decl {
                            Decl::Fn(f) => {
                                let name = f.ident.sym.to_string();
                                self.body.push(ModuleItemOut::ExportDeclFn { node: self.s(f.function.span), name });
                            }
                            Decl::Class(c) => {
                                let name = c.ident.sym.to_string();
                                self.body.push(ModuleItemOut::ExportDeclClass { node: self.s(c.class.span), name });
                            }
                            _ => {}
                        }
                    }
                    ModuleDecl::TsImportEquals(_) | ModuleDecl::TsExportAssignment(_) | ModuleDecl::TsNamespaceExport(_) => {}
                }
            }
            ModuleItem::Stmt(stmt) => {
                match stmt {
                    Stmt::Decl(decl) => {
                        match decl {
                            Decl::Var(v) => {
                                for d in &v.decls {
                                    let mut names: Vec<String> = Vec::new();
                                    collect_pat_idents(&d.name, &mut names);
                                    // kind of declaration: var/let/const
                                    let decl_kind = match v.kind {
                                        swc_ecma_ast::VarDeclKind::Var => "var".to_string(),
                                        swc_ecma_ast::VarDeclKind::Let => "let".to_string(),
                                        swc_ecma_ast::VarDeclKind::Const => "const".to_string(),
                                    };
                                    // primary name (first identifier if available)
                                    let name = names.first().cloned().unwrap_or_default();
                                    let mut init_text: Option<String> = None;
                                    let mut init_callee_ident: Option<String> = None;
                                    let mut init_type_args: Option<Vec<String>> = None;
                                    let mut init_span: Option<SpanOut> = None;
                                    let inited = d.init.is_some();
                                    if let Some(init) = &d.init {
                                        init_text = self.cm.span_to_snippet(init.span()).ok();
                                        init_span = {
                                            let sp = init.span();
                                            let ns = self.cm.lookup_char_pos(sp.lo());
                                            let ne = self.cm.lookup_char_pos(sp.hi());
                                            Some(SpanOut {
                                                start: if sp.lo.0 > 0 { sp.lo.0 - 1 } else { sp.lo.0 },
                                                end: sp.hi.0,
                                                loc_start: Loc { line: ns.line as u32, column: ns.col.0 as u32 },
                                                loc_end: Loc { line: ne.line as u32, column: ne.col.0 as u32 },
                                            })
                                        };
                                        if let Expr::Call(c) = &**init {
                                            if let Callee::Expr(expr) = &c.callee {
                                                if let Expr::Ident(i) = &**expr {
                                                    init_callee_ident = Some(i.sym.to_string());
                                                }
                                            }
                                            if let Some(t) = &c.type_args {
                                                let mut names_t = Vec::new();
                                                for p in &t.params {
                                                    let s = self.cm.span_to_snippet(p.span()).unwrap_or_default();
                                                    names_t.push(s);
                                                }
                                                init_type_args = Some(names_t);
                                            }
                                        }
                                    }
                                    fn to_array_pattern(cm: &SourceMap, pat: &Pat) -> Option<ArrayBindingPatternOut> {
                                        match pat {
                                            Pat::Array(arr) => {
                                                let mut elements: Vec<ArrayBindingElementOut> = Vec::new();
                                                for (idx, e) in arr.elems.iter().enumerate() {
                                                    if let Some(p) = e {
                                                        match p {
                                                            Pat::Ident(bi) => {
                                                                elements.push(ArrayBindingElementOut { name: Some(bi.id.sym.to_string()), default_text: None, is_rest: false, index: idx as u32 });
                                                            }
                                                            Pat::Assign(assign) => {
                                                                let mut name: Option<String> = None;
                                                                if let Pat::Ident(bi) = &*assign.left { name = Some(bi.id.sym.to_string()); }
                                                                let def = cm.span_to_snippet(assign.right.span()).ok();
                                                                elements.push(ArrayBindingElementOut { name, default_text: def, is_rest: false, index: idx as u32 });
                                                            }
                                                            Pat::Rest(rest) => {
                                                                let mut name: Option<String> = None;
                                                                if let Pat::Ident(bi) = &*rest.arg { name = Some(bi.id.sym.to_string()); }
                                                                elements.push(ArrayBindingElementOut { name, default_text: None, is_rest: true, index: idx as u32 });
                                                            }
                                                            _ => {
                                                                elements.push(ArrayBindingElementOut { name: None, default_text: None, is_rest: false, index: idx as u32 });
                                                            }
                                                        }
                                                    } else {
                                                        elements.push(ArrayBindingElementOut { name: None, default_text: None, is_rest: false, index: idx as u32 });
                                                    }
                                                }
                                                let type_ann = arr.type_ann.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok());
                                                Some(ArrayBindingPatternOut { elements, pattern_type_ann_text: type_ann })
                                            }
                                            _ => None,
                                        }
                                    }
                                    fn to_object_pattern(cm: &SourceMap, pat: &Pat) -> Option<ObjectBindingPatternOut> {
                                        fn build(cm: &SourceMap, obj: &ObjectPat) -> ObjectBindingPatternOut {
                                            let mut props: Vec<ObjectBindingPropertyOut> = Vec::new();
                                            for prop in &obj.props {
                                                match prop {
                                                    ObjectPatProp::KeyValue(kv) => {
                                                        let key = match &kv.key {
                                                            PropName::Ident(i) => i.sym.to_string(),
                                                            PropName::Str(s) => s.value.as_str().unwrap_or_default().to_string(),
                                                            _ => cm.span_to_snippet(kv.key.span()).unwrap_or_default(),
                                                        };
                                                        let mut alias: Option<String> = None;
                                                        let mut default_text: Option<String> = None;
                                                        let mut nested: Option<ObjectBindingPatternOut> = None;
                                                        match &*kv.value {
                                                            Pat::Ident(bi) => { alias = Some(bi.id.sym.to_string()); }
                                                            Pat::Assign(assign) => {
                                                                if let Pat::Ident(bi) = &*assign.left { alias = Some(bi.id.sym.to_string()); }
                                                                default_text = cm.span_to_snippet(assign.right.span()).ok();
                                                            }
                                                            Pat::Object(nested_obj) => {
                                                                nested = Some(build(cm, nested_obj));
                                                            }
                                                            _ => {}
                                                        }
                                                        props.push(ObjectBindingPropertyOut { key, alias, default_text, nested });
                                                    }
                                                    ObjectPatProp::Assign(assign) => {
                                                        let key = assign.key.sym.to_string();
                                                        let alias = Some(assign.key.sym.to_string());
                                                        let default_text = assign.value.as_ref().and_then(|e| cm.span_to_snippet(e.span()).ok());
                                                        props.push(ObjectBindingPropertyOut { key, alias, default_text, nested: None });
                                                    }
                                                    ObjectPatProp::Rest(rest) => {
                                                        if let Pat::Ident(bi) = &*rest.arg {
                                                            let key = cm.span_to_snippet(rest.span).unwrap_or_else(|_| bi.id.sym.to_string());
                                                            let alias = Some(bi.id.sym.to_string());
                                                            props.push(ObjectBindingPropertyOut { key, alias, default_text: None, nested: None });
                                                        }
                                                    }
                                                }
                                            }
                                            let type_ann = obj.type_ann.as_ref().and_then(|t| cm.span_to_snippet(t.span).ok());
                                            ObjectBindingPatternOut { properties: props, pattern_type_ann_text: type_ann }
                                        }
                                        match pat {
                                            Pat::Object(obj) => Some(build(cm, obj)),
                                            _ => None,
                                        }
                                    }
                                    let array_pattern = to_array_pattern(self.cm, &d.name);
                                    let object_pattern = to_object_pattern(self.cm, &d.name);
                                    self.body.push(ModuleItemOut::VariableDeclaration {
                                        node: self.s(v.span),
                                        decl_kind,
                                        name,
                                        name_span: {
                                            let ns = self.cm.lookup_char_pos(d.name.span().lo());
                                            let ne = self.cm.lookup_char_pos(d.name.span().hi());
                                            SpanOut {
                                                start: if d.name.span().lo.0 > 0 { d.name.span().lo.0 - 1 } else { d.name.span().lo.0 },
                                                end: d.name.span().hi.0,
                                                loc_start: Loc { line: ns.line as u32, column: ns.col.0 as u32 },
                                                loc_end: Loc { line: ne.line as u32, column: ne.col.0 as u32 },
                                            }
                                        },
                                        names,
                                        inited,
                                        init_text,
                                        init_callee_ident,
                                        init_span,
                                        type_parameters: init_type_args,
                                        array_pattern,
                                        object_pattern,
                                    });
                                }
                            }
                            Decl::Fn(f) => {
                                let name = f.ident.sym.to_string();
                                let text = self.cm.span_to_snippet(f.function.span).ok();
                                fn to_fn_param(cm: &SourceMap, p: &Param) -> FnParamOut {
                                    let mut name: Option<String> = None;
                                    let mut default_text: Option<String> = None;
                                    let mut is_rest = false;
                                    let mut type_ann_text: Option<String> = None;
                                    match &p.pat {
                                        Pat::Ident(bi) => {
                                            name = Some(bi.id.sym.to_string());
                                            if let Some(ann) = &bi.type_ann { type_ann_text = cm.span_to_snippet(ann.span).ok(); }
                                        }
                                        Pat::Assign(assign) => {
                                            if let Pat::Ident(bi) = &*assign.left { name = Some(bi.id.sym.to_string()); }
                                            default_text = cm.span_to_snippet(assign.right.span()).ok();
                                        }
                                        Pat::Rest(rest) => {
                                            is_rest = true;
                                            if let Pat::Ident(bi) = &*rest.arg { name = Some(bi.id.sym.to_string()); }
                                        }
                                        Pat::Array(_) | Pat::Object(_) | Pat::Expr(_) | Pat::Invalid(_) => {
                                            name = Some(cm.span_to_snippet(p.pat.span()).unwrap_or_default());
                                        }
                                    }
                                    FnParamOut { name, default_text, is_rest, type_ann_text }
                                }
                                let mut params: Vec<FnParamOut> = Vec::new();
                                for par in &f.function.params { params.push(to_fn_param(self.cm, par)); }
                                let r_async = f.function.is_async;
                                let r_generator = f.function.is_generator;
                                let return_type = f.function.return_type.as_ref().and_then(|t| self.cm.span_to_snippet(t.span).ok());
                                self.body.push(ModuleItemOut::FunctionDeclaration { node: self.s(f.function.span), name, text, r#async: r_async, generator: r_generator, params, return_type });
                            }
                            Decl::Class(c) => {
                                let name = c.ident.sym.to_string();
                                let super_class = c.class.super_class.as_ref().and_then(|e| self.cm.span_to_snippet(e.span()).ok());
                                let mut implements: Vec<String> = Vec::new();
                                for im in &c.class.implements { implements.push(self.cm.span_to_snippet(im.span()).unwrap_or_default()); }
                                let mut decorators: Vec<String> = Vec::new();
                                for d in &c.class.decorators { decorators.push(self.cm.span_to_snippet(d.span()).unwrap_or_default()); }
                                fn member_to_out(cm: &SourceMap, m: &ClassMember) -> ClassMemberOut {
                                    match m {
                                        ClassMember::Constructor(cons) => ClassMemberOut::Constructor { node: Collector::new(cm).s(cons.span()) },
                                        ClassMember::Method(method) => {
                                            let key = match &method.key { PropName::Ident(i) => i.sym.to_string(), PropName::Str(s) => s.value.as_str().unwrap_or_default().to_string(), PropName::Num(n) => n.value.to_string(), PropName::Computed(c) => cm.span_to_snippet(c.span()).unwrap_or_default(), PropName::BigInt(b) => b.value.to_string() };
                                            match method.kind {
                                                MethodKind::Getter => ClassMemberOut::Getter { node: Collector::new(cm).s(method.span()), key, is_static: method.is_static },
                                                MethodKind::Setter => ClassMemberOut::Setter { node: Collector::new(cm).s(method.span()), key, is_static: method.is_static },
                                                MethodKind::Method => ClassMemberOut::Method { node: Collector::new(cm).s(method.span()), key, is_static: method.is_static, r#async: method.function.is_async, generator: method.function.is_generator },
                                            }
                                        }
                                        ClassMember::PrivateMethod(method) => {
                                            let key = cm.span_to_snippet(method.span()).unwrap_or_default();
                                            ClassMemberOut::Method { node: Collector::new(cm).s(method.span()), key, is_static: method.is_static, r#async: method.function.is_async, generator: method.function.is_generator }
                                        }
                                        ClassMember::ClassProp(prop) => {
                                            let key = match &prop.key {
                                                PropName::Ident(i) => i.sym.to_string(),
                                                PropName::Str(s) => s.value.as_str().unwrap_or_default().to_string(),
                                                PropName::Num(n) => n.value.to_string(),
                                                PropName::Computed(c) => cm.span_to_snippet(c.span()).unwrap_or_default(),
                                                PropName::BigInt(b) => b.value.to_string(),
                                            };
                                            ClassMemberOut::Property { node: Collector::new(cm).s(prop.span), key, is_static: prop.is_static }
                                        }
                                        ClassMember::PrivateProp(prop) => {
                                            let key = cm.span_to_snippet(prop.span()).unwrap_or_default();
                                            ClassMemberOut::Property { node: Collector::new(cm).s(prop.span()), key, is_static: prop.is_static }
                                        }
                                        ClassMember::StaticBlock(sb) => ClassMemberOut::StaticBlock { node: Collector::new(cm).s(sb.span()) },
                                        _ => {
                                            let sp = m.span();
                                            ClassMemberOut::Property { node: Collector::new(cm).s(sp), key: String::new(), is_static: false }
                                        }
                                    }
                                }
                                let mut members: Vec<ClassMemberOut> = Vec::new();
                                for m in &c.class.body { members.push(member_to_out(self.cm, m)); }
                                self.body.push(ModuleItemOut::ClassDeclaration { node: self.s(c.class.span), name, super_class, implements, decorators, members });
                            }
                            _ => {}
                        }
                    }
                    _ => {
                        stmt.visit_with(self);
                    }
                }
            }
        }
    }

    fn visit_call_expr(&mut self, n: &CallExpr) {
        let mut callee_ident: Option<String> = None;
        if let Callee::Expr(expr) = &n.callee {
            if let Expr::Ident(i) = &**expr {
                callee_ident = Some(i.sym.to_string());
            }
        }
        let mut args = Vec::new();
        for a in &n.args {
            let s = self.cm.span_to_snippet(a.span()).unwrap_or_default();
            args.push(s);
        }
        let mut type_args: Option<Vec<String>> = None;
        let mut type_argument_text: Option<String> = None;
        let mut type_arg_kinds: Option<Vec<String>> = None;
        let mut type_ref_idents: Option<Vec<String>> = None;
        let mut type_literal_props: Option<Vec<Vec<TSPropSigOut>>> = None;
        if let Some(t) = &n.type_args {
            let mut names = Vec::new();
            for p in &t.params {
                let s = self.cm.span_to_snippet(p.span()).unwrap_or_default();
                names.push(s);
            }
            type_args = Some(names);
            // type argument text
            if !t.params.is_empty() {
                let mut parts: Vec<String> = Vec::new();
                for p in &t.params {
                    let s = self.cm.span_to_snippet(p.span()).unwrap_or_default();
                    parts.push(s);
                }
                let txt = format!("<{}>", parts.join(", "));
                if !txt.is_empty() { type_argument_text = Some(txt); }
            }
            // kinds, refs and literal props
            let mut kinds: Vec<String> = Vec::new();
            let mut ref_idents: Vec<String> = Vec::new();
            let mut lit_props_list: Vec<Vec<TSPropSigOut>> = Vec::new();
            for p in &t.params {
                match &**p {
                    TsType::TsTypeRef(tr) => {
                        kinds.push("type_ref".to_string());
                        let name = match &tr.type_name {
                            TsEntityName::Ident(i) => i.sym.to_string(),
                            TsEntityName::TsQualifiedName(q) => match &q.left { TsEntityName::Ident(i) => format!("{}.{}", i.sym.to_string(), q.right.sym.to_string()), TsEntityName::TsQualifiedName(_) => self.cm.span_to_snippet(q.span()).unwrap_or_default() },
                        };
                        ref_idents.push(name);
                        lit_props_list.push(Vec::new());
                    }
                    TsType::TsTypeLit(lit) => {
                        kinds.push("type_literal".to_string());
                        let mut members: Vec<TSPropSigOut> = Vec::new();
                        for m in &lit.members {
                            if let TsTypeElement::TsPropertySignature(ps) = m {
                                let key = match &*ps.key {
                                    Expr::Ident(i) => i.sym.to_string(),
                                    Expr::Lit(Lit::Str(s)) => s.value.as_str().unwrap_or_default().to_string(),
                                    _ => self.cm.span_to_snippet(ps.span).unwrap_or_default(),
                                };
                                let type_ann = ps.type_ann.as_ref().map(|t| self.cm.span_to_snippet(t.span).unwrap_or_default());
                                let optional = ps.optional;
                                members.push(TSPropSigOut { key, type_ann, optional });
                            }
                        }
                        ref_idents.push(String::new());
                        lit_props_list.push(members);
                    }
                    // union / intersection not matched explicitly in this version; treat as other
                    _ => {
                        kinds.push("other".to_string());
                        ref_idents.push(String::new());
                        lit_props_list.push(Vec::new());
                    }
                }
            }
            type_arg_kinds = Some(kinds);
            type_ref_idents = Some(ref_idents);
            type_literal_props = Some(lit_props_list);
        }
        let text = self.cm.span_to_snippet(n.span).ok();
        self.body.push(ModuleItemOut::CallExpression {
            node: self.s(n.span),
            callee_ident,
            args,
            type_parameters: type_args,
            text,
            type_argument_text,
            type_arg_kinds,
            type_ref_idents,
            type_literal_props,
        });
    }

    fn visit_ts_type_alias_decl(&mut self, n: &TsTypeAliasDecl) {
        let id = n.id.sym.to_string();
        let mut members: Vec<TSPropSigOut> = Vec::new();
        if let TsType::TsTypeLit(lit) = &*n.type_ann {
            for m in &lit.members {
                if let TsTypeElement::TsPropertySignature(ps) = m {
                    let key = match &*ps.key {
                        Expr::Ident(i) => i.sym.to_string(),
                        Expr::Lit(Lit::Str(s)) => s.value.as_str().unwrap_or_default().to_string(),
                        _ => self.cm.span_to_snippet(ps.span).unwrap_or_default(),
                    };
                    let type_ann = ps.type_ann.as_ref().map(|t| self.cm.span_to_snippet(t.span).unwrap_or_default());
                    let optional = ps.optional;
                    members.push(TSPropSigOut { key, type_ann, optional });
                }
            }
        }
        self.body.push(ModuleItemOut::TSTypeAliasDeclaration { node: self.s(n.span), id: id.clone(), members: members.clone() });
        if !members.is_empty() {
            self.type_aliases.insert(id, members);
        }
    }

    fn visit_ts_interface_decl(&mut self, n: &TsInterfaceDecl) {
        let id = n.id.sym.to_string();
        let mut members: Vec<TSPropSigOut> = Vec::new();
        let body = &n.body;
        for m in &body.body {
            if let TsTypeElement::TsPropertySignature(ps) = m {
                    let key = match &*ps.key {
                        Expr::Ident(i) => i.sym.to_string(),
                        Expr::Lit(Lit::Str(s)) => s.value.as_str().unwrap_or_default().to_string(),
                        _ => self.cm.span_to_snippet(ps.span).unwrap_or_default(),
                    };
                    let type_ann = ps.type_ann.as_ref().map(|t| self.cm.span_to_snippet(t.span).unwrap_or_default());
                    let optional = ps.optional;
                    members.push(TSPropSigOut { key, type_ann, optional });
                }
        }
        self.body.push(ModuleItemOut::TSInterfaceDeclaration { node: self.s(n.span), id: id.clone(), members: members.clone() });
        if !members.is_empty() {
            self.interfaces.insert(id, members);
        }
    }
}

fn parse_to_json(src: &str, is_tsx: bool, _keep_comments: bool) -> Result<String> {
    let cm = SourceMap::default();
    let fm = cm.new_source_file(Lrc::new(FileName::Custom("input.ts".into())), src.to_owned());
    let syntax = Syntax::Typescript(TsSyntax { tsx: is_tsx, decorators: true, ..Default::default() });
    let lexer = Lexer::new(syntax, EsVersion::Es2022, StringInput::from(&*fm), None);
    let mut parser = Parser::new_from(lexer);
    let module = parser.parse_module().map_err(|e| anyhow::anyhow!("parse error: {:?}", e))?;
    let mut collector = Collector::new(&cm);
    module.visit_with(&mut collector);
    let out = ModuleOut { body: collector.body };
    let json = serde_json::to_string(&out)?;
    Ok(json)
}

#[no_mangle]
pub extern "C" fn swc_parse_ts(src: *const c_char, is_tsx: c_uchar, keep_comments: c_uchar) -> *mut c_char {
    if src.is_null() { return std::ptr::null_mut(); }
    let c_str = unsafe { CStr::from_ptr(src) };
    let s = match c_str.to_str() { Ok(v) => v, Err(_) => return std::ptr::null_mut() };
    match parse_to_json(s, is_tsx != 0, keep_comments != 0) {
        Ok(json) => {
            let c = CString::new(json).unwrap_or_else(|_| CString::new("{}").unwrap());
            c.into_raw()
        }
        Err(_) => {
            let c = CString::new("{\"error\":\"parse failed\"}").unwrap();
            c.into_raw()
        }
    }
}

#[no_mangle]
pub extern "C" fn swc_free(ptr: *mut c_char) {
    if ptr.is_null() { return; }
    unsafe { let _ = CString::from_raw(ptr); }
}
#[derive(Serialize)]
#[serde(tag = "type")]
enum ExpressionOut {
    NullLiteral { #[serde(flatten)] node: NodeOut },
    BooleanLiteral { #[serde(flatten)] node: NodeOut, value: bool },
    NumberLiteral { #[serde(flatten)] node: NodeOut, value: f64 },
    BigIntLiteral { #[serde(flatten)] node: NodeOut, value: String },
    StringLiteral { #[serde(flatten)] node: NodeOut, value: String },
    ArrayExpression { #[serde(flatten)] node: NodeOut, elements: Vec<ExpressionOut> },
    ObjectExpression { #[serde(flatten)] node: NodeOut, properties: Vec<PropertyOut> },
    FunctionExpression { #[serde(flatten)] node: NodeOut, function_text: String, r#async: bool, generator: bool },
    ArrowFunctionExpression { #[serde(flatten)] node: NodeOut, function_text: String, r#async: bool, expression: bool },
    Identifier { #[serde(flatten)] node: NodeOut, name: String },
}

#[derive(Serialize)]
struct ExpressionWrapOut { expr: ExpressionOut }

#[derive(Serialize)]
#[serde(tag = "type")]
enum PropertyOut {
    #[serde(rename = "Property")]
    Property {
        #[serde(flatten)] node: NodeOut,
        key: ExpressionOut,
        value: ExpressionOut,
        kind: String, // init | get | set | method
        method: bool,
        shorthand: bool,
        computed: bool,
    }
}

fn parse_expr_to_json(src: &str, is_tsx: bool) -> Result<String> {
    let cm = SourceMap::default();
    let fm = cm.new_source_file(Lrc::new(FileName::Custom("input.ts".into())), src.to_owned());
    let syntax = Syntax::Typescript(TsSyntax { tsx: is_tsx, decorators: true, ..Default::default() });
    let lexer = Lexer::new(syntax, EsVersion::Es2022, StringInput::from(&*fm), None);
    let mut parser = Parser::new_from(lexer);
    let expr = parser.parse_expr().map_err(|e| anyhow::anyhow!("parse error: {:?}", e))?;

    fn to_expr_out(cm: &SourceMap, e: &Expr) -> ExpressionOut {
        match e {
            Expr::Lit(Lit::Null(_)) => ExpressionOut::NullLiteral { node: Collector::new(cm).s(e.span()) },
            Expr::Lit(Lit::Bool(b)) => ExpressionOut::BooleanLiteral { node: Collector::new(cm).s(e.span()), value: b.value },
            Expr::Lit(Lit::Num(n)) => ExpressionOut::NumberLiteral { node: Collector::new(cm).s(e.span()), value: n.value },
            Expr::Lit(Lit::BigInt(b)) => ExpressionOut::BigIntLiteral { node: Collector::new(cm).s(e.span()), value: b.value.to_string() },
            Expr::Lit(Lit::Str(s)) => ExpressionOut::StringLiteral { node: Collector::new(cm).s(e.span()), value: s.value.as_str().unwrap_or_default().to_string() },
            Expr::Array(arr) => {
                let mut elements: Vec<ExpressionOut> = Vec::new();
                for el in &arr.elems {
                    if let Some(ExprOrSpread { expr, .. }) = el { elements.push(to_expr_out(cm, expr)); } else { elements.push(ExpressionOut::NullLiteral { node: Collector::new(cm).s(arr.span) }); }
                }
                ExpressionOut::ArrayExpression { node: Collector::new(cm).s(e.span()), elements }
            }
            Expr::Object(obj) => {
                fn prop_name_to_string(cm: &SourceMap, p: &PropName) -> String {
                    match p {
                        PropName::Ident(i) => i.sym.to_string(),
                        PropName::Str(s) => s.value.as_str().unwrap_or_default().to_string(),
                        PropName::Num(n) => n.value.to_string(),
                        PropName::Computed(c) => cm.span_to_snippet(c.span()).unwrap_or_default(),
                        PropName::BigInt(b) => b.value.to_string(),
                    }
                }
                let mut props: Vec<PropertyOut> = Vec::new();
                for p in &obj.props {
                    match p {
                        PropOrSpread::Prop(prop) => {
                            match &**prop {
                                Prop::KeyValue(kv) => {
                                    let key_text = prop_name_to_string(cm, &kv.key);
                                    let key = match &kv.key {
                                        PropName::Ident(i) => ExpressionOut::Identifier { node: Collector::new(cm).s(i.span), name: i.sym.to_string() },
                                        PropName::Str(s) => ExpressionOut::StringLiteral { node: Collector::new(cm).s(s.span), value: s.value.as_str().unwrap_or_default().to_string() },
                                        PropName::Num(n) => ExpressionOut::NumberLiteral { node: Collector::new(cm).s(n.span), value: n.value },
                                        PropName::Computed(c) => to_expr_out(cm, &c.expr),
                                        PropName::BigInt(b) => ExpressionOut::BigIntLiteral { node: Collector::new(cm).s(b.span), value: b.value.to_string() },
                                    };
                                    let value = to_expr_out(cm, &kv.value);
                                    props.push(PropertyOut::Property { node: Collector::new(cm).s(kv.value.span()), key, value, kind: "init".to_string(), method: false, shorthand: false, computed: matches!(kv.key, PropName::Computed(_)) });
                                }
                                Prop::Shorthand(ident) => {
                                    let key_text = ident.sym.to_string();
                                    let key = ExpressionOut::Identifier { node: Collector::new(cm).s(ident.span), name: key_text.clone() };
                                    let value = ExpressionOut::Identifier { node: Collector::new(cm).s(ident.span), name: key_text.clone() };
                                    props.push(PropertyOut::Property { node: Collector::new(cm).s(ident.span), key, value, kind: "init".to_string(), method: false, shorthand: true, computed: false });
                                }
                                Prop::Method(m) => {
                                    let key_text = prop_name_to_string(cm, &m.key);
                                    let key = match &m.key {
                                        PropName::Ident(i) => ExpressionOut::Identifier { node: Collector::new(cm).s(i.span), name: i.sym.to_string() },
                                        PropName::Str(s) => ExpressionOut::StringLiteral { node: Collector::new(cm).s(s.span), value: s.value.as_str().unwrap_or_default().to_string() },
                                        PropName::Num(n) => ExpressionOut::NumberLiteral { node: Collector::new(cm).s(n.span), value: n.value },
                                        PropName::Computed(c) => to_expr_out(cm, &c.expr),
                                        PropName::BigInt(b) => ExpressionOut::BigIntLiteral { node: Collector::new(cm).s(b.span), value: b.value.to_string() },
                                    };
                                    let txt = cm.span_to_snippet(m.function.span).unwrap_or_default();
                                    let value = ExpressionOut::FunctionExpression { node: Collector::new(cm).s(m.function.span), function_text: txt, r#async: m.function.is_async, generator: m.function.is_generator };
                                    props.push(PropertyOut::Property { node: Collector::new(cm).s(m.function.span), key, value, kind: "method".to_string(), method: true, shorthand: false, computed: matches!(m.key, PropName::Computed(_)) });
                                }
                                Prop::Getter(g) => {
                                    let key_text = prop_name_to_string(cm, &g.key);
                                    let key = match &g.key {
                                        PropName::Ident(i) => ExpressionOut::Identifier { node: Collector::new(cm).s(i.span), name: i.sym.to_string() },
                                        PropName::Str(s) => ExpressionOut::StringLiteral { node: Collector::new(cm).s(s.span), value: s.value.as_str().unwrap_or_default().to_string() },
                                        PropName::Num(n) => ExpressionOut::NumberLiteral { node: Collector::new(cm).s(n.span), value: n.value },
                                        PropName::Computed(c) => to_expr_out(cm, &c.expr),
                                        PropName::BigInt(b) => ExpressionOut::BigIntLiteral { node: Collector::new(cm).s(b.span), value: b.value.to_string() },
                                    };
                                    let txt = cm.span_to_snippet(g.span).unwrap_or_default();
                                    let value = ExpressionOut::FunctionExpression { node: Collector::new(cm).s(g.span), function_text: txt, r#async: false, generator: false };
                                    props.push(PropertyOut::Property { node: Collector::new(cm).s(g.span), key, value, kind: "get".to_string(), method: false, shorthand: false, computed: matches!(g.key, PropName::Computed(_)) });
                                }
                                Prop::Setter(sv) => {
                                    let key_text = prop_name_to_string(cm, &sv.key);
                                    let key = match &sv.key {
                                        PropName::Ident(i) => ExpressionOut::Identifier { node: Collector::new(cm).s(i.span), name: i.sym.to_string() },
                                        PropName::Str(s) => ExpressionOut::StringLiteral { node: Collector::new(cm).s(s.span), value: s.value.as_str().unwrap_or_default().to_string() },
                                        PropName::Num(n) => ExpressionOut::NumberLiteral { node: Collector::new(cm).s(n.span), value: n.value },
                                        PropName::Computed(c) => to_expr_out(cm, &c.expr),
                                        PropName::BigInt(b) => ExpressionOut::BigIntLiteral { node: Collector::new(cm).s(b.span), value: b.value.to_string() },
                                    };
                                    let txt = cm.span_to_snippet(sv.span).unwrap_or_default();
                                    let value = ExpressionOut::FunctionExpression { node: Collector::new(cm).s(sv.span), function_text: txt, r#async: false, generator: false };
                                    props.push(PropertyOut::Property { node: Collector::new(cm).s(sv.span), key, value, kind: "set".to_string(), method: false, shorthand: false, computed: matches!(sv.key, PropName::Computed(_)) });
                                }
                                Prop::Assign(ap) => {
                                    let key_text = ap.key.sym.to_string();
                                    let key = ExpressionOut::Identifier { node: Collector::new(cm).s(ap.key.span), name: key_text.clone() };
                                    let value = to_expr_out(cm, &*ap.value);
                                    props.push(PropertyOut::Property { node: Collector::new(cm).s(ap.span), key, value, kind: "init".to_string(), method: false, shorthand: true, computed: false });
                                }
                            }
                        }
                        PropOrSpread::Spread(sp) => {
                            let key_text = "...".to_string();
                            let key = ExpressionOut::Identifier { node: Collector::new(cm).s(sp.span()), name: key_text.clone() };
                            let value = to_expr_out(cm, &sp.expr);
                            props.push(PropertyOut::Property { node: Collector::new(cm).s(sp.span()), key, value, kind: "init".to_string(), method: false, shorthand: false, computed: false });
                        }
                    }
                }
                ExpressionOut::ObjectExpression { node: Collector::new(cm).s(e.span()), properties: props }
            }
            swc_ecma_ast::Expr::Fn(f) => {
                let txt = cm.span_to_snippet(f.function.span).unwrap_or_default();
                ExpressionOut::FunctionExpression { node: Collector::new(cm).s(f.function.span), function_text: txt, r#async: f.function.is_async, generator: f.function.is_generator }
            }
            swc_ecma_ast::Expr::Arrow(af) => {
                let txt = cm.span_to_snippet(af.span).unwrap_or_default();
                ExpressionOut::ArrowFunctionExpression { node: Collector::new(cm).s(af.span), function_text: txt, r#async: af.is_async, expression: af.body.is_expr() }
            }
            Expr::Ident(i) => ExpressionOut::Identifier { node: Collector::new(cm).s(i.span), name: i.sym.to_string() },
            _ => ExpressionOut::Identifier { node: Collector::new(cm).s(e.span()), name: cm.span_to_snippet(e.span()).unwrap_or_default() },
        }
    }

    let out = to_expr_out(&cm, &expr);
    let wrap = ExpressionWrapOut { expr: out };
    let json = serde_json::to_string(&wrap)?;
    Ok(json)
}

#[no_mangle]
pub extern "C" fn swc_parse_expr(src: *const c_char, is_tsx: c_uchar) -> *mut c_char {
    if src.is_null() { return std::ptr::null_mut(); }
    let c_str = unsafe { CStr::from_ptr(src) };
    let s = match c_str.to_str() { Ok(v) => v, Err(_) => return std::ptr::null_mut() };
    match parse_expr_to_json(s, is_tsx != 0) {
        Ok(json) => {
            let c = CString::new(json).unwrap_or_else(|_| CString::new("{}").unwrap());
            c.into_raw()
        }
        Err(_) => {
            let c = CString::new("{\"error\":\"parse failed\"}").unwrap();
            c.into_raw()
        }
    }
}