//! CLI twin of the cdylib: read source from stdin, print the same JSON
//! payload `oxc_parse` would return. Used for smoke tests without Dart.
//! Usage: oxc_ts [ts|tsx|js|jsx] < source

use std::io::Read;

fn lang_tag(name: &str) -> u32 {
    match name {
        "tsx" => 1,
        "js" => 2,
        "jsx" => 3,
        _ => 0,
    }
}

fn main() {
    let lang = std::env::args().nth(1).map_or(0, |a| lang_tag(&a));
    let mut source = String::new();
    if std::io::stdin().read_to_string(&mut source).is_err() {
        eprintln!("failed to read stdin");
        std::process::exit(1);
    }
    println!("{}", oxc_ts::parse_to_json(&source, lang));
}
