import 'package:test/test.dart';
import 'package:vue_sfc_parser/sfc_script_codegen_helpers.dart';

void main() {
  group('CodegenHelpers', () {
    group('extractDefineProps', () {
      test('should handle basic defineProps with inline object type', () {
        // This would require a CompilationUnit, so we'll test the helper functions directly
        const testInput = 'defineProps<{ msg: string; count?: number }>()';
        final result = CodegenHelpers.extractPropsFromDefineProps(testInput);
        
        expect(result, isNotNull);
        expect(result, contains('msg: { type: String, required: true }'));
        expect(result, contains('count: { type: Number, required: false }'));
      });
      
      test('should handle withDefaults with inline object type', () {
        const testInput = "withDefaults(defineProps<{ msg?: string; count?: number }>(), { msg: 'hi', count: 1 })";
        final result = CodegenHelpers.extractPropsFromWithDefaults(testInput);
        
        expect(result, isNotNull);
        expect(result, contains('msg: { type: String, required: false , default: \'hi\' }'));
        expect(result, contains('count: { type: Number, required: false , default: 1 }'));
      });
      
      test('should handle TypeScript type conversion', () {
        expect(CodegenHelpers.convertTsTypeToRuntimeType('string'), equals('String'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('number'), equals('Number'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('boolean'), equals('Boolean'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('Array'), equals('Array'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('Object'), equals('Object'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('Function'), equals('Function'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('string[]'), equals('Array'));
        expect(CodegenHelpers.convertTsTypeToRuntimeType('Array<string>'), equals('Array'));
      });
      
      test('should parse defaults object correctly', () {
        const defaultsObject = "{ msg: 'hi', count: 1, active: true }";
        final defaults = CodegenHelpers.parseDefaultsObject(defaultsObject);
        
        expect(defaults, isNotNull);
        expect(defaults['msg'], equals("'hi'"));
        expect(defaults['count'], equals('1'));
        expect(defaults['active'], equals('true'));
      });
      
      test('should merge defaults with props correctly', () {
        const propsResult = '{\n    msg: { type: String, required: false },\n    count: { type: Number, required: false }\n  }';
        final defaults = <String, String>{
          'msg': "'hi'",
          'count': '1'
        };
        
        final merged = CodegenHelpers.mergeDefaultsWithProps(propsResult, defaults);
        
        expect(merged, contains('default: \'hi\''));
        expect(merged, contains('default: 1'));
      });
    });
    
    group('Helper functions', () {
      test('should check macro types correctly', () {
        expect(CodegenHelpers.isDefineProps('defineProps'), isTrue);
        expect(CodegenHelpers.isDefineProps('other'), isFalse);
        expect(CodegenHelpers.isWithDefaults('withDefaults'), isTrue);
        expect(CodegenHelpers.isWithDefaults('other'), isFalse);
      });
      
      test('should generate import statements correctly', () {
        final aliases = ['defineComponent', 'ref'];
        final import = CodegenHelpers.importFromVue(aliases);
        expect(import, equals("import { defineComponent, ref } from 'vue'"));
      });
      
      test('should generate setup start correctly', () {
        final setupStart = CodegenHelpers.setupStart(true, false);
        expect(setupStart, equals('setup(__props: any, { expose: __expose }) {'));
        
        final setupStartJs = CodegenHelpers.setupStart(false, false);
        expect(setupStartJs, equals('setup(__props, { expose: __expose }) {'));
      });
    });
  });
}