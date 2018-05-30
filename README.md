# QScript
A fast, static typed, scripting language, with a syntax similar to D Language.
## Setting it up
To add QScript to your dub package or project, add the following into dub.json dependencies:
```
"qscript": "~>0.6.1"
```
or if you have dub.sdl:
```
dependency "qscript" version="~>0.6.1"
```
After adding that, look at the `demos/demo.d` to see how to use the `QScript` class to execute scripts.

---

## Getting Started:
To get started on using QScript, see the following documents:
* `spec/syntax.md`		- Contains the specification for QScript's syntax.
* `spec/functions.md`	- Contains a list of predefined QScript functions.
* `demos/demo.d`		- A demo usage of QScript in D langauage. Shows how to add new functions, 
  
And for the documentation on the code, including QScript's compiler, it is stored in `docs/`.  
The spec for QScript's byte code is also available, in `spec/bytecode.md`, but knowing it is not necessary for using QScript.

## Features:
1. Syntax very similar to D
2. Dynamic arrays
3. Very fast execution speed. QScript has a virtual machine for this purpose, no interpretation is done at run time.
4. Static typed. This eliminates a lot of errors.

## Planned Features To Add:
1. Rewrite the AST generator (parser?) and byte code generator to avoid recursion.
1. `for`, `do while`, and `foreach` loops
2. Compile time optimizations, where the compiler executes some code at compile time, to make byte code more efficient
3. Basic support for classes and structs, will probably take lot of times

---

## Example scripts:
The following scripts are written assuming that the program, which is running QScript, provides the `writeln(string)` function, and starts execution from `main`.  
**Hello World:**
```
function void main(){
	writeln ("Hello World!");
}
```
**Arrays:**
```
function void main{
	int[] (array);
	array = array(1, 2, 3, 4);
	int (i, length);
	i = 0;
	length = getLength(array);
	while (i < length){
		writeln (intToStr(array[i]));
		i = i + 1;
	}
}
```
