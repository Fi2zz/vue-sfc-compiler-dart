## Changelog – AST-driven imports and output alignment

Date: 2025-11-17

Highlights:
- Replace regex-based import collection with AST traversal for `<script setup>` and normal `<script>`.
- Preserve user imports verbatim; remove runtime API auto-injection and import reordering.
- Emit Vue runtime API imports as a multi-line block derived from setup source imports, ordered to match official compiler style.
- Align error output with official format, including accurate coordinates and code frames.
- Introduce safe UTF-8 slicing for AST byte offsets to avoid multi-byte truncation.
- Ensure `vue_complex` compiled output matches official import structure.

Files impacted:
- `lib/sfc_compile_script.dart`: AST import collection for setup and normal script; error validation uses AST; safe slicing.
- `lib/sfc_script_codegen.dart`: header alias imports single-line; merge and order Vue runtime API import names from setup; output user imports verbatim; safe slicing.
- Auxiliary parsing utilities added within codegen for name extraction and ordering.

Verification:
- `make all` passes; samples show imports and error messages aligned with official outputs, including `vue_complex_*`.
