# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
import os, shutil

class Path(unicode):
  """ Models a path in an object oriented way. """
  sep = os.sep # File system path separator: '/' or '\'.
  pathsep = os.pathsep # Separator in the PATH environment variable.

  def __new__(cls, *paths):
    return unicode.__new__(cls, os.path.join(*paths) if len(paths) else '')

  def __div__(self, path):
    """ Joins this path with another path. """
    """ path_obj / 'bc.d' """
    """ path_obj / path_obj2 """
    return Path(self, path)

  def __rdiv__(self, path):
    """ Joins this path with another path. """
    """ "/home/a" / path_obj """
    return Path(path, self)

  def __idiv__(self, path):
    """ Like __div__ but also assigns to the variable. """
    """ path_obj /= 'bc.d' """
    return Path(self, path)

  def __floordiv__(self, paths):
    """ Returns a list of paths prefixed with 'self'. """
    """ '/home/a' // [bc.d, ef.g] -> [/home/a/bc.d, /home/a/ef.g] """
    return [Path(self, path) for path in paths]

  def __add__(self, path):
    """ Path('/home/a') + 'bc.d' -> '/home/abc.d' """
    return Path(unicode(self) + path)

  def __radd__(self, path):
    """ '/home/a' + Path('bc.d') -> '/home/abc.d' """
    return Path(path + unicode(self))

  def __repr__(self):
    return u"Path(%s)" % unicode.__repr__(self)

  @property
  def name(self):
    """ '/home/a/bc.d' -> 'bc.d' """
    return os.path.basename(self)

  @property
  def namebase(self):
    """ '/home/a/bc.d' -> 'bc' """
    return self.noext.name

  @property
  def noext(self):
    """ '/home/a/bc.d' -> '/home/a/bc' """
    return Path(os.path.splitext(self)[0])

  @property
  def ext(self):
    """ '/home/a/bc.d' -> '.d' """
    return Path(os.path.splitext(self)[1])

  @property
  def abspath(self):
    """ './a/bc.d' -> '/home/a/bc.d'  """
    return Path(os.path.abspath(self))

  @property
  def realpath(self):
    """ Resolves symbolic links. """
    return Path(os.path.realpath(self))

  @property
  def normpath(self):
    """ '/home/x/.././a//bc.d' -> '/home/a/bc.d' """
    return Path(os.path.normpath(self))

  @property
  def folder(self):
    """ Returns the folder of this path. """
    """ '/home/a/bc.d' -> '/home/a' """
    """ '/home/a/' -> '/home/a' """
    """ '/home/a' -> '/home' """
    return Path(os.path.dirname(self))

  @property
  def exists(self):
    """ Returns True if the path exists. """
    return os.path.exists(self)

  @property
  def atime(self):
    """ Returns last accessed time. """
    return os.path.getatime(self)

  @property
  def mtime(self):
    """ Returns last modified time. """
    return os.path.getmtime(self)

  @property
  def ctime(self):
    """ Returns last changed time. """
    return os.path.getctime(self)

  @classmethod
  def supports_unicode(self):
    """ Returns True if the system can handle Unicode file names. """
    return os.path.supports_unicode_filenames()

  def walk(self, **kwargs):
    """ Returns a generator that walks through a directory tree. """
    if "followlinks" in kwargs:
      from sys import version_info as vi
      if vi[0]*10+vi[1] < 26: # Only Python 2.6 or newer supports followlinks.
        del kwargs["followlinks"]
    return os.walk(self, **kwargs)

  def mkdir(self, mode=0777):
    """ Creates a directory, if it doesn't exist already. """
    if not self.exists:
      os.mkdir(self, mode)

  def makedirs(self, mode=0777):
    """ Like mkdir(), but also creates parent directories. """
    if not self.exists:
      os.makedirs(self, mode)

  def remove(self):
    """ Removes a file. """
    os.remove(self)
  rm = remove # Alias.

  def rmdir(self):
    """ Removes a directory. """
    return os.rmdir(self)

  def rmtree(self, noerrors=True):
    """ Removes a directory tree. Ignores errors by default. """
    return shutil.rmtree(self, ignore_errors=noerrors)

  def copy(self, to):
    shutil.copy(self, to)

  def copytree(self, to):
    """ Copies a directory tree to another path. """
    shutil.copytree(self, to)

  def move(self, to):
    """ Moves a file or directory to another path. """
    shutil.move(self, to)

  def rename(self, to):
    """ Renames a file or directory. May throw an OSError. """
    os.rename(self, to)

  def renames(self, to):
    os.renames(self, to)

  def glob(self, pattern):
    from glob import glob
    return map(Path, glob(unicode(self/pattern)))
