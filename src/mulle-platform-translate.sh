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

   Change the representation of a filenames suitable for passing them to the
   linker. The default prints each link command on a separate line for "ld"
   and "file".

   Some output-formats like "rpath" or "path" are invalid for some platforms
   and will produce no output.

Options:
   --prefix            : specify prefix for link command (-ld)
   --output-format <f> : one of file,ld,ldpath,ld_library_path,path,rpath (ld)
   --separator <sep>   : specify separator for "ld" and "file"

EOF
   exit 1
}


r_platform_simplify_wholearchive()
{
   log_entry "r_platform_simplify_wholearchive" "$@"

   local lines="$1"
   local wholearchiveformat="$2"

   # do some common substitutions regardless of format
   RVAL="${lines//-Wl,--as-needed -Wl,--no-whole-archive
-Wl,--whole-archive -Wl,--no-as-needed/}"
   RVAL="${RVAL//-Wl,--no-whole-archive -Wl,--as-needed
-Wl,--no-as-needed -Wl,--whole-archive/}"
   RVAL="${RVAL//-Wl,--no-whole-archive
-Wl,--whole-archive/}"
   RVAL="${RVAL//-Wl,--as-needed -Wl,--no-as-needed/}"
}


_r_platform_translate()
{
   log_entry "_r_platform_translate" "$@"

   local format="$1"
   local prefix="$2"
   local wholearchiveformat="$3"
   local csv="$4"

   local name
   local lines
   local marks

   RVAL=
   name="${csv%%;*}"
   if [ -z "${name}" ]
   then
      return
   fi

   marks=""
   if [ "${name}" != "${csv}" ]
   then
      marks="${csv#*;}"
   fi

   case "${format}" in
      file)
         RVAL="${name}"
      ;;

      #
      # emit -l statements, or -framework for only-framework marks (hacque)
      # these marks are added by the linkorder command they are not really
      # part of the sourcetree, unless it's a system framework. System 
      # frameworks are not dependencies but libraries. They aren't searched
      # for here, so only-framework will make the linkorder emit a -framework
      #
      ld)
         local ldname

         r_extensionless_basename "${name}"
         ldname="${RVAL}"

         case ",${marks}," in
            *,no-all-load,*)
               RVAL="${prefix}${ldname#${_libprefix}}"
            ;;

            *,only-framework,*)
               RVAL="-framework ${ldname}"
            ;;

            *)
               RVAL=""
               case ",${wholearchiveformat}," in
                  *',whole-archive,'*)
                     r_concat "${RVAL}" "-Wl,--whole-archive"
                  ;;
               esac

               case ",${wholearchiveformat}," in
                  *',no-as-needed,'*)
                     r_concat "${RVAL}" "-Wl,--no-as-needed"
                  ;;
               esac

               case ",${wholearchiveformat}," in
                  *',export-dynamic,'*)
                     r_concat "${RVAL}" "-Wl,--export-dynamic"
                  ;;
               esac

               case ",${wholearchiveformat}," in
                  *',whole-archive-win,'*)
                     RVAL="-WHOLEARCHIVE:${ldname#${_libprefix}}"
                  ;;

                  *',force-load,'*)
                     is_absolutepath "${name}" || fail "\"${name}\" must be absolute for -force_load"
                     RVAL="-force_load ${name}"
                  ;;

                  *)
                     r_concat "${RVAL}" "${prefix}${ldname#${_libprefix}}"
                  ;;
               esac

               case ",${wholearchiveformat}," in
                  *',no-as-needed,'*)
                     r_concat "${RVAL}" "-Wl,--as-needed"
                  ;;
               esac

               case ",${wholearchiveformat}," in
                  *',whole-archive,'*)
                     r_concat "${RVAL}" "-Wl,--no-whole-archive"
                  ;;
               esac
            ;;
         esac
      ;;

      # emit -L statements (and -F statements (hacque))
      ldpath)
         case ",${marks}," in 
            *,only-framework,*)
               prefix="-F"
            ;;
         esac

         case "${name}" in
            /*)
               r_dirname "${name}"
               RVAL="${prefix}${RVAL}"
            ;;

            *)
               log_fluff "Relative path \"${name}\" ignored"
            ;;
         esac
      ;;

      # systems that don't have rpath use LD_LIBRARY_PATH
      ld_library_path)
         case "${MULLE_UNAME}" in
            darwin|mingw)
               log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
            ;;

            *)
               case "${name}" in
                  /*${_dynamiclibsuffix})
                     r_dirname "${name}"
                     r_add_unique_line "${lines}" "${RVAL}"
                  ;;

                  *)
                     log_fluff "\"${name}\" without \"${_dynamiclibsuffix}\" suffix ignored"
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
                     r_dirname "${name}"
                     r_add_unique_line "${lines}" "${RVAL}"
                  ;;

                  *)
                     log_fluff "\"${name}\" without \"${_dynamiclibsuffix}\" suffix ignored"
                  ;;
               esac
            ;;

            *)
               log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
            ;;
         esac
      ;;

      # DO we need to do something here for frameworks ?
      rpath)
         case "${MULLE_UNAME}" in
            darwin|linux)
               case "${name}" in
                  /*${_dynamiclibsuffix})
                     r_dirname "${name}"
                     r_add_unique_line "${lines}" "${prefix}${RVAL}"
                  ;;

                  *)
                     log_fluff "\"${name}\" without \"${_dynamiclibsuffix}\" suffix ignored"
                  ;;
               esac
            ;;

            *)
               log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
            ;;
         esac
      ;;

      *)
         internal_fail "unknown format \"${format}\""
      ;;
   esac

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "csv   : ${csv}"
      log_trace2 "name  : ${name}"
      log_trace2 "marks : ${marks}"
      log_trace2 "RVAL  : ${RVAL}"
   fi
}


r_platform_translate_lines()
{
   log_entry "r_platform_translate_lines" "$@"

   local format="$1"; shift
   local prefix="$1"; shift
   local separator="$1"; shift
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

   lines=""
   for csv in "$@"
   do
      _r_platform_translate "${format}" \
                            "${prefix}" \
                            "${wholearchiveformat}" \
                            "${csv}"
      r_add_unique_line "${lines}" "${RVAL}"
      lines="${RVAL}"
   done

   local line

   RVAL=""
   set -o noglob; IFS=$'\n'
   for line in ${lines}
   do
      set +o noglob; IFS="${DEFAULT_IFS}"
      r_concat "${RVAL}" "${line}" "${separator}"
   done
   set +o noglob; IFS="${DEFAULT_IFS}"
}


r_platform_default_whole_archive_format()
{
   case "${MULLE_UNAME}" in
      mingw*)
         RVAL="whole-archive-win"
      ;;

      darwin)
         RVAL="force-load"
      ;;

      *)
         RVAL="whole-archive,no-as-needed,export-dynamic"
      ;;
   esac
}


platform_default_wholearchive_format()
{
   r_platform_default_whole_archive_format
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}


platform_translate_main()
{
   log_entry "platform_translate_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_OUTPUT_FORMAT="ld"
   local OPTION_PREFIX="-l"
   local OPTION_WHOLE_ARCHIVE_FORMAT
   local OPTION_SEPARATOR=$'\n'

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

         --separator|--separator)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_SEPARATOR="$1"
         ;;

         --whole-archive-format)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift

            OPTION_WHOLE_ARCHIVE_FORMAT="$1"
            case "${OPTION_OUTPUT_FORMAT}" in
               whole-archive|force-load|none|whole-archive-win|as-needed)
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
               ld|file|ldpath|ld_library_path|path|rpath)
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

   r_platform_translate_lines "${OPTION_OUTPUT_FORMAT}" \
                              "${OPTION_PREFIX}" \
                              "${OPTION_SEPARATOR}" \
                              "${OPTION_WHOLE_ARCHIVE_FORMAT}" \
                              "$@"

   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}

