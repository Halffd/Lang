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
  final Map<String, Function> _helpers = {};

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  /// Render [template] with [data]. Returns the expanded string.
  /// [helpers] are named functions callable as
  /// `{{helpername arg}}` or `{{#if (helpername arg)}}`.
  static String render(
    String template,
    Map<String, dynamic> data, {
    Map<String, Function>? helpers,
  }) {
    final engine = HandlebarsEngine._();
    if (helpers != null) engine._helpers.addAll(helpers);
    return engine._renderTemplate(template, data);
  }

  /// Render using pre-registered partials (for template chains).
  static String renderWithPartials(
    String template,
    Map<String, String> partials,
    Map<String, dynamic> data, {
    Map<String, Function>? helpers,
  }) {
    final engine = HandlebarsEngine._();
    if (helpers != null) engine._helpers.addAll(helpers);
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
        final saved = Map<String, dynamic>.from(_partialArgs);
        _partialArgs.clear();
        for (final e in n.args.entries) {
          _partialArgs[e.key] = _evalArg(e.value, ctx);
        }
        // partial sees a copy of current context + args (never
        // mutate the caller's data map)
        final pData = <String, dynamic>{};
        pData.addAll(ctx.data);
        pData.addAll(_partialArgs);
        final pctx = _Context(pData, parent: ctx);
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
                : _Context(
                    {},
                    parent: ctx,
                    thisValue: raw,
                    isNullItem: raw == null,
                  );
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
    final pattern = _stringArg(n.pattern, ctx);

    if (n.type == 'regexMatch') {
      // {{#regexMatch pattern flags}}content{{/regexMatch}}
      // Yomitan semantics: output the content only when pattern
      // matches it. Side effects (set) inside the body must NOT run
      // when the match fails, so render into a snapshot and commit
      // only on success.
      // render into a sandbox copy; if the pattern does not match,
      // discard the body entirely (including any set side effects)
      final before = _collectVars(ctx);
      final sandbox = _Context(ctx.data, parent: ctx.parent);
      sandbox._vars.addAll(before);
      final sb = StringBuffer();
      _renderNodes(n.body, sandbox, sb);
      final inner = sb.toString();
      var matched = false;
      try {
        matched = RegExp(pattern).hasMatch(inner);
      } catch (_) {}
      if (matched) {
        // commit: replay body against the real context so sets
        // inside persist
        _renderNodes(n.body, ctx, out);
      } else {
        // rollback writes the trial render pushed into ancestors
        _restoreVars(ctx, before);
      }
    } else {
      // regexReplace: side effects in body always run
      final inner = _renderToString(n.body, ctx);
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

  /// Copy var values from this context and all ancestors.
  Map<String, dynamic> _collectVars(_Context ctx) {
    final vars = <String, dynamic>{};
    // collect from root down so nearer scopes overwrite ancestors
    final chain = <_Context>[];
    for (_Context? c = ctx; c != null; c = c.parent) {
      chain.add(c);
    }
    for (final c in chain.reversed) {
      vars.addAll(c._vars);
    }
    return vars;
  }

  /// Restore var state across the whole chain after a rolled-back
  /// render: values changed vs [before] are reset.
  void _restoreVars(_Context? ctx, Map<String, dynamic> before) {
    for (_Context? c = ctx; c != null; c = c.parent) {
      final scope = c;
      scope._vars.removeWhere((k, v) => !before.containsKey(k));
      for (final e in before.entries) {
        scope._vars[e.key] = e.value;
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
      // null each-item renders empty, scalars as themselves
      if (ctx.isNullItem) return '';
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

    // registered helper called without parens: {{helpername arg ...}}
    final firstSpace = expr.indexOf(' ');
    if (firstSpace > 0) {
      final helperName = expr.substring(0, firstSpace);
      // registered helper functions (bare call syntax)
      final fn = _helpers[helperName];
      if (fn != null) {
        final args = _Parser._parseArgsStatic(expr.substring(firstSpace + 1));
        final values = args.map((a) => _evalArg(a, ctx)).toList();
        try {
          return Function.apply(fn, values);
        } catch (_) {
          return null;
        }
      }
      // built-in helpers in bare call syntax: {{property m "k"}}
      const builtins = [
        'concat',
        'spread',
        'property',
        'lookup',
        'regexMatch',
        'hiragana',
      ];
      if (builtins.contains(helperName)) {
        final args = _Parser._parseArgsStatic(expr.substring(firstSpace + 1));
        return _evalHelper(_HelperArg(helperName, args), ctx);
      }
    }

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
        // registered helper functions (hasMedia, getMedia, ...)
        final fn = _helpers[arg.name];
        if (fn != null) {
          final args = arg.args.map((a) => _evalArg(a, ctx)).toList();
          try {
            return Function.apply(fn, args);
          } catch (_) {
            return null;
          }
        }
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
    // strict: different runtime types are never equal (no coercion)
    if (a.runtimeType != b.runtimeType) return false;
    return a == b;
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
    // this.x refers to the current context item
    if (path.startsWith('this.')) {
      final base = ctx.thisValue ?? ctx.data;
      final baseMap = base is Map<String, dynamic>
          ? base
          : (base is Map
                ? base.map((k, v) => MapEntry(k.toString(), v))
                : <String, dynamic>{});
      return _lookupPath(
        path.substring(5),
        _Context(baseMap, parent: ctx.parent),
      );
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
          if (s == 'length') {
            cur = cur.length;
          } else {
            final i = int.tryParse(s);
            if (i != null && i >= 0 && i < cur.length) {
              cur = cur[i];
            } else {
              return null;
            }
          }
        } else {
          return null;
        }
      }
      return cur;
    }
    // data lookup (handles .length on lists/strings)
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
  final bool isNullItem;

  _Context(this.data, {this.parent, this.thisValue, this.isNullItem = false});

  /// Set a variable at the scope where it was declared (nearest
  /// ancestor holding it), else the current scope. This keeps
  /// counters working inside {{#each}} child scopes.
  void setVar(String name, dynamic value) {
    _Context? owner;
    for (_Context? c = this; c != null; c = c.parent) {
      if (c._vars.containsKey(name)) {
        owner = c;
      }
    }
    (owner ?? this)._vars[name] = value;
  }

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
        if (s == 'length') {
          cur = cur.length;
        } else {
          final i = int.tryParse(s);
          if (i != null && i >= 0 && i < cur.length) {
            cur = cur[i];
          } else {
            return null;
          }
        }
      } else if (cur is String && s == 'length') {
        cur = cur.length;
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
        var tail = remaining;
        if (_pendingLeftTrim) tail = tail.trimLeft();
        out.add(_TextNode(tail));
        pos = src.length;
        // unterminated block: keep what we parsed (graceful)
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
      if (_pendingLeftTrim) text = text.trimLeft();
      _pendingLeftTrim = false;
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
          // right-~ on the closing tag trims the text after the block
          if (rTrimText) _pendingLeftTrim = true;
          return out; // normal block end: return accumulated nodes
        }
        if (stopType == null) continue; // stray close
        return out; // some other close: caller re-checks
      }

      // else: only meaningful when a block is being parsed
      if (stopType != null && (inner == 'else' || inner.startsWith('else '))) {
        if (rTrimText) _trimLastTextRight(out);
        if (rTrimText) _pendingLeftTrim = true;
        _atElse = true;
        return out;
      }

      // trailing ~ trims the next text node's left side; set BEFORE
      // parsing so nested block bodies see it too
      if (rTrimText) _pendingLeftTrim = true;
      _parseTag(inner, isBlock, isPartial, out, stopType, rTrimText);
    }
    return out;
  }

  bool _atElse = false;
  bool _pendingLeftTrim = false;

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
      // {{#set "name"~}}body{{/set}} - only a BLOCK set when there
      // is no inline value after the name
      final nv = _parseSetNameValue(inner.substring(4));
      final hasInlineValue =
          nv.$2 is! _LiteralArg ||
          (nv.$2 as _LiteralArg).value.toString().isNotEmpty;
      if (!hasInlineValue ||
          (nv.$2 is _LiteralArg && (nv.$2 as _LiteralArg).value == '')) {
        final body = _parse('set');
        final rendered = _SubexprValue(body ?? const []);
        out.add(_SetNode(nv.$1, _RawArg(rendered)));
      } else {
        // inline value: treat like {{set name value}}
        out.add(_SetNode(nv.$1, nv.$2));
      }
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
      final str = RegExp(r'^"((?:[^"\\]|\\.)*)"').firstMatch(s);
      final num = RegExp(r'^-?\d+(\.\d+)?').firstMatch(s);
      if (s.startsWith('(')) {
        var depth = 0;
        var i = 0;
        var closed = false;
        for (; i < s.length; i++) {
          if (s[i] == '(') depth++;
          if (s[i] == ')') {
            depth--;
            if (depth == 0) {
              closed = true;
              break;
            }
          }
        }
        if (!closed) {
          // unterminated subexpression: consume the rest as-is
          args.add(_LiteralArg(s));
          break;
        }
        final inner = s.substring(1, i);
        final name = inner.split(RegExp(r'\s+')).first;
        final rest = inner.length > name.length
            ? inner.substring(name.length)
            : '';
        args.add(_HelperArg(name, _parseArgs(rest)));
        s = s.substring(i + 1).trim();
      } else if (str != null) {
        // unescape " inside the string literal
        args.add(_LiteralArg(str.group(1)!.replaceAll(r'\"', '"')));
        s = s.substring(str.end).trim();
      } else if (num != null) {
        final v = num.group(0)!;
        args.add(_LiteralArg(v.contains('.') ? double.parse(v) : int.parse(v)));
        s = s.substring(num.end).trim();
      } else if (s == 'true' || s.startsWith('true ')) {
        args.add(_LiteralArg(true));
        s = s.substring(4).trim();
      } else if (s == 'false' || s.startsWith('false ')) {
        args.add(_LiteralArg(false));
        s = s.substring(5).trim();
      } else if (s == 'null' || s.startsWith('null ')) {
        args.add(_LiteralArg(null));
        s = s.substring(4).trim();
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
