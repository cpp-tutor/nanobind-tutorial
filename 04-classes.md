# Classes

In this notebook we will explain how to create class definitions in C++ that are accessible to Python. The official **nanobind** documentation goes into a much greater amount of detail than that covered here, really we are just scratching the surface of what can be achieved.

## Class hierarchy

Consider C++ classes `Dog` and `Cat` inheriting from `Pet`, being accessible as a class hierarchy from Python. The C++ code to make this happen is:

```cpp
// test8.cpp
#include <string>
#include <nanobind/stl/string.h>

namespace nb = nanobind;

struct Pet {
    std::string name;
};

struct Dog : Pet {
    std::string bark() const { return name + ": woof!"; }
};

struct Cat : Pet {
    std::string mew() const { return name + ": miaow!"; }
};

NB_MODULE(test8, m) {
    nb::class_<Pet>(m, "Pet")
        .def(nb::init<const std::string &>())
        .def_rw("name", &Pet::name);

    nb::class_<Dog, Pet /* <- C++ parent type */>(m, "Dog")
        .def(nb::init<const std::string &>())
        .def("bark", &Dog::bark);

    nb::class_<Cat, Pet /* <- C++ parent type */>(m, "Cat")
        .def(nb::init<const std::string &>())
        .def("mew", &Cat::mew);
}
```

To build this code, run CMake again with `--target test8`:

```bash
cmake --build build --target test8
```

As always, ensure Python looks in the `build` sub-directory for loadable modules:

```python
import sys, os
module_dir = os.path.abspath('build')
if module_dir not in sys.path:
    sys.path.append(module_dir)
    print("Directory 'build' has been added to Python's module path")
```

Try out the classes using Python:

```python
import test8
dog = test8.Dog('Fido')
print(dog.bark())
cat = test8.Cat('Tickles')
print(cat.mew())
dog.name = 'Nicholas'
print(f"Renamed: {dog.name}")
print(dog.bark())
dog.mew() # Error
```

The final line fails because class `Dog` has no method `mew()`. Note that class `Pet` is *not* polymorphic (no virtual destructor), so while it can be instantiated (with a name) it cannot be invoked with methods `bark()` or `mew()`.

## Downcasting and overloading

A more involved class hierarchy could include a polymorphic base class and overriding of methods. Let's write this in C++:

```cpp
// test9.cpp
#include <string>
#include <nanobind/stl/string.h>

namespace nb = nanobind;

namespace test9 {

struct Pet {
    Pet(const std::string &name, int age) : name{ name }, age{ age } {}

    virtual std::string sound() const = 0;
    virtual ~Pet() = default;

    void set(int age_) { age = age_; }
    void set(const std::string &name_) { name = name_; }

    std::string name;
    int age;
};

struct Dog : Pet {
    Dog(const std::string &name, int age) : Pet(name, age) {}
    virtual std::string sound() const override { return name + ": woof!"; }
};

struct Cat : Pet {
    Cat(const std::string &name, int age) : Pet(name, age) {}
    virtual std::string sound() const override { return name + ": miaow!"; }
};

}

NB_MODULE(test9, m) {
    nb::class_<test9::Pet>(m, "Pet")
        .def("set", nb::overload_cast<int>(&test9::Pet::set), "Set the pet's age")
        .def("set", nb::overload_cast<const std::string &>(&test9::Pet::set), "Set the pet's name")
        .def("sound", &test9::Pet::sound, "Pet makes a sound")
        .def_ro("name", &test9::Pet::name, "Pet's name as a string")
        .def_ro("age", &test9::Pet::age, "Pet's age in years as an integer");

    nb::class_<test9::Dog, test9::Pet /* <- C++ parent type */>(m, "Dog")
        .def(nb::init<const std::string &, int>());

    nb::class_<test9::Cat, test9::Pet /* <- C++ parent type */>(m, "Cat")
        .def(nb::init<const std::string &, int>());

    m.def("pet_store", []() { return (test9::Pet *) new test9::Dog{ "Molly", 2 }; });
}
```

A lot of changes to make this class hierarchy correct for Python:

* Use of a new namespace `test9` to avoid clashes with previously defined `Pet`, `Dog`, and `Cat` classes
* Constructors for the newly virtual `Pet`, `Dog`, and `Cat` classes
* Bindings for member functions are only provided for `Pet` (other than there being no `init` function defined becuase it is pure virtual)
* C++/Python member function `set()` is overloaded for strings and integers
* C++/Python member function `sound()` is overridded by subclasses `Dog` and `Cat`
* The fields are read-only in Python, despite being `public:` in C++
* A `pet_store()` function returns a `Pet*` (whose lifetime is managed by Python) which is correctly downcast by Python to `Dog` when necessary

To build this code, run CMake again with `--target test9`:

```bash
cmake --build build --target test9
```

Try out our more realistic class hierarchy using:

```python
import test9
dog = test9.Dog('Fido', 1)
dog.set(5)
print(dog.sound())
print(f"{dog.name} is {dog.age} years old")
cat = test9.Cat('Macey', 9)
cat.set('Tickles')
print(cat.sound())
print(f"{cat.name} is {cat.age} years old")
new_pet = test9.pet_store()
print(type(new_pet))
dog.name = 'Nicholas'
```

The last line fails because the fields have been made read-only, while the type of `new_pet` is correctly displayed as `Dog`, not `Pet`. You should be aware that virtual function calls originating from C++ won't be propagated to Python&mdash;for this to happen a "trampoline class" must be included as part of the hierarchy (see the documentation for details).

*All text and program code &copy;2026 Richard Spencer, all rights reserved.*