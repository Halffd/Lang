/// Minimal Handlebars-compatible template engine supporting the
/// Yomitan/jp-mining-note template feature subset:
///
/// - `{{~! comments ~}}`
/// - `{{#*inline "name"}}...{{/inline}}` partial definitions
/// - `{{~> name args~}}` partial invocation
/// - `{{set "name" value}}`, `{{~#set "name"~}}...{{~/set~}}`
/// - `{{get "name"}}`
/// - `{{#if}}/{{else}}/{{else if}}`, `{{#unless}}`
/// - `{{#each}}` with @index/@last/@first
/// - `{{#scope}}`, `{{#with}}`
/// - `{{#regexMatch pattern flags}}...{{/regexMatch}}`
/// - `{{#regexReplace pattern replacement flags}}...{{/regexReplace}}`
/// - `{{op "..." a b}}` operator dispatch
/// - triple-stash `{{{...}}}` (unescaped) and `{{...}}` (escaped)
/// - whitespace control `~`
/// - `{{.}}`, `{{this}}`, `{{../x}}` context paths
///
/// Not supported (gracefully skipped): {{formatGlossary}}, {{furigana}},
/// {{getMedia}}/{{hasMedia}}, {{pronunciation}} and other Yomitan
/// native helpers - they render as empty strings unless overridden.

class HandlebarsEngine {
  final Map<String, List<_AstNode>> _partials = {};
  final Map<String, dynamic> _partialArgs = {};

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  /// Render [template] with [data]. Returns the expanded string.
  static String render(String template, Map<String, dynamic> data) {
    final engine = HandlebarsEngine._();
    return engine._renderTemplate(template, data);
  }

  /// Render using pre-registered partials (for template chains).
  static String renderWithPartials(
    String template,
    Map<String, String> partials,
    Map<String, dynamic> data,
  ) {
    final engine = HandlebarsEngine._();
    for (final e in partials.entries) {
      engine._partials[e.key] = _Parser(e.value).parse();
    }
    return engine._renderTemplate(template, data);
  }

  // ------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------

  HandlebarsEngine._();

  String _renderTemplate(String template, Map<String, dynamic> data) {
    final nodes = _Parser(template).parse();
    // two passes: first collects inline partials, second renders
    _collectPartials(nodes);
    final ctx = _Context(data);
    final sb = StringBuffer();
    _renderNodes(nodes, ctx, sb);
    return sb.toString();
  }

  void _collectPartials(List<_AstNode> nodes) {
    for (final n in nodes) {
      if (n is _InlineDefNode) {
        _partials[n.name] = n.body;
        _collectPartials(n.body);
      } else if (n is _BlockNode) {
        _collectPartials(n.children);
        if (n.inverse != null) _collectPartials(n.inverse!);
      }
    }
  }

  void _renderNodes(List<_AstNode> nodes, _Context ctx, StringBuffer out) {
    for (final n in nodes) {
      _renderNode(n, ctx, out);
    }
  }

  void _renderNode(_AstNode n, _Context ctx, StringBuffer out) {
    if (n is _TextNode) {
      out.write(n.text);
    } else if (n is _InlineDefNode) {
      // already collected - no output
      return;
    } else if (n is _ExprNode) {
      final v = _evalExpr(n.expr, ctx);
      if (v != null) {
        out.write(n.unescaped ? v.toString() : _escape(v.toString()));
      }
    } else if (n is _PartialNode) {
      final partial = _partials[n.name];
      if (partial != null) {
        final saved = _partialArgs;
        _partialArgs.clear();
        for (final e in n.args.entries) {
          _partialArgs[e.key] = _evalArg(e.value, ctx);
        }
        // partial sees current context + args
        final pctx = _Context(ctx.data, parent: ctx);
        pctx.data.addAll(_partialArgs);
        _renderNodes(partial, pctx, out);
        _partialArgs
          ..clear()
          ..addAll(saved);
      }
    } else if (n is _SetNode) {
      ctx.setVar(n.name, _evalArg(n.value, ctx));
    } else if (n is _GetNode) {
      final v = ctx.getVar(n.name);
      if (v != null) out.write(v.toString());
    } else if (n is _BlockNode) {
      _renderBlock(n, ctx, out);
    } else if (n is _RegexNode) {
      _renderRegex(n, ctx, out);
    } else if (n is _OpNode) {
      final result = _evalOp(n, ctx);
      if (result != null) out.write(result.toString());
    }
  }

  void _renderBlock(_BlockNode n, _Context ctx, StringBuffer out) {
    switch (n.type) {
      case 'if':
        final cond = _truthy(_evalArg(n.value, ctx));
        if (cond) {
          _renderNodes(n.children, ctx, out);
        } else {
          // else-if chains not supported; render inverse
          if (n.inverse != null) _renderNodes(n.inverse!, ctx, out);
        }
      case 'unless':
        if (!_truthy(_evalArg(n.value, ctx))) {
          _renderNodes(n.children, ctx, out);
        } else if (n.inverse != null) {
          _renderNodes(n.inverse!, ctx, out);
        }
      case 'each':
        final list = _evalArg(n.value, ctx);
        if (list is List) {
          if (list.isEmpty) {
            if (n.inverse != null) _renderNodes(n.inverse!, ctx, out);
            return;
          }
          for (var i = 0; i < list.length; i++) {
            final raw = list[i];
            Map<String, dynamic>? mapItem;
            if (raw is Map<String, dynamic>) {
              mapItem = raw;
            } else if (raw is Map) {
              mapItem = raw.map((k, v) => MapEntry(k.toString(), v));
            }
            final ictx = mapItem != null
                ? _Context(mapItem, parent: ctx)
                : _Context({}, parent: ctx, thisValue: raw);
            ictx.setVar('@index', i);
            ictx.setVar('@first', i == 0);
            ictx.setVar('@last', i == list.length - 1);
            _renderNodes(n.children, ictx, out);
          }
        }
      case 'scope':
        final sctx = _Context(ctx.data, parent: ctx);
        _renderNodes(n.children, sctx, out);
      case 'with':
        final v = _evalArg(n.value, ctx);
        if (v is Map) {
          final wctx = _Context(Map<String, dynamic>.from(v), parent: ctx);
          _renderNodes(n.children, wctx, out);
        } else if (v != null) {
          _renderNodes(n.children, ctx, out);
        }
      default:
        // unknown block: render children (graceful degradation)
        _renderNodes(n.children, ctx, out);
    }
  }

  void _renderRegex(_RegexNode n, _Context ctx, StringBuffer out) {
    final inner = _renderToString(n.body, ctx);
    final pattern = _stringArg(n.pattern, ctx);

    if (n.type == 'regexMatch') {
      // {{#regexMatch pattern flags}}content{{/regexMatch}}
      // renders content only where pattern matches content - per
      // Yomitan semantics: match pattern against the *block content*
      // and output matched substrings. Reverse usage in
      // jpmn-get-dict-type: pattern is a dict-regex, content is
      // dictionary name; outputs dictionary name if it matches.
      try {
        final re = RegExp(pattern);
        if (re.hasMatch(inner)) {
          out.write(inner);
        }
      } catch (_) {}
    } else {
      // regexReplace
      final replacement = _stringArg(n.replacement as _Arg, ctx);
      try {
        final re = RegExp(pattern);
        out.write(
          inner.replaceAllMapped(re, (m) {
            var r = replacement;
            for (var i = 0; i <= m.groupCount; i++) {
              final g = m.group(i);
              if (g != null) r = r.replaceAll('\$$i', g);
            }

            return r;
          }),
        );
      } catch (_) {
        out.write(inner);
      }
    }
  }

  String _renderToString(List<_AstNode> nodes, _Context ctx) {
    final sb = StringBuffer();
    _renderNodes(nodes, ctx, sb);
    return sb.toString();
  }

  // ------------------------------------------------------------
  // Expression evaluation
  // ------------------------------------------------------------

  dynamic _evalArg(_Arg arg, _Context ctx) {
    if (arg is _LiteralArg) return arg.value;
    if (arg is _PathArg) return _lookupPath(arg.path, ctx);
    if (arg is _HelperArg) return _evalHelper(arg, ctx);
    if (arg is _RawArg) {
      return _renderToString(arg.value.nodes, _Context(ctx.data, parent: ctx));
    }
    return null;
  }

  dynamic _evalExpr(String raw, _Context ctx) {
    // strip whitespace control leftovers
    final expr = raw.trim();
    if (expr.isEmpty) return null;
    if (expr == '.' || expr == 'this') {
      return ctx.thisValue ?? ctx.data;
    }

    // {{set ...}} and {{get ...}} handled by node types; here only
    // plain paths and helper calls appear
    if (expr.startsWith('get ')) {
      final name = _Parser._parseStringLiteral(expr.substring(4));
      return ctx.getVar(name);
    }
    if (expr.startsWith('op ')) {
      return _evalOpInline(expr.substring(3), ctx);
    }
    if (expr.startsWith('concat ')) {
      final parts = _Parser._parseArgsStatic(expr.substring(7));
      return parts.map((p) => _evalArg(p, ctx)?.toString() ?? '').join();
    }
    if (expr.startsWith('dictionaryAlias')) return ctx.get('dictionaryAlias');

    return _lookupPath(expr, ctx);
  }

  dynamic _evalHelper(_HelperArg arg, _Context ctx) {
    switch (arg.name) {
      case 'get':
        if (arg.args.isNotEmpty) {
          final name = _evalArg(arg.args[0], ctx)?.toString() ?? '';
          return ctx.getVar(name);
        }
        return null;
      case 'op':
        final values = arg.args.map((a) => _evalArg(a, ctx)).toList();
        if (values.length < 2) return null;
        final opName = values[0]?.toString();
        // unary operators take one operand
        if (values.length == 2 && (opName == '!' || opName == '-')) {
          if (opName == '!') return !_truthy(values[1]);
          return -_num(values[1]);
        }
        if (values.length < 3) return null;
        return _op(opName, values[1], values[2]);
      case 'concat':
        return arg.args.map((a) => _evalArg(a, ctx)?.toString() ?? '').join();
      case 'spread':
        final lists = arg.args.map((a) => _evalArg(a, ctx)).toList();
        final out = <dynamic>[];
        for (final l in lists) {
          if (l is List) out.addAll(l);
        }
        return out;
      case 'property':
        final obj = _evalArg(arg.args[0], ctx);
        final prop = _evalArg(arg.args[1], ctx);
        if (obj is List && prop == 'length') return obj.length;
        if (obj is Map && obj.containsKey(prop)) return obj[prop];
        return null;
      case 'regexMatch':
        final pattern = _evalArg(arg.args[0], ctx)?.toString() ?? '';
        final content = arg.args.length > 2
            ? _evalArg(arg.args[2], ctx)?.toString() ?? ''
            : '';
        try {
          final re = RegExp(pattern);
          if (re.hasMatch(content)) return content;
          return '';
        } catch (_) {
          return '';
        }
      case 'hiragana':
        return _evalArg(arg.args[0], ctx)?.toString() ?? '';
      case 'lookup':
        final obj = _evalArg(arg.args[0], ctx);
        final key = _evalArg(arg.args[1], ctx);
        if (obj is Map && key != null && obj.containsKey(key.toString())) {
          return obj[key.toString()];
        }
        return null;
      default:
        return null;
    }
  }

  dynamic _evalOpInline(String raw, _Context ctx) {
    final argNodes = _Parser._parseArgsStatic(raw);
    final values = argNodes.map((a) => _evalArg(a, ctx)).toList();
    if (values.isEmpty) return null;
    final op = values[0]?.toString();
    if (values.length < 3) return null;
    return _op(op, values[1], values[2]);
  }

  dynamic _evalOp(_OpNode n, _Context ctx) {
    final values = n.args.map((a) => _evalArg(a, ctx)).toList();
    if (values.length < 3) return null;
    return _op(values[0]?.toString(), values[1], values[2]);
  }

  dynamic _op(String? op, dynamic a, dynamic b) {
    switch (op) {
      case '==':
        return a.toString() == b.toString();
      case '===':
        return _strictEq(a, b);
      case '!=':
        return a.toString() != b.toString();
      case '!==':
        return !_strictEq(a, b);
      case '<':
        return _num(a) < _num(b);
      case '<=':
        return _num(a) <= _num(b);
      case '>':
        return _num(a) > _num(b);
      case '>=':
        return _num(a) >= _num(b);
      case '+':
        return _num(a) + _num(b);
      case '-':
        return _num(a) - _num(b);
      case '*':
        return _num(a) * _num(b);
      case '/':
        return _num(a) / _num(b);
      case '%':
        return _num(a) % _num(b);
      case '&&':
        return _truthy(a) && _truthy(b);
      case '||':
        return _truthy(a) || _truthy(b);
      case '!':
        return !_truthy(b);
      case '>>':
        return _num(a).toInt() >> _num(b).toInt();
      default:
        return null;
    }
  }

  bool _strictEq(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a is num && b is num) return a == b;
    if (a.runtimeType == b.runtimeType) return a == b;
    return a.toString() == b.toString();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  dynamic _lookupPath(String path, _Context ctx) {
    if (path.startsWith('../')) {
      return ctx.parent != null
          ? _lookupPath(path.substring(3), ctx.parent!)
          : null;
    }
    // @root special
    if (path.startsWith('@root.')) {
      var root = ctx;
      while (root.parent != null) {
        root = root.parent!;
      }
      return _lookupPath(path.substring(6), root);
    }
    // variable lookup first (set/get)
    final segs = path.split('.');
    final first = segs.first;
    final v = ctx.getVar(first);
    if (v != null && segs.length == 1) return v;
    if (v != null) {
      dynamic cur = v;
      for (final s in segs.skip(1)) {
        if (cur is Map && cur.containsKey(s)) {
          cur = cur[s];
        } else if (cur is List) {
          final i = int.tryParse(s);
          if (i != null && i < cur.length) {
            cur = cur[i];
          } else {
            return null;
          }
        } else {
          return null;
        }
      }
      return cur;
    }
    // data lookup
    return ctx.get(path);
  }

  String _stringArg(_Arg a, _Context ctx) {
    final v = _evalArg(a, ctx);
    return v?.toString() ?? '';
  }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) {
      // "false" string is falsy in handlebars-js jpmn templates
      return v.isNotEmpty && v != 'false' && v != '0';
    }
    if (v is num) return v != 0;
    if (v is List) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    return true;
  }

  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;');
}

// ============================================================
// Context
// ============================================================

class _Context {
  final Map<String, dynamic> data;
  final _Context? parent;
  final Map<String, dynamic> _vars = {};
  final dynamic thisValue;

  _Context(this.data, {this.parent, this.thisValue});

  void setVar(String name, dynamic value) => _vars[name] = value;

  dynamic getVar(String name) {
    if (_vars.containsKey(name)) return _vars[name];
    return parent?.getVar(name);
  }

  dynamic get(String path) {
    final segs = path.split('.');
    dynamic cur = data;
    for (final s in segs) {
      if (cur is Map && cur.containsKey(s)) {
        cur = cur[s];
      } else if (cur is List) {
        final i = int.tryParse(s);
        if (i != null && i >= 0 && i < cur.length) {
          cur = cur[i];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return cur;
  }
}

// ============================================================
// Parser + AST
// ============================================================

sealed class _AstNode {}

class _TextNode extends _AstNode {
  final String text;
  _TextNode(this.text);
}

class _ExprNode extends _AstNode {
  final String expr;
  final bool unescaped;
  _ExprNode(this.expr, {this.unescaped = false});
}

class _InlineDefNode extends _AstNode {
  final String name;
  final List<_AstNode> body;
  _InlineDefNode(this.name, this.body);
}

class _PartialNode extends _AstNode {
  final String name;
  final Map<String, _Arg> args;
  _PartialNode(this.name, this.args);
}

class _SetNode extends _AstNode {
  final String name;
  final _Arg value;
  _SetNode(this.name, this.value);
}

class _GetNode extends _AstNode {
  final String name;
  _GetNode(this.name);
}

class _BlockNode extends _AstNode {
  final String type;
  final _Arg value;
  final List<_AstNode> children;
  final List<_AstNode>? inverse;
  _BlockNode(this.type, this.value, this.children, [this.inverse]);
}

class _RegexNode extends _AstNode {
  final String type; // regexMatch | regexReplace
  final _Arg pattern;
  final _Arg? replacement;
  final _Arg? flags;
  final List<_AstNode> body;
  _RegexNode(this.type, this.pattern, this.replacement, this.flags, this.body);
}

class _OpNode extends _AstNode {
  final List<_Arg> args;
  _OpNode(this.args);
}

// ---------------- arguments ----------------

sealed class _Arg {}

class _LiteralArg extends _Arg {
  final dynamic value;
  _LiteralArg(this.value);
}

class _PathArg extends _Arg {
  final String path;
  _PathArg(this.path);
}

class _HelperArg extends _Arg {
  final String name;
  final List<_Arg> args;
  _HelperArg(this.name, this.args);
}

class _Parser {
  final String src;
  int pos = 0;

  _Parser(this.src);

  // tag regex: {{{ or {{, optional ~ prefix/suffix, body, }} or }}}
  static final RegExp _tagRe = RegExp(r'\{\{\{?([^{}]*?)\}?\}\}');

  List<_AstNode> parse() => _parse(null) ?? <_AstNode>[];

  // ---------------- core scanner ----------------

  List<_AstNode>? _parse(String? stopType) {
    final out = <_AstNode>[];
    while (pos < src.length) {
      final remaining = src.substring(pos);
      final m = _tagRe.firstMatch(remaining);
      if (m == null) {
        out.add(_TextNode(remaining));
        pos = src.length;
        if (stopType != null) return null; // unterminated
        return out;
      }

      var text = remaining.substring(0, m.start);
      var tag = m.group(0)!;
      var body = m.group(1)!;
      _lastTagWasTriple = tag.startsWith('{{{');

      // whitespace control: leading ~ trims preceding text right,
      final lTrim = body.startsWith('~');
      final rTrim = body.endsWith('~') || tag.contains('~}}');
      if (lTrim) body = body.substring(1);
      if (body.endsWith('~')) body = body.substring(0, body.length - 1);
      if (lTrim) text = text.trimRight();
      if (text.isNotEmpty) out.add(_TextNode(text));
      pos += m.end;

      body = body.trim();
      final rTrimText = rTrim;

      if (body.startsWith('!')) continue;

      final isBlock = body.startsWith('#');
      final isClose = body.startsWith('/');
      final isPartial = body.startsWith('>');
      var inner = body;
      if (isBlock || isClose || isPartial) inner = body.substring(1).trim();
      if (inner.startsWith('~')) inner = inner.substring(1).trim();

      // closing tag
      if (isClose) {
        final t = _blockTypeOf(inner) ?? inner.trim();
        if (stopType != null && t == stopType) {
          if (rTrimText) _trimLastTextRight(out);
          return out; // normal block end: return accumulated nodes
        }
        if (stopType == null) continue; // stray close
        return out; // some other close: caller re-checks
      }

      // else: only meaningful when a block is being parsed
      if (stopType != null && (inner == 'else' || inner.startsWith('else '))) {
        if (rTrimText) _trimLastTextRight(out);
        _atElse = true;
        return out;
      }

      _parseTag(inner, isBlock, isPartial, out, stopType, rTrimText);
      // handle trailing ~: trim next text's left - implemented via
      // flag stored on parser
    }
    return out;
  }

  bool _atElse = false;

  void _parseTag(
    String inner,
    bool isBlock,
    bool isPartial,
    List<_AstNode> out,
    String? stopType,
    bool rTrim,
  ) {
    // inline partial def: {{#*inline "name"}}
    final inlineMatch = RegExp(r'^\*?inline\s+"([^"]+)"').firstMatch(inner);
    if (isBlock && inlineMatch != null) {
      final body = _parse('inline');
      out.add(_InlineDefNode(inlineMatch.group(1)!, body ?? const []));
      return;
    }

    // partial invocation {{> name key=val}}
    if (isPartial) {
      if (inner.startsWith('(lookup')) {
        final mm = RegExp(
          r'\(\s*lookup\s+\S+\s+"([^"]+)"\s*\)',
        ).firstMatch(inner);
        out.add(_PartialNode(mm?.group(1) ?? '', {}));
        return;
      }
      final name = inner.split(RegExp(r'\s+')).first;
      final rest = inner.length > name.length
          ? inner.substring(name.length)
          : '';
      out.add(_PartialNode(name, _parsePartialArgs(rest)));
      return;
    }

    // set
    if (!isBlock && inner.startsWith('set ')) {
      final nv = _parseSetNameValue(inner.substring(4));
      out.add(_SetNode(nv.$1, nv.$2));
      return;
    }
    if (isBlock && inner.startsWith('set ')) {
      // {{#set "name"~}}body{{/set}}
      final nv = _parseSetNameValue(inner.substring(4));
      final body = _parse('set');
      final rendered = _SubexprValue(body ?? const []);
      out.add(_SetNode(nv.$1, _RawArg(rendered)));
      return;
    }

    // get
    if (!isBlock && inner.startsWith('get ')) {
      out.add(_GetNode(_parseStringLiteral(inner.substring(4))));
      return;
    }

    // op expression
    if (!isBlock && inner.startsWith('op ')) {
      out.add(_OpNode(_parseArgs(inner.substring(3))));
      return;
    }

    // regex blocks
    if (isBlock &&
        (inner.startsWith('regexMatch') || inner.startsWith('regexReplace'))) {
      final isMatch = inner.startsWith('regexMatch');
      final rest = inner
          .replaceFirst('regexMatch', '')
          .replaceFirst('regexReplace', '')
          .trim();
      final args = _parseArgs(rest);
      final body = _parse(isMatch ? 'regexMatch' : 'regexReplace');
      if (isMatch) {
        out.add(
          _RegexNode(
            'regexMatch',
            args.isNotEmpty ? args[0] : _LiteralArg(''),
            null,
            args.length > 1 ? args[1] : null,
            body ?? const [],
          ),
        );
      } else {
        out.add(
          _RegexNode(
            'regexReplace',
            args.isNotEmpty ? args[0] : _LiteralArg(''),
            args.length > 1 ? args[1] : _LiteralArg(''),
            null,
            body ?? const [],
          ),
        );
      }
      return;
    }

    // generic block
    final blockType = isBlock ? _blockTypeOf(inner) : null;
    if (isBlock && blockType != null) {
      final argRaw = inner.substring(blockType.length).trim();
      final value = argRaw.isEmpty ? _LiteralArg(true) : _parseOne(argRaw);
      _atElse = false;
      final children = _parse(blockType) ?? const <_AstNode>[];
      List<_AstNode>? inverse;
      if (_atElse) {
        _atElse = false;
        inverse = _parse(blockType) ?? const <_AstNode>[];
      }
      out.add(_BlockNode(blockType, value, children, inverse));
      return;
    }

    // plain expression
    final unescaped = _lastTagWasTriple;
    out.add(_ExprNode(inner, unescaped: unescaped));
  }

  bool _lastTagWasTriple = false;

  // trim trailing whitespace of the last text node (whitespace control)
  void _trimLastTextRight(List<_AstNode> out) {
    if (out.isNotEmpty && out.last is _TextNode) {
      out[out.length - 1] = _TextNode((out.last as _TextNode).text.trimRight());
    }
  }

  String? _blockTypeOf(String inner) {
    final e = inner.trim();
    for (final t in const [
      'if',
      'unless',
      'each',
      'scope',
      'with',
      'set',
      'regexMatch',
      'regexReplace',
    ]) {
      if (e == t ||
          e.startsWith('$t ') ||
          e.startsWith('$t(') ||
          e.startsWith('$t\\')) {
        return t;
      }
    }
    return null;
  }

  // ---------------- arg parsing ----------------

  static String _parseStringLiteral(String raw) {
    final m = RegExp(r'"([^"]*)"').firstMatch(raw.trim());
    return m?.group(1) ?? raw.trim();
  }

  /// Parse `{{set "name" value}}` into (name, arg).
  static (String, _Arg) _parseSetNameValue(String raw) {
    final m = RegExp(r'"([^"]+)"\s*(.*)$').firstMatch(raw.trim());
    if (m == null) return ('', _LiteralArg(''));
    final name = m.group(1)!;
    final valueRaw = (m.group(2) ?? '').trim();
    if (valueRaw.isEmpty) return (name, _LiteralArg(''));
    if (valueRaw == 'true') return (name, _LiteralArg(true));
    if (valueRaw == 'false') return (name, _LiteralArg(false));
    final args = _Parser._parseArgsStatic(valueRaw);
    if (args.length == 1) return (name, args[0]);
    return (name, _HelperArg('concat', args));
  }

  static List<_Arg> _parseArgsStatic(String raw) {
    return _Parser('')._parseArgs(raw);
  }

  List<_Arg> _parseArgs(String raw) {
    final args = <_Arg>[];
    var s = raw.trim();
    while (s.isNotEmpty) {
      final str = RegExp(r'^"([^"]*)"').firstMatch(s);
      final num = RegExp(r'^-?\d+(\.\d+)?').firstMatch(s);
      if (s.startsWith('(')) {
        var depth = 0;
        var i = 0;
        for (; i < s.length; i++) {
          if (s[i] == '(') depth++;
          if (s[i] == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        final inner = s.substring(1, i);
        final name = inner.split(RegExp(r'\s+')).first;
        final rest = inner.length > name.length
            ? inner.substring(name.length)
            : '';
        args.add(_HelperArg(name, _parseArgs(rest)));
        s = s.substring(i + 1).trim();
      } else if (str != null) {
        args.add(_LiteralArg(str.group(1)));
        s = s.substring(str.end).trim();
      } else if (num != null) {
        final v = num.group(0)!;
        args.add(_LiteralArg(v.contains('.') ? double.parse(v) : int.parse(v)));
        s = s.substring(num.end).trim();
      } else {
        final path = RegExp(r'^[^\s")]+').firstMatch(s);
        if (path == null) break;
        args.add(_PathArg(path.group(0)!));
        s = s.substring(path.end).trim();
      }
    }
    return args;
  }

  _Arg _parseOne(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return _LiteralArg('');
    if (s == 'true') return _LiteralArg(true);
    if (s == 'false') return _LiteralArg(false);
    final parsed = _parseArgs(s);
    if (parsed.length == 1) return parsed[0];
    return _HelperArg('concat', parsed);
  }

  Map<String, _Arg> _parsePartialArgs(String raw) {
    final args = <String, _Arg>{};
    for (final m in RegExp(r'([\w@.]+)=(\S+)').allMatches(raw)) {
      args[m.group(1)!] = _parseOne(m.group(2)!);
    }
    return args;
  }
}

/// Holds pre-rendered set-block value.
class _SubexprValue {
  final List<_AstNode> nodes;
  _SubexprValue(this.nodes);
}

class _RawArg extends _Arg {
  final _SubexprValue value;
  _RawArg(this.value);
}
