import { defineComponent as _defineComponent } from "vue";
type FnParams = {
  fn?: () => void;
  fn1?: (param1: any) => void;
  fn2?: (param2: any) => void;
  fn3?: (param2: any) => void;
  fn4?: (p1: any[], p2: any) => void;
};

export default /*@__PURE__*/ _defineComponent({
  ...{ name: "hello world", mounted(a, [b], { c }) {} },
  __name: "vue_complex",
  setup(__props, { expose: __expose }) {
    __expose();

    const object = {
      world: "world",
      fn1() {},
      fn2: () => {},
      fn3(param1: any) {},
      fn4(param1: any, ...more: any) {},
    };

    const fnexp = function hello() {
      return 1;
    };

    function fn(param: FnParams) {}
    fn({ fn: () => {}, fn1() {}, fn2([a]) {}, fn4([], {}) {} });
    fn({ fn() {}, fn1(param1) {}, fn2: function fn3() {}, fn3: () => {} });
    // fn({ fn() {}, fn1(param1) {}, fn2: function fn3() {}, fn3: () => {} });

    // defineModel("hello");
    // const props = defineProps({
    //   prop1: Number,
    // });
    // const text = defineModel<string>("text");
    // const req = defineModel<string>({ required: true, default: "hi" });
    // const title = defineModel<string>("title");
    // const count = defineModel<number>("count", { default: 0 });
    // const [cap, capMod] = defineModel<string, "capitalize">("cap", {
    //   set(v) {
    //     return capMod.capitalize ? v.charAt(0).toUpperCase() + v.slice(1) : v;
    //   },
    // });
    // const [tc, tcMod] = defineModel<string, "trim" | "capitalize">("tc", {
    //   set(v) {
    //     let s = tcMod.trim ? v.trim() : v;
    //     return tcMod.capitalize ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    //   },
    // });
    // //@ts-ignore
    // const [num, numModifer] = defineModel<number, "add">("num", {
    //   default: 1,
    //   set(v) {
    //     return numModifer.add ? v + 1 : v;
    //   },
    //   get(v) {
    //     return numModifer.add ? v - 1 : v;
    //   },
    // });

    const __returned__ = { object, fnexp, fn };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
