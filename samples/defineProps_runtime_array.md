# defineProps_runtime_array

```
export default {
  __name: 'defineProps_runtime_array',
  props: ['msg','count'],
  setup(__props, { expose: __expose }) {
  __expose();

const props = __props

const __returned__ = { props }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

