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
   --option            : specify commandline option for link command (-ld)
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


_r_platform_translate_file()
{
   log_entry "_r_platform_translate_file" "$@"

   local csv="$1"

   RVAL="${csv%%;*}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "csv   : ${csv}"
      log_trace2 "RVAL  : ${RVAL}"
   fi
}


_r_platform_translate_ld()
{
   log_entry "_r_platform_translate_ld" "$@"

   local option="$1" # _option_linklib (-l)
   local prefix="$2" # _prefix_lib     (lib)
   local mode="$3"
   local staticlibsuffix="$4"    # _suffix_staticlib (.a)
   local dynamiclibsuffix="$5"   # _suffix_dynamiclib (.so)
   local wholearchiveformat="$6"
   local csv="$7"

   local name
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
      marks="${marks%%;*}" # superflous
   fi

   #
   # emit -l statements, or -framework for only-framework marks (hacque)
   # these marks are added by the linkorder command they are not really
   # part of the sourcetree, unless it's a system framework. System 
   # frameworks are not dependencies but libraries. They aren't searched
   # for here, so only-framework will make the linkorder emit a -framework
   #
   local ldname

   ldname="${name}"

   case ",${mode}," in 
      *,basename,*)
         r_basename "${name}"
         ldname="${RVAL}"
      ;;
   esac

   case ",${mode}," in 
      *,no-suffix,*)
         r_extensionless_filename "${ldname}"
         ldname="${RVAL}"
      ;;
   esac

   case ",${mode}," in 
      *,add-suffix-staticlib,*)
         ldname="${ldname}${staticlibsuffix}"
      ;;
   esac

   case ",${marks}," in
      *,only-framework,*)
         RVAL="-framework ${ldname}"
      ;;

      *,no-all-load,*)
         RVAL="${option}${ldname#${prefix}}"
      ;;

      *)
         RVAL=""
         case "${name}" in 
            *${dynamiclibsuffix})
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

               ## default !!
               r_concat "${RVAL}" "${option}${ldname#${prefix}}"

               case ",${wholearchiveformat}," in
                  *',no-as-needed,'*)
                     r_concat "${RVAL}" "-Wl,--as-needed"
                  ;;
               esac
            ;;

            *)
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
                     RVAL="-WHOLEARCHIVE:${ldname#${prefix}}"
                  ;;

                  *',force-load,'*)
                     is_absolutepath "${name}" || fail "\"${name}\" must be absolute for -force_load"
                     RVAL="-force_load ${name}"
                  ;;

                  *)
                     ## default !!
                     r_concat "${RVAL}" "${option}${ldname#${prefix}}"
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
   esac

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "csv   : ${csv}"
      log_trace2 "name  : ${name}"
      log_trace2 "marks : ${marks}"
      log_trace2 "RVAL  : ${RVAL}"
   fi
}


_r_platform_translate_ldpath()
{
   log_entry "_r_platform_translate_ldpath" "$@"

   local option_library="$1"      # _option_linklib (-l)
   local option_framework="$2"    # _suffix_staticlib (.a)
   local r_path_mangler="$3"
   local csv="$4"

   local name
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
      marks="${marks%%;*}" # superflous
   fi

   # emit -L statements (and -F statements (hacque))
   local option 

   option="${option_library}"
   case ",${marks}," in 
      *,only-framework,*)
         option="${option_framework}"
      ;;
   esac

   case "${name}" in
      /*)
         r_dirname "${name}"
         ${r_path_mangler} "${RVAL}"
         RVAL="${option}${RVAL}"
      ;;

      *)
         log_fluff "Relative path \"${name}\" ignored"
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


_r_platform_translate_ld_library_path()
{
   log_entry "_r_platform_translate_ld_library_path" "$@"

   local dynamiclibsuffix="$1"   # _suffix_dynamiclib (.so)
   local r_path_mangler="$2"
   local csv="$3"

   local name

   RVAL=

   name="${csv%%;*}"
   if [ -z "${name}" ]
   then
      return
   fi


   # systems that don't have rpath use LD_LIBRARY_PATH
   case "${MULLE_UNAME}" in
      darwin|mingw)
         log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
      ;;

      *)
         case "${name}" in
            /*${dynamiclibsuffix})
               r_dirname "${name}"
               ${r_path_mangler} "${RVAL}"
            ;;

            *)
               log_fluff "\"${name}\" without \"${dynamiclibsuffix}\" suffix ignored"
            ;;
         esac
      ;;
   esac

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "csv   : ${csv}"
      log_trace2 "name  : ${name}"
      log_trace2 "RVAL  : ${RVAL}"
   fi
}


_r_platform_translate_path()
{
   log_entry "_r_platform_translate_path" "$@"

   local dynamiclibsuffix="$1"   # _suffix_dynamiclib (.so)
   local r_path_mangler="$2"
   local csv="$3"

   local name

   RVAL=

   name="${csv%%;*}"
   if [ -z "${name}" ]
   then
      return
   fi

   # PATH only set on mingw to find DLLs
   case "${MULLE_UNAME}" in
      mingw*)
         case "${name}" in
            /*${dynamiclibsuffix})
               r_dirname "${name}"
               ${r_path_mangler} "${RVAL}"
            ;;

            *)
               log_fluff "\"${name}\" without \"${dynamiclibsuffix}\" suffix ignored"
            ;;
         esac
      ;;

      *)
         log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
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


_r_platform_translate_rpath()
{
   log_entry "_r_platform_translate_rpath" "$@"

   local dynamiclibsuffix="$1"   # _suffix_dynamiclib (.so)
   local option_rpath="$2"
   local r_path_mangler="$3"
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

   # DO we need to do something here for frameworks ?
   case "${MULLE_UNAME}" in
      darwin|linux)
         case "${name}" in
            /*${dynamiclibsuffix})
               r_dirname "${name}"
               ${r_path_mangler} "${RVAL}"
               RVAL="${option_rpath}${RVAL}"
            ;;

            *)
               log_fluff "\"${name}\" without \"${dynamiclibsuffix}\" suffix ignored"
            ;;
         esac
      ;;

      *)
         log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
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


_r_platform_translate_lines()
{
   log_entry "_r_platform_translate_lines" "$@"

   local format="$1"
   local option="$2"
   local prefix="$3"
   local mode="$4"
   local wholearchiveformat="$5"
   local separator="$6"

   shift 6


   [ -z "${MULLE_PLATFORM_ENVIRONMENT_SH}" ] && \
      . "${MULLE_PLATFORM_LIBEXEC_DIR}/mulle-platform-environment.sh"

   local _suffix_dynamiclib
   local _prefix_framework
   local _suffix_framework
   local _option_libpath
   local _option_frameworkpath
   local _option_rpath
   local _prefix_lib
   local _option_linklib
   local _suffix_staticlib
   local _option_link_mode
   local _r_path_mangler

   __platform_get_fix_definitions

   local name
   local lines
   local csv

   [ "${option}" = "DEFAULT" ] &&  option="${_option_linklib}" 
   [ "${prefix}" = "DEFAULT" ] &&  prefix="${_prefix_lib}" 
   [ "${mode}"   = "DEFAULT" ] &&  mode="${_option_link_mode}" 

   if [ "${wholearchiveformat}" = "DEFAULT" ]
   then
      r_platform_default_whole_archive_format
      wholearchiveformat="${RVAL}"
   fi

   local line

   lines=""
   for csv in "$@"
   do
      case "${format}" in 
         file)
            _r_platform_translate_file \
                                  "${csv}"
         ;;
         ld)
            _r_platform_translate_ld \
                                  "${option}" \
                                  "${prefix}" \
                                  "${mode}" \
                                  "${_suffix_staticlib}" \
                                  "${_suffix_dynamiclib}" \
                                  "${wholearchiveformat}" \
                                  "${csv}"
         ;;

         ldpath)
            _r_platform_translate_ldpath  \
                                  "${_option_libpath}" \
                                  "${_option_frameworkpath}" \
                                  "${_r_path_mangler}" \
                                  "${csv}"
         ;;

         ld_library_path)
            _r_platform_translate_ld_library_path \
                                  "${_suffix_dynamiclib}" \
                                  "${_r_path_mangler}" \
                                  "${csv}"
         ;;
         path)
            _r_platform_translate_path  \
                                  "${_suffix_dynamiclib}" \
                                  "${_r_path_mangler}" \
                                  "${csv}"
         ;;
         rpath)
            _r_platform_translate_rpath \
                                  "${_suffix_dynamiclib}" \
                                  "${_option_rpath}" \
                                  "${_r_path_mangler}" \
                                  "${csv}"
         ;;

         *)
            internal_fail "unknown format \"${format}\""
         ;;
      esac
      line="${RVAL}"

      log_debug "add: $format :: $csv -> $line"
      r_add_unique_line "${lines}" "${line}"
      lines="${RVAL}"
   done

   RVAL=""
   shell_disable_glob; IFS=$'\n'
   for line in ${lines}
   do
      shell_enable_glob; IFS="${DEFAULT_IFS}"
      r_concat "${RVAL}" "${line}" "${separator}"
   done
   shell_enable_glob; IFS="${DEFAULT_IFS}"
}


r_platform_translate_lines()
{
   local format="$1" 
   local wholearchiveformat="$2"

   shift 2

   _r_platform_translate_lines "${format}" \
                               "DEFAULT" \
                               "DEFAULT" \
                               "DEFAULT" \
                               "${wholearchiveformat}" \
                               "$@"
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
   local OPTION_PREFIX="DEFAULT"
   local OPTION_OPTION="DEFAULT"
   local OPTION_MODE="DEFAULT"
   local OPTION_WHOLE_ARCHIVE_FORMAT="none"
   local OPTION_SEPARATOR=$'\n'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform_translate_usage
         ;;

         --option)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_OPTION="$1"
         ;;

         --prefix)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_PREFIX="$1"
         ;;

         --mode)
            [ $# -eq 1 ] && platform_translate_usage "Missing argument to \"$1\""
            shift
            OPTION_MODE="$1"
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
               whole-archive|force-load|none|whole-archive-win|as-needed|DEFAULT)
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

   _r_platform_translate_lines "${OPTION_OUTPUT_FORMAT}" \
                               "${OPTION_OPTION}" \
                               "${OPTION_PREFIX}" \
                               "${OPTION_MODE}" \
                               "${OPTION_WHOLE_ARCHIVE_FORMAT}" \
                               "${OPTION_SEPARATOR}" \
                               "$@"

   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}

