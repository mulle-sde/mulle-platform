# shellcheck shell=bash
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

MULLE_PLATFORM_TRANSLATE_SH='included'


platform::translate::usage()
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


platform::translate::r_simplify_wholearchive()
{
   log_entry "platform::translate::r_simplify_wholearchive" "$@"

   local lines="$1"
   local wholearchiveformat="$2"

   # do some common substitutions regardless of format
   # we substitute over lineendings here!
   RVAL="${RVAL//-Wl,--as-needed -Wl,--no-whole-archive
-Wl,--export-dynamic -Wl,--whole-archive -Wl,--no-as-needed/
-Wl,--export-dynamic}"
   RVAL="${lines//-Wl,--as-needed -Wl,--no-whole-archive
-Wl,--whole-archive -Wl,--no-as-needed/}"
   RVAL="${RVAL//-Wl,--no-whole-archive -Wl,--as-needed
-Wl,--no-as-needed -Wl,--whole-archive/}"
   RVAL="${RVAL//-Wl,--no-whole-archive
-Wl,--whole-archive/}"
   RVAL="${RVAL//-Wl,--as-needed -Wl,--no-as-needed/}"
}


platform::translate::_r_translate_file()
{
   log_entry "platform::translate::_r_translate_file" "$@"

   local csv="$1"
   local quote="$2"

   RVAL="${quote}${csv%%;*}${quote}"

   log_setting "csv   : ${csv}"
   log_setting "RVAL  : ${RVAL}"
}


platform::translate::is_dynamic_library()
{
   log_entry "platform::translate::is_dynamic_library" "$@"

   local name="$1"
   local dynamiclibsuffix="$2"
   local marks="$3"
   local preferredlibformat="$4"

   # quick check
   case "${name}" in
      *${dynamiclibsuffix})
         log_debug "is dynamic because of suffix ${dynamiclibsuffix}"
         return 0
      ;;
   esac

   case ",${marks}," in
      *,only-dynamic-link,*)
         log_debug "is dynamic because only-dynamic-link is set"
         return 0
      ;;

      *,no-dynamic-link,*)
         log_debug "is static because no-dynamic-link is set"
         return 1
      ;;

      *,only-static-link,*)
         log_debug "is static because because only-dynamic-link is set"
         return 1
      ;;
   esac

   case "${MULLE_UNAME}" in
      'windows'|'mingw'|'msys')
      ;;

      *)
         log_debug "is static because we are not on windows"
         return 1
      ;;
   esac

   #
   # there is no reason for this to be implib, if this has no marks
   # and the preference is static
   #
   case "${preferredlibformat}" in
      static)
         log_debug "is static because thats the preference"
         return 1
      ;;
   esac

   #
   # may not look like a dll, but secretly is
   #
   log_debug "is dynamic because its the preference"
   return 0
}



platform::translate::_r_translate_ld_static()
{
   log_entry "platform::translate::_r_translate_ld_static" "$@"

   local option="$1" # _option_linklib (-l)
   local prefix="$2"             # _prefix_lib     (lib)
   local ldname="$3"   # _suffix_dynamiclib (.so)
   local name="$4"   # _suffix_dynamiclib (.so)
   local wholearchiveformat="$5"
   local quote="$6"

   local result

   # this can be useful if the resultant product is a shared library
   # for example. Needed to get dlsym working. Also needed for
   # executables (but currently we don't use it for them)
   case ",${wholearchiveformat}," in
      *',export-dynamic,'*)
         case "${MULLE_UNAME}" in
            linux) # ELF linkers really
               r_concat "${result}" "-Wl,--export-dynamic"
               result="${RVAL}"
            ;;
         esac
      ;;
   esac

   case ",${marks}," in
      *,no-all-load,*)
         r_concat "${result}" "${option}${ldname#${prefix}}"
         return
      ;;
   esac

   # all-load (Objective-C) code follows,
   case ",${wholearchiveformat}," in
      *',whole-archive,'*)
         r_concat "${result}" "-Wl,--whole-archive"
         result="${RVAL}"
      ;;
   esac

   case ",${wholearchiveformat}," in
      *',no-as-needed,'*)
         r_concat "${result}" "-Wl,--no-as-needed"
         result="${RVAL}"
      ;;
   esac

   case ",${wholearchiveformat}," in
      *',whole-archive-win,'*)
         result="-WHOLEARCHIVE:${ldname#${prefix}}" # clobber
      ;;

      *',force-load,'*)
         is_absolutepath "${name}" || fail "\"${name}\" must be absolute for -force_load"
         result="-force_load ${quote}${name}${quote}" # clobber
      ;;

      *)
         r_concat "${result}" "${option}${ldname#${prefix}}"
         result="${RVAL}"
      ;;
   esac

   case ",${wholearchiveformat}," in
      *',no-as-needed,'*)
         r_concat "${result}" "-Wl,--as-needed"
         result="${RVAL}"
      ;;
   esac

   case ",${wholearchiveformat}," in
      *',whole-archive,'*)
         r_concat "${result}" "-Wl,--no-whole-archive"
         result="${RVAL}"
      ;;
   esac

   RVAL="${result}"
}


platform::translate::_r_translate_ld_dynamic()
{
   log_entry "platform::translate::_r_translate_ld_dynamic" "$@"

   local option="$1"    # _option_linklib (-l)
   local prefix="$2"    # _prefix_lib     (lib)
   local ldname="$3"    # _suffix_dynamiclib (.so)
   local wholearchiveformat="$4"
   local quote="$5"

   local result

      # the default exit for C libraries
   case ",${marks}," in
      *,no-all-load,*)
         RVAL="${option}${ldname#${prefix}}"
         return
      ;;
   esac

   # all-load (Objective-C) code follows,
   case ",${wholearchiveformat}," in
      *',no-as-needed,'*)
         r_concat "${result}" "-Wl,--no-as-needed"
         result="${RVAL}"
      ;;
   esac

   r_concat "${result}" "${option}${ldname#${prefix}}"
   result="${RVAL}"

   case ",${wholearchiveformat}," in
      *',no-as-needed,'*)
         r_concat "${result}" "-Wl,--as-needed"
         result="${RVAL}"
      ;;
   esac

   RVAL="${result}"
}


platform::translate::_r_translate_ld()
{
   log_entry "platform::translate::_r_translate_ld" "$@"

   local csv="$1"
   local option="$2" # _option_linklib (-l)
   local prefix="$3" # _prefix_lib     (lib)
   local mode="$4"
   local staticlibsuffix="$5"    # _suffix_staticlib (.a)
   local dynamiclibsuffix="$6"   # _suffix_dynamiclib (.so)
   local preferredlibformat="$7"
   local wholearchiveformat="$8"
   local quote="$9"

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
      marks="${marks%%;*}" # superfluous
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
         RVAL="-framework ${quote}${ldname}${quote}"
      ;;

      *)
         if platform::translate::is_dynamic_library "${name}" \
                                                    "${dynamiclibsuffix}" \
                                                    "${marks}" \
                                                    "${preferredlibformat}"
         then
            platform::translate::_r_translate_ld_dynamic "${option}" \
                                                         "${prefix}" \
                                                         "${ldname}" \
                                                         "${wholearchiveformat}" \
                                                         "${quote}"

         else
            platform::translate::_r_translate_ld_static "${option}" \
                                                        "${prefix}" \
                                                        "${ldname}" \
                                                        "${name}" \
                                                        "${wholearchiveformat}" \
                                                        "${quote}"
         fi
      ;;
   esac

   log_setting "csv   : ${csv}"
   log_setting "name  : ${name}"
   log_setting "marks : ${marks}"
   log_setting "RVAL  : ${RVAL}"
}


platform::translate::_r_translate_ldpath()
{
   log_entry "platform::translate::_r_translate_ldpath" "$@"

   local csv="$1"
   local option_library="$2"      # _option_linklib (-l)
   local option_framework="$3"    # _suffix_staticlib (.a)
   local r_path_mangler="$4"
   local quote="$5"

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
      marks="${marks%%;*}" # superfluous
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
         RVAL="${option}${quote}${RVAL}${quote}"
      ;;

      *)
         log_debug "Relative path \"${name}\" ignored"
      ;;
   esac

   log_setting "csv   : ${csv}"
   log_setting "name  : ${name}"
   log_setting "marks : ${marks}"
   log_setting "RVAL  : ${RVAL}"
}


platform::translate::_r_translate_ld_library_path()
{
   log_entry "platform::translate::_r_translate_ld_library_path" "$@"

   local csv="$1"
   local dynamiclibsuffix="$2"   # _suffix_dynamiclib (.so)
   local r_path_mangler="$3"
   local quote="$4"

   local name

   RVAL=

   name="${csv%%;*}"
   if [ -z "${name}" ]
   then
      return
   fi

   # systems that don't have rpath use LD_LIBRARY_PATH
   case "${MULLE_UNAME}" in
      'darwin'|'mingw'|'msys')
         log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
      ;;

      *)
         case "${name}" in
            /*${dynamiclibsuffix})
               r_dirname "${name}"
               ${r_path_mangler} "${RVAL}"
               RVAL="${quote}${RVAL}${quote}"
            ;;

            *)
               _log_fluff "\"${name}\" without \"${dynamiclibsuffix}\" suffix \
ignored for LD_LIBRARY_PATH"
            ;;
         esac
      ;;
   esac

   log_setting "csv   : ${csv}"
   log_setting "name  : ${name}"
   log_setting "RVAL  : ${RVAL}"
}


platform::translate::_r_translate_path()
{
   log_entry "platform::translate::_r_translate_path" "$@"

   local csv="$1"
   local dynamiclibsuffix="$2"   # _suffix_dynamiclib (.so)
   local r_path_mangler="$3"
   local quote="$4"

   local name

   RVAL=

   name="${csv%%;*}"
   if [ -z "${name}" ]
   then
      return
   fi

   # PATH only set on mingw to find DLLs
   case "${MULLE_UNAME}" in
      'mingw')
         case "${name}" in
            /*${dynamiclibsuffix})
               r_dirname "${name}"
               ${r_path_mangler} "${RVAL}"
               RVAL="${quote}${RVAL}${quote}"
            ;;

            *)
               _log_fluff "\"${name}\" without \"${dynamiclibsuffix}\" suffix \
ignored for PATH"
            ;;
         esac
      ;;

      *)
         log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored"
      ;;
   esac

   log_setting "csv   : ${csv}"
   log_setting "name  : ${name}"
   log_setting "marks : ${marks}"
   log_setting "RVAL  : ${RVAL}"
}


platform::translate::_r_translate_rpath()
{
   log_entry "platform::translate::_r_translate_rpath" "$@"

   local csv="$1"
   local dynamiclibsuffix="$2"   # _suffix_dynamiclib (.so)
   local option_rpath="$3"
   local option_rpath_value_prefix="$4"
   local r_path_mangler="$5"
   local quote="$6"

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
               RVAL="${option_rpath}${option_rpath_value_prefix}${quote}${RVAL}${quote}"
            ;;

            *)
               log_debug "\"${name}\" without \"${dynamiclibsuffix}\" suffix ignored for RPATH"
            ;;
         esac
      ;;

      *)
         log_fluff "\"${name}\" on \"${MULLE_UNAME}\" ignored for RPATH"
      ;;
   esac

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_setting "csv   : ${csv}"
      log_setting "name  : ${name}"
      log_setting "marks : ${marks}"
      log_setting "RVAL  : ${RVAL}"
   fi
}


platform::translate::_r_translate_lines()
{
   log_entry "platform::translate::_r_translate_lines" "$@"

   local format="$1"
   local option="$2"
   local prefix="$3"
   local mode="$4"
   local preferredlibformat="$5"
   local wholearchiveformat="$6"
   local separator="$7"
   local quote="$8"

   shift 8

   include "platform::environment"

   local _suffix_dynamiclib
   local _prefix_framework
   local _suffix_framework
   local _option_libpath
   local _option_frameworkpath
   local _option_rpath
   local _option_rpath_value_prefix
   local _prefix_lib
   local _option_linklib
   local _suffix_staticlib
   local _suffix_object
   local _suffix_executable
   local _option_link_mode
   local _r_path_mangler

   platform::environment::__get_fix_definitions

   local name
   local lines
   local csv

   [ "${option}" = "DEFAULT" ] && option="${_option_linklib}"
   [ "${prefix}" = "DEFAULT" ] && prefix="${_prefix_lib}"
   [ "${mode}"   = "DEFAULT" ] && mode="${_option_link_mode}"

   platform::environment::r_whole_archive_format "${wholearchiveformat}"
   wholearchiveformat="${RVAL}"

   local line

   lines=""
   for csv in "$@"
   do
      case "${format}" in 
         file)
            platform::translate::_r_translate_file \
                                  "${csv}" \
                                  "${quote}"
         ;;

         ld)
            platform::translate::_r_translate_ld \
                                  "${csv}" \
                                  "${option}" \
                                  "${prefix}" \
                                  "${mode}" \
                                  "${_suffix_staticlib}" \
                                  "${_suffix_dynamiclib}" \
                                  "${preferredlibformat}" \
                                  "${wholearchiveformat}" \
                                  "${quote}"
         ;;

         ldpath)
            platform::translate::_r_translate_ldpath  \
                                  "${csv}" \
                                  "${_option_libpath}" \
                                  "${_option_frameworkpath}" \
                                  "${_r_path_mangler}" \
                                  "${quote}"
         ;;

         ld_library_path)
            platform::translate::_r_translate_ld_library_path \
                                  "${csv}" \
                                  "${_suffix_dynamiclib}" \
                                  "${_r_path_mangler}" \
                                  "${quote}"
         ;;
         path)
            platform::translate::_r_translate_path  \
                                  "${csv}" \
                                  "${_suffix_dynamiclib}" \
                                  "${_r_path_mangler}" \
                                  "${quote}"
         ;;
         rpath)
            platform::translate::_r_translate_rpath \
                                  "${csv}" \
                                  "${_suffix_dynamiclib}" \
                                  "${_option_rpath}" \
                                  "${_option_rpath_value_prefix}" \
                                  "${_r_path_mangler}" \
                                  "${quote}"
         ;;

         *)
            _internal_fail "unknown format \"${format}\""
         ;;
      esac
      line="${RVAL}"

      log_debug "add: $format :: $csv -> $line"
      if [ ! -z "${line}" ]
      then
         r_add_unique_line "${lines}" "${line}"
         lines="${RVAL}"
      fi
   done

   if [ "${separator}" = $'\n' ]
   then
      RVAL="${lines}"
      return 0
   fi

   RVAL=""

   .foreachline line in ${lines}
   .do
      r_concat "${RVAL}" "${line}" "${separator}"
   .done
}


platform::translate::r_translate_lines()
{
   local format="$1" 
   local preferredlibformat="$2"
   local wholearchiveformat="$3"

   shift 3

   platform::translate::_r_translate_lines "${format}" \
                                           "DEFAULT" \
                                           "DEFAULT" \
                                           "DEFAULT" \
                                           "${preferredlibformat}" \
                                           "${wholearchiveformat}" \
                                           "$@"
}


platform::translate::main()
{
   log_entry "platform::translate::main" "$@"

   [ -z "${DEFAULT_IFS}" ] && _internal_fail "IFS fail"

   local OPTION_OUTPUT_FORMAT="ld"
   local OPTION_PREFIX="DEFAULT"
   local OPTION_OPTION="DEFAULT"
   local OPTION_MODE="DEFAULT"
   local OPTION_MARKS
   local OPTION_WHOLE_ARCHIVE_FORMAT="DEFAULT"
   local OPTION_PREFERRED_LIBRARY_STYLE='static'
   local OPTION_SEPARATOR=$'\n'
   local OPTION_QUOTE

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::translate::usage
         ;;

         --dynamic)
            OPTION_PREFERRED_LIBRARY_STYLE='dynamic'
         ;;

         --static)
            OPTION_PREFERRED_LIBRARY_STYLE='static'
         ;;

         --standalone)
            OPTION_PREFERRED_LIBRARY_STYLE='standalone'
         ;;


         --fake-uname)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift

            MULLE_UNAME="$1"
         ;;

         --marks)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_MARKS="$1"
         ;;

         --mode)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_MODE="$1"
         ;;

         --option)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_OPTION="$1"
         ;;

         --prefix)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_PREFIX="$1"
         ;;

         --preferred-library-style)
           [ $# -eq 1 ] && sde_linkorder_usage "Missing argument to \"$1\""
            shift

            OPTION_PREFERRED_LIBRARY_STYLE="$1"
         ;;

         --quote)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_QUOTE="$1"
         ;;

         --separator|--separator)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_SEPARATOR="$1"
         ;;

         --output-format)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift
            OPTION_OUTPUT_FORMAT="$1"
            case "${OPTION_OUTPUT_FORMAT}" in
               ld|file|ldpath|ld_library_path|path|rpath)
               ;;

               *)
                  platform::translate::usage "Unknown output format value \"${OPTION_OUTPUT_FORMAT}\""
               ;;
            esac
         ;;

         --whole-archive-format)
            [ $# -eq 1 ] && platform::translate::usage "Missing argument to \"$1\""
            shift

            OPTION_WHOLE_ARCHIVE_FORMAT="$1"
            case "${OPTION_OUTPUT_FORMAT}" in
               whole-archive|force-load|none|whole-archive-win|as-needed|DEFAULT)
               ;;

               *)
                  platform::translate::usage "Unknown whole-archive format value \"${OPTION_WHOLE_ARCHIVE_FORMAT}\""
               ;;
            esac
         ;;

         -*)
            platform::translate::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done


   local name

   [ $# -ne 0 ] || platform::translate::usage "Missing name"

   if [ ! -z "${OPTION_MARKS}" ]
   then
      OPTION_MARKS=";${OPTION_MARKS}"
   fi

   local firstline

   firstline="$1"; shift

   platform::translate::_r_translate_lines "${OPTION_OUTPUT_FORMAT}" \
                                           "${OPTION_OPTION}" \
                                           "${OPTION_PREFIX}" \
                                           "${OPTION_MODE}" \
                                           "${OPTION_PREFERRED_LIBRARY_STYLE}" \
                                           "${OPTION_WHOLE_ARCHIVE_FORMAT}" \
                                           "${OPTION_SEPARATOR}" \
                                           "${OPTION_QUOTE}" \
                                           "${firstline}${OPTION_MARKS}" \
                                           "$@"

   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}

