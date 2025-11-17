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
} from "vue";

defineOptions({ name: "VueComplex", inheritAttrs: false });

type Item = { id: number; label: string };

const $props = withDefaults(
  defineProps<{
    title: string;
    count?: number;
    items: Item[];
    config?: { theme: "light" | "dark" };
  }>(),
  { items: () => [] }
);

const myemit = defineEmits<{
  (e: "increment", by: number): void;
  (e: "select", id: number): void;
  (e: "update:count", value: number): void;
}>();

const valueModel = defineModel<number>("value", { default: 0 });
const checked = defineModel<boolean>("cheched", { default: false });

const modelValue = defineModel({ type: String, default: "helloworld" });

defineSlots<{
  header?(props: { title: string }): any;
  default(props: { items: Item[]; selectedId: number | null }): any;
  footer?(): any;
}>();

const attrs = useAttrs();
const slots = useSlots();

const state = reactive({
  selectedId: null as number | null,
  loading: false,
});

const doubled = computed(() => (valueModel.value ?? 0) * 2);

function increment() {
  const by = 1;
  myemit("increment", by);
  myemit("update:count", ($props.count ?? 0) + by);
}

function select(id: number) {
  state.selectedId = id;
  myemit("select", id);
}

onMounted(async () => {
  state.loading = true;
  await nextTick();
  state.loading = false;
});

provide("theme", $props.config?.theme ?? "light");
const injectedTheme = inject<string>("theme", "light");

defineExpose({
  focus: () => {},
  reset: () => {
    state.selectedId = null;
  },
});

const AsyncChild = defineAsyncComponent(async () => {
  return {
    template: "<div>Async Child</div>",
  } as any;
});
</script>
<script lang="ts">
import { createApp } from "vue";
import * as vue from "vue";
import hello from "world";
// export default {};
export default {
  name: "TestComplextComponent",

  data(vm) {
    return { world: "hello" };
  },
  mounted() {},
  methods: {},
};
</script>

<template>
  <div class="complex" :data-theme="injectedTheme">
    <header v-if="slots.header">
      <slot name="header" :title="$props.title" />
    </header>
    <h1>{{ $props.title }}</h1>
    <p v-if="state.loading">Loading...</p>
    <p>Value: {{ valueModel }}</p>
    <p>Doubled: {{ doubled }}</p>
    <button type="button" @click="increment">Increment</button>
    <ul>
      <li v-for="it in $props.items" :key="it.id">
        <label>
          <input
            type="radio"
            :value="it.id"
            v-model="state.selectedId"
            @change="select(it.id)" />
          {{ it.label }}
        </label>
      </li>
    </ul>
    <slot :items="$props.items" :selected-id="state.selectedId" />
    <AsyncChild />
    <footer v-if="slots.footer">
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
