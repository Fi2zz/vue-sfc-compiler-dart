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
    ImportDeclaration { #[serde(flatten)] node: NodeOut, src: String },
    ExportDefaultDeclaration { #[serde(flatten)] node: NodeOut, obj_span: Option<SpanOut> },
    CallExpression { #[serde(flatten)] node: NodeOut, callee_ident: Option<String>, args: Vec<String>, type_parameters: Option<Vec<String>>, text: Option<String> },
    TSTypeAliasDeclaration { #[serde(flatten)] node: NodeOut, id: String, members: Vec<TSPropSigOut> },
    TSInterfaceDeclaration { #[serde(flatten)] node: NodeOut, id: String, members: Vec<TSPropSigOut> },
    VariableDeclaration { #[serde(flatten)] node: NodeOut, decl_kind: String, name: String, name_span: SpanOut, names: Vec<String>, inited: bool, init_text: Option<String>, init_callee_ident: Option<String>, init_span: Option<SpanOut>, type_parameters: Option<Vec<String>>, array_pattern: Option<ArrayBindingPatternOut>, object_pattern: Option<ObjectBindingPatternOut> },
    FunctionDeclaration { #[serde(flatten)] node: NodeOut, name: String, text: Option<String> },
    ClassDeclaration { #[serde(flatten)] node: NodeOut, name: String },
}

#[derive(Serialize)]
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
}

impl<'a> Collector<'a> {
    fn new(cm: &'a SourceMap) -> Self {
        Self { cm, body: Vec::new() }
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
}

impl<'a> Visit for Collector<'a> {
    fn visit_module_item(&mut self, n: &ModuleItem) {
        match n {
            ModuleItem::ModuleDecl(decl) => {
                match decl {
                    ModuleDecl::Import(import) => {
                        let src = import.src.value.as_str().unwrap_or_default().to_string();
                        self.body.push(ModuleItemOut::ImportDeclaration { node: self.s(import.span), src });
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
                    ModuleDecl::TsImportEquals(_) | ModuleDecl::ExportNamed(_) | ModuleDecl::ExportAll(_) | ModuleDecl::TsExportAssignment(_) | ModuleDecl::TsNamespaceExport(_) | ModuleDecl::ExportDecl(_) => {}
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
                                self.body.push(ModuleItemOut::FunctionDeclaration { node: self.s(f.function.span), name, text });
                            }
                            Decl::Class(c) => {
                                let name = c.ident.sym.to_string();
                                self.body.push(ModuleItemOut::ClassDeclaration { node: self.s(c.class.span), name });
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
        if let Some(t) = &n.type_args {
            let mut names = Vec::new();
            for p in &t.params {
                let s = self.cm.span_to_snippet(p.span()).unwrap_or_default();
                names.push(s);
            }
            type_args = Some(names);
        }
        let text = self.cm.span_to_snippet(n.span).ok();
        self.body.push(ModuleItemOut::CallExpression {
            node: self.s(n.span),
            callee_ident,
            args,
            type_parameters: type_args,
            text,
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
        self.body.push(ModuleItemOut::TSTypeAliasDeclaration { node: self.s(n.span), id, members });
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
        self.body.push(ModuleItemOut::TSInterfaceDeclaration { node: self.s(n.span), id, members });
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