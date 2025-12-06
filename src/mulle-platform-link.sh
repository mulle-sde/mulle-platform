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

MULLE_PLATFORM_LINK_SH='included'


platform::link::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} link [options] <object-files...> -o <output-file>

   Generate and optionally execute a platform-appropriate link command.
   This command translates abstract linker options into concrete ld commands.

Options:
   --platform <name>        : Platform (default: ${MULLE_UNAME})
   --language <name>        : Language: c, cpp, objc (default: c)
   --dialect <name>         : Dialect for the language
   --configuration <name>   : Debug, Release, Test, RelWithDebInfo (default: Debug)
   --compiler-type <type>   : Force compiler type (gcc, clang, mulle-clang, cl)
   -L <dir>                 : Library search directory (can be repeated)
   -l <lib>                 : Link library (can be repeated)
   -F <dir>                 : Framework search directory (Darwin only, can be repeated)
   -framework <name>        : Link framework (Darwin only, can be repeated)
   -o <file>                : Output file
   --shared                 : Create shared library instead of executable
   --print-only             : Print command without executing
   --                       : End of options, remaining args passed to linker

Example:
   # Link object files to executable
   mulle-platform link foo.o bar.o -o myapp

   # Link with libraries
   mulle-platform link foo.o -L/usr/local/lib -lmylib -o myapp

   # Create shared library on Darwin
   mulle-platform link --shared foo.o bar.o -o libmylib.dylib

   # Just print the command that would be run
   mulle-platform link --print-only foo.o -o myapp

EOF
   exit 1
}


platform::link::main()
{
   log_entry "platform::link::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_LANGUAGE="c"
   local OPTION_DIALECT
   local OPTION_OBJC_DIALECT="mulle-objc"
   local OPTION_CONFIGURATION="Debug"
   local OPTION_COMPILER_TYPE
   local OPTION_OUTPUT
   local OPTION_SHARED='NO'
   local OPTION_PRINT_ONLY='NO'
   
   local -a libdirs
   local -a libs
   local -a frameworks
   local -a framework_dirs
   local -a objects
   local -a extra_args

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::link::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         --language)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_LANGUAGE="$1"
         ;;

         --dialect)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_DIALECT="$1"
         ;;

         --objc-dialect)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_OBJC_DIALECT="$1"
         ;;

         --configuration)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_CONFIGURATION="$1"
         ;;

         --compiler-type)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER_TYPE="$1"
         ;;

         -L)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            libdirs+=( "$1" )
         ;;

         -L*)
            # Handle -L/path/to/lib format
            libdirs+=( "${1#-L}" )
         ;;

         -l)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            libs+=( "$1" )
         ;;

         -l*)
            # Handle -lmylib format
            libs+=( "${1#-l}" )
         ;;

         -F)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            framework_dirs+=( "$1" )
         ;;

         -framework)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            frameworks+=( "$1" )
         ;;

         -o)
            [ $# -eq 1 ] && platform::link::usage "Missing argument to \"$1\""
            shift
            OPTION_OUTPUT="$1"
         ;;

         --shared)
            OPTION_SHARED='YES'
         ;;

         --print-only)
            OPTION_PRINT_ONLY='YES'
         ;;

         --)
            shift
            extra_args+=( "$@" )
            break
         ;;

         -*)
            platform::link::usage "Unknown option \"$1\""
         ;;

         *)
            objects+=( "$1" )
         ;;
      esac
      shift
   done

   # Validate inputs
   if [ ${#objects[@]} -eq 0 ]
   then
      platform::link::usage "No object files specified"
   fi

   if [ -z "${OPTION_OUTPUT}" ]
   then
      platform::link::usage "No output file specified (use -o)"
   fi

   # Set dialect default based on language if not specified
   if [ -z "${OPTION_DIALECT}" ]
   then
      case "${OPTION_LANGUAGE}" in
         c)
            OPTION_DIALECT="c"
         ;;
         objc)
            OPTION_DIALECT="objc"
         ;;
         cpp)
            OPTION_DIALECT="cpp"
         ;;
         *)
            OPTION_DIALECT="${OPTION_LANGUAGE}"
         ;;
      esac
   fi

   # Get compiler (we link via the compiler driver)
   include "platform::compiler"

   platform::compiler::r_select_c_compiler "${OPTION_PLATFORM}" \
                                           "${OPTION_DIALECT}" \
                                           "${OPTION_OBJC_DIALECT}" \
                                           "${OPTION_COMPILER_TYPE}"
   local cc="${RVAL}"

   # Detect compiler type
   platform::compiler::r_detect_compiler_type "${cc}"
   local compiler_type="${RVAL}"

   # Load compiler plugin and get flags
   include "platform::plugin"

   local plugin_name
   case "${compiler_type}" in
      gcc|clang|mulle-clang)
         plugin_name="gcc"
      ;;
      msvc)
         plugin_name="msvc"
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
         plugin_name="gcc"
         log_warning "Unknown compiler type \"${compiler_type}\", using gcc plugin"
      ;;
   esac

   if ! platform::plugin::load_compiler "${plugin_name}"
   then
      fail "Failed to load compiler plugin \"${plugin_name}\""
   fi

   # Get base linker flags from plugin
   platform::plugin::compiler::${plugin_name}::get_ldflags "${OPTION_CONFIGURATION}" \
                                                           "${OPTION_PLATFORM}"
   local ldflags="${RVAL}"

   # Build command line
   local -a cmdline
   cmdline=( "${cc}" )

   # Add shared library flag if requested
   if [ "${OPTION_SHARED}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_shared_flag "${OPTION_PLATFORM}"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   fi

   # Add output file
   platform::plugin::compiler::${plugin_name}::r_format_output_flag "${OPTION_OUTPUT}" 'NO'
   cmdline+=( ${RVAL} )  # Word splitting intentional

   # Add object files
   cmdline+=( "${objects[@]}" )

   # Add library search directories
   local libdir
   for libdir in "${libdirs[@]}"
   do
      platform::plugin::compiler::${plugin_name}::r_format_libdir_flag "${libdir}"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   done

   # Add libraries
   local lib
   for lib in "${libs[@]}"
   do
      platform::plugin::compiler::${plugin_name}::r_format_lib_flag "${lib}"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   done

   # Add framework directories
   if [ ${#framework_dirs[@]} -gt 0 ]
   then
      local fdir
      for fdir in "${framework_dirs[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_framework_dir_flag "${fdir}"
         if [ ! -z "${RVAL}" ]
         then
            cmdline+=( ${RVAL} )  # Word splitting intentional
         fi
      done
   fi

   # Add frameworks
   if [ ${#frameworks[@]} -gt 0 ]
   then
      local framework
      for framework in "${frameworks[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_framework_flag "${framework}"
         if [ ! -z "${RVAL}" ]
         then
            cmdline+=( ${RVAL} )  # Word splitting intentional
         fi
      done
   fi

   # Add base linker flags
   if [ ! -z "${ldflags}" ]
   then
      cmdline+=( ${ldflags} )  # Word splitting intentional
   fi

   # Add extra arguments
   if [ ${#extra_args[@]} -gt 0 ]
   then
      cmdline+=( "${extra_args[@]}" )
   fi

   # Print or execute
   if [ "${OPTION_PRINT_ONLY}" = 'YES' ]
   then
      printf "%s\n" "${cmdline[*]}"
   else
      log_verbose "Executing: ${cmdline[*]}"
      "${cmdline[@]}"
      return $?
   fi
}
