# topLevelAwait_basic

```
{  __name: 'topLevelAwait_basic',
setup(__props, { expose: __expose }) {
  __expose();
const res = await Promise.resolve(1)
const __returned__ = { res }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}
```
