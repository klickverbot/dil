/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.semantic.Mangler;

import dil.ast.Visitor,
       dil.ast.Node,
       dil.ast.Expressions;
import dil.lexer.Funcs : String, StringHex;
import dil.semantic.TypesEnum;
import dil.i18n.Messages;
import dil.Float,
       dil.Unicode,
       dil.Diagnostics;
import common;

/// Mangles expressions used as template arguments.
class TArgMangler : Visitor2
{
  char[] text; /// The mangled text.
  Diagnostics diag;
  char[] filePath;

  void mangleFloat(Float f)
  {
    if (f.isNaN())
      text ~= "NAN";
    // FIXME:
    // Replace('-', 'N')
    // Ignore('+', 'X', '.')
    // Ignore leading 0. E.g.: "0X123" -> "123"

    // Converting from Float to long double is probably inaccurate.
    // Matching the mangled strings of DMD will be difficult.
    // Just use Float.toString() for now.
    text ~= f.toString();
  }

  /// Issues an error message.
  void error(Token* tok, MID mid, ...)
  {
    auto location = tok.getErrorLocation(filePath);
    auto msg = diag.formatMsg(mid, _arguments, _argptr);
    auto error = new SemanticError(location, msg);
    diag ~= error;
  }

  void utf16Error(Token* tok, wchar[] s, size_t i)
  {
    auto e = dil.Unicode.utf16Error(s, i);
    ushort arg1 = s[i-1], arg2 = arg1;
    MID mid = MID.InvalidUTF16Sequence;
    if (e == UTF16Error.Invalid)
      arg1 = s[i-2];
    else if (e == UTF16Error.LoSurrogate)
      mid = MID.MissingLowSurrogate;
    else if (e == UTF16Error.HiSurrogate)
      mid = MID.MissingHighSurrogate;
    else
      assert(0);
    error(tok, mid, arg1, arg2);
  }

override:
  void unhandled(Node n)
  {
    error(n.begin, MID.InvalidTemplateArgument, n.toText());
  }

  void visit(IntExpr e)
  {
    if (cast(long)e.number < 0)
      text ~= 'N' ~ String(-e.number);
    else
      text ~= 'i' ~ String(e.number);
  }

  void visit(FloatExpr e)
  {
    text ~= 'e';
    mangleFloat(e.number);
  }

  void visit(ComplexExpr e)
  {
    text ~= 'c';
    mangleFloat(e.re);
    text ~= 'c';
    mangleFloat(e.im);
  }

  void visit(NullExpr e)
  {
    text ~= 'n';
  }

  void visit(StringExpr e)
  { // := MangleChar UTF8StringLength "_" UTF8StringInHex
    char mc; // Mangle character.
    char[] utf8str;
    switch (e.charType.tid)
    {
    case TYP.Char:
      mc = 'a';
      utf8str = cast(char[])e.str;
      break;
    case TYP.WChar:
      mc = 'w';
      wchar[] tmp = (cast(wchar[])e.str)[0..$-1];
      for (size_t i; i < tmp.length;)
      {
        auto c = decode(tmp, i);
        if (c == ERROR_CHAR) {
          utf16Error(e.begin, tmp, i);
          break;
        }
        else
          encode(utf8str, c);
      }
      break;
    case TYP.DChar:
      mc = 'd';
      dchar[] tmp = (cast(dchar[])e.str)[0..$-1];
      foreach (dchar c; tmp)
        if (!isValidChar(c)) {
          error(e.begin, MID.InvalidUTF32Character, c+0);
          break;
        }
        else
          encode(utf8str, c);
      break;
    default: assert(0);
    }
    // Finally append the mangled string.
    text ~= mc ~ String(utf8str.length) ~ "_" ~ StringHex(utf8str);
  }

  void visit(ArrayLiteralExpr e)
  {
    text ~= 'A' ~ String(e.values.length);
    foreach (val; e.values)
      visitN(val);
  }

  void visit(AArrayLiteralExpr e)
  {
    text ~= 'A' ~ String(e.values.length);
    foreach (i, key; e.keys)
      visitN(key), visitN(e.values[i]);
  }

  void visit(StructInitExpr e)
  {
    text ~= 'S' ~ String(e.values.length);
    foreach (val; e.values)
      if (val.kind == NodeKind.VoidInitExpr)
        text ~= 'v';
      else
        visitN(val);
  }
}
