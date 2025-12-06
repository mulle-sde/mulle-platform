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

MULLE_PLATFORM_PLUGIN_COMPILER_MSVC_SH='included'

# MSVC Compiler Plugin
# Handles cl.exe and variants

platform::plugin::compiler::msvc::get_languages()
{
   log_entry "platform::plugin::compiler::msvc::get_languages" "$@"

   printf "c\n"
}


platform::plugin::compiler::msvc::get_dialects()
{
   log_entry "platform::plugin::compiler::msvc::get_dialects" "$@"

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


platform::plugin::compiler::msvc::get_flags()
{
   log_entry "platform::plugin::compiler::msvc::get_flags" "$@"

   local configuration="$1"
   local dialect="$2"
   local objc_dialect="$3"

   local flags

   case "${configuration}" in
      Debug|Test)
         flags="/Od /Zi /DEBUG /MDd /wd4068"
      ;;

      Release)
         flags="/O2 /MD /wd4068 /DNDEBUG /DNS_BLOCK_ASSERTIONS"
      ;;

      RelWithDebInfo)
         flags="/O2 /Zi /DEBUG /MD /wd4068"
      ;;

      *)
         flags="/Od /Zi /DEBUG /MDd /wd4068"
      ;;
   esac

   # Add dialect-specific flags
   case "${dialect}" in
      objc)
         case "${objc_dialect}" in
            mulle-objc)
               r_concat "${flags}" "/FOBJC-TAO"
               flags="${RVAL}"
            ;;
         esac
      ;;
   esac

   RVAL="${flags}"
}


platform::plugin::compiler::msvc::get_ldflags()
{
   log_entry "platform::plugin::compiler::msvc::get_ldflags" "$@"

   local configuration="$1"

   local flags

   case "${configuration}" in
      Debug|Test)
         flags="/link /DEBUG"
      ;;

      *)
         flags="/link"
      ;;
   esac

   RVAL="${flags}"
}


# Format an include directory flag
platform::plugin::compiler::msvc::r_format_include_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_include_flag" "$@"

   local dir="$1"
   RVAL="/I${dir}"
}

# Format sysroot flag (SDK path) - not applicable for MSVC
platform::plugin::compiler::msvc::r_format_sysroot_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_sysroot_flag" "$@"

   # MSVC doesn't use sysroot flags
   RVAL=""
}


# Format a preprocessor define flag
platform::plugin::compiler::msvc::r_format_define_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_define_flag" "$@"

   local define="$1"
   RVAL="/D${define}"
}


# Format compile-only flag
platform::plugin::compiler::msvc::r_format_compile_only_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_compile_only_flag" "$@"

   RVAL="/c"
}


# Format output file flag for compilation
platform::plugin::compiler::msvc::r_format_output_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_output_flag" "$@"

   local output="$1"
   local compile_only="$2"
   
   if [ "${compile_only}" = 'YES' ]
   then
      RVAL="/Fo${output}"
   else
      RVAL="/Fe${output}"
   fi
}


# Format library directory flag
platform::plugin::compiler::msvc::r_format_libdir_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_libdir_flag" "$@"

   local dir="$1"
   RVAL="/LIBPATH:${dir}"
}


# Format library flag
platform::plugin::compiler::msvc::r_format_lib_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_lib_flag" "$@"

   local lib="$1"
   # MSVC uses .lib extension
   RVAL="${lib}.lib"
}


# Format framework directory flag (not supported on Windows)
platform::plugin::compiler::msvc::r_format_framework_dir_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_framework_dir_flag" "$@"

   RVAL=""
}


# Format framework flag (not supported on Windows)
platform::plugin::compiler::msvc::r_format_framework_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_framework_flag" "$@"

   RVAL=""
}


# Format shared library linking flag
platform::plugin::compiler::msvc::r_format_shared_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_shared_flag" "$@"

   local platform="$1"
   RVAL="/LD"
}


# Format shared library compilation flag (for object files)
platform::plugin::compiler::msvc::r_format_shared_compile_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_shared_compile_flag" "$@"

   local platform="$1"
   
   # MSVC doesn't need special flags for PIC (all code is position independent)
   RVAL=""
}


# Format a linker flag
platform::plugin::compiler::msvc::r_format_linker_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_linker_flag" "$@"

   local ldflag="$1"
   
   # MSVC uses /link to separate linker options
   RVAL="${ldflag}"
}


# Format whole-archive library flag
platform::plugin::compiler::msvc::r_format_wholearchive_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_wholearchive_flag" "$@"

   local lib="$1"
   local platform="$2"
   
   # MSVC uses /WHOLEARCHIVE flag
   RVAL="/WHOLEARCHIVE:${lib}.lib"
}


# Format sanitizer flag for compilation
platform::plugin::compiler::msvc::r_format_sanitizer_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_sanitizer_flag" "$@"

   local sanitizer="$1"
   
   # MSVC only supports address sanitizer (VS 2019+)
   case "${sanitizer}" in
      address)
         RVAL="/fsanitize=address"
      ;;
      *)
         # Silently ignore unsupported sanitizers as per spec
         log_fluff "Sanitizer \"${sanitizer}\" not supported by MSVC, ignoring"
         RVAL=""
      ;;
   esac
}


# Format sanitizer flag for linking
platform::plugin::compiler::msvc::r_format_sanitizer_link_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_sanitizer_link_flag" "$@"

   local sanitizer="$1"
   
   # MSVC sanitizers don't need special link flags
   RVAL=""
}


# Format coverage flag for compilation
platform::plugin::compiler::msvc::r_format_coverage_compile_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_coverage_compile_flag" "$@"

   # MSVC doesn't support --coverage, silently ignore as per spec
   log_fluff "Coverage not supported by MSVC, ignoring"
   RVAL=""
}


# Format coverage flag for linking
platform::plugin::compiler::msvc::r_format_coverage_link_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_coverage_link_flag" "$@"

   # MSVC doesn't support --coverage, silently ignore
   RVAL=""
}


# Format export symbol flag for linking
platform::plugin::compiler::msvc::r_format_export_symbol_flag()
{
   log_entry "platform::plugin::compiler::msvc::r_format_export_symbol_flag" "$@"

   local symbol="$1"
   
   # MSVC uses /EXPORT for symbol exports
   RVAL="/EXPORT:${symbol}"
}


# Format assembler output flag
platform::plugin::compiler::msvc::format_asm_output_flag()
{
   log_entry "platform::plugin::compiler::msvc::format_asm_output_flag" "$@"

   local emit_llvm="$1"
   
   # MSVC uses /FA for assembler output, doesn't support LLVM IR
   if [ "${emit_llvm}" = 'YES' ]
   then
      log_warning "LLVM IR output not supported by MSVC, generating assembler instead"
   fi
   RVAL="/FA"
}


# Format show headers flag
platform::plugin::compiler::msvc::format_show_headers_flag()
{
   log_entry "platform::plugin::compiler::msvc::format_show_headers_flag" "$@"

   # MSVC uses /showIncludes to show header includes
   RVAL="/showIncludes"
}


# Format rpath flag - not applicable for MSVC/Windows
platform::plugin::compiler::msvc::format_rpath_flag()
{
   log_entry "platform::plugin::compiler::msvc::format_rpath_flag" "$@"

   # Windows doesn't use rpath, DLLs must be in PATH or same directory
   RVAL=""
}

:
