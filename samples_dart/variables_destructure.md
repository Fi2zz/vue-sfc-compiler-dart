# variables_destructure

```
{  __name: 'variables_destructure',
setup(__props, { expose: __expose }) {
  __expose();
const { x, ok = true } = { x: 1, ok: true }
const __returned__ = { x }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}
```
