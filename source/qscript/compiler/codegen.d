module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;




/*
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

### Function Calls:  
byte code for:  
```
function FunctionName{
	writeln("Hello", " World");
}
```  
will look like:  
```
FunctionName
	setVarCount i0
	push s"Hello" s"World"
	execFuncI s"writeln" i2
```  

### If statement
byte code for:  
```
function FunctionName{
	var (i);
	if (i == 2){
		writeln(i);
	}
}
```  
will look like:  
```
FunctionName
	setVarCount i1
	getVar s"i"
	push i2
	execFuncP s"isEqual"
	execFuncI s"if"
	jump s"if0end"
	getVar s"i"
	execFuncI s"writeln"
	if0end:
```  

### While statement
byte code for:  
```
function FunctionName{
	var (i);
	while (i < 2){
		writeln(i);
	}
}
```  
will look like:  
```
FunnctionName
	setVarCount i1
	while0start:
	getVar s"i"
	push i2
	execFuncP s"isLesser"
	execFuncI s"while"
	jump s"while0end"
	getVar s"i"
	execFuncI s"writeln"
	jump s"while0start"
	while0end:
```  
  
### List of instructions:
push 		- pushes all arguments to stack
clear 		- clears the stack, pops all elements
execFuncI 	- executes a function, arg0 is function name (string), arg1 is number (uint) of arguments to pop from
			stack for the function. ignores the return value of the function.
execFuncP	- same as execFuncI, except, the return value is pushed to stack
getVar		- pushes value of a variable to stack, arg0 is name (string) of the var
setVar		- sets value of a var of the last value pushed to stack, arg0 is name (string) of the var
setVarCount	- sets the max number of vars that will be used. The first instruction executed should be this one
jump		- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: 
			"%someString%:" and arg0 of jump should be that %someString% (string).

### Format for arguments:  
string:			s"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENT%,%ELEMENT%] // ELEMENT is either string, double, integer, or static array
*/