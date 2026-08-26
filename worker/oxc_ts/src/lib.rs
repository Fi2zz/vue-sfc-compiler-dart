//! Thin oxc parser wrapper exposing a C ABI for Dart FFI.
//! Exports exactly two symbols: `oxc_parse` and `oxc_free`.
//! The returned JSON string is owned by the caller and must be released
//! with `oxc_free`. Panics never cross the FFI boundary.

use std::ffi::{c_char, c_uint, CStr, CString};
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
use serde_json::Value;
use std::collections::HashMap;

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

/// Parse `count` NUL-terminated sources at `code` (array of char*) in one
/// call, returning `{"ok":true,"items":[<oxc_parse payload>, ...]}`. Each
/// item is isolated: a panic in one entry yields that entry's error shape,
/// never failing the whole batch.
#[no_mangle]
pub extern "C" fn oxc_parse_batch(
    code: *const *const c_char,
    count: u32,
    lang: u32,
) -> *mut c_char {
    let json = catch_unwind(AssertUnwindSafe(|| unsafe {
        let slice = slice::from_raw_parts(code, count as usize);
        let mut items = Vec::with_capacity(count as usize);
        for &p in slice {
            if p.is_null() {
                items.push(plain_error_json("null entry"));
                continue;
            }
            let cstr = CStr::from_ptr(p);
            match str::from_utf8(cstr.to_bytes()) {
                Ok(s) => items.push(parse_to_json(s, lang)),
                Err(_) => items.push(plain_error_json("input is not valid UTF-8")),
            }
        }
        format!("{{\"ok\":true,\"items\":[{}]}}", items.join(","))
    }))
    .unwrap_or_else(|_| plain_error_json("oxc panicked during batch parse"));
    into_raw(json)
}

/// Binary batch variant: same inputs as `oxc_parse_batch`, but the response
/// is a compact tagged encoding decoded Dart-side without any text parsing:
///   header: magic u32 0x4F584231, item_count u32,
///           index: item_count x (offset u32, len u32) into the blob
///   values: 0=obj 1=arr 2=str 3=num(f64 LE) 4=true 5=false 6=null
///   obj:    count u32, then count x (key str, value)
///   arr:    count u32, then count x value
///   str:    len u32 + UTF-8 bytes
#[no_mangle]
pub extern "C" fn oxc_parse_batch_bin(
    code: *const *const c_char,
    count: u32,
    lang: u32,
) -> *mut c_char {
    let bytes: Vec<u8> = catch_unwind(AssertUnwindSafe(|| unsafe {
        let slice = slice::from_raw_parts(code, count as usize);
        let mut payloads: Vec<Vec<u8>> = Vec::with_capacity(count as usize);
        for &p in slice {
            if p.is_null() {
                payloads.push(plain_error_json("null entry").into_bytes());
                continue;
            }
            let cstr = CStr::from_ptr(p);
            match str::from_utf8(cstr.to_bytes()) {
                Ok(s) => payloads.push(parse_to_json(s, lang).into_bytes()),
                Err(_) => payloads.push(plain_error_json("bad utf8").into_bytes()),
            }
        }
        encode_bin_batch(&payloads)
    }))
    .unwrap_or_else(|_| plain_error_json("oxc panicked during batch parse").into_bytes());
    // Hand bytes across via a length-prefixed C string: NUL bytes are legal
    // in the blob, so prefix the byte length and terminate for safety.
    let mut out = Vec::with_capacity(bytes.len() + 9);
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(&bytes);
    out.push(0);
    let mut boxed = out.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr as *mut c_char
}

struct Interner {
    ids: HashMap<String, u32>,
    list: Vec<String>,
}
impl Interner {
    fn new() -> Self { Self { ids: HashMap::new(), list: Vec::new() } }
    fn intern(&mut self, s: &str) -> u32 {
        *self.ids.entry(s.to_string()).or_insert_with(|| {
            self.list.push(s.to_string());
            (self.list.len() - 1) as u32
        })
    }
}

fn encode_bin_batch(payloads: &[Vec<u8>]) -> Vec<u8> {
    use serde_json::Value;
    use std::collections::HashMap;
    let mut out = Vec::new();
    out.extend_from_slice(&0x4F_58_42_32u32.to_le_bytes()); // OXB2

    let mut key_interner = Interner::new();
    let mut type_interner = Interner::new();

    // Pass 1: intern keys and type names across all payloads.
    let mut values: Vec<Value> = payloads
        .iter()
        .map(|p| serde_json::from_slice::<Value>(p).unwrap_or(Value::Null))
        .collect();
    fn collect(v: &Value, ki: &mut Interner, ti: &mut Interner) {
        match v {
            Value::Object(m) => {
                let typed = m.get("type").and_then(|t| t.as_str());
                if let Some(t) = typed {
                    ti.intern(t);
                }
                for (k, val) in m {
                    if k != "type" || typed.is_none() {
                        ki.intern(k);
                    }
                    collect(val, ki, ti);
                }
            }
            Value::Array(a) => {
                for val in a { collect(val, ki, ti); }
            }
            _ => {}
        }
    }
    for v in &values { collect(v, &mut key_interner, &mut type_interner); }

    out.extend_from_slice(&(key_interner.list.len() as u32).to_le_bytes());
    for k in &key_interner.list {
        out.extend_from_slice(&(k.len() as u32).to_le_bytes());
        out.extend_from_slice(k.as_bytes());
    }
    out.extend_from_slice(&(type_interner.list.len() as u32).to_le_bytes());
    for t in &type_interner.list {
        out.extend_from_slice(&(t.len() as u32).to_le_bytes());
        out.extend_from_slice(t.as_bytes());
    }

    // Pass 2: items + back-patched index.
    out.extend_from_slice(&(values.len() as u32).to_le_bytes());
    let index_at = out.len();
    out.extend(std::iter::repeat(0u8).take(values.len() * 8));
    for (i, v) in values.iter().enumerate() {
        let off = out.len() as u32;
        write_typed_value(&mut out, v, &key_interner, &type_interner);
        let len = out.len() as u32 - off;
        out[index_at + i * 8..index_at + i * 8 + 4].copy_from_slice(&off.to_le_bytes());
        out[index_at + i * 8 + 4..index_at + i * 8 + 8].copy_from_slice(&len.to_le_bytes());
    }
    out
}

fn write_str(out: &mut Vec<u8>, s: &str) {
    out.extend_from_slice(&(s.len() as u32).to_le_bytes());
    out.extend_from_slice(s.as_bytes());
}

fn write_typed_value(
    out: &mut Vec<u8>,
    v: &Value,
    key_interner: &Interner,
    type_interner: &Interner,
) {
    match v {
        Value::Object(m) => {
            let type_id = m
                .get("type")
                .and_then(|t| t.as_str())
                .and_then(|t| type_interner.ids.get(t).copied());
            match type_id {
                Some(tid) => {
                    out.push(8);
                    out.extend_from_slice(&tid.to_le_bytes());
                    out.extend_from_slice(&((m.len().saturating_sub(1)) as u32).to_le_bytes());
                    for (k, val) in m {
                        if k == "type" { continue; }
                        out.extend_from_slice(&key_interner.ids[k].to_le_bytes());
                        write_typed_value(out, val, key_interner, type_interner);
                    }
                }
                None => {
                    out.push(0);
                    out.extend_from_slice(&(m.len() as u32).to_le_bytes());
                    for (k, val) in m {
                        out.extend_from_slice(&key_interner.ids[k].to_le_bytes());
                        write_typed_value(out, val, key_interner, type_interner);
                    }
                }
            }
        }
        Value::Array(a) => {
            out.push(1);
            out.extend_from_slice(&(a.len() as u32).to_le_bytes());
            for val in a { write_typed_value(out, val, key_interner, type_interner); }
        }
        Value::String(s) => { out.push(2); write_str(out, s); }
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                out.push(7);
                out.extend_from_slice(&i.to_le_bytes());
            } else {
                out.push(3);
                out.extend_from_slice(&n.as_f64().unwrap_or(0.0).to_le_bytes());
            }
        }
        Value::Bool(true) => out.push(4),
        Value::Bool(false) => out.push(5),
        Value::Null => out.push(6),
    }
}

/// Release a binary batch buffer returned by `oxc_parse_batch_bin`.
/// The allocation is `[len u32][blob][0]`; pass the pointer and the BLOB
/// length (the reader reads len from the prefix).
#[no_mangle]
pub extern "C" fn oxc_free_bin(ptr: *mut u8, blob_len: u32) {
    if ptr.is_null() {
        return;
    }
    let total = blob_len as usize + 5;
    unsafe {
        drop(Vec::from_raw_parts(ptr, total, total));
    }
}

/// Release a JSON string previously returned by `oxc_parse`.
#[no_mangle]
pub extern "C" fn oxc_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe { drop(CString::from_raw(ptr)) };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bin_batch_layout() {
        let payloads = vec![
            br#"{"ok":true,"program":{"type":"Program","start":0,"end":12,"body":[],"sourceType":"module"},"comments":[],"diagnostics":[]}"#
                .to_vec(),
        ];
        let blob = encode_bin_batch(&payloads);
        // header: magic + keyCount + keys + typeCount + types + itemCount + index
        let rd = |p: usize| -> u32 {
            u32::from_le_bytes([blob[p], blob[p + 1], blob[p + 2], blob[p + 3]])
        };
        assert_eq!(rd(0), 0x4F584232);
        let kc = rd(4) as usize;
        let mut p = 8;
        for _ in 0..kc {
            p += 4 + rd(p) as usize;
        }
        let tc = rd(p) as usize;
        p += 4;
        for _ in 0..tc {
            p += 4 + rd(p) as usize;
        }
        let ic = rd(p) as usize;
        p += 4;
        assert_eq!(ic, 1);
        let off = rd(p) as usize;
        let len = rd(p + 4) as usize;
        assert_eq!(off + len, blob.len(), "item must end at buffer end");
        // item root: plain obj (payload root has no "type"), count = 5 pairs
        assert_eq!(blob[off], 0);
        assert_eq!(rd(off + 1), 4); // ok/program/comments/diagnostics
        // first pair key should be interned id of one of the five root keys
        let first_key = rd(off + 5);
        assert!((first_key as usize) < kc);
    }
}
