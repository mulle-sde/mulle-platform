#! /usr/bin/env bash
#
#   Copyright (c) 2018 nat -
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
#   Neither the name of  nor the names of its contributors
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

MULLE_PLATFORM_TRANSLATE_SH="included"


platform_translate_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-translate} [options] <filename>

   Change the representation of filenames.

Options:
   --prefix            : specify prefix for ld
   --output-format <f> : one of file,ld,ldpath,ld_library_path,path,rpath
   --seperator <sep>   : specify seperator for filenames
EOF
   exit 1
}


r_platform_translate()
{
   log_entry "r_platform_translate" "$@"

   local format="$1"; shift
   local prefix="$1"; shift
   local sep="$1"; shift
   local wholearchiveformat="$1"; shift

   local _libprefix
   local _staticlibsuffix
   local _dynamiclibsuffix

   [ -z "${MULLE_PLATFORM_ENVIRONMENT_SH}" ] && \
      . "${MULLE_PLATFORM_LIBEXEC_DIR}/mulle-platform-environment.sh"

   _platform_get_fix_definitions

   local name
   local lines
   local csv
   local marks

   lines=""
   for csv in "$@"
   do
      name="${csv%%;*}"
      marks=""
      if [ "${name}" != "${csv}" ]
      then
         marks="${csv#*;}"
      fi

      log_debug "name  : ${name}"
      log_debug "marks : ${marks}"
      log_debug "csv   : ${csv}"

      if [ -z "${name}" ]
      then
         continue
      fi

      case "${format}" in
         file)
            r_concat "${lines}" "${name}" "${sep}"
            lines="${RVAL}"
         ;;

         # emit -l statements
         ld)
            local ldname

            r_extensionless_basename "${name}"
            ldname="${RVAL}"

            if [ ! -z "${marks}" ]
            then
               case ",${marks}," in
                  *,no-all-load,*)
                  ;;

                  *)
                     case "${wholearchiveformat}" in
                        'whole-archive')
                           r_concat "${lines}" "-Wl,--whole-archive ${prefix}${ldname#${_libprefix}} -Wl,--no-whole-archive" "${sep}"
                        ;;

                        'whole-archive-win')
                           r_concat "${lines}" "-WHOLEARCHIVE:${ldname#${_libprefix}}" "${sep}"
                        ;;

                        # force load gets full path, otherwise unhappy :/
                        'force-load')
                           r_concat "${lines}" "-force_load ${name}" "${sep}"
                        ;;

                        'none')
                           r_concat "${lines}" "${prefix}${ldname#${_libprefix}}" "${sep}"
                        ;;

                        *)
                           fail "Unknown whole-archive format \"${wholearchiveformat}\""
                        ;;
                     esac
                     lines="${RVAL}"
                     continue
                  ;;
               esac
            fi

            r_concat "${lines}" "${prefix}${ldname#${_libprefix}}" "${sep}"
            lines="${RVAL}"
         ;;

         # emit -L statements
         ldpath)
            case "${name}" in
               /*)
                  r_fast_dirname "${name}"
                  r_add_unique_line "${lines}" "${prefix}${RVAL}"
                  lines="${RVAL}"
               ;;
            esac
         ;;

         # systems that don't have rpath use LD_LIBRARY_PATH
         ld_library_path)
            case "${MULLE_UNAME}" in
               darwin|mingw)
               ;;

               *)
                  case "${name}" in
                     /*${_dynamiclibsuffix})
                        r_fast_dirname "${name}"
                        r_add_unique_line "${lines}" "${RVAL}"
                        lines="${RVAL}"
                     ;;
                  esac
               ;;
            esac
         ;;

         # PATH only set on mingw to find DLLs
         path)
            case "${MULLE_UNAME}" in
               mingw*)
                  case "${name}" in
                     /*${_dynamiclibsuffix})
                        r_fast_dirname "${name}"
                        r_add_unique_line "${lines}" "${RVAL}"
                        lines="${RVAL}"
                     ;;
                  esac
               ;;
            esac
         ;;

         rpath)
            case "${MULLE_UNAME}" in
               darwin|linux)
                  case "${name}" in
                     /*${_dynamiclibsuffix})
                        r_fast_dirname "${name}"
                        r_add_unique_line "${lines}" "${prefix}${RVAL}"
                        lines="${RVAL}"
                     ;;
                  esac
               ;;
            esac
         ;;

         *)
            internal_fail "unknown format \"${format}\""
         ;;
      esac
   done

   # path stuff needs to be reorganized
   case "${format}" in
      *path)
         local line

         RVAL=""
         IFS="
"; set -f
         for line in ${lines}
         do
            IFS="${DEFAULT_IFS}"; set +f
            r_concat "${RVAL}" "${line}" "${sep}"
         done
         IFS="${DEFAULT_IFS}"; set +f

         return
      ;;
   esac

   RVAL="${lines}"
}


platform_translate_main()
{
   log_entry "platform_translate_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_OUTPUT_FORMAT="ld"
   local OPTION_PREFIX="-l"
   local OPTION_WHOLE_ARCHIVE_FORMAT="whole-archive"
   local OPTION_SEPERATOR="
"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform_translate_usage
         ;;

         --prefix)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_PREFIX="$1"
         ;;

         --seperator)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_SEPERATOR="$1"
         ;;

         --whole-archive-format)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_WHOLE_ARCHIVE_FORMAT="$1"
            case "${OPTION_OUTPUT_FORMAT}" in
               whole-archive|force-load|none|whole-archive-win)
               ;;

               *)
                  platform_translate_usage "Unknown whole-archive format value \"${OPTION_WHOLE_ARCHIVE_FORMAT}\""
               ;;
            esac
         ;;

         --output-format)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_OUTPUT_FORMAT="$1"
            case "${OPTION_OUTPUT_FORMAT}" in
               ld|file)
               ;;

               *)
                  platform_translate_usage "Unknown output format value \"${OPTION_OUTPUT_FORMAT}\""
               ;;
            esac
         ;;

         -*)
            platform_translate_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   local name

   [ $# -ne 0 ] || platform_translate_usage "Missing name"

   r_platform_translate "${OPTION_OUTPUT_FORMAT}" \
                        "${OPTION_PREFIX}" \
                        "${OPTION_SEPERATOR}" \
                        "${OPTION_WHOLE_ARCHIVE_FORMAT}" \
                        "$@"

   [ -z "${RVAL}" ] && echo "${RVAL}"
}

