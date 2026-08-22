// Template AST node model mirroring @vue/compiler-core node shapes.
// Type numbers match official NodeTypes for faithful transform/codegen ports.

// Official NodeTypes (subset used by template compilation).
const ntRoot = 0;
const ntElement = 1;
const ntText = 2;
const ntComment = 3;
const ntSimpleExpression = 4;
const ntInterpolation = 5;
const ntAttribute = 6;
const ntDirective = 7;
const ntCompoundExpression = 8;
const ntIf = 9;
const ntIfBranch = 10;
const ntFor = 11;
const ntTextCall = 12;
const ntVNodeCall = 13;
const ntJSCallExpression = 14;
const ntJSObjectExpression = 15;
const ntJSProperty = 16;
const ntJSArrayExpression = 17;
const ntJSFunctionExpression = 18;
const ntJSConditionalExpression = 19;
const ntJSCacheExpression = 20;
const ntJSBlockStatement = 21;
const ntJSTemplateLiteral = 22;
const ntJSIfStatement = 23;
const ntJSAssignmentExpression = 24;
const ntJSSequenceExpression = 25;
const ntJSReturnStatement = 26;

// Official ElementTypes.
const etElement = 0;
const etComponent = 1;
const etSlot = 2;
const etTemplate = 3;

// Official ConstantTypes.
const ctNotConstant = 0;
const ctCanSkipPatch = 1;
const ctCanHoist = 2;
const ctCanStringify = 3;

// Official Namespaces.
const nsHtml = 0;
const nsSvg = 1;
const nsMathMl = 2;

final class TmplPosition {
  int offset;
  int line;
  int column;
  TmplPosition(this.offset, this.line, this.column);
  TmplPosition clone() => TmplPosition(offset, line, column);
}

final class TmplLoc {
  TmplPosition start;
  TmplPosition end; // nullability modeled by late assignment at parse end
  String source;
  TmplLoc(this.start, this.end, this.source);
}

sealed class TmplNode {
  int get type;
  TmplLoc get loc;
  set loc(TmplLoc value);
}

final class RootNode extends TmplNode {
  @override
  final int type = ntRoot;
  List<TmplNode> children;
  @override
  TmplLoc loc;
  // Codegen state assigned by transform().
  Set<String> helpers = {};
  List<String> components = [];
  List<String> directives = [];
  List<Object?> hoists = [];
  List<Object?> cached = [];
  List<Object?> imports = [];
  int temps = 0;
  Object? codegenNode;
  bool transformed = false;
  RootNode(this.children, this.loc);
}

final class SimpleExpression extends TmplNode {
  @override
  final int type = ntSimpleExpression;
  String content;
  final bool static_;
  int constType;
  @override
  TmplLoc loc;
  Object? ast; // babel AST placeholder (null = simple ident, false = parse fail)
  Object? hoisted; // hoisted codegen node (set by context.hoist)
  List<String>? identifiers; // scope identifiers (set by processExpression)
  bool isHandlerKey = false; // set for event-handler prop keys
  SimpleExpression(this.content, this.static_, this.loc,
      [this.constType = ctNotConstant]);
}

final class TextNode extends TmplNode {
  @override
  final int type = ntText;
  String content;
  @override
  TmplLoc loc;
  Object? codegenNode;
  TextNode(this.content, this.loc);
}

final class CommentNode extends TmplNode {
  @override
  final int type = ntComment;
  final String content;
  @override
  TmplLoc loc;
  CommentNode(this.content, this.loc);
}

final class InterpolationNode extends TmplNode {
  @override
  final int type = ntInterpolation;
  TmplNode content; // SimpleExpression | CompoundExpression
  @override
  TmplLoc loc;
  InterpolationNode(this.content, this.loc);
}

final class AttributeNode extends TmplNode {
  @override
  final int type = ntAttribute;
  String name;
  TextNode? value;
  TmplLoc nameLoc;
  @override
  TmplLoc loc;
  AttributeNode(this.name, this.nameLoc, this.value, this.loc);
}

final class ForParseResult {
  TmplNode source; // SimpleExpression | CompoundExpression
  TmplNode? value;
  TmplNode? key;
  TmplNode? index;
  bool finalized = false;
  ForParseResult(this.source);
}

final class DirectiveNode extends TmplNode {
  @override
  final int type = ntDirective;
  String name;
  String rawName;
  TmplNode? exp; // SimpleExpression | CompoundExpression
  TmplNode? arg; // SimpleExpression | CompoundExpression
  List<SimpleExpression> modifiers;
  ForParseResult? forParseResult;
  @override
  TmplLoc loc;
  DirectiveNode(this.name, this.rawName, this.loc,
      {this.exp, this.arg, List<SimpleExpression>? modifiers})
      : modifiers = modifiers ?? [];
}

final class ElementNode extends TmplNode {
  @override
  final int type = ntElement;
  final String tag;
  final int ns;
  int tagType;
  final List<TmplNode> props; // AttributeNode | DirectiveNode
  List<TmplNode> children;
  bool isSelfClosing;
  @override
  TmplLoc loc;
  TmplLoc? innerLoc; // set at SFC root
  Object? codegenNode;
  Object? ssrCodegenNode;
  ElementNode(this.tag, this.ns, this.tagType, this.props, this.children,
      this.loc,
      {this.isSelfClosing = false});
}

// Structural / codegen-capable nodes (created by transforms, still live in
// the template tree until codegen reads their codegenNode).

final class CompoundExpression extends TmplNode {
  @override
  final int type = ntCompoundExpression;
  List<Object?> children; // String | TmplNode | codegen node
  @override
  TmplLoc loc;
  List<String>? identifiers;
  Object? ast;
  CompoundExpression(this.children, this.loc);
}

final class IfNode extends TmplNode {
  @override
  final int type = ntIf;
  List<IfBranchNode> branches;
  @override
  TmplLoc loc;
  Object? codegenNode;
  IfNode(this.branches, this.loc);
}

final class IfBranchNode extends TmplNode {
  @override
  final int type = ntIfBranch;
  TmplNode? condition; // SimpleExpression | CompoundExpression
  List<TmplNode> children;
  Object? userKey; // AttributeNode | DirectiveNode
  bool isTemplateIf;
  @override
  TmplLoc loc;
  Object? codegenNode;
  IfBranchNode(this.children, this.loc,
      {this.condition, this.userKey, this.isTemplateIf = false});
}

final class ForNode extends TmplNode {
  @override
  final int type = ntFor;
  TmplNode source; // SimpleExpression | CompoundExpression
  TmplNode? valueAlias;
  TmplNode? keyAlias;
  TmplNode? objectIndexAlias;
  ForParseResult parseResult;
  List<TmplNode> children;
  @override
  TmplLoc loc;
  Object? codegenNode;
  ForNode(this.source, this.parseResult, this.children, this.loc,
      {this.valueAlias, this.keyAlias, this.objectIndexAlias});
}

final class TextCallNode extends TmplNode {
  @override
  final int type = ntTextCall;
  TmplNode content; // TextNode | InterpolationNode | CompoundExpression
  @override
  TmplLoc loc;
  Object? codegenNode;
  TextCallNode(this.content, this.loc);
}

TmplLoc locStub() => TmplLoc(TmplPosition(-1, -1, -1), TmplPosition(-1, -1, -1), '');
