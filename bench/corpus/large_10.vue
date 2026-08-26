<script setup lang="ts">
import { ref } from 'vue'
const locked = false
function onPick(e: unknown, m: number) { console.log(e, m) }
const groups = Array.from({ length: 10 }, (_, m) =>
  ({ rows: [{ id: m, name: "n", kind: "a", cfg: {} }] }))
const visible0 = ref<boolean>(true);
const visible1 = ref<boolean>(false);
const visible2 = ref<boolean>(true);
const visible3 = ref<boolean>(false);
const visible4 = ref<boolean>(true);
const visible5 = ref<boolean>(false);
const visible6 = ref<boolean>(true);
const visible7 = ref<boolean>(false);
const visible8 = ref<boolean>(true);
const visible9 = ref<boolean>(false);
const visible10 = ref<boolean>(true);
const visible11 = ref<boolean>(false);
const visible12 = ref<boolean>(true);
const visible13 = ref<boolean>(false);
const visible14 = ref<boolean>(true);
const visible15 = ref<boolean>(false);
const visible16 = ref<boolean>(true);
const visible17 = ref<boolean>(false);
const visible18 = ref<boolean>(true);
const visible19 = ref<boolean>(false);
const visible20 = ref<boolean>(true);
const visible21 = ref<boolean>(false);
const visible22 = ref<boolean>(true);
const visible23 = ref<boolean>(false);
const visible24 = ref<boolean>(true);
const visible25 = ref<boolean>(false);
const visible26 = ref<boolean>(true);
const visible27 = ref<boolean>(false);
const visible28 = ref<boolean>(true);
const visible29 = ref<boolean>(false);
const visible30 = ref<boolean>(true);
const visible31 = ref<boolean>(false);
const visible32 = ref<boolean>(true);
const visible33 = ref<boolean>(false);
const visible34 = ref<boolean>(true);
const visible35 = ref<boolean>(false);
const visible36 = ref<boolean>(true);
const visible37 = ref<boolean>(false);
const visible38 = ref<boolean>(true);
const visible39 = ref<boolean>(false);
</script>
<template>
<form>
  <fieldset v-if="visible0">
    <legend>group 0</legend>
    <label v-for="(row, ri) in groups[0].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[0].cfg" @change="onPick($event, 0)"/>
  </fieldset>
  <fieldset v-if="visible1">
    <legend>group 1</legend>
    <label v-for="(row, ri) in groups[1].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[1].cfg" @change="onPick($event, 1)"/>
  </fieldset>
  <fieldset v-if="visible2">
    <legend>group 2</legend>
    <label v-for="(row, ri) in groups[2].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[2].cfg" @change="onPick($event, 2)"/>
  </fieldset>
  <fieldset v-if="visible3">
    <legend>group 3</legend>
    <label v-for="(row, ri) in groups[3].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[3].cfg" @change="onPick($event, 3)"/>
  </fieldset>
  <fieldset v-if="visible4">
    <legend>group 4</legend>
    <label v-for="(row, ri) in groups[4].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[4].cfg" @change="onPick($event, 4)"/>
  </fieldset>
  <fieldset v-if="visible5">
    <legend>group 5</legend>
    <label v-for="(row, ri) in groups[5].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[5].cfg" @change="onPick($event, 5)"/>
  </fieldset>
  <fieldset v-if="visible6">
    <legend>group 6</legend>
    <label v-for="(row, ri) in groups[6].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[6].cfg" @change="onPick($event, 6)"/>
  </fieldset>
  <fieldset v-if="visible7">
    <legend>group 7</legend>
    <label v-for="(row, ri) in groups[7].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[7].cfg" @change="onPick($event, 7)"/>
  </fieldset>
  <fieldset v-if="visible8">
    <legend>group 8</legend>
    <label v-for="(row, ri) in groups[8].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[8].cfg" @change="onPick($event, 8)"/>
  </fieldset>
  <fieldset v-if="visible9">
    <legend>group 9</legend>
    <label v-for="(row, ri) in groups[9].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[9].cfg" @change="onPick($event, 9)"/>
  </fieldset>
</form>
</template>
<style scoped>
.g0 > label:nth-child(2n) { color: #000 }
.g1 > label:nth-child(2n) { color: #111 }
.g2 > label:nth-child(2n) { color: #222 }
.g3 > label:nth-child(2n) { color: #333 }
.g4 > label:nth-child(2n) { color: #444 }
.g5 > label:nth-child(2n) { color: #555 }
.g6 > label:nth-child(2n) { color: #666 }
.g7 > label:nth-child(2n) { color: #777 }
.g8 > label:nth-child(2n) { color: #888 }
.g9 > label:nth-child(2n) { color: #999 }
.g10 > label:nth-child(2n) { color: #101010 }
.g11 > label:nth-child(2n) { color: #111111 }
.g12 > label:nth-child(2n) { color: #121212 }
.g13 > label:nth-child(2n) { color: #131313 }
.g14 > label:nth-child(2n) { color: #141414 }
.g15 > label:nth-child(2n) { color: #151515 }
.g16 > label:nth-child(2n) { color: #161616 }
.g17 > label:nth-child(2n) { color: #171717 }
.g18 > label:nth-child(2n) { color: #181818 }
.g19 > label:nth-child(2n) { color: #191919 }
</style>
