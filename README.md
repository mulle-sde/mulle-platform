# 👠 Query platform specifica and search for libraries

... for Android, BSDs, Linux, macOS, SunOS, Windows (MinGW, WSL)

**mulle-platform** lets you query the current platform for such things like the
extension of shared libraries or the location of specific libraries.

For example `mulle-platform search dl` returns
`/usr/lib/x86_64-linux-gnu/libdl.a` on my linux system.

> You might be better off to use **cmake** for such things. But this
> command can be handy in shell scripts.

| Release Version                                       | Release Notes
|-------------------------------------------------------|--------------
| ![Mulle kybernetiK tag](https://img.shields.io/github/tag/mulle-sde/mulle-platform.svg?branch=release)  | [RELEASENOTES](RELEASENOTES.md) |











## Install

See [mulle-sde-developer](//github.com/mulle-sde/mulle-sde-developer) how to
install mulle-sde, which will also install mulle-platform with required
dependencies.

The command to install only the latest mulle-platform into
`/usr/local` (with **sudo**) is:

``` bash
curl -L 'https://github.com/mulle-sde/mulle-platform/archive/latest.tar.gz' \
 | tar xfz - && cd 'mulle-platform-latest' && sudo ./bin/installer /usr/local
```



## Author

[Nat!](https://mulle-kybernetik.com/weblog) for Mulle kybernetiK


