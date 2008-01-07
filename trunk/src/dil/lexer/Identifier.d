/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.lexer.Identifier;

import dil.lexer.TokensEnum;
import dil.lexer.IdentsEnum;
import common;

align(1)
struct Identifier
{
  string str;
  TOK type;
  ID identID;

  static Identifier* opCall(string str, TOK type)
  {
    auto id = new Identifier;
    id.str = str;
    id.type = type;
    return id;
  }

  static Identifier* opCall(string str, TOK type, ID identID)
  {
    auto id = new Identifier;
    id.str = str;
    id.type = type;
    id.identID = identID;
    return id;
  }

  uint toHash()
  {
    uint hash;
    foreach(c; str) {
      hash *= 11;
      hash += c;
    }
    return hash;
  }
}
// pragma(msg, Identifier.sizeof.stringof);