# shellcheck shell=bash
#
#   Copyright (c) 2024 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of Mulle kybernetiK nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#

MULLE_PLATFORM_PLUGIN_COMPILER_GCC_SH='included'

# GCC/Clang Compiler Plugin
# Handles gcc, g++, clang, clang++, and mulle-clang

platform::plugin::compiler::gcc::get_languages()
{
   log_entry "platform::plugin::compiler::gcc::get_languages" "$@"

   printf "c\n"
}


platform::plugin::compiler::gcc::get_dialects()
{
   log_entry "platform::plugin::compiler::gcc::get_dialects" "$@"

   local language="$1"

   case "${language}" in
      c)
         printf "c\n"
      ;;
      *)
         # Unknown language
      ;;
   esac
}


platform::plugin::compiler::gcc::get_flags()
{
   log_entry "platform::plugin::compiler::gcc::get_flags" "$@"

   local configuration="$1"
   local dialect="$2"
   local objc_dialect="$3"

   local flags

   case "${configuration}" in
      Debug|Test)
         flags="-O0 -g"
      ;;

      Release)
         flags="-O3 -g -DNDEBUG -DNS_BLOCK_ASSERTIONS"
      ;;

      RelWithDebInfo)
         flags="-O2 -g"
      ;;

      *)
         flags="-O0 -g"
      ;;
   esac

   # Add dialect-specific flags
   case "${dialect}" in
      objc)
         case "${objc_dialect}" in
            mulle-objc)
               r_concat "${flags}" "-fobjc-tao"
               flags="${RVAL}"
            ;;
         esac
      ;;
   esac

   RVAL="${flags}"
}


platform::plugin::compiler::gcc::get_ldflags()
{
   log_entry "platform::plugin::compiler::gcc::get_ldflags" "$@"

   local configuration="$1"
   local platform="$2"

   local flags

   flags=""

   # Platform-specific linker flags
   case "${platform}" in
      darwin)
         case "${configuration}" in
            Release)
               flags="-Wl,-dead_strip"
            ;;
         esac
      ;;

      linux)
         case "${configuration}" in
            Release)
               flags="-Wl,--as-needed"
            ;;
         esac
      ;;
   esac

   RVAL="${flags}"
}


# Format an include directory flag
platform::plugin::compiler::gcc::r_format_include_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_include_flag" "$@"

   local dir="$1"
   RVAL="-I${dir}"
}


# Format sysroot flag (SDK path)
platform::plugin::compiler::gcc::r_format_sysroot_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_sysroot_flag" "$@"

   local sdk_path="$1"
   RVAL="-isysroot ${sdk_path}"
}


# Format a preprocessor define flag
platform::plugin::compiler::gcc::r_format_define_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_define_flag" "$@"

   local define="$1"
   RVAL="-D${define}"
}


# Format compile-only flag
platform::plugin::compiler::gcc::r_format_compile_only_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_compile_only_flag" "$@"

   RVAL="-c"
}


# Format output file flag for compilation
platform::plugin::compiler::gcc::r_format_output_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_output_flag" "$@"

   local output="$1"
   local compile_only="$2"
   
   # GCC uses -o for both object and executable output
   RVAL="-o ${output}"
}


# Format library directory flag
platform::plugin::compiler::gcc::r_format_libdir_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_libdir_flag" "$@"

   local dir="$1"
   RVAL="-L${dir}"
}


# Format library flag
platform::plugin::compiler::gcc::r_format_lib_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_lib_flag" "$@"

   local lib="$1"
   RVAL="-l${lib}"
}


# Format framework directory flag (Darwin only)
platform::plugin::compiler::gcc::r_format_framework_dir_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_framework_dir_flag" "$@"

   local dir="$1"
   RVAL="-F${dir}"
}


# Format framework flag (Darwin only)
platform::plugin::compiler::gcc::r_format_framework_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_framework_flag" "$@"

   local framework="$1"
   RVAL="-framework ${framework}"
}


# Format shared library linking flag
platform::plugin::compiler::gcc::r_format_shared_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_shared_flag" "$@"

   local platform="$1"
   
   case "${platform}" in
      darwin)
         RVAL="-dynamiclib"
      ;;
      *)
         RVAL="-shared"
      ;;
   esac
}


# Format shared library compilation flag (for object files)
platform::plugin::compiler::gcc::r_format_shared_compile_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_shared_compile_flag" "$@"

   local platform="$1"
   
   # Most platforms need -fPIC for shared libraries
   RVAL="-fPIC"
}


# Format a linker flag (wraps with -Wl,)
platform::plugin::compiler::gcc::r_format_linker_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_linker_flag" "$@"

   local ldflag="$1"
   
   # Wrap linker options with -Wl,
   RVAL="-Wl,${ldflag}"
}


# Format whole-archive library flag
platform::plugin::compiler::gcc::r_format_wholearchive_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_wholearchive_flag" "$@"

   local lib="$1"
   local platform="$2"
   
   # Wrap library with whole-archive flags and --as-needed wrappers
   case "${platform}" in
      darwin)
         RVAL="-Wl,-force_load,${lib}"
      ;;
      linux|*bsd|dragonfly|sunos)
         # On Linux/BSD, wrap with both --whole-archive and --as-needed
         RVAL="-Wl,--no-as-needed -Wl,--whole-archive -l${lib} -Wl,--no-whole-archive -Wl,--as-needed"
      ;;
      *)
         RVAL="-Wl,--whole-archive -l${lib} -Wl,--no-whole-archive"
      ;;
   esac
}


# Format sanitizer flag for compilation
platform::plugin::compiler::gcc::r_format_sanitizer_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_sanitizer_flag" "$@"

   local sanitizer="$1"
   
   case "${sanitizer}" in
      address|thread|undefined|memory|leak)
         RVAL="-fsanitize=${sanitizer}"
      ;;
      *)
         log_fluff "Unknown sanitizer type \"${sanitizer}\", ignoring"
         RVAL=""
      ;;
   esac
}


# Format sanitizer flag for linking
platform::plugin::compiler::gcc::r_format_sanitizer_link_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_sanitizer_link_flag" "$@"

   local sanitizer="$1"
   
   # GCC/Clang sanitizers need the same flag at link time
   case "${sanitizer}" in
      address|thread|undefined|memory|leak)
         RVAL="-fsanitize=${sanitizer}"
      ;;
      *)
         RVAL=""
      ;;
   esac
}


# Format coverage flag for compilation
platform::plugin::compiler::gcc::r_format_coverage_compile_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_coverage_compile_flag" "$@"

   RVAL="--coverage -fno-inline"
}


# Format coverage flag for linking
platform::plugin::compiler::gcc::r_format_coverage_link_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_coverage_link_flag" "$@"

   RVAL="-lgcov"
}


# Format export symbol flag for linking
platform::plugin::compiler::gcc::r_format_export_symbol_flag()
{
   log_entry "platform::plugin::compiler::gcc::r_format_export_symbol_flag" "$@"

   local symbol="$1"
   
   # GCC/Clang uses -Wl,-exported_symbol on Darwin, -Wl,--export-dynamic elsewhere
   case "${MULLE_UNAME}" in
      darwin)
         RVAL="-Wl,-exported_symbol -Wl,${symbol}"
      ;;
      *)
         # On Linux and other platforms, all symbols are exported by default for executables
         # This flag is mainly used on Darwin
         RVAL=""
      ;;
   esac
}


# Format assembler output flag
platform::plugin::compiler::gcc::format_asm_output_flag()
{
   log_entry "platform::plugin::compiler::gcc::format_asm_output_flag" "$@"

   local emit_llvm="$1"
   
   if [ "${emit_llvm}" = 'YES' ]
   then
      RVAL="-S -emit-llvm"
   else
      RVAL="-S"
   fi
}


# Format show headers flag
platform::plugin::compiler::gcc::format_show_headers_flag()
{
   log_entry "platform::plugin::compiler::gcc::format_show_headers_flag" "$@"

   RVAL="-H"
}


# Format rpath flag
platform::plugin::compiler::gcc::format_rpath_flag()
{
   log_entry "platform::plugin::compiler::gcc::format_rpath_flag" "$@"

   local rpath="$1"
   RVAL="-Wl,-rpath,${rpath}"
}

:
