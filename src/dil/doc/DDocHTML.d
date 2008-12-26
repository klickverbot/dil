/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.doc.DDocHTML;

import dil.doc.DDocEmitter;
import dil.doc.Macro;
import dil.semantic.Module;
import dil.Highlighter;
import common;

/// Traverses the syntax tree and writes DDoc macros to a string buffer.
class DDocHTMLEmitter : DDocEmitter
{
  /// Constructs a DDocHTMLEmitter object.
  this(Module modul, MacroTable mtable, bool includeUndocumented,
       Highlighter tokenHL)
  {
    super(modul, mtable, includeUndocumented, tokenHL);
  }
}
