# variables_basic

```ts
export default {
  __name: "variables_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const a = 1;
    const b = true;

    const __returned__ = { a, b };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
};
```
