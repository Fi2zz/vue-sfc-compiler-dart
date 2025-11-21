# class_private_field_basic

```
{  __name: 'class_private_field_basic',
setup(__props, { expose: __expose }) {
  __expose();
class Y { #a = 1 }
const y = new Y()
const __returned__ = { Y, y }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__}
```
