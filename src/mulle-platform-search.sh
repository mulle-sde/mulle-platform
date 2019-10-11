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

MULLE_PLATFORM_SEARCH_SH="included"


platform_search_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-search} [options] <name>

   Search for files (usually libraries) given a name in the the searchpath.

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


_r_platform_search_static_library()
{
   log_entry "_r_platform_search_static_library" "$@"

   local directory="$1"
   local name="$2"

   r_filepath_concat "${directory}" "${_libprefix}${name}${_staticlibsuffix}"

   log_fluff "Looking for static library \"${RVAL}\""

   [ -f "${RVAL}" ]
}


_r_platform_search_dynamic_library()
{
   log_entry "_r_platform_search_dynamic_library" "$@"

   local directory="$1"
   local name="$2"

   r_filepath_concat "${directory}" "${_libprefix}${name}${_dynamiclibsuffix}"

   log_fluff "Looking for dynamic library \"${RVAL}\""

   [ -f "${RVAL}" ]
}


r_platform_search_library_type()
{
   log_entry "r_platform_search_library_type" "$@"

   local type="$1"
   local directory="$2"
   local libdirnames="$3"
   local name="$4"

   IFS=':'; set -f

   for libdirname in ${libdirnames}
   do
      IFS="${DEFAULT_IFS}"; set +f

      r_filepath_concat "${directory}" "${libdirname}"
      if _r_platform_search_${type}_library "${RVAL}" "${name}"
      then
         return 0
      fi
   done
   IFS="${DEFAULT_IFS}"; set +f

   return 1
}


r_platform_search_library()
{
   log_entry "r_platform_search_library" "$@"

   local directory="$1"; shift
   local libdirnames="$1"; shift
   local type="$1"; shift
   local prefer="$1"; shift
   local require="$1"; shift

   local first_type
   local second_type
   local name

   while [ $# -ne 0 ]
   do
      name="$1"
      [ -z "${name}" ] && fail "empty name is not allowed"

      case "${type}" in
         standalone)
            if r_platform_search_library_type "dynamic" "${directory}" \
                                                        "${libdirnames}" \
                                                        "${name}-standalone"
            then
               return 0
            fi

            #
            # if we build everything as shared libraries then we don't
            # need a -standalone library
            #
            if r_platform_search_library_type "dynamic" "${directory}" \
                                                        "${libdirnames}" \
                                                        "${name}"
            then
               return 0
            fi

            shift
            continue
         ;;
      esac

      if [ ! -z "${require}"  ]
      then
         if r_platform_search_library_type "${require}" "${directory}" \
                                                        "${libdirnames}" \
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

      if r_platform_search_library_type "${first_type}" "${directory}" \
                                                        "${libdirnames}" \
                                                        "${name}"
      then
         return 0
      fi

      if r_platform_search_library_type "${second_type}" "${directory}" \
                                                         "${libdirnames}" \
                                                         "${name}"
      then
         return 0
      fi

      shift
   done

   return 1
}


r_platform_search()
{
   log_entry "r_platform_search" "$@"

   local searchpath="$1"; shift

   [ -z "${searchpath}" ] && fail "search path is empty"

   [ -z "${MULLE_PLATFORM_ENVIRONMENT_SH}" ] && \
      . "${MULLE_PLATFORM_LIBEXEC_DIR}/mulle-platform-environment.sh"

   local _libprefix
   local _staticlibsuffix
   local _dynamiclibsuffix

   _platform_get_fix_definitions

   local directory

   IFS=':' ; set -f
   for directory in ${searchpath}
   do
      IFS="${DEFAULT_IFS}" ; set +f

      if [ -z "${directory}" ]
      then
         continue
      fi

      if r_platform_search_library "${directory}" "$@"
      then
         return 0
      fi
   done
   IFS="${DEFAULT_IFS}" ; set +f

   RVAL=""
   return 1
}


platform_search_main()
{
   log_entry "platform_search_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_SEARCH_PATH
   local OPTION_PREFER="static"
   local OPTION_REQUIRE=
   local OPTION_TYPE="library"
   local OPTION_LIBRARY_DIR_NAMES

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform_search_usage
         ;;

         --prefer)
            [ $# -eq 1 ] && platform_search_usage "mMssing argument to \"$1\""
            shift
            OPTION_PREFER="$1"

            case "${OPTION_PREFER}" in
               dynamic|static)
               ;;

               *)
                  platform_search_usage "Unknown prefer value \"${OPTION_PREFER}\""
               ;;
            esac
         ;;

         --require)
            [ $# -eq 1 ] && platform_search_usage "mMssing argument to \"$1\""
            shift
            OPTION_REQUIRE="$1"

            case "${OPTION_REQUIRE}" in
               dynamic|static)
               ;;

               *)
                  platform_search_usage "Unknown require value \"${OPTION_REQUIRE}\""
               ;;
            esac
         ;;

         --library-dir-names)
            [ $# -eq 1 ] && platform_search_usage "Missing argument to \"$1\""
            shift
            OPTION_LIBRARY_DIR_NAMES="$1"
         ;;

         --search-path)
            [ $# -eq 1 ] && platform_search_usage "Missing argument to \"$1\""
            shift
            OPTION_SEARCH_PATH="$1"
         ;;

         --type)
            [ $# -eq 1 ] && platform_search_usage "Missing argument to \"$1\""
            shift
            OPTION_TYPE="$1"
            case "${OPTION_TYPE}" in
               library|standalone)
               ;;

               *)
                  platform_search_usage "Unknown type value \"${OPTION_TYPE}\""
               ;;
            esac
         ;;

         -*)
            platform_search_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   local name
   local directory

   [ $# -ne 0 ] || platform_search_usage "Missing name"

   local libdirnames

   libdirnames="${OPTION_LIBRARY_DIR_NAMES:-lib}"

   if r_platform_search "${OPTION_SEARCH_PATH}" \
                        "${libdirnames}" \
                        "${OPTION_TYPE}" \
                        "${OPTION_PREFER}" \
                        "$@"
   then
      rexekutor printf "%s\n" "${RVAL}"
      return 0
   fi

   log_warning "No library found for \"$*\""
   return 1
}

