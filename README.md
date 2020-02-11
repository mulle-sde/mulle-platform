# mulle-platform

👠 Query platform specifica and search for libraries

![Last version](https://img.shields.io/github/tag/mulle-sde/mulle-platform.svg)

... for Linux, OS X, FreeBSD, Windows


**mulle-platform** lets you query the current platform for such things like the
extension of shared libraries or the location of specific libraries.

For example `mulle-platform search dl` returns
`/usr/lib/x86_64-linux-gnu/libdl.a` on my linux system.

> You might be better off to use **cmake** for such things. But this
> command can be handy in shell scripts.


Executable          | Description
--------------------|--------------------------------
`mulle-platform`    | Query platform information


## Install

See [mulle-sde-developer](//github.com/mulle-sde/mulle-sde-developer) how
to install mulle-sde.


## GitHub and Mulle kybernetiK

The development is done on
[Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-platform/master).
Releases and bug-tracking are on [GitHub](https://github.com/{{PUBLISHER}}/mulle-platform).
