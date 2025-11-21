# script_and_script_setup_props_emits

```
const __default__ = {
  props: {
    title: String,
    count: {
      type: Number,
      default: 0
    }
  },
  emits: ['update', 'delete']
}

export default /*@__PURE__*/Object.assign(__default__, {
  __name: 'script_and_script_setup_props_emits',
  props: ['title', 'count'],
  emits: ['update', 'delete'],
  setup(__props, { expose: __expose, emit: __emit }) {
  __expose();

const props = __props
const emit = __emit

const __returned__ = { props, emit }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

})
```

