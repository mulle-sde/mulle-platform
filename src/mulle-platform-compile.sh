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

MULLE_PLATFORM_COMPILE_SH='included'


platform::compile::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} compiler run [options] <source-file> -o <output-file>

   Generate and optionally execute a platform-appropriate compile command.
   This command translates abstract compiler options into concrete cc/cl commands.

Options:
   --platform <name>        : Platform (default: ${MULLE_UNAME})
   --language <name>        : Language: c, cpp, objc (default: detect from extension)
   --dialect <name>         : Dialect for the language
   --configuration <name>   : Debug, Release, Test, RelWithDebInfo (default: Debug)
   --no-default-cflags      : Don't add configuration's default CFLAGS (user provides them)
   --compiler-type <type>   : Force compiler type (gcc, clang, mulle-clang, cl)
   -F <dir>                 : Framework directory (can be repeated)
   -I <dir>                 : Include directory (can be repeated)
   -D <define>              : Preprocessor define (can be repeated)
   -c                       : Compile only (produce object file)
   --shared                 : Compile for shared library (adds -fPIC on most platforms)
   --sanitizer <type>       : Enable sanitizer (address, thread, undefined) (can be repeated)
   --coverage               : Enable code coverage
   --export-symbol <symbol> : Export symbol for linking (can be repeated)
   --output-asm             : Output assembler code instead of object/executable
   --emit-llvm              : Output LLVM IR instead of assembler (use with --output-asm)
   --show-headers           : Show header file search during compilation
   --rpath <path>           : Add runtime library search path (can be repeated)
   -L <dir>                 : Library search directory (can be repeated)
   -l <lib>                 : Link library (can be repeated)
   --wholearchive <lib>     : Link library with whole-archive (can be repeated)
   -Wl,<options>            : Pass comma-separated options to linker (can be repeated)
   -o <file>                : Output file
   --print-only             : Print command without executing
   --                       : End of options, remaining args passed to compiler

Example:
   # Compile a C file to object
   mulle-platform compile -c foo.c -o foo.o

   # Compile Objective-C with mulle-objc dialect
   mulle-platform compile --dialect mulle-objc foo.m -o foo

   # Just print the command that would be run
   mulle-platform compile --print-only foo.c -o foo

EOF
   exit 1
}


platform::compile::r_detect_language_from_extension()
{
   log_entry "platform::compile::r_detect_language_from_extension" "$@"

   local filepath="$1"

   case "${filepath}" in
      *.c)
         RVAL="c"
      ;;
      *.m|*.aam)
         RVAL="objc"
      ;;
      *.cpp|*.cxx|*.cc|*.C)
         RVAL="cpp"
      ;;
      *.mm)
         RVAL="objcpp"
      ;;
      *)
         RVAL="c"  # Default to C
      ;;
   esac
}


platform::compile::main()
{
   log_entry "platform::compile::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_LANGUAGE
   local OPTION_DIALECT
   local OPTION_OBJC_DIALECT="mulle-objc"
   local OPTION_CONFIGURATION="Debug"
   local OPTION_COMPILER_TYPE
   local OPTION_COMPILE_ONLY='NO'
   local OPTION_SHARED='NO'
   local OPTION_OUTPUT
   local OPTION_PRINT_ONLY='NO'
   local OPTION_COVERAGE='NO'
   local OPTION_OUTPUT_ASM='NO'
   local OPTION_EMIT_LLVM='NO'
   local OPTION_SHOW_HEADERS='NO'
   
   local -a includes
   local -a defines
   local -a frameworkpaths
   local -a sources
   local -a libdirs
   local -a libs
   local -a wholearchive_libs
   local -a ldflags
   local -a extra_args
   local -a sanitizers
   local -a export_symbols
   local -a rpaths

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::compile::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         --language)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_LANGUAGE="$1"
         ;;

         --dialect)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_DIALECT="$1"
         ;;

         --objc-dialect)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_OBJC_DIALECT="$1"
         ;;

         --configuration)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_CONFIGURATION="$1"
         ;;

         --no-default-cflags)
            OPTION_NO_DEFAULT_CFLAGS='YES'
         ;;

         --compiler-type)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER_TYPE="$1"
         ;;

         -F)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            frameworkpaths+=( "$1" )
         ;;

         -F*)
            # Handle -I/path/to/include format
            frameworkpaths+=( "${1#-I}" )
         ;;

         -I)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            includes+=( "$1" )
         ;;

         -I*)
            # Handle -I/path/to/include format
            includes+=( "${1#-I}" )
         ;;

         -D)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            defines+=( "$1" )
         ;;

         -D*)
            # Handle -DDEFINE format
            defines+=( "${1#-D}" )
         ;;

         -L)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            libdirs+=( "$1" )
         ;;

         -L*)
            # Handle -L/path/to/lib format
            libdirs+=( "${1#-L}" )
         ;;

         -l)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            libs+=( "$1" )
         ;;

         -l*)
            # Handle -lmylib format
            libs+=( "${1#-l}" )
         ;;

         --wholearchive)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            wholearchive_libs+=( "$1" )
         ;;

         -Wl,*)
            # Handle -Wl,option format
            ldflags+=( "${1#-Wl,}" )
         ;;

         -c)
            OPTION_COMPILE_ONLY='YES'
         ;;

         --shared)
            OPTION_SHARED='YES'
         ;;

         --sanitizer)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            sanitizers+=( "$1" )
         ;;

         --coverage)
            OPTION_COVERAGE='YES'
         ;;

         --export-symbol)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            export_symbols+=( "$1" )
         ;;

         --output-asm)
            OPTION_OUTPUT_ASM='YES'
         ;;

         --emit-llvm)
            OPTION_EMIT_LLVM='YES'
         ;;

         --show-headers)
            OPTION_SHOW_HEADERS='YES'
         ;;

         --rpath)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            rpaths+=( "$1" )
         ;;

         -o)
            [ $# -eq 1 ] && platform::compile::usage "Missing argument to \"$1\""
            shift
            OPTION_OUTPUT="$1"
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
            platform::compile::usage "Unknown option \"$1\""
         ;;

         *)
            sources+=( "$1" )
         ;;
      esac
      shift
   done

   # Validate inputs
   if [ ${#sources[@]} -eq 0 ]
   then
      platform::compile::usage "No source file specified"
   fi

   if [ -z "${OPTION_OUTPUT}" ]
   then
      platform::compile::usage "No output file specified (use -o)"
   fi

   # Detect language from first source file if not specified
   if [ -z "${OPTION_LANGUAGE}" ]
   then
      platform::compile::r_detect_language_from_extension "${sources[0]}"
      OPTION_LANGUAGE="${RVAL}"
      log_fluff "Detected language: ${OPTION_LANGUAGE}"
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

   # Get compiler
   include "platform::compiler-environment"

   platform::compiler::r_select_c_compiler "${OPTION_PLATFORM}" \
                                           "${OPTION_DIALECT}" \
                                           "${OPTION_OBJC_DIALECT}" \
                                           "${OPTION_COMPILER_TYPE}"
   local cc="${RVAL}"

   # Get SDK path for Darwin Objective-C if needed
   local sdk_path
   sdk_path=""
   case "${OPTION_PLATFORM}" in
      darwin)
         if [ "${OPTION_DIALECT}" = "objc" -o "${OPTION_DIALECT}" = "objcpp" ]
         then
            include "platform::sdkpath"
            
            if platform::sdkpath::r_darwin_sdkpath
            then
               sdk_path="${RVAL}"
               log_debug "Using SDK path: ${sdk_path}"
            else
               log_warning "Could not determine Darwin SDK path"
            fi
         fi
      ;;
   esac

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

   # Get base flags from plugin (unless --no-default-cflags)
   local cflags
   if [ "${OPTION_NO_DEFAULT_CFLAGS}" != 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::get_flags "${OPTION_CONFIGURATION}" \
                                                            "${OPTION_DIALECT}" \
                                                            "${OPTION_OBJC_DIALECT}"
      cflags="${RVAL}"
   fi

   # Build command line
   local -a cmdline
   cmdline=( "${cc}" )

   # Add base flags
   if [ ! -z "${cflags}" ]
   then
      cmdline+=( ${cflags} )  # Word splitting intentional
   fi

   # Add compile-only flag if requested
   if [ "${OPTION_COMPILE_ONLY}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_compile_only_flag
      cmdline+=( ${RVAL} )  # Word splitting intentional
   fi

   # Add assembler output flag if requested
   if [ "${OPTION_OUTPUT_ASM}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::format_asm_output_flag "${OPTION_EMIT_LLVM}"
      if [ ! -z "${RVAL}" ]
      then
         cmdline+=( ${RVAL} )  # Word splitting intentional
      fi
   fi

   # Add show headers flag if requested
   if [ "${OPTION_SHOW_HEADERS}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::format_show_headers_flag
      if [ ! -z "${RVAL}" ]
      then
         cmdline+=( ${RVAL} )  # Word splitting intentional
      fi
   fi

   # Add shared library compilation flag if requested
   if [ "${OPTION_SHARED}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_shared_compile_flag "${OPTION_PLATFORM}"
      if [ ! -z "${RVAL}" ]
      then
         cmdline+=( ${RVAL} )  # Word splitting intentional
      fi
   fi

   # Add sanitizer flags
   if [ ${#sanitizers[@]} -gt 0 ]
   then
      local sanitizer
      for sanitizer in "${sanitizers[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_sanitizer_flag "${sanitizer}"
         if [ ! -z "${RVAL}" ]
         then
            cmdline+=( ${RVAL} )  # Word splitting intentional
         fi
      done
   fi

   # Add coverage flags
   if [ "${OPTION_COVERAGE}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_coverage_compile_flag
      if [ ! -z "${RVAL}" ]
      then
         cmdline+=( ${RVAL} )  # Word splitting intentional
      fi
   fi

   # Add SDK path flag if needed (before other includes)
   if [ ! -z "${sdk_path}" ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_sysroot_flag "${sdk_path}"
      if [ ! -z "${RVAL}" ]
      then
         cmdline+=( ${RVAL} )  # Word splitting intentional
      fi
   fi

   # Add include directories
   local include_dir
   for include_dir in "${includes[@]}"
   do
      platform::plugin::compiler::${plugin_name}::r_format_include_flag "${include_dir}"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   done

   # Add framework directories
   local framework_dir
   for framework_dir in "${frameworkpaths[@]}"
   do
      platform::plugin::compiler::${plugin_name}::r_format_framework_dir_flag "${framework_dir}"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   done

   # Add defines
   local define
   for define in "${defines[@]}"
   do
      platform::plugin::compiler::${plugin_name}::r_format_define_flag "${define}"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   done

   # Add MULLE_INCLUDE_DYNAMIC define for shared library compilation
   if [ "${OPTION_SHARED}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_define_flag "MULLE_INCLUDE_DYNAMIC=1"
      cmdline+=( ${RVAL} )  # Word splitting intentional
   fi

   # Add output file
   platform::plugin::compiler::${plugin_name}::r_format_output_flag "${OPTION_OUTPUT}" "${OPTION_COMPILE_ONLY}"
   cmdline+=( ${RVAL} )  # Word splitting intentional

   # Add source files
   cmdline+=( "${sources[@]}" )

   # Add library search directories (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#libdirs[@]} -gt 0 ]
   then
      local libdir
      for libdir in "${libdirs[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_libdir_flag "${libdir}"
         cmdline+=( ${RVAL} )  # Word splitting intentional
      done
   fi

   # Add libraries (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#libs[@]} -gt 0 ]
   then
      local lib
      for lib in "${libs[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_lib_flag "${lib}"
         cmdline+=( ${RVAL} )  # Word splitting intentional
      done
   fi

   # Add wholearchive libraries (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#wholearchive_libs[@]} -gt 0 ]
   then
      local walib
      for walib in "${wholearchive_libs[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_wholearchive_flag "${walib}" "${OPTION_PLATFORM}"
         cmdline+=( ${RVAL} )  # Word splitting intentional
      done
   fi

   # Add linker flags (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#ldflags[@]} -gt 0 ]
   then
      local ldflag
      for ldflag in "${ldflags[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_linker_flag "${ldflag}"
         cmdline+=( ${RVAL} )  # Word splitting intentional
      done
   fi

   # Add sanitizer link flags (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#sanitizers[@]} -gt 0 ]
   then
      local sanitizer
      for sanitizer in "${sanitizers[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_sanitizer_link_flag "${sanitizer}"
         if [ ! -z "${RVAL}" ]
         then
            cmdline+=( ${RVAL} )  # Word splitting intentional
         fi
      done
   fi

   # Add export symbol flags (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#export_symbols[@]} -gt 0 ]
   then
      local export_symbol
      for export_symbol in "${export_symbols[@]}"
      do
         platform::plugin::compiler::${plugin_name}::r_format_export_symbol_flag "${export_symbol}"
         if [ ! -z "${RVAL}" ]
         then
            cmdline+=( ${RVAL} )  # Word splitting intentional
         fi
      done
   fi

   # Add rpath flags (only if not compile-only)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ ${#rpaths[@]} -gt 0 ]
   then
      local rpath
      for rpath in "${rpaths[@]}"
      do
         platform::plugin::compiler::${plugin_name}::format_rpath_flag "${rpath}"
         if [ ! -z "${RVAL}" ]
         then
            cmdline+=( ${RVAL} )  # Word splitting intentional
         fi
      done
   fi

   # Add extra arguments
   if [ ${#extra_args[@]} -gt 0 ]
   then
      cmdline+=( "${extra_args[@]}" )
   fi

   # Add coverage link flags AFTER extra_args so coverage runtime follows all static libs
   # (GNU ld requires the runtime lib after all libs referencing __gcov_* symbols)
   if [ "${OPTION_COMPILE_ONLY}" != 'YES' ] && [ "${OPTION_COVERAGE}" = 'YES' ]
   then
      platform::plugin::compiler::${plugin_name}::r_format_coverage_link_flag "${compiler_type}"
      if [ ! -z "${RVAL}" ]
      then
         cmdline+=( ${RVAL} )  # Word splitting intentional
      fi
   fi

   # Print or execute
   if [ "${OPTION_PRINT_ONLY}" = 'YES' ]
   then
      printf "%s\n" "${cmdline[*]}"
   else
      printf "%s\n" "${cmdline[*]}"
      exekutor "${cmdline[@]}"
      return $?
   fi
}
