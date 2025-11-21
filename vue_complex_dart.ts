import {
  defineComponent as _defineComponent,
  mergeModels as _mergeModels,
  useModel as _useModel,
} from "vue";
import {
  ref,
  reactive,
  computed,
  watch,
  watchEffect,
  onMounted,
  provide,
  inject,
  nextTick,
  defineAsyncComponent,
  useSlots,
  useAttrs,
  unref as _unref,
} from "vue";
import { createApp } from "vue";
import * as vue from "vue";
import hello from "world";
const __default__ = {
  name: "TestComplextComponent",
  //@ts-ignore
  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
};
export default /*@__PURE__*/ _defineComponent({
  ...__default__,
  ...{ name: "VueComplex", inheritAttrs: false },
  props: _mergeModels(
    {
      title: { type: String, required: true, default: "Helloworld" },
      count: { type: Number, required: false, default: 0 },
      items: { type: Array, required: true, default: () => [] },
      config: { type: String, required: false },
    },
    { modelValue: { type: Object }, modelValue: { type: Object } },
  ),

  emits: _mergeModels([], ["update:modelValue"]),

  setup(__props: any, { expose: __expose, emit: __emit }) {
    function hellow() {}
    const world = () => {};
    const world2 = function () {};
    const world3 = function named() {};
    const abc: number = 123;
    const abcd = 123,
      cde = 234;
    const abcd = 123,
      cde = 234;
    const $props = __props;

    const $emitter = __emit;

    const attrs = useAttrs();
    const $slots = useSlots();
    const de = $slots.default;
    const state = reactive({
      selectedId: null as number | null,
      loading: false,
    });
    const doubled = computed(() => (valueModel.value ?? 0) * 2);
    function onIncrement() {
      const by = 1;
      $emitter("increment", by);
      $emitter("update:count", ($props.count ?? 0) + by);
    }
    function onSelect(id: number) {
      state.selectedId = id;
      $emitter("select", id);
    }
    onMounted(async () => {
      state.loading = true;
      await nextTick();
      state.loading = false;
    });
    provide("theme", $props.config?.theme ?? "light");
    const injectedTheme = inject<string>("theme", "light");
    const AsyncChild = defineAsyncComponent(async () => {
      return {
        template: "<div>Async Child</div>",
      } as any;
    });
    const __returned__ = {
      hellow,
      world,
      world2,
      world3,
      abc,
      abcd,
      cde,
      $props,
      $emitter,
      valueModel,
      checked,
      model,
      header,
      attrs,
      $slots,
      de,
      state,
      doubled,
      onIncrement,
      onSelect,
      injectedTheme,
      AsyncChild,
    };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });

    return __returned__;
  },
});
