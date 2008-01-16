/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.ast.Expression;

import dil.ast.Node;
import dil.semantic.Types;
import common;

/// The root class of all expressions.
abstract class Expression : Node
{
  Type type; /// The type of this expression.

  this()
  {
    super(NodeCategory.Expression);
  }

  Expression evaluate()
  {
    return null;
  }
}