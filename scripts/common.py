# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re, sys
from path import Path

def find_source_files(source, filter_pred=lambda x: False):
  """ Searches for source files (.d and .di). Appends file paths to found. """
  found = []
  for root, dirs, files in Path(source).walk(followlinks=True):
    for f in files:
      f = Path(root, f) # Join the root and the file name.
      if f.ext.lower() in ('.d','.di') and not filter_pred(f):
        found.append(f)
  return found

def find_dil_source_files(source):
  """ Filters out files in "src/tests/". """
  filter_func = lambda f: f.startswith(source/"tests")
  return find_source_files(source, filter_func)

def script_parent_folder(script_path):
  return Path(script_path).realpath.folder.folder

def change_cwd(script_path):
  """ Changes the current working directory to "script_dir/.." """
  os.chdir(script_parent_folder(script_path))

def kandil_path(where="kandil"):
  P = firstof(Path, where, Path(where))
  P.IMG, P.CSS, P.JS = P//("img", "css", "js")
  P.ddoc    = P/"kandil.ddoc"
  P.style   = P.CSS/"style.css"
  P.jsfiles = P.JS//("navigation.js", "jquery.js", "quicksearch.js",
    "utilities.js", "symbols.js")
  P.navi, P.jquery, P.qsearch, P.utils, P.syms = P.jsfiles
  P.images = P.IMG.glob("*.png") + P.IMG.glob("*.gif")
  return P

def dil_path(where="", dilconf=True):
  P = firstof(Path, where, Path(where))
  P.BIN = P/"bin" # The destination of the binaries.
  P.EXE = P.BIN/"dil" # The compiled binary.
  P.SRC = P/"src" # The source code folder.
  P.DOC = P/"doc" # Documentation folder.
  # Default to these values:
  P.DATA = P/"data" # The data folder with various files.
  P.KANDIL = P/"kandil" # Kandil's folder.
  # Paths might differ because of the settings in dilconf.
  if dilconf:
    exe_path = P.EXE if P.EXE.exists else locate_command("dil")
    if exe_path:
      P.BIN = exe_path.folder # Update binary folder.
      P.EXE = exe_path # Update exe path.
      # Get the DATADIR from dil.
      dil_command = exe_path + " set datadir"
      datadir = os.popen(dil_command).read()[:-1] # Remove \n.
      P.DATA = Path(datadir.partition("=")[2]).normpath
      P.KANDIL = P.DATA.folder/"kandil"
      if not P.KANDIL.exists:      # If not a sibling folder,
        P.KANDIL = P.DATA/"kandil" # assume kandil/ is in data/.
  P.KANDIL = kandil_path(P.KANDIL) # Extend the path object.
  return P

def doc_path(where):
  P = firstof(Path, where, Path(where))
  P.HTMLSRC = P/"htmlsrc" # Destination of syntax highlighted source files.
  P.JS, P.CSS, P.IMG = P//("js", "css", "img")
  return P

def get_module_fqn(prefix_path, filepath):
  """ Returns the fully qualified module name (FQN) of a D source file.
    Note: this might not match with the module declaration
          in the source file. """
  # Remove prefix and strip off path separator.
  # E.g.: prefix_path/std/format.d -> std/format.d
  filepath = filepath[len(prefix_path):].lstrip(os.path.sep)
  # Remove the extension.
  # E.g.: std/format.d - > std/format
  filepath = os.path.splitext(filepath)[0]
  # Finally replace the path separators.
  return filepath.replace(os.path.sep, '.') # E.g.: std/format -> std.format

def read_modules_list(path):
  from re import compile
  rx = compile(r"^(?P<path>[^,]+), (?P<fqn>\w+(?:\.\w+)*)$")
  return [match.groupdict() for match in map(rx.match, open(path)) if match]

def generate_modules_js(modlist, dest_path, max_line_len=80):
  """ Generates a JavaScript file with a list of fully qual. module names.
      Note: This function is obsolete. See src/cmd/DDoc.d. """
  if not len(modlist):
    raise Exception("modlist must not be empty")
  from symbols import Module, Package, PackageTree
  modlist = [m['fqn'] for m in modlist] # Get list of the fully qual. names.
  f = open(dest_path, "w")
  f.write('var g_modulesList = [\n ') # Write a flat list of FQNs.
  line_len = 0
  for mod in modlist:
    line = ' "%s",' % mod
    line_len += len(line)
    if line_len >= max_line_len: # See if we have to start a new line.
      line_len = len(line)+1 # +1 for the space in "\n ".
      line = "\n " + line
    f.write(line)
  f.write('\n];\n\n') # Closing ].

  package_tree = PackageTree()

  # Construct the package tree with modules as leafs.
  for fqn in modlist:
    package_tree.addModule(Module(fqn))

  package_tree.sortTree()

  def writePackage(package, indent='  '):
    """ Writes the sub-packages and sub-modules of a package to the disk. """
    for p in package.packages:
      f.write("%sP('%s','%s',[\n" % (indent, p.name, p.fqn))
      writePackage(p, indent+'  ')
      f.write(indent+"]),\n")
    for m in package.modules:
      f.write("%sM('%s','%s'),\n" % (indent, m.name, m.fqn))

  # Write a function that constructs a module/package object.
  f.write('function M(name, fqn, sub)\n{\n'
    '  sub = sub ? sub : [];\n'
    '  return {\n'
    '    name: name, fqn: fqn, sub: sub,\n'
    '    kind : (sub && sub.length == 0) ? "module" : "package"\n'
    '  };\n'
    '}\nvar P = M;\n\n')
  # Write the packages and modules as JavaScript objects.
  f.write('var g_moduleObjects = [\n')
  writePackage(package_tree.root)
  f.write('];')

  f.close()

def generate_docs(dil_exe, dest, modlist, files,
                  versions=[], options=[], cwd=None):
  """ Generates documenation files. """
  from subprocess import call
  versions = ["-version="+v for v in versions]
  call([dil_exe, "ddoc", dest, "-m="+modlist] + options + versions + files,
       cwd=cwd)

def generate_pymodules(dil_exe, dest, files, options=[], cwd=None):
  """ Generates Python source files. """
  from subprocess import call
  call([dil_exe, "py", dest] + options + files, cwd=cwd)

def load_pymodules(folder):
  """ Loads all python modules (names matching 'd_*.py') from a folder. """
  # Add the folder to the system import path.
  sys.path = [folder] + sys.path
  files = folder.glob("d_*.py")
  modules = [__import__(f.namebase, level=0) for f in files]
  # Reset the path variable.
  sys.path = sys.path[1:]
  return modules

def generate_shl_files(dil_exe, dest, prefix, files):
  """ Generates syntax highlighted files. """
  for filepath in files:
    htmlfile = get_module_fqn(prefix, filepath) + ".html"
    yield (filepath, dest/htmlfile)
    args = (dil_exe, filepath, dest/htmlfile)
    os.system('%s hl --lines --syntax --html %s > "%s"' % args)

def generate_shl_files2(dil_exe, dest, modlist):
  """ Generates syntax highlighted files. """
  for mod in modlist:
    htmlfile = mod['fqn'] + ".html"
    yield (mod['path'], dest/htmlfile)
    args = (dil_exe, mod['path'], dest/htmlfile)
    os.system('%s hl --lines --syntax --html %s > "%s"' % args)

def locate_command(command):
  """ Locates a command using the PATH environment variable. """
  if 'PATH' in os.environ:
    from sys import platform
    if platform is 'win32' and Path(command).ext.lower() != ".exe":
      command += ".exe" # Append extension if we're on Windows.
    PATH = os.environ['PATH'].split(Path.pathsep)
    for path in reversed(PATH): # Search in reverse order.
      path = Path(path, command)
      if path.exists:
        return path
  return None

def build_dil_if_inexistant(dil_exe):
  from sys import platform
  if platform == 'win32': dil_exe += ".exe"
  if not dil_exe.exists and not locate_command('dil'):
    inp = raw_input("Executable %s doesn't exist. Build it? (Y/n) " % dil_exe)
    if inp.lower() in ("", "y", "yes"):
      from build import build_dil
      # TODO: Ask user about compiling with -version=D2?
      build_dil_release()
    else:
      raise Exception("can't proceed without dil executable")

# Not in use atm.
def download_jquery(dest_path, force=False,
                    url="http://code.jquery.com/jquery-latest.pack.js"):
  """ Downloads the jquery library from "url".
    If force is True, the file is fetched regardless
    of the "Last-Modified" header. """
  from urllib2 import Request, urlopen, HTTPError
  from time import gmtime, strftime

  request = Request(url)

  if dest_path.exists and not force: # Create a GMT date stamp.
    date_stamp = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(dest_path.mtime))
    request.add_header('If-Modified-Since', date_stamp)

  try:
    print "Downloading '%s':" % url
    js_file = urlopen(request)      # Perform the request.
    open(dest_path, "w").write(js_file.read()) # Write to destination path.
    print "Done >", dest_path
  except HTTPError, e:
    if e.code == 304: print "Not Modified"
    else:             print e

class VersionInfo:
  from sys import version_info as vi
  vi = vi
  f = float("%d.%d%d" % vi[:3])
  i = int(f*100)
  def __lt__(self, other): return self.f < other
  def __le__(self, other): return self.f <= other
  def __eq__(self, other): return self.f == other
  def __ne__(self, other): return self.f != other
  def __gt__(self, other): return self.f > other
  def __ge__(self, other): return self.f >= other
PyVersion = VersionInfo()

def chunks(seq, n):
  """ Returns chunks of a sequence of size n. """
  return [seq[i:i+n] for i in xrange(0, len(seq), n)]

def firstof(typ, *args):
  """ Returns the first argument that is of type 'typ'. """
  for arg in args:
    if type(arg) == typ:
      return arg

def getitem(array, index, d=None):
  """ Returns array[index] if the index exists, else d. """
  return array[index] if index < len(array) else d
