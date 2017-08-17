module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;

/*
## Byte code format:
as string:  
```
[instruction] [argument1] [argument2] [...]
```  
Each instruction can recieve a dynamic number of arguments  
  
### List of instructions:
push 		- pushes all arguments to stack, the format for each argument is defined below this list
clear 		- clears the stack, pops all elements
execFuncI 	- executes a function, arg0 is function name (string), arg1 is number (uint) of arguments to pop from
			stack for the function. ignores the return value of the function.
execFuncP	- same as execFuncI, except, the return value is pushed to stack
getVar		- pushes value of a variable to stack, arg0 is the ID (uint) representing the var
setVar		- sets value of a var of the last value pushed to stack, arg0 is the ID (uint) representing the var
setVarCount	- sets the max number of vars that will be used. The first instruction executed should be this one

Format for `push` arguments:
string:			"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENTS%] // ELEMENTS can contain another array, in this same format
*/