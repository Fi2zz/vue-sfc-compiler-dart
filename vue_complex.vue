<!-- <script setup lang="ts">
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

// withDefaults();
// withDefaults(defineModel)
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
// defineModel();

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

// defineExpose();
const AsyncChild = defineAsyncComponent(async () => {
  return {
    template: "<div>Async Child</div>",
  } as any;
});

// export const ab = 1;
</script>

<script lang="ts">
const array = [];

const object = {
  hello: "world",
};
const optionComponent = {
  name: "TestComplextComponent",
  //@ts-ignore
  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
  computed: {
    get a() {
      return 1;
    },
    set a(value) {
      //@ts-ignore
      this.c = value;
    },
  },
};
export default optionComponent;
export const a = 1;
var abc = a;
export * from "vue";
export interface ix {}
export type xt = string;
export function xfn() {}
export enum A {}
export var b = A;
export let d = abc;
export class D {
  d = abc;
}
export * as vue from "vue";
import { createApp } from "vue";
//@ts-ignore
import * as vue from "vue";
//@ts-ignore
import hello from "world";
const script = {
  name: "TestComplextComponent",
  //@ts-ignore
  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
};
// export default ;
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
</style> -->

<!-- NewModelDemo.vue -->
<!-- <template>
  <fieldset>
    <legend>1. 最简 v-model</legend>
    <input v-model="text" />
    <span>{{ text }}</span>
  </fieldset>

  <fieldset>
    <legend>2. 必填 + 默认值</legend>
    <input v-model="req" />
    <span>{{ req }}</span>
  </fieldset>

  <fieldset>
    <legend>3. 多个 v-model（title / count）</legend>
    <input v-model="title" />
    <button @click="count++">+</button>
    <span>{{ title }} | {{ count }}</span>
  </fieldset>

  <fieldset>
    <legend>4. 修饰符 capitalize</legend>
    <input v-model.capitalize="cap" />
    <span>{{ cap }}</span>
  </fieldset>

  <fieldset>
    <legend>5. 组合修饰符 trim+capitalize</legend>
    <input v-model.trim.capitalize="tc" />
    <span>{{ tc }}</span>
  </fieldset>

  <fieldset>
    <legend>6. 数字修饰符 add</legend>
    <button @click="num++">子内+1</button>
    <span>{{ num }}（父级=子级-1）</span>
  </fieldset>
</template> -->

<script setup lang="ts">
const object = {
  world: "world",
  fn1() {},
  fn2: () => {},
  fn3(param1: any) {},
  fn4(param1: any, ...more: any) {},
};

function fnDeclartion() {}

type FnParams = {
  fn?: () => void;
  fn1?: (param1: any) => void;
  fn2?: (param2: any) => void;
  fn3?: (param2: any) => void;
  fn4?: (p1: any[], p2: any) => void;
};

const fnexp = function hello() {
  return 1;
};

function fn(param: FnParams) {}
fn({ fn: () => {}, fn1() {}, fn2([a]) {}, fn4([], {}) {} });
fn({ fn() {}, fn1(param1) {}, fn2: function fn3() {}, fn3: () => {} });
// fn({ fn() {}, fn1(param1) {}, fn2: function fn3() {}, fn3: () => {} });
defineOptions({ name: "hello world", mounted(a, [b], { c }) {} });
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
</script>
