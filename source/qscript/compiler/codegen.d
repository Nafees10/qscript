module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

/// contains functions to generate byte code from AST
public struct CodeGen{

	/// generates byte code for an ASTNdode
	/// TODO add calls to other functions
	public string[] generateByteCode(ASTNode node){
		// check the type, call the function
		if (node.type == ASTNode.Type.Assign){

		}else if (node.type == ASTNode.Type.Block){
			return generateBlockByteCode(node);
		}else if (node.type == ASTNode.Type.Function){
			return generateFunctionByteCode(node);
		}else if (node.type == ASTNode.Type.FunctionCall){

		}else if (node.type == ASTNode.Type.IfStatement){

		}else if (node.type == ASTNode.Type.WhileStatement){

		}else if (node.type == ASTNode.Type.Operator){

		}else if (node.type == ASTNode.Type.Script){
			return generateScriptByteCode(node);
		}else if (node.type == ASTNode.Type.VarDeclare){

		}else if (node.type == ASTNode.Type.NumberLiteral){

		}else if (node.type == ASTNode.Type.StringLiteral){

		}else if (node.type == ASTNode.Type.StaticArray){

		}else if (node.type == ASTNode.Type.Variable){

		}else{
			throw new Exception("generateByteCode called with unsupported ASTNode.Type");
		}
	}

	/// generates byte code for a script
	private string[] generateScriptByteCode(ASTNode scriptNode){
		LinkedList!string byteCode = new LinkedList!string;
		// go through all nodes/ functions, and generate byte-code for them
		foreach (functionNode; scriptNode.subNodes){
			// make sure its a function definition
			if (functionNode.type == ASTNode.Type.Function){
				// ok
				byteCode.append(generateFunctionByteCode(functionNode));
			}else{
				compileErrors.append(CompileError(functionNode.lineno, "not a function definition"));
			}
		}

		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for a function definition
	private string[] generateFunctionByteCode(ASTNode functionNode){
		LinkedList!string byteCode = new LinkedList!string;
		if (functionNode.type == ASTNode.Type.Function){
			// ok
			byteCode.append(functionNode.data); // start it with the function name

			ASTNode block;
			integer blockIndex = functionNode.readSubNode(ASTNode.Type.Block);
			if (blockIndex == -1){
				compileErrors.append(CompileError(functionNode.lineno, "function definition has no body"));
			}
			block = functionNode.subNodes[blockIndex];
			// now the statements
			byteCode.append(generateBlockByteCode(block));
		}else{
			compileErrors.append(CompileError(functionNode.lineno, "not a function definition"));
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for a block
	private string[] generateBlockByteCode(ASTNode block){
		// make sure it's a block
		LinkedList!string byteCode = new LinkedList!string;
		if (block.type == ASTNode.Type.Block){
			// ok
			foreach (statement; block.subNodes){
				// check if is a valid statement
				if ([ASTNode.Type.Assign, ASTNode.Type.Block, ASTNode.Type.FunctionCall,ASTNode.Type.IfStatement,
						ASTNode.Type.VarDeclare, ASTNode.Type.WhileStatement].hasElement(statement.type)){
					// type is ok
					byteCode.append(generateByteCode(statement));
				}else{
					compileErrors.append(CompileError(statement.lineno, "not a valid statement"));
				}
			}
		}else{
			compileErrors.append(CompileError(block.lineno, "not a block"));
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}
}




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
	initVar s"i"
	getVar s"i"
	push i2
	execFuncP s"isEqual"
	execFuncI s"if"
	jump s"if0end"
	getVar s"i"
	execFuncI s"writeln"
	if0end:
	endVar s"i"
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
	initVar s"i"
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
	endVar s"i"
```  
  
### List of instructions:
push 		- pushes all arguments to stack
clear 		- clears the stack, pops all elements
execFuncI 	- executes a function, arg0 is function name (string), arg1 is number (uint) of arguments to pop from
			stack for the function. ignores the return value of the function.
execFuncP	- same as execFuncI, except, the return value is pushed to stack
initVar		- to declare vars, each argument is a var name as string
endVar		- frees memory occupied by a var. All arguments are var names
getVar		- pushes value of a variable to stack, arg0 is name (string) of the var
setVar		- sets value of a var of the last value pushed to stack, arg0 is name (string) of the var
jump		- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: 
			"%someString%:" and arg0 of jump should be that %someString% (string).

### Format for arguments:  
string:			s"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENT%,%ELEMENT%] // ELEMENT is either string, double, integer, or static array
*/