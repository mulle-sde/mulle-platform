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

MULLE_PLATFORM_COMPILER_FLAGS_SH='included'


platform::compiler_flags::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} flags [options]

   Generate platform and configuration-appropriate compiler/linker flags.
   Output is in environment variable format suitable for eval.

Options:
   --platform <name>        : Platform (default: ${MULLE_UNAME})
   --language <name>        : Language: c (default: c)
   --dialect <name>         : Dialect for the language (c has: c, objc)
   --configuration <name>   : Debug, Release, Test, RelWithDebInfo (default: Debug)
   --compiler-type <type>   : Compiler type (gcc, clang, msvc)
   --type <type>            : Flag type: compile, link, or both (default: both)
   --print-env              : Output as environment variables (default)
   --print-list             : Output as space-separated list

Example:
   eval \`mulle-platform flags --configuration Release --language c --dialect objc\`
   echo \${CFLAGS}  # Outputs: -O3 -g -DNDEBUG -fobjc-tao (or similar)

EOF
   exit 1
}


# These functions have been moved to compiler plugins


platform::compiler_flags::print_var()
{
   local key="$1"
   local value="$2"

   r_escaped_doublequotes "${value}"
   printf "%s=\"%s\"\n" "${key}" "${RVAL}"
}


platform::compiler_flags::main()
{
   log_entry "platform::compiler_flags::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_LANGUAGE="c"
   local OPTION_DIALECT
   local OPTION_OBJC_DIALECT="mulle-objc"
   local OPTION_CONFIGURATION="Debug"
   local OPTION_COMPILER_TYPE
   local OPTION_FLAG_TYPE="both"
   local OPTION_OUTPUT_FORMAT="env"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::compiler_flags::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         --language)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_LANGUAGE="$1"
         ;;

         --dialect)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_DIALECT="$1"
         ;;

         --objc-dialect)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_OBJC_DIALECT="$1"
         ;;

         --configuration)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_CONFIGURATION="$1"
         ;;

         --compiler-type)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER_TYPE="$1"
         ;;

         --type)
            [ $# -eq 1 ] && platform::compiler_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_FLAG_TYPE="$1"
            case "${OPTION_FLAG_TYPE}" in
               compile|link|both)
               ;;
               *)
                  platform::compiler_flags::usage "Unknown flag type \"${OPTION_FLAG_TYPE}\""
               ;;
            esac
         ;;

         --print-env)
            OPTION_OUTPUT_FORMAT="env"
         ;;

         --print-list)
            OPTION_OUTPUT_FORMAT="list"
         ;;

         -*)
            platform::compiler_flags::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::compiler_flags::usage "Superfluous arguments \"$*\""

   # Set dialect default based on language if not specified
   if [ -z "${OPTION_DIALECT}" ]
   then
      case "${OPTION_LANGUAGE}" in
         c)
            OPTION_DIALECT="c"
         ;;
         *)
            OPTION_DIALECT="${OPTION_LANGUAGE}"
         ;;
      esac
   fi

   # Detect compiler type if not specified
   if [ -z "${OPTION_COMPILER_TYPE}" ]
   then
      include "platform::compiler"

      platform::compiler::r_select_c_compiler "${OPTION_PLATFORM}" \
                                              "${OPTION_DIALECT}" \
                                              "${OPTION_OBJC_DIALECT}" \
                                              ""
      local cc="${RVAL}"

      platform::compiler::r_detect_compiler_type "${cc}"
      OPTION_COMPILER_TYPE="${RVAL}"
   fi

   # Load the compiler plugin
   include "platform::plugin"

   # Map compiler types to plugin names
   local plugin_name
   case "${OPTION_COMPILER_TYPE}" in
      gcc|clang|mulle-clang)
         plugin_name="gcc"
      ;;
      msvc)
         plugin_name="msvc"
      ;;

      'DEFAULT')
         case "${OPTION_PLATFORM}" in
            'windows')
               plugin_name='msvc'
            ;;

            'darwin')
               plugin_name='clang'
            ;;

            *)
               plugin_name='gcc'
            ;;
         esac
      ;;

      *)
         # Fallback to gcc plugin for unknown compilers
         plugin_name="gcc"
         log_warning "Unknown compiler type \"${OPTION_COMPILER_TYPE}\", using gcc plugin as fallback"
      ;;
   esac

   if ! platform::plugin::load_compiler "${plugin_name}"
   then
      fail "Failed to load compiler plugin \"${plugin_name}\""
   fi

   local cflags
   local ldflags

   # Get flags from compiler plugin
   if [ "${OPTION_FLAG_TYPE}" = "compile" ] || [ "${OPTION_FLAG_TYPE}" = "both" ]
   then
      platform::plugin::compiler::${plugin_name}::get_flags "${OPTION_CONFIGURATION}" \
                                                            "${OPTION_DIALECT}" \
                                                            "${OPTION_OBJC_DIALECT}"
      cflags="${RVAL}"
   fi

   if [ "${OPTION_FLAG_TYPE}" = "link" ] || [ "${OPTION_FLAG_TYPE}" = "both" ]
   then
      platform::plugin::compiler::${plugin_name}::get_ldflags "${OPTION_CONFIGURATION}" \
                                                              "${OPTION_PLATFORM}"
      ldflags="${RVAL}"
   fi

   # Output results
   case "${OPTION_OUTPUT_FORMAT}" in
      env)
         if [ ! -z "${cflags}" ]
         then
            platform::compiler_flags::print_var "CFLAGS" "${cflags}"
         fi
         if [ ! -z "${ldflags}" ]
         then
            platform::compiler_flags::print_var "LDFLAGS" "${ldflags}"
         fi
         platform::compiler_flags::print_var "CPPFLAGS" ""
      ;;

      list)
         if [ ! -z "${cflags}" ]
         then
            printf "%s\n" "${cflags}"
         fi
         if [ ! -z "${ldflags}" ]
         then
            printf "%s\n" "${ldflags}"
         fi
      ;;
   esac
}
