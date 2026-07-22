# QScript

A Simple Scripting Language.

**This version is currently under development, and has several bugs, use [v0.7.4](https://github.com/Nafees10/qscript/tree/v0.7.4)**

## Setting it up

To add QScript to your dub package or project, run this in your dub package's directory:

```bash
dub add qscript
```

After adding that, look at the `source/demo.d` to see how to use the `QScript` class to execute scripts.

---

## Getting Started

To get started on using QScript, see the following documents:

* `spec/architecture.md` - How qscript works under the hood. Don't bother if you wont be using advanced stuff.
* `spec/libraries.md` - Built in QScript libraries. `// TODO write this`
* `spec/syntax.md` - describes QScript's syntax and more.
* `source/standalone.d`- A demo usage of QScript in D langauage.
* `examples/` - Contains some scripts showing how to write scripts.

The code is thoroughly documented. Separate documentation can be found [here](https://qscript.dpldocs.info/).

### Building
QScript comes with a standalone configuration, so it can be used without being first integrated into some program as a library.  
You can build it using:

```bash
dub build qscript -c=standalone -b=release
```
You can use this executable to run scripts, inspect the generated AST for script, or the generated NaVM bytecode:
```bash
./qscript /path/to/script # execute a script

./qscript --ast /path/to/script # pretty print AST for script

./qscript --bcode /path/to/script # print NaVM bytecode for script
```
## Features

1. Dynamic arrays
1. Static typed
1. Function overloading
1. References (pointers, but a bit simplified)
1. Structs
1. Enums
1. Global Variables
1. Importing libraries (script can be loaded as library too)
---

## Hello World

This is how a hello world would look like in QScript. For more examples, see `examples/`.  

```
import qscript_stdio;

function void main(){
	writeln ("Hello World!");
}
```