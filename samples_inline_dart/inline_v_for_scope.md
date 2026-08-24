# inline_v_for_scope

```
import { renderList as _renderList, Fragment as _Fragment, openBlock as _openBlock, createElementBlock as _createElementBlock, toDisplayString as _toDisplayString } from "vue"

import { ref } from 'vue'

export default {
  __name: 'inline_v_for_scope',
  setup(__props) {

const list = ref([1, 2])

return (_ctx, _cache) => {
  return (_openBlock(), _createElementBlock("ul", null, [
    (_openBlock(true), _createElementBlock(_Fragment, null, _renderList(list.value, (item, i) => {
      return (_openBlock(), _createElementBlock("li", { key: i }, _toDisplayString(item) + " " + _toDisplayString(i), 1 /* TEXT */))
    }), 128 /* KEYED_FRAGMENT */))
  ]))
}
}

}
```

BINDINGS: {"ref":"setup-const","list":"setup-ref"}
