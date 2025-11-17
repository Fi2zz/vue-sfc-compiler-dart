.PHONY: run build-js build-core build-ts clean-native test bun all samples debug



# English comments per ~/REPO rule.
# Build tree-sitter TypeScript/TSX grammars into dynamic libraries for macOS (.dylib)
# and Linux-style naming (.so). On macOS, the .so output will be a Mach-O dylib
# with a .so filename. For true Linux .so, run these commands on a Linux host.


TS_HEADERS := node_modules/tree-sitter-javascript/src/tree_sitter
TS_SRC_DIR := node_modules/tree-sitter-typescript/typescript/src
TSX_SRC_DIR := node_modules/tree-sitter-typescript/tsx/src
JS_SRC_DIR := node_modules/tree-sitter-javascript/src
OUT_DIR := lib/native
CORE_OUT := $(OUT_DIR)/libtree-sitter
CORE_SRCS :=

build-ts:
	mkdir -p $(OUT_DIR)
	# Build TypeScript dylib
	cc -O3 -fPIC -I $(TS_HEADERS) -dynamiclib \
		-I $(TS_SRC_DIR) \
		$(TS_SRC_DIR)/parser.c $(TS_SRC_DIR)/scanner.c \
		-o $(OUT_DIR)/tree-sitter-typescript.dylib
	# Build TypeScript so (macOS-compatible .so filename)
	cc -O3 -fPIC -I $(TS_HEADERS) -shared \
		-I $(TS_SRC_DIR) \
		$(TS_SRC_DIR)/parser.c $(TS_SRC_DIR)/scanner.c \
		-o $(OUT_DIR)/tree-sitter-typescript.so
	# Build TSX dylib
	cc -O3 -fPIC -I $(TS_HEADERS) -dynamiclib \
		-I $(TSX_SRC_DIR) \
		$(TSX_SRC_DIR)/parser.c $(TSX_SRC_DIR)/scanner.c \
		-o $(OUT_DIR)/tree-sitter-tsx.dylib
	# Build TSX so (macOS-compatible .so filename)
	cc -O3 -fPIC -I $(TS_HEADERS) -shared \
		-I $(TSX_SRC_DIR) \
		$(TSX_SRC_DIR)/parser.c $(TSX_SRC_DIR)/scanner.c \
		-o $(OUT_DIR)/tree-sitter-tsx.so

# .PHONY: build-js
# Build tree-sitter JavaScript grammar (.dylib/.so) into lib/native
build-js:
	mkdir -p $(OUT_DIR)
	# Build JavaScript dylib
	cc -O3 -fPIC -I $(TS_HEADERS) -dynamiclib \
		-I $(JS_SRC_DIR) \
		$(JS_SRC_DIR)/parser.c $(JS_SRC_DIR)/scanner.c \
		-o $(OUT_DIR)/tree-sitter-javascript.dylib
	# Build JavaScript so (macOS-compatible .so filename)
	cc -O3 -fPIC -I $(TS_HEADERS) -shared \
		-I $(JS_SRC_DIR) \
		$(JS_SRC_DIR)/parser.c $(JS_SRC_DIR)/scanner.c \
		-o $(OUT_DIR)/tree-sitter-javascript.so

# Build core tree-sitter library into lib/native as libtree-sitter.dylib and .so
# This provides the C API (ts_parser_*, ts_tree_*, ts_node_*) for Dart FFI.
build-core:
	mkdir -p $(OUT_DIR)
	# macOS dylib
	@if [ -n "$(CORE_SRCS)" ]; then \
		cc -O3 -fPIC -I $(TS_HEADERS) -dynamiclib $(CORE_SRCS) -o $(CORE_OUT).dylib; \
	else \
		echo "tree-sitter core sources not found; install core or use Homebrew libtree-sitter"; \
	fi
	# macOS-compatible .so filename (Mach-O dylib with .so suffix)
	@if [ -n "$(CORE_SRCS)" ]; then \
		cc -O3 -fPIC -I $(TS_HEADERS) -shared $(CORE_SRCS) -o $(CORE_OUT).so; \
	else \
		echo "tree-sitter core sources not found; install core or use Homebrew libtree-sitter"; \
	fi

clean-native:
	rm -f $(OUT_DIR)/tree-sitter-typescript.dylib \
		$(OUT_DIR)/tree-sitter-typescript.so \
		$(OUT_DIR)/tree-sitter-tsx.dylib \
		$(OUT_DIR)/tree-sitter-tsx.so \
		$(OUT_DIR)/tree-sitter-javascript.dylib \
		$(OUT_DIR)/tree-sitter-javascript.so \
		$(CORE_OUT).dylib \
		$(CORE_OUT).so

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