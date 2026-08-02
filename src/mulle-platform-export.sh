# shellcheck shell=bash
#
#   Copyright (c) 2025 Nat! - Mulle kybernetiK
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
MULLE_PLATFORM_EXPORT_SH='included'


platform::export::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} export [options] <symbol>

   Produces the necessary linker or cc flags for exporting a symbol or
   multiple symbols.

Options:
   --platform <name>    : Platform (default: ${MULLE_UNAME})
   --compiler-type <t>  : Compiler type (gcc, clang, msvc)
   --compiler           : produce compiler flags (default)
   --linker             : produce linker flags
EOF
   exit 1
}


platform::export::main()
{
   log_entry "platform::export::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_COMPILER_TYPE
   local OPTION_FLAG_TYPE="cc" # cc or ld

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::export::usage
         ;; 

         --platform)
            [ $# -eq 1 ] && platform::export::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;; 

         --compiler-type)
            [ $# -eq 1 ] && platform::export::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER_TYPE="$1"
         ;; 

         --compiler)
            OPTION_FLAG_TYPE="cc"
         ;; 

         --linker)
            OPTION_FLAG_TYPE="ld"
         ;; 

         -*)
            platform::export::usage "Unknown option \"$1\""
         ;; 

         *)
            break
         ;; 
      esac
      shift
   done


   if [ $# -eq 0  ]
   then
      platform::export::usage "Missing symbol argument"
   fi

   include "platform::compiler-environment"
   include "platform::plugin"

   local original_mulle_uname="${MULLE_UNAME}"
   MULLE_UNAME="${OPTION_PLATFORM}"

   #
   # Get compiler, just to determine the compiler type. We don't actually
   # use the compiler executable.
   # Default language to "c" for this.
   #
   platform::compiler::r_select_c_compiler "${OPTION_PLATFORM}" \
                                           "c" \
                                           "mulle-objc" \
                                           "${OPTION_COMPILER_TYPE}"
   local cc_executable_path="${RVAL}"
   
   local detected_compiler_type
   if [ ! -z "${OPTION_COMPILER_TYPE}" ]
   then
      plugin_name="${OPTION_COMPILER_TYPE}"
   else
      platform::compiler::r_detect_compiler_type "${cc_executable_path}"
      detected_compiler_type="${RVAL}"

      case "${detected_compiler_type}" in
         gcc|clang|mulle-clang|msvc)
            plugin_name="${detected_compiler_type}"
         ;;
         DEFAULT)
            # Use platform-appropriate plugin for DEFAULT
            case "${OPTION_PLATFORM}" in
               windows|mingw|msys)
                  plugin_name="msvc"
               ;;
               *)
                  plugin_name="gcc"
               ;;
            esac
         ;;
         *)
            log_warning "Unknown compiler type \"${detected_compiler_type}\", using gcc plugin"
            plugin_name="gcc"
         ;;
      esac
   fi

   if ! platform::plugin::load_compiler "${plugin_name}"
   then
      fail "Failed to load compiler plugin \"${plugin_name}\""
   fi

   local flags
   local symbol
   local cmdline

   while [ $# -ne 0 ]
   do
      symbol="$1"
      shift
      #
      # With gcc/clang the flags are the same for cc and ld.
      # For msvc, the linker option is /EXPORT but cl.exe understands it.
      # The logic inside format_export_symbol_flag already handles the platform.
      # We don't need to differentiate between cc and ld here, but let's
      # keep the option for future extensions.
      #
      platform::plugin::compiler::${plugin_name}::r_format_export_symbol_flag "${symbol}"
      flags="${RVAL}"

      MULLE_UNAME="${original_mulle_uname}"

      r_concat "${cmdline}" "${flags}"
      cmdline="${RVAL}"
   done

   if [ ! -z "${cmdline}" ]
   then
      printf "%s\n" "${cmdline}"
   fi
}
