import { defineComponent as _defineComponent } from "vue";
export default /*@__PURE__*/ _defineComponent({
  ...{ name: "hello world", mounted(a, [b], { c }) {} },
  setup(__props: any, { expose: __expose }) {
    __expose();
    const object = {
      world: "world",
      fn1() {},
      fn2: () => {},
      fn3(param1: any) {},
      fn4(param1: any, ...more: any) {},
    };
    function fnDeclartion() {}
    const fnexp = function hello() {
      return 1;
    };
    function fn(param: FnParams) {}
    fn({ fn: () => {}, fn1() {}, fn2([a]) {}, fn4([], {}) {} });
    fn({ fn() {}, fn1(param1) {}, fn2: function fn3() {}, fn3: () => {} });
    const __returned__ = { object, fnexp };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });

    return __returned__;
  },
});
