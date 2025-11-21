<script setup lang="ts">
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

// import * as bug from "vue";
//@ts-ignore
// import vue from "vue";
function hellow() {}

const world = () => {};
const world2 = function () {};
const world3 = function named() {};
// export { hellow };

defineOptions({ name: "VueComplex", inheritAttrs: false });

const abc: number = 123;
const abcd = 123,
  cde = 234;
type Item = { id: number; label: string };

// const [items = [], config = "dark"] = defineProps<{
//   title: string;
//   count?: number;
//   items: Item[];
//   config?: { theme: "light" | "dark" };
// }>();

const $props = withDefaults(
  defineProps<{
    title: string;
    count?: number;
    items: Item[];
    config?: { theme: "light" | "dark" };
  }>(),
  { items: () => [], count: 0, title: "Helloworld" }
);

const $emitter = defineEmits<{
  (e: "increment", by: number): void;
  (e: "select", id: number): void;
  (e: "update:count", value: number): void;
}>();
//@ts-ignore
const valueModel = defineModel<number>("value", { default: 0 });
//@ts-ignore
const checked = defineModel<boolean>("cheched", { default: false });
const [model, modelModifiers] = defineModel("hello", {
  type: String,
  default: "helloworld",
});
// defineSlots();
defineModel();

const {
  header,
  default: defaultSlot = () => {},
  footer,
} = defineSlots<{
  header?(props: { title: string }): any;
  default(props: { items: Item[]; selectedId: number | null }): any;
  footer?(): any;
}>();

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
// defineExpose({
//   focus: () => {},
//   reset: () => {
//     state.selectedId = null;
//   },
// });

defineExpose();
const AsyncChild = defineAsyncComponent(async () => {
  return {
    template: "<div>Async Child</div>",
  } as any;
});
</script>

<script lang="ts">
export const a = 1;

import { createApp } from "vue";
//@ts-ignore
import * as vue from "vue";
//@ts-ignore
import hello from "world";
// export default {};
export default {
  name: "TestComplextComponent",
  //@ts-ignore
  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
};
</script>

<template>
  <div class="complex" :data-theme="injectedTheme">
    <header v-if="$slots.header">
      <slot name="header" :title="$props.title" />
    </header>
    <h1>{{ $props.title }}</h1>
    <p v-if="state.loading">Loading...</p>
    <p>Value: {{ valueModel }}</p>
    <p>Doubled: {{ doubled }}</p>
    <button type="button" @click="onIncrement">Increment</button>
    <ul>
      <li v-for="it in $props.items" :key="it.id">
        <label>
          <input
            type="radio"
            :value="it.id"
            v-model="state.selectedId"
            @change="onSelect(it.id)" />
          {{ it.label }}
        </label>
      </li>
    </ul>
    <slot :items="$props.items" :selected-id="state.selectedId" />
    <AsyncChild />
    <footer v-if="$slots.footer">
      <slot name="footer" />
    </footer>
    <pre v-bind="attrs"></pre>
  </div>
</template>

<style scoped>
.complex {
  display: grid;
  gap: 0.5rem;
}
.complex[data-theme="dark"] {
  background: #111;
  color: #eee;
}
.complex[data-theme="light"] {
  background: #fff;
  color: #222;
}
</style>
