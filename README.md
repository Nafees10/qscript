# QScript

A Simple Scripting Language.

**For last stable version, see v0.7.4**

**QScript is currently under active development, and being redesigned under a
new specification, see spec/syntax.md.**

## Setting it up

To add QScript to your dub package or project, run this in your dub package's
directory:

```bash
dub add qscript
```

Look at the `source/demo.d` to see how to use QScript

---

## Getting Started

To get started on using QScript, see the following documents:

* `spec/syntax.md` - language specification
* `examples/` - Contains some scripts showing how to write scripts. // TODO
	write these

### Building
QScript comes with a standalone configuration, so it can be used without being
first integrated into some program as a library.  
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

// Most of these are not yet implemented

1. Static typed
1. Dynamic arrays
1. Templates
1. Conditional Compilation
1. Compile Time Function Execution
1. First class Functions
1. Lambda Functions
1. Function overloading
1. Operator overloading
1. Reference Data Types
1. Structs
1. Enums

---

## Hello World

This is how a hello world would look like in QScript. For more examples, see
`examples/` // TODO write examples

```
load(stdio);

fn main(){
	writeln("Hello World!");
}
```
