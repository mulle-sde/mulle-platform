# mulle-platform Library Documentation for AI
<!-- Keywords: platform, compiler, linker, libraries, build, cross-compilation, search -->

## 1. Introduction & Purpose

- `mulle-platform` is a **bash-based command-line tool** (not a C library) that acts as the "central knowledge dispenser on platform differences" for the `mulle-sde` build system. It lets shell scripts query the current (or a specified target) platform for things like: the extension of shared libraries (`.so`, `.dylib`, `.dll`), the prefix/suffix of executables, the ldflags/ccflags used to link libraries, the search path for OS libraries, SDK paths, and the location of specific installed libraries.
- **Problem it solves:** Build logic that is platform-dependent (flags, suffixes, paths, toolchain selection) is otherwise scattered and hard to get right across Android, BSDs, Linux, macOS, SunOS, and Windows (MinGW, MSYS, WSL). `mulle-platform` centralizes this knowledge in one queryable command.
- **Key features (high level)**:
  - Emits `MULLE_PLATFORM_*` environment definitions for the current host platform (or a specified one via `--platform`), ready for `eval`.
  - Searches platform library search paths for static/dynamic/standalone libraries and frameworks (`search`).
  - Selects and configures compilers/linkers per platform/language/dialect and generates configuration-appropriate flags (`compiler env/list/flags`, `linker env/list/flags`).
  - Generates and executes platform-appropriate compile/link command lines from abstract options (`compile`, `link`, `linker run`).
  - Translates filenames into linker representations (`translate`, `wholearchive`).
  - Answers platform-specific behavior questions (`quirks`), SDK paths (`sdkpath`), header include paths (`includepath`), symbol export flags (`export`), cross-compiler roots (`crosscompiler-root`), and default emulators (`emulator`).
- Relation to other software: It is shipped with and used by the `mulle-sde` tool suite. The dispatcher script itself runs under the `mulle-bash` interpreter, so it depends on the mulle-bash runtime (see "Dependencies"). It is *not* part of `mulle-core`; it is a standalone companion tool. The README explicitly notes that "You might be better off to use **cmake** for such things", positioning this as handy for shell scripts.

## 2. Key Concepts & Design Philosophy

- **Everything is a query.** The tool is organized as a single dispatcher script with subcommands. Each subcommand maps to one `src/` module named `mulle-platform-<name>.sh`, which defines a `platform::<name>::main` entry function.
- **Platform names** follow `MULLE_UNAME` conventions: `darwin`, `linux`, `mingw`, `msys`, `windows`, `freebsd`, `openbsd`, `netbsd`, `dragonfly`, `bsd`, `sunos`. Many commands accept `--platform <os>` to query a *target* platform even when running on a different host (e.g., cross-compilation).
- **Environment-variable output style.** Query commands that produce values (e.g. `environment`, `compiler env`, `compiler flags`, `linker env`, `linker flags`) print `NAME="value"` lines so they can be incorporated into shell code with backticks + `eval`. The set of emitted variable names is the contract a caller should rely on.
- **Shared library suffix/prefix model.** `environment` computes these definitions by platform and they are reused by `search` (via `platform::environment::__get_fix_definitions`) with internal names such as `_prefix_lib`, `_suffix_staticlib`, `_suffix_dynamiclib`, `_suffix_framework`, `_option_linklib`, `_option_libpath`, `_option_rpath`, `_option_rpath_value_prefix`, `_option_frameworkpath`, `_option_link_mode`, `_suffix_object`, `_suffix_executable`, and a per-host path mangler `_r_path_mangler` (no-op normally, `platform::wsl::r_wslpath` under Windows WSL).
- **Plugin architecture.** Compiler behavior (`src/plugins/compilers/gcc.sh|clang.sh|mulle-clang.sh|msvc.sh`) and platform behavior (`src/plugins/platforms/linux.sh|darwin.sh|bsd.sh|sunos.sh|windows.sh`) are externalized into plugins loaded by `platform::plugin::load_compiler` / `platform::plugin::load_platform`. Plugins expose functions like `platform::plugin::compiler::<type>::get_flags`, `r_format_*_flag`, and `platform::plugin::platform::<name>::r_quirks` / `r_emulator`. Quirks are also exposed via the `quirks` command.
- **Cross-compilation note on Windows.** Many commands special-case `mingw`/`msys`/`windows`, including a distinction between *native* Windows (MSVC output style, `.lib`, `.obj`) and *cross*-compilation to Windows via MinGW (GNU-style flags, import libraries `.dll.a`).

## 3. Core API & Data Structures

This is a shell tool, so the public API is the **command-line surface** of `mulle-platform [flags] <command> [options]`. There are no C structs. The authoritative set of commands is the `case` dispatch in the `mulle-platform` script; use `mulle-platform <command> -h` for the canonical per-command help.

### 3.1. Global dispatcher (`mulle-platform`)

- **Purpose:** Parse global flags, then dispatch to a subcommand module.
- **Global flags** (parsed before the command): `-f|--force`, `-h*|--help|help`, `--version`, plus the runtime technical flags (`-n --dry-run`, `-s --silent`, `-v --verbose`, `-vv/--very-verbose`, `-ld --log-debug`, `-lt --trace`, etc.). `MULLE_FLAG_MAGNUM_FORCE` is set by `-f/--force`.
- `MULLE_EXECUTABLE_VERSION` is "1.4.0".
- The command table (from `platform::print_commands`, sorted at usage time):
  - `compile` — generate and execute platform-appropriate compile command
  - `compiler run` — generate and execute platform-appropriate compile command
  - `compiler env` — select and configure compiler for platform/language
  - `compiler list` — list installed compilers on the system
  - `compiler flags` — generate platform and configuration-appropriate flags
  - `crosscompiler-root` — find cross-compiler toolchain root directory
  - `emulator` — get default emulator for cross-platform execution
  - `environment` — output platform-specific information in env style
  - `export` — produce linker flags for exporting a symbol
  - `flags` — generate platform and configuration-appropriate flags (documented in help; legacy no-longer-dispatched in `main()`, use `compiler flags`/`linker flags`)
  - `includepath` — print path for OS headers
  - `languages` — list available languages and dialects
  - `link` — generate and execute platform-appropriate link command
  - `linker run` — generate and execute platform-appropriate link command
  - `linker env` — select and configure linker for platform/language
  - `linker list` — list installed linkers on the system
  - `linker flags` — generate platform and configuration-appropriate linker flags
  - `quirks` — check for platform-specific behaviors
  - `search` — search for an OS library
  - `searchpath` — print searchpath for OS libraries
  - `translate` — translate link commands
  - `wholearchive` — produce linker command for whole archive linking
  - Hidden (shown only with verbosity): `sdkpath` (print SDK path), `libexec-dir` (print path to mulle-platform libexec), `uname` (simplified `uname(1)`), `version` (print mulle-platform version).
- The tool locates its modules via `MULLE_PLATFORM_LIBEXEC_DIR` (defaults to `src` in development, `../libexec` when deployed), found with `r_get_libexec_dir`.

### 3.2. `environment` — platform definitions (module `mulle-platform-environment.sh`)

- **Purpose:** Prints `NAME="value"` lines for the chosen platform so a script can do `eval \`mulle-platform environment --platform darwin\``.
- **Options:**
  - `--platform <os>` / `--os` / `-p` : specify platform (default `$MULLE_UNAME`)
  - `--build-tools` / `-b` : also emit build tool definitions; sets `OPTION_BUILD_TOOLS='YES'` and by default also turns off the library block
  - `--no-build-tools` : disable build tool output
  - `--library` / `-l` : emit library flags and strings (this is the default)
  - `--no-library` : disable library output
- **Build tools emitted** (only with `--build-tools`): `CMAKE`, `CMAKE_GENERATOR`, `MAKE`. Per platform defaults, e.g. on `mingw|msys`: variants pick `nmake` / `MinGW Makefiles` / `mulle-mingw-cmake.sh`; on `windows`: `cl.exe`/`ninja.exe`.
- **Library/executable variables emitted** (default output for a non-Windows platform, verbatim names):
  - `MULLE_PLATFORM_EXECUTABLE_SUFFIX`
  - On `darwin`: `MULLE_PLATFORM_FRAMEWORK_PATH_LDFLAG`, `MULLE_PLATFORM_FRAMEWORK_PREFIX`, `MULLE_PLATFORM_FRAMEWORK_SUFFIX`
  - `MULLE_PLATFORM_LIBRARY_LDFLAG`
  - `MULLE_PLATFORM_LIBRARY_PATH_LDFLAG`
  - `MULLE_PLATFORM_LIBRARY_PREFIX`
  - `MULLE_PLATFORM_LIBRARY_SUFFIX_STATIC`
  - `MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC`
  - `MULLE_PLATFORM_LINK_MODE`
  - `MULLE_PLATFORM_OBJECT_SUFFIX`
  - `MULLE_PLATFORM_RPATH_LDFLAG`
  - `MULLE_PLATFORM_RPATH_VALUE_PREFIX`
  - `MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_DEFAULT`
  - `MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_STATIC`
- **Example values** (linux): `MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC=".so"`, `MULLE_PLATFORM_LIBRARY_SUFFIX_STATIC=".a"`, `MULLE_PLATFORM_OBJECT_SUFFIX=".o"`, `MULLE_PLATFORM_LIBRARY_LDFLAG="-l"`, `MULLE_PLATFORM_LIBRARY_PATH_LDFLAG="-L"`, `MULLE_PLATFORM_LIBRARY_PREFIX="lib"`, `MULLE_PLATFORM_LINK_MODE="basename,no-suffix"`, `MULLE_PLATFORM_RPATH_LDFLAG="-Wl,-rpath="`, `MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_DEFAULT="whole-archive,no-as-needed,export-dynamic"`, `MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_STATIC="whole-archive,no-as-needed"`. Darwin overrides suffix to `.dylib`/`.framework` and framework path flag to `-F`. Windows (MinGW/MSVC) uses `-libpath:` (no space), no `-l`, `.dll`/`.lib`, `.obj`, `.exe`.
- **Internal helper functions used elsewhere:** `platform::environment::__get_fix_definitions <platform>` fills the `_prefix_lib`/`_suffix_*`/`_option_*` globals; `platform::environment::r_whole_archive_format <format> <platform>` maps `DEFAULT`/`STATIC` to the per-platform plugin spellings (`whole-archive`, `whole-archive-win`, `force-load`, …); `platform::environment::print_var <key>` / `print_kv <key> <value>`.

### 3.3. `search` — find a library (`src/mulle-platform-search.sh`)

- **Purpose:** Search for files (usually libraries) by name in the platform search path and print the resolved absolute file path. "Installed software outside your project". README example: `mulle-platform search dl` → `/usr/lib/x86_64-linux-gnu/libdl.a`.
- **Options:**
  - `<name>`… : one or more library/basename names (first match wins)
  - `--prefer <libtype>` : `static` or `dynamic` (default `static`)
  - `--require <libtype>` : `static` or `dynamic` (default: none — then prefers the requested `--prefer` type, falling back to the other)
  - `--platform <os>` : target platform (default `$MULLE_UNAME`)
  - `--search-path <path>` : colon-separated path override (default: from `searchpath` command)
  - `--type <filetype>` : `library`, `standalone`, or `framework` (default `library`)
  - `--output-format <f>` : `file` or `ld`
- **Resolution algorithm** (`platform::search::r_platform_search`): for each directory of the search path, `library`/`standalone`/`framework` variants are tried. Static lookup uses `<prefix><name><suffix>` where prefix/suffix come from `__get_fix_definitions` (`lib` + `.a` on Linux). On Windows dynamic lookup tries import libraries `lib<name>.dll.a` (MinGW cross) then `lib<name>.lib` (native MSVC) before/around `.dll` itself. Diagnostics warn when `*dll` vs `*.so` mismatches indicate the wrong toolchain was used for cross-compilation.

### 3.4. `searchpath` — print OS library searchpath (`src/mulle-platform-searchpath.sh`)

- **Purpose:** print the colon-separated search path used for finding OS libraries. "Works on linux and darwin."
- No options.
- Implementation: On linux-type systems it queries the linker (`cc -Xlinker --verbose`) for `SEARCH_DIR` values; on darwin it uses `xcrun --show-sdk-path` (`/usr/local/lib:<sdk>/usr/lib:/usr/lib`); on Windows it scans `PATH` for `Windows Kits` bin directories and derives the matching `Lib/<version>/um/<arch>` directory. Caches in `MULLE_PLATFORM_SEARCHPATH`.
- The reusable function `platform::search::r_platform_searchpath` (in `mulle-platform-searchpath.sh`) sets `RVAL`.

### 3.5. Pure query commands: `includepath`, `sdkpath`, `export`, `translate`, `quirks`, `emulator`, `crosscompiler-root`, `languages`, `libexec-dir`, `uname`, `version`

- **`includepath`** — print colon-separated path used for finding headers (`/usr/local/include:/usr/include` plus the dirs queried from `gcc -E -Wp,-v -xc /dev/null`, excluding `.../Frameworks`). Caches in `MULLE_PLATFORM_INCLUDEPATH`.
- **`sdkpath`** — print the SDK path (useful on darwin only). Dispatches to `platform::sdkpath::r_<uname>_sdkpath` (darwin uses `xcrun --show-sdk-path`, fallback `xcode-select -print-path`).
- **`export <symbol>`** — produce flags for exporting symbols. Use `--compiler` (default, cc flags) or `--linker` (ld flags); `--platform`, `--compiler-type gcc|clang|msvc`.
- **`translate`** — convert filenames/link definitions into linker-representation flags. Options: `--option` (specify link command option), `--output-format <ld|file|ldpath|ld_library_path|path|rpath>` (default `ld`), `--prefix <p>`, `--platform`/`-p`/`--os`/`--fake-uname`, `--separator <sep>`, `--quote`, `--marks <names>`, `--mode <mode>`, `--dynamic`/`--static`/`--standalone` (preferred library style), `--preferred-library-style`, `--whole-archive-format <whole-archive|force-load|none|whole-archive-win|as-needed|DEFAULT>`. Internals: `platform::translate::is_dynamic_library <name> <dynSuffix>`, `_r_translate_file`, `r_simplify_wholearchive`.
- **`wholearchive`** — prints just `platform::translate::r_default_wholearchive_format "<archive>"`.
- **`quirks`** — list, show, or check platform-specific behaviors: usage syntax is `quirks [list|show|check <name>]` with `--platform`. Known quirk names: `mingw-needs-link-flag`, `needs-exported-symbols`, `windows-needs-dll-path`, `msvc-needs-md-flag`, `needs-pic-for-shared`, `supports-rpath`, `needs-framework-flag` (Darwin), `needs-whole-archive`, `uses-dyld`, `uses-ld-library-path`, `supports-sanitizer-address/thread/undefined/memory/leak`, `supports-coverage`. Platform plugins supply `platform::plugin::platform::<name>::r_quirks` (e.g. linux: `needs-pic-for-shared supports-rpath uses-ld-library-path ...`).
- **`emulator`** — return the default emulator to run a *target* platform's binaries on the host. `--platform <platform>` required; empty when target==host. Host platform plugin supplies `r_emulator` (e.g. on Linux, for target `windows`/`mingw*` → `WINEDEBUG=fixme-all,err-all wine`).
- **`crosscompiler-root`** — find highest-version cross toolchain root under `/opt` matching `/opt/<compiler>-*<platform>/<version>`. Options `--compiler <gcc|mulle-clang|...>` and `--platform <windows|mingw|...>`.
- **`languages`** — list languages/dialects from compiler plugins. `--compiler-type <gcc|clang|msvc>`.
- **`libexec-dir`** — print `MULLE_PLATFORM_LIBEXEC_DIR`.
- **`uname`** — print simplified `$MULLE_UNAME`.
- **`version`** — print `$MULLE_EXECUTABLE_VERSION` (`1.4.0`).

### 3.6. Compiler commands

#### `compiler env` (`src/mulle-platform-compiler-environment.sh`)
- **Purpose:** select and configure compiler for platform/language/dialect. Output as env (`--print-env`, default) or JSON (`--print-json`).
- Options: `--platform <name>`, `--language <name>` (default `c`), `--dialect <name>` (for `c`: `c`, `objc`), `--objc-dialect` (default `mulle-objc`), `--compiler-type <gcc|clang|mulle-clang|cl>`.
- **Env output (`--print-env`)**: `CC="..."`, `CXX="..."`, `COMPILER_TYPE="..."`. JSON output has keys `"CC"`, `"CXX"`, `"COMPILER_TYPE"`.
- Example from usage: `eval \`mulle-platform compiler --language c --dialect objc\`; echo ${CC}`.
- **`compiler list`** (`mulle-platform-compiler-list.sh`): list installed compilers. Option `--verbose` adds paths and versions.
- **`compiler flags`** — `mulle-platform-compiler-flags.sh`; Options `--platform`, `--language` (default `c`), `--dialect` (for `c`: `c`, `objc`), `--objc-dialect` (default `mulle-objc`), `--configuration` (Debug|Release|Test|RelWithDebInfo, default `Debug`), `--compiler-type` (gcc, clang, msvc), `--type` (compile|link|both, default `both`), `--sanitizer <address|thread|undefined>` (repeatable), `--print-env` vs `--print-list`. Emits env vars: `CFLAGS` (for compile type), `LDFLAGS` (for link type), and `CPPFLAGS=""`. For example an objc Release build yields flags like `-O3 -g -DNDEBUG -fobjc-tao`.

### 3.7. Linker environment

- **`linker env`** — `mulle-platform-linker-environment.sh`: Options `--platform`, `--language` (default `c`), `--dialect`, `--linker-type` (ld, gold, lld, link), `--print-env` (default) / `--print-json`. Currently emits placeholder `LD` (implementation is under development).
- **`linker list`** — `mulle-platform-linker-list.sh`: `--platform`, `--verbose`. Current implementation is a placeholder; prints at least `ld` (and with `--verbose` a `NAME PER-VERSION` table).
- **`linker flags`** — `mulle-platform-linker-flags.sh`: same options as `compiler flags` (language/dialect/configuration/linker-type), `--type <link|both>`, `--print-env` (default) or `--print-list`. Emits `LDFLAGS="..."`.

### 3.8. `compile` and `link`/`linker run` — generate and execute real tool commands

#### `compile` (also `compiler run`)
- Dispatches a platform/configuration-appropriate compile command line and prints it; unless `--print-only`, also executes it with the mulle executor.
- **Options**: `--platform`, `--language c|cpp|objc` (default detect by extension), `--dialect`, `--configuration` (Debug|Release|Test|RelWithDebInfo, default Debug), `--no-default-cflags`, `--compiler-type`, `-F <dir>` (repeatable), `-I <dir>` (repeatable), `-D <define>` (repeatable), `-c`, `--shared`, `--sanitizer`, `--coverage`, `--export-symbol`, `--export-dynamic`, `--output-asm`, `--emit-llvm` (with `--output-asm`), `--show-headers`, `--rpath <path>` (repeat), `-L <dir>` (repeat), `-l <lib>` (repeat), `--wholearchive <lib>` (repeat), `-Wl,<options>` (repeat), `-o <file>`, `--print-only`, `--`.
- **Behavioral notes**: builds up `cmdline` array from compiler plugin `r_format_*` functions (include dirs `-I`, defines `-D`, output filenames `-o`); on Windows/WSL it passes paths via wslpath and uses `/I`, `/Fo`, `/Fe`. `--print-only` prints the assembled command without running; otherwise it prints and executes.

#### `link` (also `linker run`)
- Same as `compile` but for linking object files into executables/dynamic libs: `-L <dir>` (repeat), `-l <lib>` (repeat), `-F <dir>` (Darwin), `-framework <name>` (Darwin), `-o <file>`, `--shared`, `--print-only`, `--platform`, `--language`, `--dialect`, `--objc-dialect`, `--configuration`, `--compiler-type`, `--`. Example: `mulle-platform link -L/usr/local/lib -lfoo -o myapp foo.o bar.o`.

### 3.9. Flags helpers (`src/mulle-platform-flags.sh`) — for internal reuse

- Helper functions for script authors: `platform::flags::r_cc_include_dir <dir> <quote>`, `r_cc_framework_dir`, `r_cc_output_object_filename`, `r_cc_output_exe_filename` — mapped to `-I<dir>`, `-F<dir>`, `-o <f>`/`/Fo`/`/Fe` per platform (WSL/Windows translate paths and use `/I"/path"`).

Modules loaded from libexec: `mulle-platform-mingw.sh`, `mulle-platform-mingwbourne.sh`, `mulle-platform-wsl.sh` (path mangling helpers such as `platform::mingw::r_mangle_compiler_exe` for `CC`/`CXX` on MinGW), `mulle-platform-plugin.sh` (plugin loader exposing `platform::plugin::load_compiler <type>`, `load_platform <name>`, `list_compilers`, `list_platforms`).

### 3.10. Environment variables a shell script may inspect

| Variable | Meaning |
| --- | --- |
| `MULLE_PLATFORM_EXECUTABLE_SUFFIX` | `.exe` on Windows, empty otherwise |
| `MULLE_PLATFORM_LIBRARY_LDFLAG` | link option prefix, e.g. `-l` (empty for MSVC `-libpath:`) |
| `MULLE_PLATFORM_LIBRARY_PATH_LDFLAG` | library search option, e.g. `-L`, `-F` (darwin kit) |
| `MULLE_PLATFORM_LIBRARY_PREFIX` | `lib` (empty for MSVC) |
| `MULLE_PLATFORM_LIBRARY_SUFFIX_STATIC` | `.a` (`.lib` for MSVC) |
| `MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC` | `.so` (`.dylib`/`.framework` darwin, `.dll` win32) |
| `MULLE_PLATFORM_OBJECT_SUFFIX` | `.o` (`.obj` for MSVC) |
| `MULLE_PLATFORM_LINK_MODE` | e.g. `basename,no-suffix`, `basename,no-suffix,add-suffix-staticlib` |
| `MULLE_PLATFORM_RPATH_LDFLAG` | `-Wl,-rpath` or `-Wl,-rpath=` |
| `MULLE_PLATFORM_RPATH_VALUE_PREFIX` | ` -Wl,` or empty |
| `MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_DEFAULT` / `_STATIC` | `whole-archive,no-as-needed[,export-dynamic]` |
| `CC`, `CXX`, `COMPILER_TYPE` | from `compiler env` |
| `CFLAGS`, `LDFLAGS`, `CPPFLAGS` | from `compiler flags` |
| `LDFLAGS` | from `linker flags` |
| `CMAKE`, `CMAKE_GENERATOR`, `MAKE` | from `environment --build-tools` |

## 4. Performance Characteristics

- This is a shell tool, not a library; performance characteristics are procedural:
  - `search` is linear in the number of search-path directories × applicable library suffixes (constant suffix set per platform); it stops at first hit. `--require`/`--prefer` saves I/O by checking one file-type family first, falls back only on miss.
  - `searchpath`, `includepath`, `sdkpath`: one-time derived values (from output of `cc -Xlinker --verbose`, `gcc -E -Wp,-v`, or `xcrun`) are cached in module-level variables (`MULLE_PLATFORM_SEARCHPATH`, `MULLE_PLATFORM_INCLUDEPATH`), so repeated queries within one process are O(1).
  - `crosscompiler-root` scans `/opt` once and picks the highest version; `O(n)` in the number of matching dirs.
  - `compile`/`link`: same order-of-magnitude as running the compiler/linker directly; `--print-only` avoids subprocess execution.
- **Thread-safety / concurrency**: Bash scripts — single-threaded, no locking. Do not invoke the dispatcher concurrently on the same `TMPDIR`/install; mulle-sde itself warns "Avoid running mulle-sde commands in parallel."

## 5. AI Usage Recommendations & Patterns

- **Best practices**
  - Use the `environment` command as the canonical source of `*_SUFFIX`, `*_PREFIX`, and flags; don't hardcode `.so`/`.a`/`-l` forms in your own script. E.g. `eval \`mulle-platform environment\` && echo "dynamic ext is $MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC"`. On macOS note the extra framework vars are emitted.
  - Use `--platform` to query definitions for cross-targets (e.g. `environment --platform mingw`).
  - For obtaining `CC`/`CXX`, use `compiler env`; `environment --build-tools` deliberately does **not** emit `CC`/`CXX`.
  - For compilers, output variables `CFLAGS`/`LDFLAGS`, use `--print-env` to eval them, else `--print-list` to get a word list.
  - Prefer `cmake` for permanent build logic (README says so); use `mulle-platform` when a small shell script needs the answer.
  - Return values for query helpers are carried in the global `RVAL`; the `r_` prefix convention means "this function sets `RVAL`".
- **Common pitfalls:**
  - This whole tool is name-stable for the *environment* variables, but the command surface may be evolving; verify subcommand options with `-h`, especially for `flags`, `linker env`, `linker list`, and `linker flags` (currently contain TODO/placeholder implementations).
  - `MULLE_PLATFORM_LINK_MODE` is a comma-separated hint (e.g. `basename,no-suffix`), not a direct flag list.
  - `sdkpath` is meaningless on non-darwin; it returns nothing unless a platform-specific `r_<uname>_sdkpath` function exists.
  - `wholearchive` needs a full archive filename (it calls `platform::translate::r_default_wholearchive_format`, which sets `RVAL`).
  - Do not rely on `-L`/`-l` / `-F` spelling from other platforms: `translate` and `compile`/`link` re-map them per target platform (e.g. `-libpath:` for Windows/MSVC).
- **Idiomatic usage (mulle-sde way):** run tool queries as the top-level CLI, parse the `key="value"` lines with `eval` in a controlled block, and let mulle-platform own all platform variance. Runtime functions used internally (from mulle-bash) follow `r_<name>` (result in `RVAL`), `log_*` (logging), `rexekutor`/`exekutor` (execution w/ tracing), and `.foreachpath`/`.foreachline` loops.

## 6. Integration Examples

These mimic the project's own style (3-space indent, `platform::name::function` naming, `RVAL` results, `eval` of env output).

### Example 1: Query platform library suffixes and use them in a script

```bash
# capture the platform defaults as shell variables, then use them
MULLE_PLATFORM_STRING="$(mulle-platform environment --platform "$(mulle-platform uname)")"
eval "${MULLE_PLATFORM_STRING}"

# now script uses platform-invariant names
printf 'static library extension: %s\n' "${MULLE_PLATFORM_LIBRARY_SUFFIX_STATIC}"
printf 'dynamic library extension: %s\n' "${MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC}"
printf 'object file extension: %s\n' "${MULLE_PLATFORM_OBJECT_SUFFIX}"
printf 'link with: %s %s\n' "${MULLE_PLATFORM_LIBRARY_LDFLAG}" "${MULLE_PLATFORM_LIBRARY_PATH_LDFLAG}"
```

### Example 2: Search for a library across the system search path

```bash
# find zlib wherever the OS keeps it
path="$(mulle-platform search z)"
if [ ! -z "${path}" ]
then
   echo "found: ${path}"
else
   echo "z library not found" >&2
   exit 1
fi

# force a static library, prefer static first then dynamic
mulle-platform search --prefer dynamic dl

# search a framework on darwin
mulle-platform search --type framework --platform darwin CoreFoundation || :
```

### Example 3: Select a compiler and produce flags for a Release objc build

```bash
# configure compiler
eval "$(mulle-platform compiler env --language c --dialect objc --configuration Release --print-env)"
echo "cc=${CC} cxx=${CXX} type=${COMPILER_TYPE}"

# get the flags in env or list form
eval "$(mulle-platform compiler flags --language c --dialect objc --objc-dialect mulle-objc --configuration Release --print-env)"
echo "CFLAGS=${CFLAGS}"
echo "LDFLAGS=${LDFLAGS}"
flags="$(mulle-platform compiler flags --configuration Release --print-list)"
for flag in ${flags}
do
   echo "flag: ${flag}"
done
```

### Example 4: use `compile` to compile and link a small program

```bash
# write a tiny source
cat > hello.c <<'EOF'
#include <stdio.h>
int main( void)
{
   printf( "hello platform\n");
   return( 0);
}
EOF

# compile object (prints the cc line)
mulle-platform compile -c hello.c -o hello.o --print-only

# link
mulle-platform link hello.o -o hello --print-only

# real execution
mulle-platform compile -c hello.c -o hello.o
mulle-platform link hello.o -o hello
./hello
```

### Example 5: resolve a library path for a linker invocation

```bash
# convert a library name list to linker args, with explicit output format
mulle-platform translate --output-format ld --separator ' ' -lanl
mulle-platform wholearchive libz.a
```

## 7. Dependencies

- The project has no code-level dependency libraries (it ships solely as scripts). Its direct runtime prerequisites:
  - `mulle-bash` (the `/usr/bin/env mulle-bash` shebang interpreter) and the mulle-bash runtime functions it relies on (`fail`, `log_error`, `log_warning`, `rexekutor`, `exekutor`, `r_filepath_concat`, `r_shell_indirect_expand`, `r_escaped_doublequotes`, `options_technical_flags`, `call_with_flags`, `.foreachpath`, `.foreachline`, `shell_is_function`, `mudo`, `include`, `dir_list_files`, …).
  - `mulle-sde` / `mulle-env` (the tool is usually installed alongside them; `mulle-platform` obtains its shell helpers from the shared mulle-bash runtime).
- Optional runtime needs: `cc`/`gcc`/`clang` (or `mulle-clang`) on Linux/BSD for `searchpath`/`includepath`; `xcrun`/`xcode-select` on darwin for `sdkpath`/`searchpath`; on Windows WSL, `cygpath` and the Windows SDK on `PATH` for `searchpath`.
- No sourcetree/managed dependency list exists in `.mulle/etc/sourcetree/config` for this standalone CLI.

## 8. Shortcut

- This file was just created (no prior `index.md` existed in `asset/dox/api/toc/`); it covers the whole project as of version 1.4.0.