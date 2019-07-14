# QScript Byte-Code:
This document contains the spec for the byte code used in QScript
## Function Map:
At the beginning of the byte code, there must be a "function map", which maps function IDs to the function names, and its argument types. The return type is not included in this, and only script defined functions are included in this map. It's format is:
```
functions: # comments are valid in any part of the byte code, even here
	main/101/210/ # 0 is function named main that accepts arg0 as array of string, and arg1
	# as a ref to int
	fillRand/111/ # 1 is function named fillRand. Accepts arg0 as ref to array of string.
	fillRand/211/ # 2 is overload of fillRand. Accepts arg0 as ref to array of int.
```
These function names ( like `main/101/210/` ) are encoded using `qscript.compiler.misc.encodeFunctionName();`  
And decoded using `qscript.compiler.misc.decodeFunctionName();`.
## Function Definitions:
```
FunctionID
stack:
	[stack element#0]
	[stack element#1]
	[stack element#2]
	...
instructions:
	[instruction] [argument1] [argument2] [...]
	[instruction] [argument1] [argument2] [...]
	...
AnotherFunctionID
stack:
	[stack element#0]
	[stack element#1]
	...
instructions:
	[instruction] [argument1] [argument2] [...]
	[instruction] [argument1] [argument2] [...]
	...
```

## Comments:
Comments can be added in the byte code. They are written like:  
```
FunctionID
stack:
	[stack element] # comment
	# another comment
instructions:
	[instruction] [arguments] # comment
	# another comment
```

## Stack elements:
The stack elements are written in this format:

1. string:		`s"%STRING%"`
2. double:		`d%DOUBLE%`
3. integer:		`i%INTEGER%`
4. array:		`[%ELEMENT%,%ELEMENT%]` - ELEMENT is either string, double, integer, or static array, each element must be of the same data type
5. empty:		`0` - This should be used to leave an element in the stack empty.
6. null:			`null` - Any data written to this element will be ignored.
7. reference:	`@%index%` - This means the value of this element is always equal to the value of another element.  

Number 1-4 are also used for arguments for instructions.

## How instructions read/write from/to stack:
Some terms that will be used here:

* `peek index` or just `peek` is the index of the element on stack that will be read or written to
* `stack` is what its name is, a stack. Every function **call** gets its own stack, and the values of all the elements are what are defined in the "`stack:`" section of a function definition. It's a fixed length stack, and doesn't work by push and pop, but by read-at-index and write-at-index. The variables are also stored on this.
* `stack-length` is the number of elements defined in the "`stack:`" section of a function declaration.

And this is how a script-defined function call works under the hood:

1. A new stack empty is created, with length=`number-of-vars-declared + stack-length`.
2. Assuming it has 5 variables declared, `stack[0 .. 5]` (first 5 elements) will be for the variables. A variable's ID (can be seen in `VariableNode` in `AST`) will be its index on the stack.
3. The rest of the stack is filled with the stack's elements defined in the "`stack:`" section.
4. the `peek index` is set to the index after the last variable, so it's at the first element in the "`stack:`" section.
5. The first instruction is executed, and here begins the execution loop.

And this is how instructions are executed & how they access the stack:

1. The data that an instruction needs from stack is read using `stack[peek index .. peek index +n]` where `n` is the number of elements it wants to read.
2. The `peek index` is increased by `n`.
3. If the instruction needs to write back to the stack, it is written at `stack[peek index .. peek index + n]`. Here, `n` is number of elements to write, because an instruction can write more than one element.
4. The `peek index` is again increased by `n`.
5. Repeat for the next instruction.

## Instructions:
** TODO figure out what instructions should be removed/added/modified**
### Executing functions:
* execFuncS 	- executes a script-defined function, arg0 is function id (int), arg1 is number (int) of arguments to pop from stack for the function. Writes return value to stack.
* execFuncE		- executes an external function, arg0 is function id (int), arg1 is number (int) of arguments to pop from stack for the function. Writes return value to stack.

### Operators:
* addInt			- adds two integers
* addDouble			- adds two doubles
* subtractInt		- subtracts two integers
* subtractDouble	- subtracts two doubles
* multiplyInt		- multiplies two integers
* multiplyDouble	- multiplies two doubles
* divideInt			- divides two integers
* divideDouble		- divides two doubles
* modInt			- remainder of division of two integers
* modDouble			- remainder of division of two doubles
* concatArray		- concatenates two arrays
* concatString		- concatenates two strings

### Comparision Operators:
* isSameInt		- writes 1(int) if two integers on stack are same
* isSameDouble	- writes 1(int) if two doubles on stack are same
* isSameString	- writes 1(int) if two strings on stack are same
* isLesserInt	- writes 1(int) if first element(int) on stack is less than second(int)
* isLesserDouble - writes 1(int) if first element(double) on stack is less than second(double)
* isGreaterInt	- writes 1(int) if first element(int) on stack is greater than second(int)
* isGreaterDouble - writes 1(int) if first element(double) on stack is greater than second(double)
* not			- if element(int) on stack == 1, writes 1(int), else, 0(int)
* and			- if 2 elements on stack (int) == 1, writes 1(int), else writes 0(int)
* or			- if either of 2 elements on stack == 1 (int), writes 1(int), else writes 0(int)

### Modifying stack:
* write		 	- writes data (read from stack) to an index on stack. Index is arg0 (int).
* writeRef		- writes data (read from stack) to another element whose reference is read from stack. Reference is read first, then the data.
* getRefArray	- writes reference to `var[index0][index1][...]` where the var is arg0 (int). number of indexes is specified in arg1 (int). The indexes are read from stack.
* getRefRefArray - writes reference to `@var[index0][index1][...]` where the ref-to-array is first read from stack. Number of indexes specified in arg0(int). Indxes are read from stack.
* peek			- sets peek index to arg0(int)

### Misc.:
* jump			- jumps to instruction at index arg0(int). sets peek to arg1(int)
* doIf			- only execute the next instrcution if element on stack == 1 (int)
* return 		- sets the element read from stack as the return value, and breaks execution of the function

### Arrays
* setLen		- modifies length of an array. First element read is ref to array, second is new length(int).
* getLen		- writes length of array. First element read is array.
* readElement	- writes the element at index of an array. Array is read first, then index.
* modifyArray	- pops an array, and a newVal from stack. Then pops `n` nodes from stack, where n is specfied by arg0(int). 
Then does something like: `array[popped0][popped1].. = newVal` and pushes the array
* makeArray		- arg0(int) is count. pops `count` number of elements/nodes from stack, puts them in an array, pushes the array to stack

### Strings
* strLen		- writes length of string. First element read is string.
* readChar		- writes the char at an index of string. First string is read, then index.

### Converting between data types
* strToInt		- reads an integer from a string.
* strToDouble	- reads a double from a string.
* intToStr		- writes a string containing the integer's string representation.
* intToDouble	- writes a double with the same value as an integer.
* doubleToStr	- writes a string containing the double's string representation.
* doubleToInt	- writes an integer with the same value as the integer part of a double.
