//! Thin oxc parser wrapper exposing a C ABI for Dart FFI.
//! Exports exactly two symbols: `oxc_parse` and `oxc_free`.
//! The returned JSON string is owned by the caller and must be released
//! with `oxc_free`. Panics never cross the FFI boundary.

use std::ffi::{c_char, c_uint, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::slice;
use std::str;

use oxc_allocator::Allocator;
use oxc_ast::ast::{Comment, CommentKind, Program};
use oxc_diagnostics::OxcDiagnostic;
use oxc_estree::{CompactFormatter, ConfigNoFixes, ESTree, ESTreeSerializer};
use oxc_parser::Parser;
use oxc_span::SourceType;

const LANG_TSX: u32 = 1;
const LANG_JS: u32 = 2;
const LANG_JSX: u32 = 3;

/// Map the FFI language tag to an oxc SourceType. SFC scripts are modules.
pub fn source_type_of(lang: u32) -> SourceType {
    match lang {
        LANG_TSX => SourceType::tsx(),
        LANG_JS => SourceType::mjs(),
        LANG_JSX => SourceType::jsx(),
        _ => SourceType::ts(),
    }
}

/// Parse `source` and return the JSON payload.
/// Recovered syntax/semantic diagnostics ship alongside the AST (matching
/// tree-sitter's always-return-a-tree behavior); only a parser panic or
/// invalid input produces the error shape.
pub fn parse_to_json(source: &str, lang: u32) -> String {
    let allocator = Allocator::default();
    let ret = Parser::new(&allocator, source, source_type_of(lang)).parse();
    if ret.panicked {
        return error_json(&ret.diagnostics);
    }
    let program = program_json(&ret.program);
    let comments = comments_json(&ret.program.comments, source);
    let diagnostics = diagnostics_json(&ret.diagnostics);
    format!(
        "{{\"ok\":true,\"program\":{program},\"comments\":{comments},\"diagnostics\":{diagnostics}}}"
    )
}

/// Serialize all diagnostics as a JSON array of message+span objects.
fn diagnostics_json(errors: &[OxcDiagnostic]) -> String {
    let parts: Vec<String> = errors.iter().map(diagnostic_json).collect();
    format!("[{}]", parts.join(","))
}

/// Serialize one diagnostic as message plus byte span.
fn diagnostic_json(e: &OxcDiagnostic) -> String {
    let (start, len) = e.labels.first().map_or((0, 0), |s| (s.offset(), s.len()));
    serde_json::json!({
        "error": e.to_string(),
        "start": start,
        "end": start + len,
    })
    .to_string()
}

/// Serialize the Program as compact ESTree JSON, keeping TS-only fields.
fn program_json(program: &Program) -> String {
    to_estree_json(program)
}

/// Serialize the sorted comment list as a JSON array; the ESTree Program
/// payload omits comments by convention, but the Dart mapper needs them.
fn comments_json(comments: &[Comment], source: &str) -> String {
    let parts: Vec<String> = comments.iter().map(|c| comment_json(c, source)).collect();
    format!("[{}]", parts.join(","))
}

/// Serialize one comment manually; the ESTree Comment impl panics by design
/// (value transfer is left to consumers slicing source text).
fn comment_json(c: &Comment, source: &str) -> String {
    let (start, end) = (c.span.start as usize, c.span.end as usize);
    let line = matches!(c.kind, CommentKind::Line);
    let value = &source[start + 2..end - usize::from(!line) * 2];
    serde_json::json!({
        "type": "comment",
        "kind": if line { "line" } else { "block" },
        "value": value,
        "start": start,
        "end": end,
    })
    .to_string()
}

/// Run one ESTree serialization pass into a compact JSON string.
fn to_estree_json<T: ESTree>(node: &T) -> String {
    let mut ser = ESTreeSerializer::<ConfigNoFixes, CompactFormatter>::new(true, false);
    node.serialize(&mut ser);
    ser.into_string()
}

/// Serialize the first diagnostic as the fatal error payload.
fn error_json(errors: &[OxcDiagnostic]) -> String {
    match errors.first() {
        Some(e) => {
            let inner = diagnostic_json(e);
            format!("{{\"ok\":false,\"diagnostic\":{inner}}}")
        }
        None => plain_error_json("parse failed"),
    }
}

/// One-line error payload for failures outside the parser itself.
fn plain_error_json(message: &str) -> String {
    serde_json::json!({"ok": false, "error": message}).to_string()
}

/// Hand a String across the FFI boundary; JSON never contains NUL bytes.
fn into_raw(json: String) -> *mut c_char {
    CString::new(json).map_or(ptr::null_mut(), CString::into_raw)
}

/// Parse `len` UTF-8 bytes at `code` in language `lang` (0=ts 1=tsx 2=js 3=jsx).
/// Returns a heap JSON string the caller must release with `oxc_free`,
/// or null on the (impossible) NUL-containing payload.
#[no_mangle]
pub extern "C" fn oxc_parse(code: *const u8, len: c_uint, lang: c_uint) -> *mut c_char {
    let json = catch_unwind(AssertUnwindSafe(|| unsafe {
        let bytes = slice::from_raw_parts(code, len as usize);
        match str::from_utf8(bytes) {
            Ok(src) => parse_to_json(src, lang),
            Err(_) => plain_error_json("input is not valid UTF-8"),
        }
    }))
    .unwrap_or_else(|_| plain_error_json("oxc panicked during parse"));
    into_raw(json)
}

/// Release a JSON string previously returned by `oxc_parse`.
#[no_mangle]
pub extern "C" fn oxc_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe { drop(CString::from_raw(ptr)) };
}
