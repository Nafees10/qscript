# QScript Byte-Code:
This document contains the spec for the byte code used in QScript
## Function Definitions:
```
FunctionName
stack:
	[stack element#0]
	[stack element#1]
	[stack element#2]
	...
instructions:
	[instruction] [argument1] [argument2] [...]
	[instruction] [argument1] [argument2] [...]
	...
AnotherFunctionName
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
FunctionName
stack:
	[stack element] # comment
	# another comment
instructions:
	[instruction] [arguments] # comment
	# another comment
```

## Literal Data:
All the literals (numbers/strings which are known at compile time) are written in this format:

* string:	`s"%STRING%"`
* double:	`d%DOUBLE%`
* integer:	`i%INTEGER%`
* array:	`[%ELEMENT%,%ELEMENT%]` - ELEMENT is either string, double, integer, or static array, each element must be of the same data type
* empty:	`0` - This should be used to leave an element in the stack empty.

## Jumps:
The `jump` instruction can be used to jump to a different instruction, provided that the "jump point" is in the same function.  
Jump point will be marked as:  
```
FunctionName
stack:
	[stack element#0]
	...
instructions:
	instruction0
	jump someJumpPosition
	instruction2
	someJumpPosition:
	instruction3
```  
the instructions will be executed in this order:  
```
instruction0
jump
instruction3
```

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

# TODO figure out what instructions should be removed/added/modified
## Instructions:
### Instructions for executing functions:
* execFuncS 	- executes a script-defined function, arg0 is function name (string), arg1 is number (int) of arguments to pop from stack for the function. 
Result is pushed to stack
* execFuncE		- executes an external function, arg0 is function name (string), arg1 is number (int) of arguments to pop from stack for the function. 
Result is pushed to stack

### Instructions for handling variables:
* varCount		- changes the max number of vars available
* getVar		- pushes value of a variable to stack, arg0 is ID (int, >=0) of the var
* setVar		- sets value of a var of the last value pushed to stack, arg0 is ID (int, >=0) of the var

### Instructions for mathematical operators:
* addInt		- adds last two integers pushed to stack, pushes the result to stack
* addDouble		- adds last two doubles pushed to stack, pushes the result to stack
* subtractInt	- subtracts last two integers pushed to stack, pushes the result to stack
* subtractDouble- subtracts last two doubles pushed to stack, pushes the result to stack
* multiplyInt	- multiplies last two integers pushed to stack, pushes the result to stack
* multiplyDouble- multiplies last two doubles pushed to stack, pushes the result to stack
* divideInt		- adds last two integers pushed to stack, pushes the result to stack
* divideDouble	- adds last two doubles pushed to stack, pushes the result to stack
* modInt		- divides last two integers pushed to stack, pushes the remainder to stack
* modDouble		- divides last two doubles pushed to stack, pushes the remainder to stack
* concatArray	- concatenates last two arrays pushed to stack, pushes the result to stack
* concatString	- concatenates last two strings pushed to stack, pushes the result to stack

### Instructions for comparing 2 vals:
* isSameInt		- pops 2 values, if both are same, pushes 1(int) to stack, else, pushes 0(int)
* isSameDouble	- pops 2 values, if both are same, pushes 1(int) to stack, else, pushes 0(int)
* isSameString	- pops 2 values, if both are same, pushes 1(int) to stack, else, pushes 0(int)
* isLesserInt	- pops 2 values(int), if first value is less, pushes 1(int) to stack, else, pushes 0(int)
* isLesserDouble- pops 2 values(int), if first value is less, pushes 1(int) to stack, else, pushes 0(int)
* isGreaterInt	- pops 2 values(int), if first value is larger, pushes 1(int) to stack, else, pushes 0(int)
* isGreaterDouble- pops 2 values(int), if first value is larger, pushes 1(int) to stack, else, pushes 0(int)
* not			- if last element pushed == 1(int), then pushes 0(int), else, pushes 1(int)
* and			- if last 2 elements on stack (int) == 1, pushes 1, else pushes 0
* or			- if either of last 2 elements on stack == 1 (int), pushes 1, else pushes 0

### Misc. instructions:
* push 			- pushes all arguments to stack
* clear 		- clears the stack, pops all elements
* pop			- clears a number of elements from the stack, the number is arg0 (integer)
* jump			- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: "%someString%:" 
and arg0 of jump should be that %someString% (string), without any spaces or quotation marks.
* skipTrue		- skips the next instrcution if the last element on stack == 1 (int)
* return 		- sets the last value pushed to stack as the return value, and breaks execution of the function

### Instructions for arrays
* setLen		- modifies length of an array, the array-to-modify, and new-length are pop-ed from stack, new array is pushed
* getLen		- pops array from stack, pushes the length (integer) of the array
* readElement	- pops an array, and element-index(int), pushes that element to the stack
* modifyArray	- pops an array, and a newVal from stack. Then pops `n` nodes from stack, where n is specfied by arg0(int). 
Then does something like: `array[popped0][popped1].. = newVal` and pushes the array
* makeArray		- arg0(int) is count. pops `count` number of elements/nodes from stack, puts them in an array, pushes the array to stack
* emptyArray	- makes an empty one-dimensional array

### Instructions for strings
* strLen		- pops a string from stack, pushes it's length (int)
* readChar		- pops a string, and index(int) from stack. Pushed the char at that index in the string

### Instructions for converting between data types
* strToInt		- pops a string from stack, uses `to!int` or `to!long` to convert to int, pushes the int
* strToDouble	- pops a string from stack, uses `to!double` to convert to double, pushes the double
* intToStr		- pops an int from stack, pushes a string containing the int
* intToDouble	- pops an int from string, pushes a double with the same value as the int
* doubleToStr	- pops a double from stack, pushes a string containing the double
* doubleToInt	- pops a double from stack, pushes an int, with the same value, ignoring the decimals, to stack.
