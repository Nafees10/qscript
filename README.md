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

You can also use the demo build to see the generated NaVM byte code for your scripts using:  

`./demo "path/to/script" "output/bytecode/file/path"`

## Features

1. Simple syntax
1. Dynamic arrays
1. Fast execution
1. Static typed.
1. Function overloading
1. References

## TODO For Upcoming Versions

1. Add `cast(Type)`, and add more types like `byte`
1. Structs
1. Be able to load multiple scripts, to make it easier to separete scripts across files.

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

### Functions & Function Overloading
```
function void main{
	int[] array;
	int len = 10;
	length(@array, len);
	for (int i = 0; i < len; i = i + 1;)
		array[i] = i;
	write(array); # calls write(int[])
	write("Hello World"); # calls write(char[])
}
function void write(int[] array){
	for (int i = 0; i < length(array); i = i + 1;)
		writeln(toStr(array[i]));
}
function void write(char[] str){
	writeln(str); # just uses writeln(char[]) from demo config
}

```
