<script setup lang="ts">
import { ref } from 'vue'
const locked = false
function onPick(e: unknown, m: number) { console.log(e, m) }
const groups = Array.from({ length: 50 }, (_, m) =>
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
const visible40 = ref<boolean>(true);
const visible41 = ref<boolean>(false);
const visible42 = ref<boolean>(true);
const visible43 = ref<boolean>(false);
const visible44 = ref<boolean>(true);
const visible45 = ref<boolean>(false);
const visible46 = ref<boolean>(true);
const visible47 = ref<boolean>(false);
const visible48 = ref<boolean>(true);
const visible49 = ref<boolean>(false);
const visible50 = ref<boolean>(true);
const visible51 = ref<boolean>(false);
const visible52 = ref<boolean>(true);
const visible53 = ref<boolean>(false);
const visible54 = ref<boolean>(true);
const visible55 = ref<boolean>(false);
const visible56 = ref<boolean>(true);
const visible57 = ref<boolean>(false);
const visible58 = ref<boolean>(true);
const visible59 = ref<boolean>(false);
const visible60 = ref<boolean>(true);
const visible61 = ref<boolean>(false);
const visible62 = ref<boolean>(true);
const visible63 = ref<boolean>(false);
const visible64 = ref<boolean>(true);
const visible65 = ref<boolean>(false);
const visible66 = ref<boolean>(true);
const visible67 = ref<boolean>(false);
const visible68 = ref<boolean>(true);
const visible69 = ref<boolean>(false);
const visible70 = ref<boolean>(true);
const visible71 = ref<boolean>(false);
const visible72 = ref<boolean>(true);
const visible73 = ref<boolean>(false);
const visible74 = ref<boolean>(true);
const visible75 = ref<boolean>(false);
const visible76 = ref<boolean>(true);
const visible77 = ref<boolean>(false);
const visible78 = ref<boolean>(true);
const visible79 = ref<boolean>(false);
const visible80 = ref<boolean>(true);
const visible81 = ref<boolean>(false);
const visible82 = ref<boolean>(true);
const visible83 = ref<boolean>(false);
const visible84 = ref<boolean>(true);
const visible85 = ref<boolean>(false);
const visible86 = ref<boolean>(true);
const visible87 = ref<boolean>(false);
const visible88 = ref<boolean>(true);
const visible89 = ref<boolean>(false);
const visible90 = ref<boolean>(true);
const visible91 = ref<boolean>(false);
const visible92 = ref<boolean>(true);
const visible93 = ref<boolean>(false);
const visible94 = ref<boolean>(true);
const visible95 = ref<boolean>(false);
const visible96 = ref<boolean>(true);
const visible97 = ref<boolean>(false);
const visible98 = ref<boolean>(true);
const visible99 = ref<boolean>(false);
const visible100 = ref<boolean>(true);
const visible101 = ref<boolean>(false);
const visible102 = ref<boolean>(true);
const visible103 = ref<boolean>(false);
const visible104 = ref<boolean>(true);
const visible105 = ref<boolean>(false);
const visible106 = ref<boolean>(true);
const visible107 = ref<boolean>(false);
const visible108 = ref<boolean>(true);
const visible109 = ref<boolean>(false);
const visible110 = ref<boolean>(true);
const visible111 = ref<boolean>(false);
const visible112 = ref<boolean>(true);
const visible113 = ref<boolean>(false);
const visible114 = ref<boolean>(true);
const visible115 = ref<boolean>(false);
const visible116 = ref<boolean>(true);
const visible117 = ref<boolean>(false);
const visible118 = ref<boolean>(true);
const visible119 = ref<boolean>(false);
const visible120 = ref<boolean>(true);
const visible121 = ref<boolean>(false);
const visible122 = ref<boolean>(true);
const visible123 = ref<boolean>(false);
const visible124 = ref<boolean>(true);
const visible125 = ref<boolean>(false);
const visible126 = ref<boolean>(true);
const visible127 = ref<boolean>(false);
const visible128 = ref<boolean>(true);
const visible129 = ref<boolean>(false);
const visible130 = ref<boolean>(true);
const visible131 = ref<boolean>(false);
const visible132 = ref<boolean>(true);
const visible133 = ref<boolean>(false);
const visible134 = ref<boolean>(true);
const visible135 = ref<boolean>(false);
const visible136 = ref<boolean>(true);
const visible137 = ref<boolean>(false);
const visible138 = ref<boolean>(true);
const visible139 = ref<boolean>(false);
const visible140 = ref<boolean>(true);
const visible141 = ref<boolean>(false);
const visible142 = ref<boolean>(true);
const visible143 = ref<boolean>(false);
const visible144 = ref<boolean>(true);
const visible145 = ref<boolean>(false);
const visible146 = ref<boolean>(true);
const visible147 = ref<boolean>(false);
const visible148 = ref<boolean>(true);
const visible149 = ref<boolean>(false);
const visible150 = ref<boolean>(true);
const visible151 = ref<boolean>(false);
const visible152 = ref<boolean>(true);
const visible153 = ref<boolean>(false);
const visible154 = ref<boolean>(true);
const visible155 = ref<boolean>(false);
const visible156 = ref<boolean>(true);
const visible157 = ref<boolean>(false);
const visible158 = ref<boolean>(true);
const visible159 = ref<boolean>(false);
const visible160 = ref<boolean>(true);
const visible161 = ref<boolean>(false);
const visible162 = ref<boolean>(true);
const visible163 = ref<boolean>(false);
const visible164 = ref<boolean>(true);
const visible165 = ref<boolean>(false);
const visible166 = ref<boolean>(true);
const visible167 = ref<boolean>(false);
const visible168 = ref<boolean>(true);
const visible169 = ref<boolean>(false);
const visible170 = ref<boolean>(true);
const visible171 = ref<boolean>(false);
const visible172 = ref<boolean>(true);
const visible173 = ref<boolean>(false);
const visible174 = ref<boolean>(true);
const visible175 = ref<boolean>(false);
const visible176 = ref<boolean>(true);
const visible177 = ref<boolean>(false);
const visible178 = ref<boolean>(true);
const visible179 = ref<boolean>(false);
const visible180 = ref<boolean>(true);
const visible181 = ref<boolean>(false);
const visible182 = ref<boolean>(true);
const visible183 = ref<boolean>(false);
const visible184 = ref<boolean>(true);
const visible185 = ref<boolean>(false);
const visible186 = ref<boolean>(true);
const visible187 = ref<boolean>(false);
const visible188 = ref<boolean>(true);
const visible189 = ref<boolean>(false);
const visible190 = ref<boolean>(true);
const visible191 = ref<boolean>(false);
const visible192 = ref<boolean>(true);
const visible193 = ref<boolean>(false);
const visible194 = ref<boolean>(true);
const visible195 = ref<boolean>(false);
const visible196 = ref<boolean>(true);
const visible197 = ref<boolean>(false);
const visible198 = ref<boolean>(true);
const visible199 = ref<boolean>(false);
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
  <fieldset v-if="visible10">
    <legend>group 10</legend>
    <label v-for="(row, ri) in groups[10].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[10].cfg" @change="onPick($event, 10)"/>
  </fieldset>
  <fieldset v-if="visible11">
    <legend>group 11</legend>
    <label v-for="(row, ri) in groups[11].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[11].cfg" @change="onPick($event, 11)"/>
  </fieldset>
  <fieldset v-if="visible12">
    <legend>group 12</legend>
    <label v-for="(row, ri) in groups[12].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[12].cfg" @change="onPick($event, 12)"/>
  </fieldset>
  <fieldset v-if="visible13">
    <legend>group 13</legend>
    <label v-for="(row, ri) in groups[13].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[13].cfg" @change="onPick($event, 13)"/>
  </fieldset>
  <fieldset v-if="visible14">
    <legend>group 14</legend>
    <label v-for="(row, ri) in groups[14].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[14].cfg" @change="onPick($event, 14)"/>
  </fieldset>
  <fieldset v-if="visible15">
    <legend>group 15</legend>
    <label v-for="(row, ri) in groups[15].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[15].cfg" @change="onPick($event, 15)"/>
  </fieldset>
  <fieldset v-if="visible16">
    <legend>group 16</legend>
    <label v-for="(row, ri) in groups[16].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[16].cfg" @change="onPick($event, 16)"/>
  </fieldset>
  <fieldset v-if="visible17">
    <legend>group 17</legend>
    <label v-for="(row, ri) in groups[17].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[17].cfg" @change="onPick($event, 17)"/>
  </fieldset>
  <fieldset v-if="visible18">
    <legend>group 18</legend>
    <label v-for="(row, ri) in groups[18].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[18].cfg" @change="onPick($event, 18)"/>
  </fieldset>
  <fieldset v-if="visible19">
    <legend>group 19</legend>
    <label v-for="(row, ri) in groups[19].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[19].cfg" @change="onPick($event, 19)"/>
  </fieldset>
  <fieldset v-if="visible20">
    <legend>group 20</legend>
    <label v-for="(row, ri) in groups[20].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[20].cfg" @change="onPick($event, 20)"/>
  </fieldset>
  <fieldset v-if="visible21">
    <legend>group 21</legend>
    <label v-for="(row, ri) in groups[21].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[21].cfg" @change="onPick($event, 21)"/>
  </fieldset>
  <fieldset v-if="visible22">
    <legend>group 22</legend>
    <label v-for="(row, ri) in groups[22].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[22].cfg" @change="onPick($event, 22)"/>
  </fieldset>
  <fieldset v-if="visible23">
    <legend>group 23</legend>
    <label v-for="(row, ri) in groups[23].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[23].cfg" @change="onPick($event, 23)"/>
  </fieldset>
  <fieldset v-if="visible24">
    <legend>group 24</legend>
    <label v-for="(row, ri) in groups[24].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[24].cfg" @change="onPick($event, 24)"/>
  </fieldset>
  <fieldset v-if="visible25">
    <legend>group 25</legend>
    <label v-for="(row, ri) in groups[25].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[25].cfg" @change="onPick($event, 25)"/>
  </fieldset>
  <fieldset v-if="visible26">
    <legend>group 26</legend>
    <label v-for="(row, ri) in groups[26].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[26].cfg" @change="onPick($event, 26)"/>
  </fieldset>
  <fieldset v-if="visible27">
    <legend>group 27</legend>
    <label v-for="(row, ri) in groups[27].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[27].cfg" @change="onPick($event, 27)"/>
  </fieldset>
  <fieldset v-if="visible28">
    <legend>group 28</legend>
    <label v-for="(row, ri) in groups[28].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[28].cfg" @change="onPick($event, 28)"/>
  </fieldset>
  <fieldset v-if="visible29">
    <legend>group 29</legend>
    <label v-for="(row, ri) in groups[29].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[29].cfg" @change="onPick($event, 29)"/>
  </fieldset>
  <fieldset v-if="visible30">
    <legend>group 30</legend>
    <label v-for="(row, ri) in groups[30].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[30].cfg" @change="onPick($event, 30)"/>
  </fieldset>
  <fieldset v-if="visible31">
    <legend>group 31</legend>
    <label v-for="(row, ri) in groups[31].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[31].cfg" @change="onPick($event, 31)"/>
  </fieldset>
  <fieldset v-if="visible32">
    <legend>group 32</legend>
    <label v-for="(row, ri) in groups[32].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[32].cfg" @change="onPick($event, 32)"/>
  </fieldset>
  <fieldset v-if="visible33">
    <legend>group 33</legend>
    <label v-for="(row, ri) in groups[33].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[33].cfg" @change="onPick($event, 33)"/>
  </fieldset>
  <fieldset v-if="visible34">
    <legend>group 34</legend>
    <label v-for="(row, ri) in groups[34].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[34].cfg" @change="onPick($event, 34)"/>
  </fieldset>
  <fieldset v-if="visible35">
    <legend>group 35</legend>
    <label v-for="(row, ri) in groups[35].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[35].cfg" @change="onPick($event, 35)"/>
  </fieldset>
  <fieldset v-if="visible36">
    <legend>group 36</legend>
    <label v-for="(row, ri) in groups[36].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[36].cfg" @change="onPick($event, 36)"/>
  </fieldset>
  <fieldset v-if="visible37">
    <legend>group 37</legend>
    <label v-for="(row, ri) in groups[37].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[37].cfg" @change="onPick($event, 37)"/>
  </fieldset>
  <fieldset v-if="visible38">
    <legend>group 38</legend>
    <label v-for="(row, ri) in groups[38].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[38].cfg" @change="onPick($event, 38)"/>
  </fieldset>
  <fieldset v-if="visible39">
    <legend>group 39</legend>
    <label v-for="(row, ri) in groups[39].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[39].cfg" @change="onPick($event, 39)"/>
  </fieldset>
  <fieldset v-if="visible40">
    <legend>group 40</legend>
    <label v-for="(row, ri) in groups[40].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[40].cfg" @change="onPick($event, 40)"/>
  </fieldset>
  <fieldset v-if="visible41">
    <legend>group 41</legend>
    <label v-for="(row, ri) in groups[41].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[41].cfg" @change="onPick($event, 41)"/>
  </fieldset>
  <fieldset v-if="visible42">
    <legend>group 42</legend>
    <label v-for="(row, ri) in groups[42].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[42].cfg" @change="onPick($event, 42)"/>
  </fieldset>
  <fieldset v-if="visible43">
    <legend>group 43</legend>
    <label v-for="(row, ri) in groups[43].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[43].cfg" @change="onPick($event, 43)"/>
  </fieldset>
  <fieldset v-if="visible44">
    <legend>group 44</legend>
    <label v-for="(row, ri) in groups[44].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[44].cfg" @change="onPick($event, 44)"/>
  </fieldset>
  <fieldset v-if="visible45">
    <legend>group 45</legend>
    <label v-for="(row, ri) in groups[45].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[45].cfg" @change="onPick($event, 45)"/>
  </fieldset>
  <fieldset v-if="visible46">
    <legend>group 46</legend>
    <label v-for="(row, ri) in groups[46].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[46].cfg" @change="onPick($event, 46)"/>
  </fieldset>
  <fieldset v-if="visible47">
    <legend>group 47</legend>
    <label v-for="(row, ri) in groups[47].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[47].cfg" @change="onPick($event, 47)"/>
  </fieldset>
  <fieldset v-if="visible48">
    <legend>group 48</legend>
    <label v-for="(row, ri) in groups[48].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[48].cfg" @change="onPick($event, 48)"/>
  </fieldset>
  <fieldset v-if="visible49">
    <legend>group 49</legend>
    <label v-for="(row, ri) in groups[49].rows" :key="row.id">
      <input v-model="row.name" :disabled="locked">
      <select v-model="row.kind"><option value="a">A</option><option value="b">B</option></select>
      <b v-show="row.id % 3 === 0">{{ row.name | cap }}#{{ ri }}</b>
    </label>
    <ChildComp :config="groups[49].cfg" @change="onPick($event, 49)"/>
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
.g20 > label:nth-child(2n) { color: #202020 }
.g21 > label:nth-child(2n) { color: #212121 }
.g22 > label:nth-child(2n) { color: #222222 }
.g23 > label:nth-child(2n) { color: #232323 }
.g24 > label:nth-child(2n) { color: #242424 }
.g25 > label:nth-child(2n) { color: #252525 }
.g26 > label:nth-child(2n) { color: #262626 }
.g27 > label:nth-child(2n) { color: #272727 }
.g28 > label:nth-child(2n) { color: #282828 }
.g29 > label:nth-child(2n) { color: #292929 }
.g30 > label:nth-child(2n) { color: #303030 }
.g31 > label:nth-child(2n) { color: #313131 }
.g32 > label:nth-child(2n) { color: #323232 }
.g33 > label:nth-child(2n) { color: #333333 }
.g34 > label:nth-child(2n) { color: #343434 }
.g35 > label:nth-child(2n) { color: #353535 }
.g36 > label:nth-child(2n) { color: #363636 }
.g37 > label:nth-child(2n) { color: #373737 }
.g38 > label:nth-child(2n) { color: #383838 }
.g39 > label:nth-child(2n) { color: #393939 }
.g40 > label:nth-child(2n) { color: #404040 }
.g41 > label:nth-child(2n) { color: #414141 }
.g42 > label:nth-child(2n) { color: #424242 }
.g43 > label:nth-child(2n) { color: #434343 }
.g44 > label:nth-child(2n) { color: #444444 }
.g45 > label:nth-child(2n) { color: #454545 }
.g46 > label:nth-child(2n) { color: #464646 }
.g47 > label:nth-child(2n) { color: #474747 }
.g48 > label:nth-child(2n) { color: #484848 }
.g49 > label:nth-child(2n) { color: #494949 }
.g50 > label:nth-child(2n) { color: #505050 }
.g51 > label:nth-child(2n) { color: #515151 }
.g52 > label:nth-child(2n) { color: #525252 }
.g53 > label:nth-child(2n) { color: #535353 }
.g54 > label:nth-child(2n) { color: #545454 }
.g55 > label:nth-child(2n) { color: #555555 }
.g56 > label:nth-child(2n) { color: #565656 }
.g57 > label:nth-child(2n) { color: #575757 }
.g58 > label:nth-child(2n) { color: #585858 }
.g59 > label:nth-child(2n) { color: #595959 }
.g60 > label:nth-child(2n) { color: #606060 }
.g61 > label:nth-child(2n) { color: #616161 }
.g62 > label:nth-child(2n) { color: #626262 }
.g63 > label:nth-child(2n) { color: #636363 }
.g64 > label:nth-child(2n) { color: #646464 }
.g65 > label:nth-child(2n) { color: #656565 }
.g66 > label:nth-child(2n) { color: #666666 }
.g67 > label:nth-child(2n) { color: #676767 }
.g68 > label:nth-child(2n) { color: #686868 }
.g69 > label:nth-child(2n) { color: #696969 }
.g70 > label:nth-child(2n) { color: #707070 }
.g71 > label:nth-child(2n) { color: #717171 }
.g72 > label:nth-child(2n) { color: #727272 }
.g73 > label:nth-child(2n) { color: #737373 }
.g74 > label:nth-child(2n) { color: #747474 }
.g75 > label:nth-child(2n) { color: #757575 }
.g76 > label:nth-child(2n) { color: #767676 }
.g77 > label:nth-child(2n) { color: #777777 }
.g78 > label:nth-child(2n) { color: #787878 }
.g79 > label:nth-child(2n) { color: #797979 }
.g80 > label:nth-child(2n) { color: #808080 }
.g81 > label:nth-child(2n) { color: #818181 }
.g82 > label:nth-child(2n) { color: #828282 }
.g83 > label:nth-child(2n) { color: #838383 }
.g84 > label:nth-child(2n) { color: #848484 }
.g85 > label:nth-child(2n) { color: #858585 }
.g86 > label:nth-child(2n) { color: #868686 }
.g87 > label:nth-child(2n) { color: #878787 }
.g88 > label:nth-child(2n) { color: #888888 }
.g89 > label:nth-child(2n) { color: #898989 }
.g90 > label:nth-child(2n) { color: #909090 }
.g91 > label:nth-child(2n) { color: #919191 }
.g92 > label:nth-child(2n) { color: #929292 }
.g93 > label:nth-child(2n) { color: #939393 }
.g94 > label:nth-child(2n) { color: #949494 }
.g95 > label:nth-child(2n) { color: #959595 }
.g96 > label:nth-child(2n) { color: #969696 }
.g97 > label:nth-child(2n) { color: #979797 }
.g98 > label:nth-child(2n) { color: #989898 }
.g99 > label:nth-child(2n) { color: #999999 }
</style>
