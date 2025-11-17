# variables_let

```
export default {
  __name: 'variables_let',
  setup(__props, { expose: __expose }) {
  __expose();

let a = 1

const __returned__ = { get a() { return a }, set a(v) { a = v } }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```
