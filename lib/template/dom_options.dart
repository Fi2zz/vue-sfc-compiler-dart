// DOM tag configuration ported from @vue/shared + compiler-dom parserOptions.

import 'tmpl_ast.dart';
import 'tmpl_parser.dart';
import 'tokenizer.dart';

const _htmlTags =
    'html,body,base,head,link,meta,style,title,address,article,aside,footer,header,hgroup,h1,h2,h3,h4,h5,h6,nav,section,div,dd,dl,dt,figcaption,figure,picture,hr,img,li,main,ol,p,pre,ul,a,b,abbr,bdi,bdo,br,cite,code,data,dfn,em,i,kbd,mark,q,rp,rt,ruby,s,samp,small,span,strong,sub,sup,time,u,var,wbr,area,audio,map,track,video,embed,object,param,source,canvas,script,noscript,del,ins,caption,col,colgroup,table,thead,tbody,td,th,tr,button,datalist,fieldset,form,input,label,legend,meter,optgroup,option,output,progress,select,textarea,details,dialog,menu,summary,template,blockquote,iframe,tfoot';
const _svgTags =
    'svg,animate,animateMotion,animateTransform,circle,clipPath,color-profile,defs,desc,discard,ellipse,feBlend,feColorMatrix,feComponentTransfer,feComposite,feConvolveMatrix,feDiffuseLighting,feDisplacementMap,feDistantLight,feDropShadow,feFlood,feFuncA,feFuncB,feFuncG,feFuncR,feGaussianBlur,feImage,feMerge,feMergeNode,feMorphology,feOffset,fePointLight,feSpecularLighting,feSpotLight,feTile,feTurbulence,filter,foreignObject,g,hatch,hatchpath,image,line,linearGradient,marker,mask,mesh,meshgradient,meshpatch,meshrow,metadata,mpath,path,pattern,polygon,polyline,radialGradient,rect,set,solidcolor,stop,switch,symbol,text,textPath,title,tspan,unknown,use,view';
const _mathTags =
    'annotation,annotation-xml,maction,maligngroup,malignmark,math,menclose,merror,mfenced,mfrac,mfraction,mglyph,mi,mlabeledtr,mlongdiv,mmultiscripts,mn,mo,mover,mpadded,mphantom,mprescripts,mroot,mrow,ms,mscarries,mscarry,msgroup,msline,mspace,msqrt,msrow,mstack,mstyle,msub,msubsup,msup,mtable,mtd,mtext,mtr,munder,munderover,none,semantics';
const _voidTags =
    'area,base,br,col,embed,hr,img,input,link,meta,param,source,track,wbr';

Set<String> _mkSet(String csv) => csv.split(',').toSet();
final _htmlSet = _mkSet(_htmlTags);
final _svgSet = _mkSet(_svgTags);
final _mathSet = _mkSet(_mathTags);
final _voidSet = _mkSet(_voidTags);

bool isHtmlTag(String tag) => _htmlSet.contains(tag);
bool isSvgTag(String tag) => _svgSet.contains(tag);
bool isMathMLTag(String tag) => _mathSet.contains(tag);
bool isVoidTag(String tag) => _voidSet.contains(tag);

bool domNativeTag(String tag) =>
    isHtmlTag(tag) || isSvgTag(tag) || isMathMLTag(tag);

/// compiler-dom getNamespace (tree-construction dispatcher rules).
int domGetNamespace(String tag, ElementNode? parent, int rootNs) {
  var ns = parent?.ns ?? rootNs;
  if (parent != null && ns == nsMathMl) {
    ns = _mathMlChildNs(tag, parent, ns);
  } else if (parent != null && ns == nsSvg) {
    final t = parent.tag;
    if (t == 'foreignObject' || t == 'desc' || t == 'title') ns = nsHtml;
  }
  if (ns == nsHtml) {
    if (tag == 'svg') return nsSvg;
    if (tag == 'math') return nsMathMl;
  }
  return ns;
}

int _mathMlChildNs(String tag, ElementNode parent, int ns) {
  if (parent.tag == 'annotation-xml') {
    if (tag == 'svg') return nsSvg;
    final htmlIntegration = parent.props.any((a) =>
        a is AttributeNode &&
        a.name == 'encoding' &&
        a.value != null &&
        (a.value!.content == 'text/html' ||
            a.value!.content == 'application/xhtml+xml'));
    if (htmlIntegration) return nsHtml;
    return ns;
  }
  final miNs = RegExp(r'^m(?:[ions]|text)$').hasMatch(parent.tag);
  if (miNs && tag != 'mglyph' && tag != 'malignmark') return nsHtml;
  return ns;
}

bool domBuiltInComponent(String tag) =>
    tag == 'Transition' ||
    tag == 'transition' ||
    tag == 'TransitionGroup' ||
    tag == 'transition-group';

/// parserOptions used by compiler-dom.
TmplParserOptions domParserOptions({
  int parseMode = modeHtml,
  bool comments = true,
  bool prefixIdentifiers = false,
  String whitespace = 'condense',
  bool Function(String tag)? isCustomElement,
  void Function(TmplParseError e)? onError,
}) {
  return TmplParserOptions(
    parseMode: parseMode,
    comments: comments,
    prefixIdentifiers: prefixIdentifiers,
    whitespace: whitespace,
    isVoidTag: isVoidTag,
    isNativeTag: domNativeTag,
    isPreTag: (tag) => tag == 'pre',
    isIgnoreNewlineTag: (tag) => tag == 'pre' || tag == 'textarea',
    isCustomElement: isCustomElement ?? ((tag) => false),
    isBuiltInComponent: (tag) => domBuiltInComponent(tag),
    getNamespace: domGetNamespace,
    onError: onError ?? ((e) {}),
  );
}
