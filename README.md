# Recursive, à la carte `git-mktree`

Allows for the efficient creation of tree objects that represent a subset of
the contents of a source git tree. Functionality provided is similar to 
a recursive version of `git-mktree`.

Equivalent functionality could be achieved by checking out the source tree 
in a working directory, selectively deleting material to be excluded, and 
committing the result. The benefit of the approach enabled by this utility 
is that the creation of the subtree can be done without involving a work tree,
and it allows included files to specified directly, without the otherwise-necessary
intermediate step of determining which files are to be *excluded*. If the 
source repository is sufficiently large, and/or the target subset tree is
considerably smaller than the source tree, this approach can be much more 
efficient. 

## Usage
```
Usage: git-mktree-recursive.rb [options]
    -c, --base-commit=val            base commit for resolving blobs; defaults to HEAD
    -z, --null-delimited             expect null-delimited input, all internal handling is null-delimited
    -h, --help                       Show this message
```
The command should be run from a directory within the source git repository. Input
file list should be provided on `stdin`. Filenames provided should be relative
to the source commit tree root. It is assumed/required that the input be formated 
as the result of a standard, depth-first traversal of a filesystem tree; e.g., the 
native ordering of the output of `git ls-files` or the Unix `find` command are
both acceptable in this respect.

## Example
In a git repository containing `*.java` and `*.properties` files, to obtain
a tree object id of an equivalent tree containing only `*.properties` files,
from within the repository, run:
```
git ls-files --full-name -z | grep -Z '\.properties$' | git-mktree-recursive.rb -z
```
