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

MULLE_PLATFORM_COMPILER_SH='included'


platform::compiler::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} compiler [options]

   Select and configure the appropriate compiler for a platform/language/dialect
   combination. Output is in environment variable format suitable for eval.

Options:
   --platform <name>        : Platform (default: ${MULLE_UNAME})
   --language <name>        : Language: c (default: c)
   --dialect <name>         : Dialect for the language (c has: c, objc)
   --compiler-type <type>   : Force compiler type (gcc, clang, mulle-clang, cl)
   --print-env              : Output as environment variables (default)
   --print-json             : Output as JSON

Example:
   eval \`mulle-platform compiler --language c --dialect objc\`
   echo \${CC}  # Outputs: cc (or similar)

EOF
   exit 1
}


platform::compiler::r_detect_compiler_type()
{
   log_entry "platform::compiler::r_detect_compiler_type" "$@"

   local compiler="$1"

   case "${compiler}" in
      *mulle-clang*)
         RVAL="mulle-clang"
      ;;

      *clang*)
         RVAL="clang"
      ;;

      *gcc*|*g++*)
         RVAL="gcc"
      ;;

      cl|cl.exe|*-cl|*-cl.exe)
         RVAL="msvc"
      ;;

      cc|c++)
         # Try to detect what cc actually is
         if command -v "${compiler}" >/dev/null 2>&1
         then
            local version_output
            version_output="$(${compiler} --version 2>&1 | head -1)"
            case "${version_output}" in
               *clang*)
                  RVAL="clang"
               ;;
               *gcc*|*GCC*)
                  RVAL="gcc"
               ;;
               *)
                  RVAL="DEFAULT"
               ;;
            esac
         else
            RVAL="DEFAULT"
         fi
      ;;

      *)
         RVAL="DEFAULT"
      ;;
   esac
}


platform::compiler::r_select_c_compiler()
{
   log_entry "platform::compiler::r_select_c_compiler" "$@"

   local platform="$1"
   local dialect="$2"
   local objc_dialect="$3"
   local compiler_type="$4"

   # Check environment variable override first
   if [ ! -z "${CC}" ] && [ "${compiler_type}" != "DEFAULT" ]
   then
      RVAL="${CC}"
      return 0
   fi

   # If compiler_type is DEFAULT, select platform default and check CC env var
   if [ "${compiler_type}" = "DEFAULT" ] || [ -z "${compiler_type}" ]
   then
      # Check for Objective-C dialect first
      case "${dialect}" in
         objc)
            case "${objc_dialect}" in
               mulle-objc)
                  # Check CC environment variable
                  if [ ! -z "${CC}" ]
                  then
                     RVAL="${CC}"
                     return 0
                  fi
                  RVAL="mulle-clang"
                  return 0
               ;;
            esac
         ;;
      esac

      # Check CC environment variable
      if [ ! -z "${CC}" ]
      then
         RVAL="${CC}"
         return 0
      fi

      # Select platform-specific default
      case "${platform}" in
         windows|mingw|msys)
            RVAL="cl.exe"
         ;;
         darwin)
            RVAL="clang"
         ;;
         *)
            RVAL="cc"
         ;;
      esac
      return 0
   fi

   # Platform-specific defaults
   case "${platform}" in
      mingw|msys)
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang-cl"
                  ;;
                  *)
                     RVAL="cl"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-cl}"
            ;;
         esac
      ;;

      windows)
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang-cl.exe"
                  ;;
                  *)
                     RVAL="cl.exe"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-cl.exe}"
            ;;
         esac
      ;;

      darwin)
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang"
                  ;;
                  *)
                     RVAL="clang"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-clang}"
            ;;
         esac
      ;;

      *bsd|dragonfly)
         RVAL="${compiler_type:-clang}"
      ;;

      sunos)
         RVAL="${compiler_type:-gcc}"
      ;;

      *)
         # Linux and others
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang"
                  ;;
                  *)
                     RVAL="${compiler_type:-cc}"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-cc}"
            ;;
         esac
      ;;
   esac
}


platform::compiler::r_select_cxx_compiler()
{
   log_entry "platform::compiler::r_select_cxx_compiler" "$@"

   local platform="$1"
   local dialect="$2"
   local objc_dialect="$3"
   local compiler_type="$4"

   # Check environment variable override first
   if [ ! -z "${CXX}" ] && [ "${compiler_type}" != "DEFAULT" ]
   then
      RVAL="${CXX}"
      return 0
   fi

   # If compiler_type is DEFAULT, select platform default and check CXX env var
   if [ "${compiler_type}" = "DEFAULT" ] || [ -z "${compiler_type}" ]
   then
      # Check for Objective-C dialect first
      case "${dialect}" in
         objc|objcpp)
            case "${objc_dialect}" in
               mulle-objc)
                  # Check CXX environment variable
                  if [ ! -z "${CXX}" ]
                  then
                     RVAL="${CXX}"
                     return 0
                  fi
                  RVAL="mulle-clang"
                  return 0
               ;;
            esac
         ;;
      esac

      # Check CXX environment variable
      if [ ! -z "${CXX}" ]
      then
         RVAL="${CXX}"
         return 0
      fi

      # Select platform-specific default
      case "${platform}" in
         windows|mingw|msys)
            RVAL="cl.exe"
         ;;
         darwin)
            RVAL="clang++"
         ;;
         *)
            RVAL="c++"
         ;;
      esac
      return 0
   fi

   # Platform-specific defaults
   case "${platform}" in
      mingw|msys)
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang-cl"
                  ;;
                  *)
                     RVAL="cl"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-cl}"
            ;;
         esac
      ;;

      windows)
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang-cl.exe"
                  ;;
                  *)
                     RVAL="cl.exe"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-cl.exe}"
            ;;
         esac
      ;;

      darwin)
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang"
                  ;;
                  *)
                     RVAL="clang++"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-clang++}"
            ;;
         esac
      ;;

      *bsd|dragonfly)
         RVAL="${compiler_type:-clang++}"
      ;;

      sunos)
         RVAL="${compiler_type:-g++}"
      ;;

      *)
         # Linux and others
         case "${dialect}" in
            objc)
               case "${objc_dialect}" in
                  mulle-objc)
                     RVAL="mulle-clang"
                  ;;
                  *)
                     RVAL="${compiler_type:-c++}"
                  ;;
               esac
            ;;
            *)
               RVAL="${compiler_type:-c++}"
            ;;
         esac
      ;;
   esac
}


platform::compiler::print_var()
{
   local key="$1"
   local value="$2"

   r_escaped_doublequotes "${value}"
   printf "%s=\"%s\"\n" "${key}" "${RVAL}"
}


platform::compiler::main()
{
   log_entry "platform::compiler::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_LANGUAGE="c"
   local OPTION_DIALECT
   local OPTION_OBJC_DIALECT="mulle-objc"
   local OPTION_COMPILER_TYPE
   local OPTION_OUTPUT_FORMAT="env"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::compiler::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::compiler::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         --language)
            [ $# -eq 1 ] && platform::compiler::usage "Missing argument to \"$1\""
            shift
            OPTION_LANGUAGE="$1"
         ;;

         --dialect)
            [ $# -eq 1 ] && platform::compiler::usage "Missing argument to \"$1\""
            shift
            OPTION_DIALECT="$1"
         ;;

         --objc-dialect)
            [ $# -eq 1 ] && platform::compiler::usage "Missing argument to \"$1\""
            shift
            OPTION_OBJC_DIALECT="$1"
         ;;

         --compiler-type)
            [ $# -eq 1 ] && platform::compiler::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER_TYPE="$1"
         ;;

         --print-env)
            OPTION_OUTPUT_FORMAT="env"
         ;;

         --print-json)
            OPTION_OUTPUT_FORMAT="json"
         ;;

         -*)
            platform::compiler::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::compiler::usage "Superfluous arguments \"$*\""

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

   # Select compilers
   platform::compiler::r_select_c_compiler "${OPTION_PLATFORM}" \
                                           "${OPTION_DIALECT}" \
                                           "${OPTION_OBJC_DIALECT}" \
                                           "${OPTION_COMPILER_TYPE}"
   local cc="${RVAL}"

   platform::compiler::r_select_cxx_compiler "${OPTION_PLATFORM}" \
                                             "${OPTION_DIALECT}" \
                                             "${OPTION_OBJC_DIALECT}" \
                                             "${OPTION_COMPILER_TYPE}"
   local cxx="${RVAL}"

   # Detect compiler type
   platform::compiler::r_detect_compiler_type "${cc}"
   local compiler_type="${RVAL}"

   # Output results
   case "${OPTION_OUTPUT_FORMAT}" in
      env)
         platform::compiler::print_var "CC" "${cc}"
         platform::compiler::print_var "CXX" "${cxx}"
         platform::compiler::print_var "COMPILER_TYPE" "${compiler_type}"
      ;;

      json)
         printf '{\n'
         printf '  "CC": "%s",\n' "${cc}"
         printf '  "CXX": "%s",\n' "${cxx}"
         printf '  "COMPILER_TYPE": "%s"\n' "${compiler_type}"
         printf '}\n'
      ;;
   esac
}
