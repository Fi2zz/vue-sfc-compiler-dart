<script setup lang="ts">
import { computed, defineProps, ref } from "vue";
type PropType = string;
type Props = { msg: PropType };
const props = defineProps<Props>();
defineOptions({ inheritAttrs: false });
function world() {}
const msg = computed(() => props.msg);
const emit = defineEmits({
  click: (event: MouseEvent) => void 0,
  "update:modelValue": (value: PropType) => true,
});
const refvalue = ref("hello");
const model = defineModel();
const visible = defineModel("visible", { type: Boolean, default: false });
const onClick = (event: MouseEvent) => emit("click", event);
defineExpose({ msg });
const slots = defineSlots<{ default: (props: { msg: PropType }) => void }>();

console.log(slots.default);
</script>
<template>
  <div class="hello"></div>
  <h1>{{ msg }}</h1>
  <textarea />
  <input v-model="msg" />

  <textarea v-bind:model-value="msg"></textarea>
  <template v-for="item in msg">
    <div>{{ item }} &</div>
  </template>
</template>

<style lang="scss">
div {
  width: 100%;
}
</style>
<!-- <script lang="ts">
export default {
  inheritAttrs: false,
};
</script> -->
