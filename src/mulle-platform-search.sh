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

MULLE_PLATFORM_SEARCH_SH='included'


platform::search::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-search} [options] <name>

   Search for files (usually libraries) given a name in the platforms
   searchpath.

   Generally it's preferable to use cmake's \`find_library\` for this, which
   is more flexable.

Options:
   --prefer <libtype>  : can be "static" or "dynamic" (static)
   --require <libtype> : can be "static" or "dynamic" (none)
   --searchpath <path> : a colon separated path to search
   --type <filetype>   : can be "library" or "standalone" (library)
   --output-format <f> : format can be "file" or "ld"
EOF
   exit 1
}


# some values are passed in via global vars!
platform::search::r_search_static_library()
{
   log_entry "platform::search::r_search_static_library" "$@"

   local directory="$1"
   local name="$2"

   r_filepath_concat "${directory}" "${_prefix_lib}${name}${_suffix_staticlib}"

   log_fluff "Looking for static library \"${RVAL}\""

   [ -f "${RVAL}" ]
}


# some values are passed in via global vars!
platform::search::r_search_dynamic_library()
{
   log_entry "platform::search::r_search_dynamic_library" "$@"

   local directory="$1"
   local name="$2"

   r_filepath_concat "${directory}" "${_prefix_lib}${name}${_suffix_dynamiclib}"

   log_fluff "Looking for dynamic library \"${RVAL}\""

   [ -f "${RVAL}" ]
}


# some values are passed in via global vars!
platform::search::r_search_library_type()
{
   log_entry "platform::search::r_search_library_type" "$@"

   local type="$1"
   local directory="$2"
   local name="$3"
   local prefix="$4"
   local suffix="$5"

   if "platform::search::r_search_${type}_library" "${directory}" \
                                                   "${name}" \
                                                   "${prefix}" \
                                                   "${suffix}"
   then
      log_fluff "Found"
      return 0
   fi
   return 1
}


# some values are passed in via global vars!
platform::search::r_search_library()
{
   log_entry "platform::search::r_search_library" "$@"

   [ $# -gt 4 ] || _internal_fail "API mismatch"

   local directory="$1"
   local require="$2"
   local prefer="$3"
   local require="$4"

   shift 4

   local name
   local first_type
   local second_type

   while [ $# -ne 0 ]
   do
      name="$1"
      [ -z "${name}" ] && _internal_fail "empty name is not allowed"

      if [  "${type}" = 'standalone' ]
      then
         if platform::search::r_search_library_type "dynamic" \
                                                     "${directory}" \
                                                     "${name}-standalone"
         then
            return 0
         fi

         #
         # if we build everything as shared libraries then we don't
         # need a -standalone library
         #
         if platform::search::r_search_library_type "dynamic" \
                                                     "${directory}" \
                                                     "${name}"
         then
            return 0
         fi

         shift
         continue
      fi

      if [ ! -z "${require}" ]
      then
         if platform::search::r_search_library_type "${require}" \
                                                     "${directory}" \
                                                     "${name}"
         then
            return 0
         fi

         shift
         continue
      fi

      first_type=static
      second_type=dynamic

      case "${prefer}" in
         dynamic)
            first_type=dynamic
            second_type=static
         ;;
      esac

      if platform::search::r_search_library_type "${first_type}" \
                                                  "${directory}" \
                                                  "${name}"
      then
         return 0
      fi

      if platform::search::r_search_library_type "${second_type}" \
                                                  "${directory}" \
                                                  "${name}"
      then
         return 0
      fi

      shift
   done

   return 1
}


# some values are passed in via global vars!
#
platform::search::_r_search_framework()
{
   log_entry "platform::search::_r_search_framework" "$@"

   [ $# -gt 1 ] || _internal_fail "API mismatch"

   local directory="$1"
   shift 1

   local name

   while [ $# -ne 0 ]
   do
      name="$1"
      [ -z "${name}" ] && _internal_fail "empty name is not allowed"

      r_filepath_concat "${directory}" "${_prefix_framework}${name}${_suffix_framework}"

      log_fluff "Looking for framework \"${RVAL}\""
      if [ -d "${RVAL}" ]
      then
         # log_fluff "Found" # someone else will print this soon
         return 0
      fi
      shift
   done

   return 1
}


platform::search::r_platform_search()
{
   log_entry "platform::search::r_platform_search" "$@"

   local searchpath="$1"
   local type="$2"
   local prefer="$3"
   local require="$4"
   shift 4

   include "platform::environment"

   if [ -z "${searchpath}" ]
   then
      include "platform::searchpath"

      platform::search::r_platform_searchpath
      searchpath="${RVAL}"
   fi

   local _option_frameworkpath
   local _option_libpath
   local _option_link_mode
   local _option_linklib
   local _option_rpath
   local _prefix_framework
   local _prefix_lib
   local _suffix_dynamiclib
   local _suffix_framework
   local _suffix_staticlib
   local _suffix_object
   local _suffix_executable
   local _r_path_mangler

   platform::environment::__get_fix_definitions

   local directory

   shell_disable_glob; IFS=':'
   for directory in ${searchpath}
   do
      shell_enable_glob; IFS="${DEFAULT_IFS}"

      if [ -z "${directory}" ]
      then
         continue
      fi

      if [ "${type}" = "framework" ]
      then
         if platform::search::_r_search_framework "${directory}" \
                                                  "$@"
         then
            return 0
         fi
      else
         if platform::search::r_search_library "${directory}" \
                                                "${type}" \
                                                "${prefer}" \
                                                "${require}" \
                                                "$@"
         then
            return 0
         fi
      fi
   done
   shell_enable_glob; IFS="${DEFAULT_IFS}"

   RVAL=""
   return 1
}


platform::search::main()
{
   log_entry "platform::search::main" "$@"

   [ -z "${DEFAULT_IFS}" ] && _internal_fail "IFS fail"

   local OPTION_SEARCH_PATH
   local OPTION_PREFER="static"
   local OPTION_REQUIRE=
   local OPTION_TYPE="library"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::search::usage
         ;;

         --prefer)
            [ $# -eq 1 ] && platform::search::usage "Missing argument to \"$1\""
            shift
            OPTION_PREFER="$1"

            case "${OPTION_PREFER}" in
               dynamic|static)
               ;;

               *)
                  platform::search::usage "Unknown prefer value \"${OPTION_PREFER}\""
               ;;
            esac
         ;;

         --require)
            [ $# -eq 1 ] && platform::search::usage "Missing argument to \"$1\""
            shift
            OPTION_REQUIRE="$1"

            case "${OPTION_REQUIRE}" in
               dynamic|static)
               ;;

               *)
                  platform::search::usage "Unknown require value \"${OPTION_REQUIRE}\""
               ;;
            esac
         ;;

         --search-path)
            [ $# -eq 1 ] && platform::search::usage "Missing argument to \"$1\""
            shift
            OPTION_SEARCH_PATH="$1"
         ;;

         --type)
            [ $# -eq 1 ] && platform::search::usage "Missing argument to \"$1\""
            shift

            OPTION_TYPE="$1"
            case "${OPTION_TYPE}" in
               library|standalone|framework)
               ;;

               *)
                  platform::search::usage "Unknown type value \"${OPTION_TYPE}\""
               ;;
            esac
         ;;

         -*)
            platform::search::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   local name
   local directory

   [ $# -ne 0 ] || platform::search::usage "Missing name"

   if platform::search::r_platform_search "${OPTION_SEARCH_PATH}" \
                                          "${OPTION_TYPE}" \
                                          "${OPTION_PREFER}" \
                                          "${OPTION_REQUIRE}" \
                                          "$@"
   then
      rexekutor printf "%s\n" "${RVAL}"
      return 0
   fi

   log_warning "No library found for \"$*\""
   return 1
}



