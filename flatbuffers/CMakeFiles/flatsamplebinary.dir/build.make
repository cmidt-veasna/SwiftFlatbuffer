# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.5

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list


# Suppress display of executed commands.
$(VERBOSE).SILENT:


# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /Applications/CMake.app/Contents/bin/cmake

# The command to remove a file.
RM = /Applications/CMake.app/Contents/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers

# Include any dependencies generated for this target.
include CMakeFiles/flatsamplebinary.dir/depend.make

# Include the progress variables for this target.
include CMakeFiles/flatsamplebinary.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/flatsamplebinary.dir/flags.make

samples/monster_generated.h: flatc
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --blue --bold --progress-dir=/Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Generating samples/monster_generated.h"
	./flatc -c --no-includes --gen-mutable --gen-object-api -o samples /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/samples/monster.fbs

CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o: CMakeFiles/flatsamplebinary.dir/flags.make
CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o: samples/sample_binary.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Building CXX object CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o"
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o -c /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/samples/sample_binary.cpp

CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.i"
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/samples/sample_binary.cpp > CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.i

CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.s"
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/samples/sample_binary.cpp -o CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.s

CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.requires:

.PHONY : CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.requires

CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.provides: CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.requires
	$(MAKE) -f CMakeFiles/flatsamplebinary.dir/build.make CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.provides.build
.PHONY : CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.provides

CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.provides.build: CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o


# Object files for target flatsamplebinary
flatsamplebinary_OBJECTS = \
"CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o"

# External object files for target flatsamplebinary
flatsamplebinary_EXTERNAL_OBJECTS =

flatsamplebinary: CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o
flatsamplebinary: CMakeFiles/flatsamplebinary.dir/build.make
flatsamplebinary: CMakeFiles/flatsamplebinary.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/CMakeFiles --progress-num=$(CMAKE_PROGRESS_3) "Linking CXX executable flatsamplebinary"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/flatsamplebinary.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/flatsamplebinary.dir/build: flatsamplebinary

.PHONY : CMakeFiles/flatsamplebinary.dir/build

CMakeFiles/flatsamplebinary.dir/requires: CMakeFiles/flatsamplebinary.dir/samples/sample_binary.cpp.o.requires

.PHONY : CMakeFiles/flatsamplebinary.dir/requires

CMakeFiles/flatsamplebinary.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/flatsamplebinary.dir/cmake_clean.cmake
.PHONY : CMakeFiles/flatsamplebinary.dir/clean

CMakeFiles/flatsamplebinary.dir/depend: samples/monster_generated.h
	cd /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers /Users/veasna/Documents/MyProject/Web/Cmidt.com/flatbuffers/CMakeFiles/flatsamplebinary.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/flatsamplebinary.dir/depend
