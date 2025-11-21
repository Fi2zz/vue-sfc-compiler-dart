// ast-nodes.ts
export interface Position {
  line: number;
  column: number;
}
export interface SourceLocation {
  start: Position;
  end: Position;
}

export type Node =
  | Program
  | VariableDeclaration
  | FunctionDeclaration
  | ClassDeclaration
  | IfStatement
  | BlockStatement
  | ExpressionStatement
  | ReturnStatement
  | ForStatement
  | WhileStatement
  | BreakStatement
  | ContinueStatement
  | TryStatement
  | ThrowStatement
  | SwitchStatement
  | SwitchCase
  | Identifier
  | Literal
  | ArrayExpression
  | ObjectExpression
  | Property
  | FunctionExpression
  | ArrowFunctionExpression
  | ClassExpression
  | CallExpression
  | NewExpression
  | MemberExpression
  | UpdateExpression
  | UnaryExpression
  | BinaryExpression
  | LogicalExpression
  | AssignmentExpression
  | ConditionalExpression
  | ThisExpression
  | TemplateLiteral
  | TaggedTemplateExpression
  | TSTypeAnnotation
  | TSTypeReference
  | TSAsExpression
  | TSInterfaceDeclaration
  | TSEnumDeclaration
  | TSModuleDeclaration
  | TSParameterProperty
  | TSNonNullExpression
  | TSDeclareFunction
  | ImportDeclaration
  | ExportNamedDeclaration
  | ExportDefaultDeclaration
  | ExportAllDeclaration
  | AwaitExpression
  | ImportExpression
  | MetaProperty
  | Decorator
  | AssertEntry;

export interface BaseNode {
  type: string;
  loc?: SourceLocation;
  range?: [number, number];
}

export interface Program extends BaseNode {
  type: "Program";
  sourceType: "script" | "module";
  body: Statement[];
}

export interface VariableDeclaration extends BaseNode {
  type: "VariableDeclaration";
  kind: "var" | "let" | "const";
  declarations: VariableDeclarator[];
}

export interface VariableDeclarator extends BaseNode {
  type: "VariableDeclarator";
  id: Identifier;
  init?: Expression | null;
}

export interface FunctionDeclaration extends BaseNode {
  type: "FunctionDeclaration";
  id: Identifier | null;
  params: Parameter[];
  body: BlockStatement;
  generator?: boolean;
  async?: boolean;
}

export interface ClassDeclaration extends BaseNode {
  type: "ClassDeclaration";
  id: Identifier | null;
  superClass?: Expression | null;
  body: ClassBody;
}

export interface ClassBody extends BaseNode {
  type: "ClassBody";
  body: MethodDefinition[];
}

export interface MethodDefinition extends BaseNode {
  type: "MethodDefinition";
  key: Expression;
  value: FunctionExpression;
  kind: "constructor" | "method" | "get" | "set";
  static: boolean;
}

export interface IfStatement extends BaseNode {
  type: "IfStatement";
  test: Expression;
  consequent: Statement;
  alternate?: Statement | null;
}

export interface BlockStatement extends BaseNode {
  type: "BlockStatement";
  body: Statement[];
}

export interface ExpressionStatement extends BaseNode {
  type: "ExpressionStatement";
  expression: Expression;
}

export interface ReturnStatement extends BaseNode {
  type: "ReturnStatement";
  argument?: Expression | null;
}

export interface ForStatement extends BaseNode {
  type: "ForStatement";
  init?: Expression | VariableDeclaration | null;
  test?: Expression | null;
  update?: Expression | null;
  body: Statement;
}

export interface WhileStatement extends BaseNode {
  type: "WhileStatement";
  test: Expression;
  body: Statement;
}

export interface BreakStatement extends BaseNode {
  type: "BreakStatement";
  label?: Identifier | null;
}

export interface ContinueStatement extends BaseNode {
  type: "ContinueStatement";
  label?: Identifier | null;
}

export interface TryStatement extends BaseNode {
  type: "TryStatement";
  block: BlockStatement;
  handler?: CatchClause | null;
  finalizer?: BlockStatement | null;
}

export interface CatchClause extends BaseNode {
  type: "CatchClause";
  param?: Identifier | null;
  body: BlockStatement;
}

export interface ThrowStatement extends BaseNode {
  type: "ThrowStatement";
  argument: Expression;
}

export interface SwitchStatement extends BaseNode {
  type: "SwitchStatement";
  discriminant: Expression;
  cases: SwitchCase[];
}

export interface SwitchCase extends BaseNode {
  type: "SwitchCase";
  test?: Expression | null;
  consequent: Statement[];
}

export interface Identifier extends BaseNode {
  type: "Identifier";
  name: string;
}

export interface Literal extends BaseNode {
  type: "Literal";
  value: string | number | boolean | RegExp | bigint | null;
  raw?: string;
}

export interface ArrayExpression extends BaseNode {
  type: "ArrayExpression";
  elements: (Expression | null)[];
}

export interface ObjectExpression extends BaseNode {
  type: "ObjectExpression";
  properties: Property[];
}

export interface Property extends BaseNode {
  type: "Property";
  key: Expression;
  value: Expression;
  kind: "init" | "get" | "set";
  method: boolean;
  shorthand: boolean;
  computed: boolean;
}

export interface FunctionExpression extends BaseNode {
  type: "FunctionExpression";
  id: Identifier | null;
  params: Parameter[];
  body: BlockStatement;
  generator?: boolean;
  async?: boolean;
}

export interface ArrowFunctionExpression extends BaseNode {
  type: "ArrowFunctionExpression";
  params: Parameter[];
  body: BlockStatement | Expression;
  async?: boolean;
}

export interface ClassExpression extends BaseNode {
  type: "ClassExpression";
  id: Identifier | null;
  superClass?: Expression | null;
  body: ClassBody;
}

export interface CallExpression extends BaseNode {
  type: "CallExpression";
  callee: Expression;
  arguments: (Expression | SpreadElement)[];
}

export interface NewExpression extends BaseNode {
  type: "NewExpression";
  callee: Expression;
  arguments: (Expression | SpreadElement)[];
}

export interface MemberExpression extends BaseNode {
  type: "MemberExpression";
  object: Expression;
  property: Expression;
  computed: boolean;
}

export interface UpdateExpression extends BaseNode {
  type: "UpdateExpression";
  operator: "++" | "--";
  argument: Expression;
  prefix: boolean;
}

export interface UnaryExpression extends BaseNode {
  type: "UnaryExpression";
  operator: "+" | "-" | "!" | "~" | "typeof" | "void" | "delete";
  argument: Expression;
  prefix: boolean;
}

export interface BinaryExpression extends BaseNode {
  type: "BinaryExpression";
  operator:
    | "=="
    | "!="
    | "==="
    | "!=="
    | "<"
    | "<="
    | ">"
    | ">="
    | "<<"
    | ">>"
    | ">>>"
    | "+"
    | "-"
    | "*"
    | "/"
    | "%"
    | "**"
    | "|"
    | "^"
    | "&"
    | "in"
    | "instanceof";
  left: Expression;
  right: Expression;
}

export interface LogicalExpression extends BaseNode {
  type: "LogicalExpression";
  operator: "||" | "&&" | "??";
  left: Expression;
  right: Expression;
}

export interface AssignmentExpression extends BaseNode {
  type: "AssignmentExpression";
  operator:
    | "="
    | "+="
    | "-="
    | "*="
    | "/="
    | "%="
    | "**="
    | "<<="
    | ">>="
    | ">>>="
    | "|="
    | "^="
    | "&=";
  left: Expression;
  right: Expression;
}

export interface ConditionalExpression extends BaseNode {
  type: "ConditionalExpression";
  test: Expression;
  alternate: Expression;
  consequent: Expression;
}

export interface ThisExpression extends BaseNode {
  type: "ThisExpression";
}

export interface TemplateLiteral extends BaseNode {
  type: "TemplateLiteral";
  quasis: TemplateElement[];
  expressions: Expression[];
}

export interface TemplateElement extends BaseNode {
  type: "TemplateElement";
  value: { cooked: string; raw: string };
  tail: boolean;
}

export interface TaggedTemplateExpression extends BaseNode {
  type: "TaggedTemplateExpression";
  tag: Expression;
  quasi: TemplateLiteral;
}

export interface TSTypeAnnotation extends BaseNode {
  type: "TSTypeAnnotation";
  typeAnnotation: TSType;
}

export type TSType =
  | TSTypeReference
  | TSInterfaceDeclaration
  | TSEnumDeclaration
  | TSModuleDeclaration;

export interface TSTypeReference extends BaseNode {
  type: "TSTypeReference";
  typeName: Identifier;
}

export interface TSAsExpression extends BaseNode {
  type: "TSAsExpression";
  expression: Expression;
  typeAnnotation: TSType;
}

export interface TSInterfaceDeclaration extends BaseNode {
  type: "TSInterfaceDeclaration";
  id: Identifier;
  body: TSInterfaceBody;
}

export interface TSInterfaceBody extends BaseNode {
  type: "TSInterfaceBody";
  body: TSPropertySignature[];
}

export interface TSPropertySignature extends BaseNode {
  type: "TSPropertySignature";
  key: Identifier;
  typeAnnotation?: TSTypeAnnotation;
}

export interface TSEnumDeclaration extends BaseNode {
  type: "TSEnumDeclaration";
  id: Identifier;
  members: TSEnumMember[];
}

export interface TSEnumMember extends BaseNode {
  type: "TSEnumMember";
  id: Identifier;
  initializer?: Expression;
}

export interface TSModuleDeclaration extends BaseNode {
  type: "TSModuleDeclaration";
  id: Identifier;
  body: TSModuleBlock;
}

export interface TSModuleBlock extends BaseNode {
  type: "TSModuleBlock";
  body: Statement[];
}

export interface TSParameterProperty extends BaseNode {
  type: "TSParameterProperty";
  parameter: Identifier;
}

export interface TSNonNullExpression extends BaseNode {
  type: "TSNonNullExpression";
  expression: Expression;
}

export interface TSDeclareFunction extends BaseNode {
  type: "TSDeclareFunction";
  id: Identifier | null;
  params: Parameter[];
  returnType?: TSTypeAnnotation;
}

export interface ImportDeclaration extends BaseNode {
  type: "ImportDeclaration";
  specifiers: ImportSpecifier[];
  source: Literal;
}

export interface ImportSpecifier extends BaseNode {
  type:
    | "ImportSpecifier"
    | "ImportDefaultSpecifier"
    | "ImportNamespaceSpecifier";
  imported?: Identifier;
  local: Identifier;
}

export interface ExportNamedDeclaration extends BaseNode {
  type: "ExportNamedDeclaration";
  declaration?: Declaration | null;
  specifiers: ExportSpecifier[];
  source?: Literal | null;
}

export interface ExportDefaultDeclaration extends BaseNode {
  type: "ExportDefaultDeclaration";
  declaration: Declaration | Expression;
}

export interface ExportAllDeclaration extends BaseNode {
  type: "ExportAllDeclaration";
  source: Literal;
  exported?: Identifier | null;
}

export interface ExportSpecifier extends BaseNode {
  type: "ExportSpecifier";
  exported: Identifier;
  local: Identifier;
}

export interface AwaitExpression extends BaseNode {
  type: "AwaitExpression";
  argument: Expression;
}

export interface ImportExpression extends BaseNode {
  type: "ImportExpression";
  source: Expression;
}

export interface MetaProperty extends BaseNode {
  type: "MetaProperty";
  meta: Identifier;
  property: Identifier;
}

export interface Decorator extends BaseNode {
  type: "Decorator";
  expression: Expression;
}

export interface AssertEntry extends BaseNode {
  type: "AssertEntry";
  key: Identifier;
  value: Literal;
}

// 通用参数节点
export type Parameter = Identifier | AssignmentPattern | RestElement;
export interface AssignmentPattern extends BaseNode {
  type: "AssignmentPattern";
  left: Identifier;
  right: Expression;
}
export interface RestElement extends BaseNode {
  type: "RestElement";
  argument: Identifier;
}
export interface SpreadElement extends BaseNode {
  type: "SpreadElement";
  argument: Expression;
}

// -------------- 语句补充 --------------
export interface EmptyStatement extends BaseNode {
  type: "EmptyStatement";
}

export interface DebuggerStatement extends BaseNode {
  type: "DebuggerStatement";
}

export interface ForInStatement extends BaseNode {
  type: "ForInStatement";
  left: VariableDeclaration | Identifier | AssignmentPattern | MemberExpression;
  right: Expression;
  body: Statement;
}

export interface ForOfStatement extends BaseNode {
  type: "ForOfStatement";
  left: VariableDeclaration | Identifier | AssignmentPattern | MemberExpression;
  right: Expression;
  body: Statement;
  await: boolean;
}

// 语句 & 表达式总称
export type Statement =
  | ExpressionStatement
  | BlockStatement
  | EmptyStatement
  | DebuggerStatement
  | ReturnStatement
  | BreakStatement
  | ContinueStatement
  | IfStatement
  | SwitchStatement
  | ThrowStatement
  | TryStatement
  | WhileStatement
  | ForStatement
  | ForInStatement
  | ForOfStatement
  | VariableDeclaration
  | FunctionDeclaration
  | ClassDeclaration
  | ImportDeclaration
  | ExportNamedDeclaration
  | ExportDefaultDeclaration
  | ExportAllDeclaration;

export type Expression =
  | Identifier
  | Literal
  | ArrayExpression
  | ObjectExpression
  | FunctionExpression
  | ArrowFunctionExpression
  | ClassExpression
  | CallExpression
  | NewExpression
  | MemberExpression
  | UpdateExpression
  | UnaryExpression
  | BinaryExpression
  | LogicalExpression
  | AssignmentExpression
  | ConditionalExpression
  | ThisExpression
  | TemplateLiteral
  | TaggedTemplateExpression
  | AwaitExpression
  | ImportExpression
  | MetaProperty
  | TSAsExpression
  | TSNonNullExpression;

export type Declaration =
  | VariableDeclaration
  | FunctionDeclaration
  | ClassDeclaration
  | TSInterfaceDeclaration
  | TSEnumDeclaration
  | TSModuleDeclaration
  | TSDeclareFunction;
