# tmpl_err_side_effect_tag

```
import { openBlock as _openBlock, createElementBlock as _createElementBlock } from "vue"

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, "d"))
}
```
ERRORS: SyntaxError: Tags with side effect (<script> and <style>) are ignored in client component templates.
