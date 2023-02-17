# 

... for Android, BSDs, Linux, macOS, SunOS, Windows (MinGW, WSL)

**mulle-platform** lets you query the current platform for such things like the
extension of shared libraries or the location of specific libraries.

For example `mulle-platform search dl` returns
`/usr/lib/x86_64-linux-gnu/libdl.a` on my linux system.

> You might be better off to use **cmake** for such things. But this
> command can be handy in shell scripts.










## Install

See [mulle-sde-developer](//github.com/mulle-sde/mulle-sde-developer) how to
install mulle-sde, which will also install  and required
dependencies.

The command to install only the latest  into
`/usr/local` (with **sudo**) is:

``` bash
curl -L 'https://github.com///archive/latest.tar.gz' \
 | tar xfz - && cd '-latest' && sudo ./bin/installer /usr/local
```



## Author

[Nat!](https://mulle-kybernetik.com/weblog) for Mulle kybernetiK
