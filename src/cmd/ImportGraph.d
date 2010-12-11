/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module cmd.ImportGraph;

import dil.ast.Node,
       dil.ast.Declarations;
import dil.semantic.Module,
       dil.semantic.Package;
import dil.parser.ImportParser,
       dil.lexer.Funcs : hashOf;
import dil.SourceText,
       dil.Compilation,
       dil.ModuleManager,
       dil.Diagnostics;
import util.Path;
import Settings;
import common;

import tango.text.Regex : RegExp = Regex;
import tango.text.Util;
import tango.io.model.IFile;

alias FileConst.PathSeparatorChar dirSep;

/// The importgraph command.
struct IGraphCommand
{
  /// Options for the command.
  enum Option
  {
    None,
    IncludeUnlocatableModules = 1,
    PrintDot                  = 1<<1,
    HighlightCyclicEdges      = 1<<2,
    HighlightCyclicVertices   = 1<<3,
    GroupByPackageNames       = 1<<4,
    GroupByFullPackageName    = 1<<5,
    PrintPaths                = 1<<6,
    PrintList                 = 1<<7,
    MarkCyclicModules         = 1<<8,
  }
  alias Option Options;

  Options options; /// Command options.
  string filePath; /// File path to the root module.
  string[] regexps; /// Regular expressions.
  string siStyle = "dashed"; /// Static import style.
  string piStyle = "bold";   /// Public import style.
  uint levels; /// How many levels to print.

  CompilationContext context;

  /// Adds o to the options.
  void add(Option o)
  {
    options |= o;
  }

  /// Executes the command.
  void run()
  {
    // Init regular expressions.
    RegExp[] regexps;
    foreach (strRegexp; this.regexps)
      regexps ~= new RegExp(strRegexp);

    // Add the directory of the file to the import paths.
    auto filePath = Path(this.filePath);
    context.importPaths ~= filePath.folder();

    auto gbuilder = new GraphBuilder(context);

    gbuilder.importPaths = context.importPaths;
    gbuilder.options = options;
    gbuilder.filterPredicate = (string moduleFQNPath) {
      foreach (rx; regexps)
        // Replace slashes: dil/ast/Node -> dil.ast.Node
        if (rx.test(replace(moduleFQNPath.dup, dirSep, '.')))
          return true;
      return false;
    };

    auto graph = gbuilder.start(filePath.name());

    if (options & (Option.PrintList | Option.PrintPaths))
    {
      if (options & Option.MarkCyclicModules)
        graph.detectCycles();

      if (options & Option.PrintPaths)
        printModulePaths(graph.vertices, levels+1, "");
      else
        printModuleList(graph.vertices, levels+1, "");
    }
    else
      printDotDocument(context, graph, siStyle, piStyle, options);
  }
}

/// Represents a module dependency graph.
class Graph
{
  Vertex[] vertices; /// The vertices or modules.
  Edge[] edges; /// The edges or import statements.

  /// Adds a vertex to the graph.
  void addVertex(Vertex vertex)
  {
    vertex.id = vertices.length;
    vertices ~= vertex;
  }

  /// Adds an edge between two vertices to the graph.
  Edge addEdge(Vertex from, Vertex to)
  {
    auto edge = new Edge(from, to);
    edges ~= edge;
    from.outgoing ~= to;
    to.incoming ~= from;
    return edge;
  }

  /// Walks the graph and marks cyclic vertices and edges.
  void detectCycles()
  { // Cycles could also be detected in the GraphBuilder,
    // but having the code here makes things much clearer.

    // Commented out because this algorithm doesn't work.
    // Returns true if the vertex is in status Visiting.
    /+bool visit(Vertex vertex)
    {
      switch (vertex.status)
      {
      case Vertex.Status.Visiting:
        vertex.isCyclic = true;
        return true;
      case Vertex.Status.None:
        vertex.status = Vertex.Status.Visiting; // Flag as visiting.
        foreach (outVertex; vertex.outgoing)    // Visit successors.
          vertex.isCyclic |= visit(outVertex);
        vertex.status = Vertex.Status.Visited;  // Flag as visited.
        break;
      case Vertex.Status.Visited:
        break;
      default:
        assert(0, "unknown vertex status");
      }
      return false; // return (vertex.status == Vertex.Status.Visiting);
    }
    // Start visiting vertices.
    visit(vertices[0]);+/

    //foreach (edge; edges)
    //  if (edge.from.isCyclic && edge.to.isCyclic)
    //    edge.isCyclic = true;

    // Use functioning algorithm.
    analyzeGraph(vertices, edges);
  }
}

/// Represents a directed connection between two vertices.
class Edge
{
  Vertex from;   /// Coming from vertex.
  Vertex to;     /// Going to vertex.
  bool isCyclic; /// Edge connects cyclic vertices.
  bool isPublic; /// Public import.
  bool isStatic; /// Static import.

  /// Constructs an Edge object between two vertices.
  this(Vertex from, Vertex to)
  {
    this.from = from;
    this.to = to;
  }
}

/// Represents a module in the graph.
class Vertex
{
  Module modul;      /// The module represented by this vertex.
  uint id;           /// The nth vertex in the graph.
  Vertex[] incoming; /// Also called predecessors.
  Vertex[] outgoing; /// Also called successors.
  bool isCyclic;     /// Whether this vertex is in a cyclic relationship
                     /// with other vertices.

  enum Status : ubyte
  { None, Visiting, Visited }
  Status status; /// Used by the cycle detection algorithm.
}

/// Builds a module dependency graph.
class GraphBuilder
{
  Graph graph; /// The graph object.
  IGraphCommand.Options options; /// The options.
  string[] importPaths; /// Where to look for modules.
  Vertex[hash_t] loadedModulesTable; /// Maps FQN paths to modules.
  bool delegate(string) filterPredicate;
  CompilationContext cc; /// The context.

  /// Constructs a GraphBuilder object.
  this(CompilationContext cc)
  {
    this.graph = new Graph;
    this.cc = cc;
  }

  /// Start building the graph and return that.
  /// Params:
  ///   fileName = the file name of the root module.
  Graph start(string fileName)
  {
    loadModule(fileName);
    return graph;
  }

  /// Loads all modules recursively and builds the graph at the same time.
  /// Params:
  ///   moduleFQNPath = the path version of the module FQN.$(BR)
  ///                   E.g.: FQN = dil.ast.Node -> FQNPath = dil/ast/Node
  Vertex loadModule(string moduleFQNPath)
  {
    // Look up in table if the module is already loaded.
    auto hash = hashOf(moduleFQNPath);
    auto pVertex = hash in loadedModulesTable;
    if (pVertex !is null)
      return *pVertex; // Returns null for filtered or unlocatable modules.

    // Filter out modules.
    if (filterPredicate && filterPredicate(moduleFQNPath))
    { // Store null for filtered modules.
      loadedModulesTable[hash] = null;
      return null;
    }

    // Locate the module in the file system.
    auto moduleFilePath = ModuleManager.findModuleFilePath(
      moduleFQNPath,
      importPaths
    );

    Vertex vertex;

    if (moduleFilePath is null)
    { // Module not found.
      if (options & IGraphCommand.Option.IncludeUnlocatableModules)
      { // Include module nevertheless.
        vertex = new Vertex;
        vertex.modul = new Module("", cc);
        vertex.modul.setFQN(replace(moduleFQNPath, dirSep, '.'));
        graph.addVertex(vertex);
      }
      // Store vertex in the table (vertex may be null.)
      loadedModulesTable[hash] = vertex;
    }
    else
    {
      auto modul = new Module(moduleFilePath, cc);
      // Use lightweight ImportParser.
      modul.setParser(new ImportParser(modul.sourceText, cc.tables));
      modul.parse();

      vertex = new Vertex;
      vertex.modul = modul;

      graph.addVertex(vertex);
      loadedModulesTable[hashOf(modul.getFQNPath())] = vertex;

      // Load the modules which this module depends on.
      foreach (importDecl; modul.imports)
      {
        foreach (moduleFQNPath2; importDecl.getModuleFQNs(dirSep))
        {
          auto loaded = loadModule(moduleFQNPath2);
          if (loaded !is null)
          {
            auto edge = graph.addEdge(vertex, loaded);
            edge.isPublic = importDecl.isPublic();
            edge.isStatic = importDecl.isStatic();
          }
        }
      }
    }
    return vertex;
  }
}

/// Prints the file paths to the modules.
void printModulePaths(Vertex[] vertices, uint level, char[] indent)
{
  if (level == 0)
    return;
  foreach (vertex; vertices)
  {
    Stdout(indent)((vertex.isCyclic?"*":"")~vertex.modul.filePath).newline;
    if (vertex.outgoing.length)
      printModulePaths(vertex.outgoing, level-1, indent~"  ");
  }
}

/// Prints a list of module FQNs.
void printModuleList(Vertex[] vertices, uint level, char[] indent)
{
  if (level == 0)
    return;
  foreach (vertex; vertices)
  {
    Stdout(indent)((vertex.isCyclic?"*":"")~vertex.modul.getFQN()).newline;
    if (vertex.outgoing.length)
      printModuleList(vertex.outgoing, level-1, indent~"  ");
  }
}

/// Prints the graph as a graphviz dot document.
void printDotDocument(CompilationContext cc, Graph graph,
  string siStyle, string piStyle, IGraphCommand.Options options)
{
  // Needed for grouping by package names.
  ModuleManager mm;
  uint groupModules = options & (IGraphCommand.Option.GroupByFullPackageName |
                                 IGraphCommand.Option.GroupByPackageNames);

  if (groupModules)
  {
    mm = new ModuleManager(cc, cc.diag);
    foreach (vertex; graph.vertices)
      mm.addModule(vertex.modul);
  }

  if (options & (IGraphCommand.Option.HighlightCyclicVertices |
                 IGraphCommand.Option.HighlightCyclicEdges))
    graph.detectCycles();

  // Output header of the dot document.
  Stdout("Digraph ImportGraph\n{\n");
  Stdout("  fontname = Verdana; /*fontsize = 10;*/\n");
  // Output nodes.
  // 'i' and vertex.id should be the same.
  foreach (i, vertex; graph.vertices)
    Stdout.formatln(`  n{} [label="{}"{}];`, i, //, URL="{}.html"
                    groupModules ? vertex.modul.moduleName :
                                   vertex.modul.getFQN(),
                    (vertex.isCyclic ? ",style=filled,fillcolor=tomato" : ""));

  // Output edges.
  foreach (edge; graph.edges)
  {
    string edgeStyles = "";
    if (edge.isStatic || edge.isPublic)
    {
      edgeStyles = `[style="`;
      edge.isStatic && (edgeStyles ~= siStyle ~ ",");
      edge.isPublic && (edgeStyles ~= piStyle);
      if (edgeStyles[$-1] == ',')
        edgeStyles = edgeStyles[0..$-1]; // Remove last comma.
      edgeStyles ~= `"]`;
    }
    edge.isCyclic && (edgeStyles ~= "[color=red]");
    Stdout.formatln(`  n{} -> n{} {};`, edge.from.id, edge.to.id, edgeStyles);
  }

  if (options & IGraphCommand.Option.GroupByFullPackageName)
  {
    Vertex[][string] verticesByPckgName;
    foreach (vertex; graph.vertices)
      verticesByPckgName[vertex.modul.packageName] ~= vertex;
    foreach (packageFQN, vertices; verticesByPckgName)
    { // Output nodes in a cluster.
      Stdout.format(`  subgraph "cluster_{0}" {{`"\n"
                    `    label="{0}";color=blue;`"\n    ",
                    packageFQN);
      foreach (vertex; vertices)
        Stdout.format(`n{};`, vertex.id);
      Stdout("\n  }\n");
    }
  }
  else if (options & IGraphCommand.Option.GroupByPackageNames)
  {
    Stdout("  // Warning: some nested clusters may crash dot.\n");
    uint[Module] idTable;
    foreach (vertex; graph.vertices)
      idTable[vertex.modul] = vertex.id;
    void printSubgraph(Package pckg, string indent)
    { // Output nodes in a cluster.
      foreach (p; pckg.packages)
      {
        Stdout.format(`{0}subgraph "cluster_{1}" {{`"\n"
                      `{0}  label="{2}";color=blue;`"\n"
                      "{0}  ",
                      indent, p.getFQN(), p.pckgName);
        foreach (modul; p.modules)
          Stdout.format(`n{};`, idTable[modul]);
        if (p.packages) {
          Stdout.newline;
          printSubgraph(p, indent~"  "); // Output nested clusters.
        }
        Stdout("\n  }\n");
      }
    }
    printSubgraph(mm.rootPackage, "  ");
  }

  Stdout("}\n");
}

/// This is the old algorithm that is used
/// to detect cycles in a directed graph.
/// The new algorithm doesn't work (yet.)
void analyzeGraph(Vertex[] vertices, Edge[] edges)
{
  // TODO: use a BitArray for this algorithm?
  edges = edges.dup;
  vertices = vertices.dup;

RestartLoop:
  foreach (idx, vertex; vertices)
  { // 1. Count the outgoing and incoming edges from/to the current vertex.
    uint outgoing, incoming;
    alias outgoing i; // Reuse below.
    alias incoming j;
    foreach (edge; edges)
    {
      if (edge.from is vertex)
        outgoing = true;
      if (edge.to is vertex)
        incoming = true;
    }
    // 2. See if the vertex is a "sink" or a "source".
    if (outgoing == 0)
    {
      if (incoming != 0)
      { // Vertex is a sink.
        // Remove edges leading to this vertex.
        for (i=j=0; i < edges.length; i++)
          if (edges[i].to !is vertex)
            edges[j++] = edges[i];
        edges.length = j;
      }
      // else
        // Edges to this vertex were removed previously.
        // Only remove vertex now.
    }
    else if (incoming == 0)
    { // Vertex is a source.
      // Remove edges coming from this vertex.
      for (i=j=0; i < edges.length; i++)
        if (edges[i].from !is vertex)
          edges[j++] = edges[i];
      edges.length = j;
    }
    else // Vertex is source and sink. Continue loop.
      continue;

    // 3. Remove the vertex from the list.
    auto p = vertices.ptr + idx,
         end = vertices.ptr + vertices.length -1;
    for (; p < end; p++)
      *p = p[1]; // Move all elements one position to the left.
    vertices.length = vertices.length -1;
    goto RestartLoop; // Start over.
  }

  // When reaching this point it means only cyclic edges and vertices are left.
  foreach (vertex; vertices)
    vertex.isCyclic = true;
  foreach (edge; edges)
    edge.isCyclic = true;
}
