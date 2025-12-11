_mulle_platform_complete()
{
   local cur prev words cword

   _get_comp_words_by_ref -n : cur prev words cword

   local cmd="${words[1]}"
   local subcmd="${words[2]}"
   local i=1

   # Global options
   case "$cur" in
      -*)
         COMPREPLY=($(compgen -W "-f --force -h --help --version" -- "$cur"))
         return 0
      ;;
   esac

   # No command yet, complete commands
   if [[ $cword -eq 1 ]]; then
      COMPREPLY=($(compgen -W "compiler env environment export flags includepath languages link quirks search searchpath translate wholearchive sdkpath libexec-dir uname version" -- "$cur"))
      return 0
   fi

   case "$cmd" in
      compiler)
         # Handle compiler subcommands
         if [[ $cword -eq 2 ]]; then
            COMPREPLY=($(compgen -W "run env list" -- "$cur"))
            return 0
         fi

         case "$subcmd" in
            run)
               # compiler run (compile) options
               if [[ "$prev" == --platform ]]; then
                  COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --language ]]; then
                  COMPREPLY=($(compgen -W "c cpp objc objcpp" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --dialect ]]; then
                  COMPREPLY=($(compgen -W "c objc mulle-objc" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --configuration ]]; then
                  COMPREPLY=($(compgen -W "Debug Release Test RelWithDebInfo" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --compiler-type ]]; then
                  COMPREPLY=($(compgen -W "gcc clang mulle-clang cl" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --sanitizer ]]; then
                  COMPREPLY=($(compgen -W "address thread undefined" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == -F || "$prev" == -I || "$prev" == -L || "$prev" == --rpath ]]; then
                  COMPREPLY=($(compgen -d -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == -o ]]; then
                  COMPREPLY=($(compgen -f -- "$cur"))
                  return 0
               fi
               if [[ "$cur" == -* ]]; then
                  COMPREPLY=($(compgen -W "--platform --language --dialect --configuration --compiler-type -F -I -D -c --shared --sanitizer --coverage --export-symbol --output-asm --emit-llvm --show-headers --rpath -L -l --wholearchive -Wl -o --print-only" -- "$cur"))
                  return 0
               fi
               COMPREPLY=($(compgen -f -- "$cur"))
               return 0
               ;;
            env)
               # compiler env options
               if [[ "$prev" == --platform ]]; then
                  COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --language ]]; then
                  COMPREPLY=($(compgen -W "c cpp objc objcpp" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --dialect ]]; then
                  COMPREPLY=($(compgen -W "c objc mulle-objc" -- "$cur"))
                  return 0
               fi
               if [[ "$prev" == --compiler-type ]]; then
                  COMPREPLY=($(compgen -W "gcc clang mulle-clang cl" -- "$cur"))
                  return 0
               fi
               if [[ "$cur" == -* ]]; then
                  COMPREPLY=($(compgen -W "--platform --language --dialect --compiler-type --print-env --print-json" -- "$cur"))
                  return 0
               fi
               ;;
            list)
               # compiler list (compilers) options
               if [[ "$cur" == -* ]]; then
                  COMPREPLY=($(compgen -W "--verbose" -- "$cur"))
                  return 0
               fi
               ;;
         esac
         ;;
      env|environment)
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "-b --build-tools --no-build-tools -l --library --no-library --platform" -- "$cur"))
            return 0
         fi
         ;;
      export)
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --compiler-type ]]; then
            COMPREPLY=($(compgen -W "gcc clang mulle-clang msvc" -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--platform --compiler-type --compiler --linker" -- "$cur"))
            return 0
         fi
         ;;
      flags)
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --language ]]; then
            COMPREPLY=($(compgen -W "c cpp objc objcpp" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --dialect ]]; then
            COMPREPLY=($(compgen -W "c objc mulle-objc" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --configuration ]]; then
            COMPREPLY=($(compgen -W "Debug Release Test RelWithDebInfo" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --compiler-type ]]; then
            COMPREPLY=($(compgen -W "gcc clang mulle-clang msvc cl" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --type ]]; then
            COMPREPLY=($(compgen -W "compile link both" -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--platform --language --dialect --configuration --compiler-type --type --print-env --print-list" -- "$cur"))
            return 0
         fi
         ;;
      includepath)
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--cmake" -- "$cur"))
            return 0
         fi
         ;;
      languages)
         if [[ "$prev" == --compiler-type ]]; then
            COMPREPLY=($(compgen -W "gcc clang mulle-clang msvc cl" -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--compiler-type" -- "$cur"))
            return 0
         fi
         ;;
      link)
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --language ]]; then
            COMPREPLY=($(compgen -W "c cpp objc objcpp" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --dialect ]]; then
            COMPREPLY=($(compgen -W "c objc mulle-objc" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --configuration ]]; then
            COMPREPLY=($(compgen -W "Debug Release Test RelWithDebInfo" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --compiler-type ]]; then
            COMPREPLY=($(compgen -W "gcc clang mulle-clang cl" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == -L || "$prev" == -F ]]; then
            COMPREPLY=($(compgen -d -- "$cur"))
            return 0
         fi
         if [[ "$prev" == -o ]]; then
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--platform --language --dialect --configuration --compiler-type -L -l -F -framework -o --shared --print-only" -- "$cur"))
            return 0
         fi
         COMPREPLY=($(compgen -f -- "$cur"))
         return 0
         ;;
      quirks)
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--platform" -- "$cur"))
            return 0
         fi
         # Handle subcommands: list, show, check
         if [[ $cword -eq 2 ]]; then
            COMPREPLY=($(compgen -W "list show check" -- "$cur"))
            return 0
         fi
         # If subcommand is check, complete with quirk names
         if [[ "${words[2]}" == "check" && $cword -eq 3 ]]; then
            COMPREPLY=($(compgen -W "mingw-needs-link-flag needs-exported-symbols windows-needs-dll-path msvc-needs-md-flag needs-pic-for-shared supports-rpath needs-framework-flag needs-whole-archive uses-dyld uses-ld-library-path needs-no-common supports-sanitizer-address supports-sanitizer-thread supports-sanitizer-undefined supports-sanitizer-memory supports-sanitizer-leak supports-coverage" -- "$cur"))
            return 0
         fi
         ;;
      search)
         if [[ "$prev" == --prefer || "$prev" == --require ]]; then
            COMPREPLY=($(compgen -W "static dynamic" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --type ]]; then
            COMPREPLY=($(compgen -W "library standalone framework" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --output-format ]]; then
            COMPREPLY=($(compgen -W "file ld" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --searchpath ]]; then
            COMPREPLY=($(compgen -d -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--prefer --require --platform --searchpath --type --output-format" -- "$cur"))
            return 0
         fi
         ;;
      searchpath)
         if [[ "$cur" == -* ]]; then
            COMPREPLY=()
            return 0
         fi
         ;;
      translate)
         if [[ "$prev" == --output-format ]]; then
            COMPREPLY=($(compgen -W "ld file ldpath ld_library_path path rpath" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --separator ]]; then
            COMPREPLY=()
            return 0
         fi
         if [[ "$prev" == --quote ]]; then
            COMPREPLY=($(compgen -W "\" '" -- "$cur"))
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--option --output-format --separator --quote --prefix --mode --marks --preferred-library-style --whole-archive-format --dynamic --static --standalone --fake-uname" -- "$cur"))
            return 0
         fi
         COMPREPLY=($(compgen -f -- "$cur"))
         return 0
         ;;
      wholearchive)
         ;;
      sdkpath|libexec-dir|uname|version)
         ;;
   esac

   return 0
}

complete -F _mulle_platform_complete mulle-platform
