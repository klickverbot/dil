/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.graphutils.modulenamewriter;
import docgen.graphutils.writer;

import tango.io.protocol.Writer : Writer;
import tango.io.FileConduit : FileConduit;
import tango.io.Print: Print;
import tango.text.convert.Layout : Layout;


/**
 * TODO: add support for html/xml/latex?
 */
class ModuleNameWriter : AbstractGraphWriter {
  this(GraphWriterFactory factory, OutputStream[] outputs) {
    super(factory, outputs);
    assert(outputs.length == 1, "Wrong number of outputs");
  }

  void generateGraph(Vertex[] vertices, Edge[] edges) {
    auto output = new Writer(outputs[0]);

    void doList(Vertex[] v, uint level, char[] indent = "") {
      if (!level) return;

      foreach (vertex; v) {
        output(indent)(vertex.name).newline;
        if (vertex.outgoing.length)
          doList(vertex.outgoing, level-1, indent ~ "  ");
      }
    }

    doList(vertices, factory.options.depth);
  }
}