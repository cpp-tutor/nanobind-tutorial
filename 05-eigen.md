# Interfacing with the Eigen Library

In this notebook we will cover how to convert types used by the Eigen C++ Linear Algebra library between Python and C++. The only prerequisite for using this notebook is to complete all of the steps in the first, including downloading and installing the Eigen library.

To load the modules (written using C++ and **nanobind**) from the build directory, the following code must be run each time the kernel is restarted:

```python
import sys, os
module_dir = os.path.abspath('build')
if module_dir not in sys.path:
    sys.path.append(module_dir)
    print("Directory 'build' has been added to Python's module path")
```

## nb::ndarray class

Key to interfacing with Eigen (and other libraries such as NumPy, PyTorch, TensorFlow, JAX, and CuPy) is the `ndarray` type which is part of **nanobind** (in header `<nanobind/ndarray.h>`). This type is mapped to various other n-dimensional array types using pre-defined (custom) **bindings**, as explained in a previous notebook.

To gain an idea of the capabilities of this type (compared to NumPy's `np.array`), execute the following code:

```cpp
// eigen1.cpp
#include <nanobind/ndarray.h>

namespace nb = nanobind;

NB_MODULE(eigen1, m) {
    m.def("inspect", [](const nb::ndarray<>& a) {
        nb::print(nb::str("Array data pointer : {}").format(a.data()));
        nb::print(nb::str("Array dimension : {}").format(a.ndim()));
        for (size_t i = 0; i < a.ndim(); ++i) {
            nb::print(nb::str("Array dimension {} : {}").format(i, a.shape(i)));
            nb::print(nb::str("Array stride    {} : {}").format(i, a.stride(i)));
        }
        nb::print(nb::str("Device ID = {} (cpu={}, cuda={})").format(a.device_id(),
            int(a.device_type() == nb::device::cpu::value),
            int(a.device_type() == nb::device::cuda::value)
        ));
        nb::print(nb::str("Array dtype: int16={}, uint32={}, float32={}").format(
            a.dtype() == nb::dtype<int16_t>(),
            a.dtype() == nb::dtype<uint32_t>(),
            a.dtype() == nb::dtype<float>()
        ));
    });
}
```

As always, build the relevant target with CMake:

```bash
cmake --build build --target eigen1
```

And try it out in Python:

```python
import numpy as np
import eigen1

eigen1.inspect(np.array([[1,2,3], [3,4,5]], dtype=np.float32))
```

Comparing the output with the definition of the function `inspect()` previously will give a good idea of the purpose of `nb::ndarray`. See the documentation for further details on how to create `np.array`s (and other Python libraries' types) objects from C++, and how to specify shape, strides etc. dynamically.

## Vector operations with Eigen

Use of the Eigen library with **nanobind** can be thought of as a specialization of using the `nb::ndarray` class. The header `<nanobind/eigen/dense.h>` provides for conversions between Python and C++ (both ways) for types: `Eigen::Matrix`, `Eigen::Array`, `Eigen::Vector`, `Eigen::Ref`, `Eigen::Map`.

If a C++ function returns one of these types *by value*, **nanobind** will capture and wrap it in a NumPy array without making a copy. All other cases (returning by reference, returning an unevaluated expression template) either evaluate or copy the array.

If a C++ function accepts *by reference*, **nanobind** will still need to make a copy. To prevent this, use should be made of `nb::DRef` which makes the source data directly available to C++.

The following code is bad form for several reasons:

```plaintext
m.def("sum", [](Eigen::Vector3f a, Eigen::Vector3d b) { return a + b; }); // Bad!
```

Firstly, `a` and `b` are accepted by value (although see previous discussion of why by reference would be no better). Secondly, C++ would attempt to return the **unevaluated expression template** of `a + b` instead of a new `Eigen::Vector`. Thus the following should be used instead:

```cpp
// eigen2.cpp
#include <nanobind/eigen/dense.h>

namespace nb = nanobind;

Eigen::Vector3f sum(const nb::DRef<Eigen::Vector3f> &a, const nb::DRef<Eigen::Vector3f> &b) {
    return a + b; // no need for (a + b).eval() as return type is specified
}

NB_MODULE(eigen2, m) {
    m.def("sum", &sum);
}
```

Build the same target with CMake:

```bash
cmake --build build --target eigen2
```

Try it out in Python:

```python
import numpy as np
import eigen2

print(eigen2.sum(np.array([1., 2., 3.], dtype='float32'), np.array([2., 3., 4.], dtype='float32')))
```

If you get into difficulties with types, recall that by value implies possible type conversion. Use code such as `nb::arg("x").noconvert()` to avoid this.

## Matrix operations with Eigen

For a more complete treatment of Eigen's types we can extend the available functions with matrix types and operations such as `addV`, `mulM` etc., defining all Python symbols with C++ lambda functions:

```cpp
// eigen3.cpp
#include <nanobind/eigen/dense.h>
#include <Eigen/LU>

namespace nb = nanobind;
using dtype = double;
using Vector = Eigen::VectorXd;
using Matrix = Eigen::MatrixXd;

NB_MODULE(eigen3, m) {
    m.def("addV", [](const nb::DRef<Vector> &a, const nb::DRef<Vector> &b) -> Vector { return a + b; });
    m.def("addM", [](const nb::DRef<Matrix> &a, const nb::DRef<Matrix> &b) -> Matrix { return a + b; });
    m.def("subV", [](const nb::DRef<Vector> &a, const nb::DRef<Vector> &b) -> Vector { return a + b; });
    m.def("subM", [](const nb::DRef<Matrix> &a, const nb::DRef<Matrix> &b) -> Matrix { return a + b; });
    m.def("inner", [](const nb::DRef<Vector> &a, const nb::DRef<Vector> &b) -> dtype { return a.dot(b); });
    m.def("cross", [](const nb::DRef<Vector> &a, const nb::DRef<Vector> &b) -> Vector { return a * b; });
    m.def("mulM", [](const nb::DRef<Matrix> &a, const nb::DRef<Matrix> &b) -> Matrix { return a * b; });
    m.def("mulMV", [](const nb::DRef<Matrix> &a, const nb::DRef<Vector> &b) -> Matrix { return a * b; });
    m.def("det", [](const nb::DRef<Matrix> &a) -> dtype { return a.determinant(); });
    m.def("inv", [](const nb::DRef<Matrix> &a) -> Matrix { return a.inverse(); });
}
```

Build the right target with CMake:

```bash
cmake --build build --target eigen3
```

Try it out again in Python:

```python
import numpy as np
import eigen3

vector1 = np.array([1., 2., 3.])
vector2 = np.array([2., 3., 4.])
matrix1 = np.array([[1., 2., 3.], [4., 5., 6]])
matrix2 = np.array([[2., 3., 4.], [5., 6., 7]])

print(eigen3.addV(vector1, vector2))
print(eigen3.addM(matrix1, matrix2))
print(eigen3.subV(vector1, vector2))
print(eigen3.subM(matrix1, matrix2))
print(eigen3.mulM(matrix1, matrix2))
print(eigen3.mulMV(matrix1, vector1))
print(eigen3.inner(vector1, vector2))
print(eigen3.cross(vector1, vector2))
print(eigen3.det(matrix1))
print(eigen3.inv(matrix2))
```

The header `<nanobind/eigen/sparse.h>` maps the types `Eigen::SparseMatrix<..>` and `Eigen::Map<Eigen::SparseMatrix<..>>` either `scipy.sparse.csr_matrix` (row-major stprage) or `scipy.sparse.csc_matrix` (column-major storage), via custom bindings.

*All text and program code &copy;2026 Richard Spencer, all rights reserved.*