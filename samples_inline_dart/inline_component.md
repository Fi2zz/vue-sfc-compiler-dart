# inline_component

```
import { openBlock as _openBlock, createBlock as _createBlock, createCommentVNode as _createCommentVNode, resolveComponent as _resolveComponent, createVNode as _createVNode, Fragment as _Fragment, createElementBlock as _createElementBlock } from "vue"

import MyComp from './MyComp.vue'
import { ref } from 'vue'

export default {
  __name: 'inline_component',
  setup(__props) {

const show = ref(true)

return (_ctx, _cache) => {
  const _component_other_one = _resolveComponent("other-one")

  return (_openBlock(), _createElementBlock(_Fragment, null, [
    (show.value)
      ? (_openBlock(), _createBlock(MyComp, { key: 0 }))
      : _createCommentVNode("v-if", true),
    _createVNode(_component_other_one)
  ], 64 /* STABLE_FRAGMENT */))
}
}

}
```

BINDINGS: {"MyComp":"setup-const","ref":"setup-const","show":"setup-ref"}
