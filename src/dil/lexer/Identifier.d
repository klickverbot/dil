/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.Identifier;

import dil.lexer.TokensEnum,
       dil.lexer.IdentsEnum,
       dil.lexer.Funcs : hashOf;
import common;

/// Represents an identifier as defined in the D specs.
///
/// $(BNF
////Identifier := IdStart IdChar*
////   IdStart := "_" | Letter
////    IdChar := IdStart | "0"-"9"
////    Letter := UniAlpha
////)
/// See_Also:
///  Unicode alphas are defined in Unicode 5.0.0.
align(1)
struct Identifier
{
  string str; /// The UTF-8 string of the identifier.
  TOK kind;   /// The token kind.
  IDK idKind; /// Only for predefined identifiers.

  /// Constructs an Identifier.
  static Identifier* opCall(string str, TOK kind)
  {
    auto id = new Identifier;
    id.str = str;
    id.kind = kind;
    return id;
  }
  /// ditto
  static Identifier* opCall(string str, TOK kind, IDK idKind)
  {
    auto id = new Identifier;
    id.str = str;
    id.kind = kind;
    id.idKind = idKind;
    return id;
  }

  /// Calculates a hash for this id.
  hash_t toHash()
  {
    return hashOf(str);
  }

  /// Returns the string of this id.
  string toString()
  {
    return str;
  }

  /// Returns true if this id starts with prefix.
  bool startsWith(string prefix)
  {
    auto plen = prefix.length;
    return str.length > plen && str[0..plen] == prefix;
  }
}
// pragma(msg, Identifier.sizeof.stringof);
