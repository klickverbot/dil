/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.lexer.IdentsGenerator;

/// Table of predefined identifiers.
///
/// The format ('#' start comments):
/// $(BNF
////PredefinedIdentifier := SourceCodeName (":" IdText)?
////SourceCodeName := Identifier # The name to be used in the source code.
////IdText := Empty | Identifier # The actual text of the identifier.
////Empty := ""                  # IdText may be empty.
////Identifier := see module $(MODLINK dil.lexer.Identifier).
////)
/// If IdText is not defined it defaults to SourceCodeName.
private static const char[][] predefIdents = [
  // Special empty identifier:
  "Empty:",
  // Predefined version identifiers:
  "DigitalMars", "X86", "X86_64",
  /*"Windows", */"Win32", "Win64",
  "Linux:linux", "LittleEndian", "BigEndian",
  "D_Coverage", "D_InlineAsm_X86", "D_Version2",
  "none", "all",
  // Variadic parameters:
  "Arguments:_arguments", "Argptr:_argptr",
  // scope(Identifier):
  "exit", "success", "failure",
  // pragma:
  "msg", "lib", "startaddress",
  // Linkage:
  "C", "D", "Windows", "Pascal", "System",
  // Con-/Destructor:
  "Ctor:__ctor", "Dtor:__dtor",
  // new() and delete() methods.
  "New:__new", "Delete:__delete",
  // Unittest and invariant.
  "Unittest:__unittest", "Invariant:__invariant",
  // Attributes (D2):
  "disable", "property", /+"safe", "system",+/ "trusted",
  // Operator overload names:
  "opNeg",    "opPos",    "opCom",
  "opEquals", "opCmp",    "opAssign",
  "opAdd",    "opAdd_r",  "opAddAssign",
  "opSub",    "opSub_r",  "opSubAssign",
  "opMul",    "opMul_r",  "opMulAssign",
  "opDiv",    "opDiv_r",  "opDivAssign",
  "opMod",    "opMod_r",  "opModAssign",
  "opAnd",    "opAnd_r",  "opAndAssign",
  "opOr",     "opOr_r",   "opOrAssign",
  "opXor",    "opXor_r",  "opXorAssign",
  "opShl",    "opShl_r",  "opShlAssign",
  "opShr",    "opShr_r",  "opShrAssign",
  "opUShr",   "opUShr_r", "opUShrAssign",
  "opCat",    "opCat_r",  "opCatAssign",
  "opIn",     "opIn_r",
  "opIndex",  "opIndexAssign",
  "opSlice",  "opSliceAssign",
  "opPostInc",
  "opPostDec",
  "opCall",
  "opCast",
  "opStar", // D2
  // foreach and foreach_reverse:
  "opApply", "opApplyReverse",
  // Entry functions:
  "main", "WinMain", "DllMain",
  // D2 module (system|safe)
  "system", "safe",
  // From object.d
  "object", "Object", "Interface",
  "Exception", "Error",
  "ClassInfo", "TypeInfo", "OffsetTypeInfo",
  "ModuleInfo", "FrameInfo", "TraceInfo",
  "ptrdiff_t", "size_t", "hash_t", "equals_t",
  // TypeInfo classes
  "TypeInfo_Array",
  "TypeInfo_AssociativeArray",
  "TypeInfo_Class",
  "TypeInfo_Const", // D2
  "TypeInfo_Delegate",
  "TypeInfo_Enum",
  "TypeInfo_Function",
  "TypeInfo_Interface",
  "TypeInfo_Invariant", // D2
  "TypeInfo_Pointer",
  "TypeInfo_Shared", // D2
  "TypeInfo_StaticArray",
  "TypeInfo_Struct",
  "TypeInfo_Tuple",
  "TypeInfo_Typedef",
  // Special properties
  "Sizeof:sizeof", "Alignof:alignof", "Mangleof:mangleof",
  // ASM identifiers:
  "near", "far", "word", "dword", "qword",
  "ptr", "offsetof", "seg", "__LOCAL_SIZE",
  "FS", "ST",
  "AL", "AH", "AX", "EAX",
  "BL", "BH", "BX", "EBX",
  "CL", "CH", "CX", "ECX",
  "DL", "DH", "DX", "EDX",
  "BP", "EBP", "SP", "ESP",
  "DI", "EDI", "SI", "ESI",
  "ES", "CS", "SS", "DS", "GS",
  "CR0", "CR2", "CR3", "CR4",
  "DR0", "DR1", "DR2", "DR3", "DR6", "DR7",
  "TR3", "TR4", "TR5", "TR6", "TR7",
  "MM0", "MM1", "MM2", "MM3",
  "MM4", "MM5", "MM6", "MM7",
  "XMM0", "XMM1", "XMM2", "XMM3",
  "XMM4", "XMM5", "XMM6", "XMM7",
  // ASM jump opcodes:
  "ja", "jae", "jb", "jbe", "jc",
  "jcxz", "je", "jecxz", "jg", "jge",
  "jl", "jle", "jmp", "jna", "jnae",
  "jnb", "jnbe", "jnc", "jne", "jng",
  "jnge", "jnl", "jnle", "jno", "jnp",
  "jns", "jnz", "jo", "jp", "jpe",
  "jpo", "js", "jz",
];

/// Splits idText at ':' and returns a tuple.
char[][] getPair(char[] idText)
{
  foreach (i, c; idText)
    if (c == ':')
      return [idText[0..i], idText[i+1..idText.length]];
  return [idText, idText];
}

unittest
{
  static assert(
    getPair("test") == ["test", "test"] &&
    getPair("test:tset") == ["test", "tset"] &&
    getPair("empty:") == ["empty", ""]
  );
}

/++
  CTF for generating the members of the struct Ident.

  The resulting string looks similar to this:
  ---
  private struct Ids {static const:
    Identifier _Empty = {"", TOK.Identifier, IDK.Empty};
    Identifier _main = {"main", TOK.Identifier, IDK.main};
    // etc.
  }
  Identifier* Empty = &Ids._Empty;
  Identifier* main = &Ids._main;
  // etc.
  private Identifier*[] __allIds = [
    Empty,
    main,
    // etc.
  ];
  ---
+/
char[] generateIdentMembers()
{
  char[] private_members = "private struct Ids {static const:";
  char[] public_members = "";
  char[] array = "private Identifier*[] __allIds = [";

  foreach (ident; predefIdents)
  {
    char[][] pair = getPair(ident);
    // Identifier _name = {"name", TOK.Identifier, ID.name};
    private_members ~= "Identifier _"~pair[0]~` = {"`~pair[1]~`", TOK.Identifier, IDK.`~pair[0]~"};\n";
    // Identifier* name = &_name;
    public_members ~= "Identifier* "~pair[0]~" = &Ids._"~pair[0]~";\n";
    array ~= pair[0]~",";
  }

  private_members ~= "}"; // Close private {
  array ~= "];";

  return private_members ~ public_members ~ array;
}

/// CTF for generating the members of the enum IDK.
char[] generateIDMembers()
{
  char[] members;
  foreach (ident; predefIdents)
    members ~= getPair(ident)[0] ~ ",\n";
  return members;
}

// pragma(msg, generateIdentMembers());
// pragma(msg, generateIDMembers());
