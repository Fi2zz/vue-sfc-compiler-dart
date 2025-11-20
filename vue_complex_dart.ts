import {
  defineComponent as _defineComponent,
  useModel as _useModel,
  mergeModels as _mergeModels,
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
} from "vue";
import { createApp } from "vue";
import * as vue from "vue";
import hello from "world";
type Item = { id: number; label: string };

export default /*@__PURE__*/ _defineComponent({
  ...{ name: "VueComplex", inheritAttrs: false },
  __name: "vue_complex",
  props: _mergeModels(
    {
      title: { type: String, required: true },
      count: { type: Number, required: false },
      items: { type: Array, required: true },
      config: { type: String, required: false },
    },
    {
      modelValue: { type: Object },
      modelValue: { type: Object },
      modelValue: { type: Object },
    },
  ),
  emits: _mergeModels([], ["update:modelValue"]),
  setup(__props: any, { expose: __expose, emit: __emit }) {
    function hellow() {}
    const abc: number = 123;
    const abcd = 123,
      cde = 234;
    const abcd = 123,
      cde = 234;
    const [items = [], config = "dark"] = __props;
    const $emitter = __emit;
    const de = slots.default;
    const attrs = useAttrs();
    const $slots = useSlots();
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
      abc,
      abcd,
      cde,
      items,
      $emitter,
      valueModel,
      checked,
      model,
      header,
      de,
      attrs,
      $slots,
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
