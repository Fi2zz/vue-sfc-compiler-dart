# script_and_script_setup_import_export

Vue Compile Error: [@vue/compiler-sfc] <script setup> cannot contain ES module exports. If you are using a previous version of <script setup>, please consult the updated RFC at https://github.com/vuejs/rfcs/pull/227.

./script_and_script_setup_import_export.vue
14 |  
15 |  const localValue = ref('local')
16 |  
   |   ^
17 |  export { localValue }
   |  ^^^^^^^^^^^^^^^^^^^^^
18 |  </script>