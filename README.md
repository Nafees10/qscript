# QScript

**this version is pre-release, only use this for testing**  
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

The code is thoroughly documented (a bit less documentation in compiler, but you probably wont touch that). Separate documentation can be found [here](https://qscript.dpldocs.info/).

### Building Demo

To be able to run basic scripts, you can build the demo using:  
`dub build -c=demo -b=release`  
This will create an executable named `demo` in the directory. To run a script through it, do:  
`./demo path/to/script`  
You can also use the demo build to see the generated byte code for your scripts using:  
`./demo "path/to/script" "output/bytecode/file/path"`

## Features

1. Syntax similar to D
2. Dynamic arrays
3. Very fast execution speed. QScript has a virtual machine for this purpose, no interpretation is done at run time.
4. Static typed. This eliminates a lot of errors.
5. Function overloading
6. References (similar to pointers, but simpler)

## TODO For Upcoming Versions

1. Add `cast(Type)`, and add more types like `byte`, `char`..
1. Add structs, and `new` keyword to be used with references - Yet to do (planned for sometime later in 0.8.x, or maybe even 0.7.x if I figure it out early)
1. Add library support using `import` keyword - Planned for 0.8.0

---

## Example Scripts

These scripts can be run through the demo configuration.

### Hello World

```
function void main(){
	writeln ("Hello World!");
}
```

### Array & For loop

```
function void main{
	int[] array = [1, 2, 3, 4];
	for (int i = 0; i < length(array); i = i + 1;){
		writeln (toStr(array[i]));
	}
}
```
