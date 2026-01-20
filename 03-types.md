# Types

Having looked at how C++ functions are made available to Python, this notebook looks in-depth at how to move different data types between the two. In a typical scenario (as we have seen), a bound C++ function will accept parameter(s) and provide a result as the return value.

There are three ways to pass data between Python and C++ using **nanobind**, they are: type casters, bindings and wrappers.

## Option 1: Type Casters

A type caster *translates* dynamically-typed Python objects to statically-typed C++ objects, and vice-versa. The built-in C++ types do not require any headers in addition to `<nanobind/nanobind.h>`, while other supported types require an additional header (such as `<nanobind/stl/string.h>`).

The following function accepts a Python list (which must contain only integers) and returns a new list with each element doubled. Note that the use of the alias `IntVector` is purely for convenience in the C++ code, there is no type with the same name on the Python side.

```cpp
// test5.cpp
#include <nanobind/nanobind.h>
#include <nanobind/stl/vector.h>

using IntVector = std::vector<int>;

IntVector double_it(const IntVector &in) {
    IntVector out(in.size());
    for (size_t i = 0; i < in.size(); ++i)
        out[i] = in[i] * 2;
    return out;
}

NB_MODULE(test5, m) {
    m.def("double_it", &double_it);
}
```

To build this code, run CMake again with `--target test5`:

```bash
cmake --build build --target test5
```

Again, ensure Python looks in the `build` sub-directory for loadable modules:

```python
import sys, os
module_dir = os.path.abspath('build')
if module_dir not in sys.path:
    sys.path.append(module_dir)
    print("Directory 'build' has been added to Python's module path")
```

It can be made available to Python and tested using:

```python
import test5
print(test5.double_it([1, 2, 3]))
print(test5.double_it([1, 2, 'foo'])) # Error
```

The second call will fail at runtime as `'foo'` cannot be converted into a C++ `int`.

Type casters are easy to use, all that is needed is the correct header `<nanobind/stl/TYPE.h>` where `TYPE` is one of: `array`, `chrono`, `complex`, `filesystem` (for type `std::filesystem::path` only), `function`, `list`, `map`, `optional`, `pair`, `set`, `string`, `string_view`, `wstring`, `tuple`, `shared_ptr`, `unique_ptr`, `unordered_map`, `unordered_set`, `variant`, `vector`.

There are several additional types supported: `nb::ndarray`, several `Eigen::*` types, and Apache Arrow types. These are provided by: `<nanobind/ndarray.h>`, `<nanobind/eigen/dense.h>`, `<nanobind/eigen/sparse.h>` and https://github.com/maximiliank/nanobind_pyarrow

You should be aware that each time the type caster is used, a copy must me made of the entire object, which can be wasteful for large and/or complex (composed) types where only part(s) of it are needed. Some type casters (`std::unique_ptr<..>`, `std::shared_ptr<..>`, `nb::ndarray`, and `Eigen::*`) can perform the type conversion *without* copying the underlying data.

Also, C++ reference parameters do *not* propagate changes back to the original Python object. Using a `std::tuple` as the return type allows for the modified parameter, plus a result, to be returned to the calling code.

## Option 2: Bindings

In **nanobind**, bindings make C++ types available directly to Python code. To switch the previous example to bindings, we first replace the type caster header (`<nanobind/stl/vector.h>`) by its binding variant (`<nanobind/stl/bind_vector.h>`) and then invoke the `nb::bind_vector<T>()` function to create a new Python type named `IntVector` *within the module itself*.

```cpp
// test6.cpp
#include <nanobind/nanobind.h>
#include <nanobind/stl/bind_vector.h>

using IntVector = std::vector<int>;

IntVector double_it(const IntVector &in) {
    IntVector out(in.size());
    for (size_t i = 0; i < in.size(); ++i)
        out[i] = in[i] * 2;
    return out;
}

namespace nb = nanobind;

NB_MODULE(test6, m) {
    nb::bind_vector<IntVector>(m, "IntVector");
    m.def("double_it", &double_it);
 }
```

To build this code, run CMake again with `--target test6`:

```bash
cmake --build build --target test6
```

Call this function and show the types involved with:

```python
import test6
print(test6.double_it([1, 2, 3]))
test6.double_it.__doc__
```

Of course, it is possible to use any other valid name for `IntVector` on the C++ and Python sides. Other types for which bindings are available are `std::map`, `std::unordered_map` (`<nanobind/stl/bind_map.h>`) and C++ forward iterators (`<nanobind/make_iterator.h>`). It is also possible to bind custom types (user-defined C++ and Python classes&mdash;see the later notebook).

## Option 3: Wrappers

Wrappers are in a sense the complement to bindings; they allow direct access of Python types within C++ code. The same function can be written can be written to use only the types `nb::list` and `nb::int_` (neither requiring any additional headers):

```cpp
// test7.cpp
#include <nanobind/nanobind.h>

namespace nb = nanobind;

nb::list double_it(nb::list l) {
    nb::list result;
    for (nb::handle h: l)
        result.append(h * nb::int_(2));
    return result;
}

NB_MODULE(test7, m) {
    m.def("double_it", &double_it);
}
```

To build this code, run CMake again with `--target test7`:

```bash
cmake --build build --target test7
```

Use the wrapper version of this function with:

```python
import test7
print(test7.double_it([1, 2, 3]))
```

It may be asked, isn't this the cleanest (and best) way to make C++ use Python types? While wrappers are convenient, and require no copying or type conversions, they can only communicate *through* Python. In this version of the function, accessing each element requires a Python API call (which will have an overhead compared to native C++ element access). The performance advantage of C++ over Python is therefore reduced considerably, and this approach is not suited to performance-critical or multi-threaded code. (It is posssible to access the wider Python ecosystem, NumPy, Matplotlib, PyTorch with wrapper-using C++ code.)

There is a large number of wrappers available, and all require no additional include directives: `any`, `bytearray`, `bytes`, `callable`, `capsule`, `dict`, `ellipsis`, `handle`, `handle_t<T>`, `bool_`, `int_`, `float_`, `frozenset`, `iterable`, `iterator`, `list`, `mapping`, `module_`, `object`, `set`, `sequence`, `slice`, `str`, `tuple`, `weakref`, `type_object`, `type_object_t<T>`, `args`, `kwargs`, `fallback`.

## Conclusion

It is possible to use any combination of type casters, bindings and wrappers in a single function. Using type casters for C++ library types, and (user-written) bindings for other (custom) types is the general advice. Wrappers are used rarely, when use of the other options is not practical (or possible).

*All text and program code &copy;2026 Richard Spencer, all rights reserved.*