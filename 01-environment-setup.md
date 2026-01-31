# Environment Setup

This notebook outlines a number of steps designed to get you up and running with the **nanobind** library, which allows for calling of C++ code from Python for C++17 and newer (and Python 3.8 and newer). It is assumed that you are using Linux, with the commands `git`, `cmake` and `g++` being available (similar invocations should work under Windows, possibly with Git-Bash installed, or MacOS, however this has not been tested).

If using this tutorial in Jupyter notebook format, running each code cell in this notebook in turn should be sufficient to fully install and test **nanobind** (and optionally the C++ **Eigen** library for matrix Math computations), all under the location of the directory in which `jupyter lab` was run (ideally the same writable directory as the notebooks themselves).

In either case, the installation should be persistent across sessions (at least for locally-hosted JupyterLab/Notebook), so subsequent notebooks can be followed, or returned to at a later time, without further reference to this one. The code for this tutorial is based upon that from http://nanobind.readthedocs.io/ and reference to this documentation for a more detailed treatment is recommended once the environment is set up.

## Download and install nanobind

The **nanobind** library is best installed as a submodule of an existing `git` project, so we'll go ahead and create one:

```bash
git init
```

Next we'll add **nanobind** to live in the subdirectory `ext`, referencing the latest version available:

```bash
git submodule add https://github.com/wjakob/nanobind ext/nanobind
```

Then we need to pull the files from the repository, and use of the `--recursive` option is necessary as **nanobind** itself has a submodule dependency (`Tessil/robin-map`):

```bash
git submodule update --init --recursive
```

## Creating CMakeLists.txt

The fact that we are using submodules means we need a master `CMakeLists.txt`, so paste the following into a new file with this name into the same directory (or run the cell to create it):

```cmake
cmake_minimum_required(VERSION 3.15...3.27)
project(NanobindTutorial)

if (CMAKE_VERSION VERSION_LESS 3.18)
  set(DEV_MODULE Development)
else()
  set(DEV_MODULE Development.Module)
endif()

find_package(Python 3.8 COMPONENTS Interpreter ${DEV_MODULE} REQUIRED)

if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/ext/nanobind)

nanobind_add_module(test1 test1.cpp)
nanobind_add_module(test2 test2.cpp)
nanobind_add_module(test3 test3.cpp)
nanobind_add_module(test4 test4.cpp)
nanobind_add_module(test5 test5.cpp)
nanobind_add_module(test6 test6.cpp)
nanobind_add_module(test7 test7.cpp)
nanobind_add_module(test8 test8.cpp)
nanobind_add_module(test9 test9.cpp)
nanobind_add_module(eigen1 eigen1.cpp)
nanobind_add_module(eigen2 eigen2.cpp)
target_include_directories(eigen2 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
nanobind_add_module(eigen3 eigen3.cpp)
target_include_directories(eigen3 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
```

Each new `.cpp` source file needs to be referenced with `nanobind_add_module(my_module my_module.cpp)`, creating a dynamic library (`.so` under Linux) from it which can be loaded at run-time with Python's `import` command.

To run CMake with this file, it expects that these `.cpp` files all exist, so we'll go ahead and create these as empty files (if necessary):

```bash
touch test1.cpp test2.cpp test3.cpp test4.cpp test5.cpp test6.cpp test7.cpp test8.cpp test9.cpp eigen1.cpp eigen2.cpp eigen3.cpp
```

Now we can configure the project, with sources in the current directory and build files in sub-directory `build`:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
```

Assuming all went well we can move on to creating our first C++ module.

## A first nanobind module

A C++ function which adds two `int`s, returning the result also as an `int`, can be exposed to Python using the following code:

```cpp
// test1.cpp
#include <nanobind/nanobind.h>

int add(int a, int b) { return a + b; }

NB_MODULE(test1, m) {
    m.def("add", &add);
}
```

We can build the whole project (including **nanobind**) from scratch with `cmake --build build`, and use the same command for subsequent builds rebuild with changes to the `.cpp` files, or even to `CMakeLists.txt` itself.

With the contents of `test1.cpp` being the above, we'll just build the `test1` target to avoid error messages related to the other (empty for now) `.cpp` source files:

```bash
cmake --build build --target test1
```

This will build the `libnanobind-static.a` library and then compile `test1.cpp` to a file such as `test1.cpython-313-x86_64-linux-gnu.so` (the exact name depends upon Python version and platform). File `Python.h` needs to be available to **nanobind** in order to permit compilation, under Linux this is probably from a package providing development headers (such as `libpython3-dev`).

If you are following this tutorial using the Jupyter notebooks, it may not be apparent whether the `.so` was created as it doesn't appear in the file browser. Run the following command to find out:

```bash
ls -l build/*.so
```

## Loading your first C++ module

The moment at which it all comes together has arrived! In the notebook, run the following in the Python interpreter to make the `build` directory available (please note: **this needs to be performed for every kernel restart**):

```python
import sys, os
module_dir = os.path.abspath('build')
if module_dir not in sys.path:
    sys.path.append(module_dir)
    print("Directory 'build' has been added to Python's module path")
```

(Alternatively, if using the command line issue `cd build` and start the Python interpreter from within this directory.)

The Python client code which loads and calls the `add()` function created above is:

```python
import test1
test1.add(1, 2)
```

And that's all there is to it. Just remember, use `cmake --build build --target my_module` after every change to the C++ source in *my_module.cpp*.

**Important note:** if using this tutorial in Jupyter notebook format, be aware that a kernel restart is needed in order to re-import a modified module, as the metadata about them is cached by the Python interpreter. To do this click the reload icon to the right of "stop" in the main panel&mdash;use the code above to add the `build` directory to the Python include path again, after the restart.

## Installing Eigen

Please note: **this part is optional** and involves a fairly sizeable download&mdash;it is only needed for the later notebook on matrix operations with the Eigen C++ library.

To perform a minimal clone of version 3.3.1 of the library (the version that current **nanobind** requires) into a directory called `eigen-3.3.1` use the following:

```bash
ls eigen-3.3.1 || git clone https://gitlab.com/libeigen/eigen.git --branch 3.3.1 --single-branch --depth 1 eigen-3.3.1
```

Then, to configure the library (which is header-only) and set the install directory as `eigen-3.3.1/include` use:

```bash
cmake -S eigen-3.3.1 -B eigen-3.3.1/build -DCMAKE_INSTALL_PREFIX="$PWD/eigen-3.3.1" -DINCLUDE_INSTALL_DIR=include
```

Finally, to create the header files as part of the overall build, and then to install them as per the `install` target use:

```bash
cmake --build eigen-3.3.1/build --target install
```

*All text and program code &copy;2026 Richard Spencer, all rights reserved.*