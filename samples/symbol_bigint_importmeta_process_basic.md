# symbol_bigint_importmeta_process_basic

```
export default {
  __name: 'symbol_bigint_importmeta_process_basic',
  setup(__props, { expose: __expose }) {
  __expose();

const S = Symbol('k')
const big = 1n
const env = import.meta.env
const nodeEnv = process.env.NODE_ENV

const __returned__ = { S, big, env, nodeEnv }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```

