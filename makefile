.PHONY: run build-worker test bun all samples debug

# English comments per ~/REPO rule.
# TS parsing backend: oxc cdylib (see OXC_REFERENCE.md). The tree-sitter
# build targets were removed in Phase 4.

OUT_DIR := lib/native

# Build the oxc parser cdylib into lib/native. Requires Rust >= 1.95.
# The .so copy follows the macOS dual-suffix convention (Mach-O renamed).
build-worker:
	mkdir -p $(OUT_DIR)
	cd worker/oxc_ts && cargo build --release
	cp worker/oxc_ts/target/release/liboxc_ts.dylib $(OUT_DIR)/
	cp $(OUT_DIR)/liboxc_ts.dylib $(OUT_DIR)/liboxc_ts.so

test: 
	dart test -r expanded
samples:
	bun run ./vue_samples.ts
bun:
	rm -rf samples
	bun run ./vue.ts && prettier samples/*.md -w
run:
	rm -rf samples_dart
	dart run ./vue_dart.dart && prettier samples_dart/*.md -w

all:
	make bun && make run
debug:
	bun run ./vue_compiler.ts
	dart run ./vue_compiler.dart	
