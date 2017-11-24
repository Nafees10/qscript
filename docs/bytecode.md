## Byte code format:  
### Function Definitions:  
```
FunctionName
	[instruction] [argument1] [argument2] [...]
	[instruction] [argument1] [argument2] [...]
	...
AnotherFunctionName
	[instruction] [argument1] [argument2] [...]
	[instruction] [argument1] [argument2] [...]
	...
```
  
### Comments:
Comments can be added in the byte code. They are written like:  
```
FunctionName
	... # comment
	...
	# comment
```
  
### Jumps:
The `jump` instruction can be used to jump to a different instruction, provided that the "jump point" is in the same function.  
Jump point will be marked as:  
```
FunctionName
	instruction0
	jump someJumpPosition
	instruciton2
	someJumpPosition:
	instruction3
```  
the instructions will be executed in this order:  
```
instruction0
jump
instruction4
```
  
### List of instructions:
#### Instructions for executing functions:
* execFuncS 	- executes a script-defined function, arg0 is function name (string), arg1 is number (int) of arguments to pop from stack for the function. 
Result is pushed to stack
* execFuncE		- executes an external function, arg0 is function name (string), arg1 is number (int) of arguments to pop from stack for the function. 
Result is pushed to stack

#### Instructions for handling variables:
* varCount		- changes the max number of vars available
* getVar		- pushes value of a variable to stack, arg0 is ID (int, >0) of the var
* setVar		- sets value of a var of the last value pushed to stack, arg0 is ID (int, >0) of the var

#### Instructions for mathematical operators:
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

#### Instructions for comparing 2 vals:
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

#### Misc. instructions:
* push 			- pushes all arguments to stack
* clear 		- clears the stack, pops all elements
* pop			- clears a number of elements from the stack, the number is arg0 (integer)
* jump			- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: "%someString%:" 
and arg0 of jump should be that %someString% (string), without any spaces or quotation marks.
* skipTrue		- skips the next instrcution if the last element on stack == 1 (int)
* return 		- sets the last value pushed to stack as the return value, and breaks execution of the function

#### Instructions for arrays
* setLen		- modifies length of an array, the array-to-modify, and new-length are pop-ed from stack, new array is pushed
* getLen		- pops array from stack, pushes the length (integer) of the array
* readElement	- pops an array, and element-index(int), pushes that element to the stack
* modifyArray	- pops an array, and a newVal from stack. Then pops `n` nodes from stack, where n is specfied by arg0(int). 
Then does something like: `array[poped0][poped1].. = newVal` and pushes the array
* makeArray		- arg0(int) is count. pops `count` number of elements/nodes from stack, puts them in an array, pushes the array to stack
* emptyArray	- makes an empty n-dimensional array, where n is arg0 (int)

#### Instructions for strings
* strLen		- pops a string from stack, pushes it's length
* readChar		- pops a string, and index(int) from stack. Pushed the char at that index in the string

#### Instructions for converting between data types
* strToInt		- pops a string from stack, uses `to!int` or `to!long` to convert to int, pushes the int
* strToDouble	- pops a string from stack, uses `to!double` to convert to double, pushes the double
* intToStr		- pops an int from stack, pushes a string containing the int
* intToDouble	- pops an int from string, pushes a double with the same value as the int
* doubleToStr	- pops a double from stack, pushes a string containing the double
* doubleToInt	- pops a double from stack, pushes an int, with the same value, ignoring the decimals, to stack.

---

### Format for instruciton arguments: 
These do not apply to the jump instruction. The jump instruction has just one argument, the name of the "jump point", without any quotation marks.
* string:		`s"%STRING%"`
* double:		`d%DOUBLE%`
* integer:		`i%INTEGER%`
* static array:	`[%ELEMENT%,%ELEMENT%]` - ELEMENT is either string, double, integer, or static array, each element must be of the same data type
