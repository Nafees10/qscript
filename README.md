# QScript

A fast, static typed, scripting language, with a syntax similar to D Language.

## Setting it up

To add QScript to your dub package or project, run this in your dub package's directory:

```bash
dub add qscript
```

After adding that, look at the `source/demo.d` to see how to use the `QScript` class to execute scripts.

---

## Getting Started

To get started on using QScript, see the following documents:

* `spec/syntax.md` - Contains the specification for QScript's syntax.
* `spec/functions.md`- Contains a list of predefined QScript functions.
* `source/demo.d`- A demo usage of QScript in D langauage. Shows how to add new functions
* `examples/` - Contains some scripts showing how to write scripts.

The code is thoroughly documented. Separate documentation can be found [here](https://qscript.dpldocs.info/).

### Building Demo

To be able to run basic scripts, you can build the demo using:  

`dub build -c=qsDemo -b=release`  

This will create an executable named `demo` in the directory. To run a script through it, do:  

`./demo path/to/script`  

You can also use the demo build to see the generated NaVM byte code for your scripts using:  

`./demo "path/to/script" "output/bytecode/file/path"`

## Features

1. Simple syntax
1. Dynamic arrays
1. Fast execution
1. Static typed
1. Function overloading
1. References

## TODO For Upcoming Versions

**Coming in next version:**

1. Structs
1. Enums
1. Global Variables
1. Scripts as libraries for other scripts

**Planned for sometime later:**

1. bitshift operators
1. More data types

---

## Hello World

This is how a hello world would look like in QScript. For more examples, see `examples/`.  

```
function void main(){
	writeln ("Hello World!");
}
```

_writeln is not included in QScript, programs that use QScript are to provide their own functions, QScript only provides the very basic functions. However, writeln is provided in the demo program so any example scripts can be run using that_
