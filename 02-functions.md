# Functions

## Annotations and Docstrings

Let's revisit our first function from the previous notebook and try to make it a little more Pythonic as far as the caller is concerned.

```cpp
// test2.cpp
#include <nanobind/nanobind.h>

namespace nb = nanobind;
using namespace nb::literals;

int add(int a, int b) { return a + b; }

NB_MODULE(test2, m) {
    m.def("add", &add, "a"_a, "b"_a = 1,
        "This function adds two numbers and increments if only one is provided.");
    m.attr("the_answer") = 42;
    m.doc() = "A simple example python extension";
}
```

Examining this code we see some new boilerplate related to the `nanobind` namespace, which you can safely include in all your C++-for-Python module code. The extra user-defined literal (`_a`) parameters allow the names of the C++ function parameters to become available in Python, while the C-string becomes the Docstring (`test2.add.__doc__`) for the function. An attribute (constant value) for the module (`test2.the_answer`) is also defined with `m.attr()`, together with a Docstring for the module.

To build this code, run CMake again with `--target test2`:

```bash
cmake --build build --target test2
```

Next, ensure Python looks in the `build` sub-directory for loadable modules:

```python
import sys, os
module_dir = os.path.abspath('build')
if module_dir not in sys.path:
    sys.path.append(module_dir)
    print("Directory 'build' has been added to Python's module path")
```

Finally, run the code to observe provision of a default value for the second parameter (`b = 1`), and provision of named parameters in any order. The Docstring is also present and can be printed by the Python interpreter:

```python
import test2
print(test2.add(1))
print(test2.add(b = 2, a = 3))
print(test2.the_answer)
help(test2)
```

Be aware that calling C++ code from Python does *not* imbue it with any special powers! Using the code above it's easy to create an overflow bug by providing numbers which are too large to fit in a 32-bit two's complement signed integer when added together:

```python
print(test2.add(1_000_000_000, 2_000_000_000))
print(1_000_000_000 + 2_000_000_000)
```

Here, C++ gets it wrong while Python gets it right, something which you should be anticipating when performing type conversions between Python and C++ types.

If a parameter value is unable to be converted to the specified C++ type, an error condition will be raised:

```python
test2.add('?') # Error: Python str not convertible to int
```

```python
test2.add(10_000_000_000) # Error: Number too big for C++ int
```

## Higher-order functions

Functions are first-class types in Python, so let's make sure we can return a C++ function to Python as an object which can be invoked later:

```cpp
// test3.cpp
#include <nanobind/nanobind.h>

namespace nb = nanobind;
using namespace nb::literals;

nb::object halve_fn() {
    return nb::cpp_function(
        [](float n){ return n / 2.0f; },
        nb::arg("n").noconvert()
    );
}


NB_MODULE(test3, m) {
    m.def("halve", &halve_fn,
        "This higher-order function returns another function which divides by 2."
    );
}
```

To build this code, run CMake again with `--target test3`:

```bash
cmake --build build --target test3
```

Now try out the higher-order function:

```python
import test3
f = test3.halve()
f(7.0)
```

Calling this returned lambda function (`f`) with an integer results in an error due to the fact that the argument name was supplied with `.noconvert()`. Also, while the free function is referenced by its address (as in `&halve_fn`), the first parameter to the `nb::cpp_function()` constructor is a C++ lambda. Free functions, lambdas (stateful or non-stateful) or `std::function` objects can be used (the latter requires header `<nanobind/stl/function.h>`).

## Accepting multiple and multiple keyword arguments

In Python it is possible to write functions such as:

```python
def generic(*args, **kwargs):
    print('Positional:')
    for a in args:
        print(f'\t{a}')
    print('Keyword:')
    for k in kwargs:
        print(f'\t{k} -> {kwargs[k]}')

generic(1, 2.2, 'Hi', name='Fred', age=34)
```

This can also be achieved using **nanobind** in the following way:

```cpp
// test4.cpp
#include <nanobind/nanobind.h>

namespace nb = nanobind;

void generic(nb::args args, nb::kwargs kwargs) {
    nb::print(nb::str("Positional:"));
    for (auto v: args)
        nb::print(nb::str("\t{}").format(v));
    nb::print(nb::str("Keyword:"));
    for (auto kv: kwargs)
        nb::print(nb::str("\t{} -> {}").format(kv.first, kv.second));
}

NB_MODULE(test4, m) {
    m.def("generic", &generic);
}
```

To build this code, run CMake again with `--target test4`:

```bash
cmake --build build --target test4
```

The output is the exactly same as previously with the function written in Python:

```python
import test4

test4.generic(1, 2.2, 'Hi', name='Fred', age=34)
```

It is also possible for functions like this to be passed to higher-order functions.

*All text and program code &copy;2026 Richard Spencer, all rights reserved.*