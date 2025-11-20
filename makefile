.PHONY: run build-js build-core build-ts build-swc clean-native test all debug ts



# English comments per ~/REPO rule.
# Build tree-sitter TypeScript/TSX grammars into dynamic libraries for macOS (.dylib)
# and Linux-style naming (.so). On macOS, the .so output will be a Mach-O dylib
# with a .so filename. For true Linux .so, run these commands on a Linux host.


TS_HEADERS :=
TS_SRC_DIR :=
TSX_SRC_DIR :=
JS_SRC_DIR :=
OUT_DIR := lib/native
CORE_OUT := $(OUT_DIR)/libtree-sitter
CORE_SRCS :=

build-ts:
	@echo "Tree-sitter build disabled (SWC in use)"

# .PHONY: build-js
# Build tree-sitter JavaScript grammar (.dylib/.so) into lib/native
build-js:
	@echo "Tree-sitter build disabled (SWC in use)"

# Build core tree-sitter library into lib/native as libtree-sitter.dylib and .so
# This provides the C API (ts_parser_*, ts_tree_*, ts_node_*) for Dart FFI.
build-core:
	mkdir -p $(OUT_DIR)
	# macOS dylib
	@if [ -n "$(CORE_SRCS)" ]; then \
		cc -O3 -fPIC -I $(TS_HEADERS) -dynamiclib $(CORE_SRCS) -o $(CORE_OUT).dylib; \
	else \
		echo "tree-sitter core build disabled (SWC in use)"; \
	fi
	# macOS-compatible .so filename (Mach-O dylib with .so suffix)
	@if [ -n "$(CORE_SRCS)" ]; then \
		cc -O3 -fPIC -I $(TS_HEADERS) -shared $(CORE_SRCS) -o $(CORE_OUT).so; \
	else \
		echo "tree-sitter core build disabled (SWC in use)"; \
	fi

clean-native:
	rm -f $(OUT_DIR)/libswc_ffi.dylib \
		$(OUT_DIR)/libswc_ffi.so

test: 
	dart test -r expanded
run:
	dart run ./vue_dart.dart

build-swc:
	mkdir -p $(OUT_DIR)
	cd native/swc_ffi && cargo build --release
	cp native/swc_ffi/target/release/libswc_ffi.dylib $(OUT_DIR)/libswc_ffi.dylib || true
	cp native/swc_ffi/target/release/libswc_ffi.so $(OUT_DIR)/libswc_ffi.so || true

all:
	make build-swc && make 

debug:
	dart run ./vue_compiler.dart && prettier --write vue_complex_dart.ts && cat vue_complex_dart.ts

ts:
	bun run ./vue_compiler.ts && prettier --write vue_complex_official.ts && cat vue_complex_official.ts