module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.conv : to;

/// contains functions to generate byte code from AST
public struct CodeGen{

	/// stores a list of available vars, linked list, because we only need to check if a var exists or not, so linked is better
	LinkedList!string varsList = null;


	/// generates byte code for an ASTNdode
	/// 
	/// `node` is the node to generate AST for
	/// `pushToStack` is to specify whether the result should be pushed to stack or not, this only works for node with type==FunctionCall
	/// TODO add calls to other functions
	public string[] generateByteCode(ASTNode node, bool pushToStack = true){
		// check the type, call the function
		if (node.type == ASTNode.Type.Assign){

		}else if (node.type == ASTNode.Type.Block){
			return generateBlockByteCode(node);
		}else if (node.type == ASTNode.Type.Function){
			return generateFunctionByteCode(node);
		}else if (node.type == ASTNode.Type.FunctionCall){
			return generateFunctionCallByteCode(node, pushToStack);
		}else if (node.type == ASTNode.Type.IfStatement){

		}else if (node.type == ASTNode.Type.WhileStatement){

		}else if (node.type == ASTNode.Type.Operator){

		}else if (node.type == ASTNode.Type.Script){
			return generateScriptByteCode(node);
		}else if (node.type == ASTNode.Type.VarDeclare){
			return generateVarDeclareByteCode(node);
		}else if (node.type == ASTNode.Type.NumberLiteral){
			return generateLiteralByteCode(node);
		}else if (node.type == ASTNode.Type.StringLiteral){
			return generateLiteralByteCode(node);
		}else if (node.type == ASTNode.Type.StaticArray){

		}else if (node.type == ASTNode.Type.Variable){
			return generateVariableByteCode(node);
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

	/// generates byte code for a function call
	private string[] generateFunctionCallByteCode(ASTNode fCall, bool pushResult = true){
		// first push the arguments to the stack, last arg first pushed
		uinteger argsIndex = fCall.readSubNode(ASTNode.Type.Arguments);
		ASTNode args;
		LinkedList!string byteCode = new LinkedList!string;
		if (argsIndex > 0){
			args = fCall.subNodes[argsIndex];
			uinteger argCount = 0;
			argCount = args.subNodes.length;
			// now start pushing them
			foreach_reverse(arg; args.subNodes){
				generateByteCode(arg);
			}
			/// now exec this function
			byteCode.append("\t"~(pushResult ? "execFuncP" : "execFuncI")~" "~fCall.data~" "~to!string(argCount));
		}else{
			compileErrors.append(CompileError(fCall.lineno, "function call has no arguments"));
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for a string/number literal
	private string[] generateLiteralByteCode(ASTNode literal){
		/// returns true if a number in a string is a double or int
		bool isDouble(string s){
			foreach (c; s){
				if (c == '.'){
					return true;
				}
			}
			return false;
		}
		if (literal.type == ASTNode.Type.NumberLiteral){
			if (isDouble(literal.data)){
				return ["\tpush d"~literal.data];
			}else{
				return ["\tpush i"~literal.data];
			}
		}else{
			return ["\tpush s\""~literal.data~'"'];
		}
	}

	/// generates byte code for a var
	private string[] generateVariableByteCode(ASTNode var){
		// make sure it's a var
		if (var.type == ASTNode.Type.Variable){
			// ok, push the var, deal with the indexes later (if any)
			string[] r = ["\tgetVar "~var.data];
			// now if there's indexes, add them
			if (var.subNodes.length > 0){
				LinkedList!string indexes = new LinkedList!string;
				foreach (index; var.subNodes){
					indexes.append(generateByteCode(index));
					indexes.append("\treadElement");
				}
				r ~= indexes.toArray;
			}
			return r;
		}else{
			compileErrors.append(CompileError(var.lineno, "not a variable"));
			return [];
		}
	}

	/// generates byte code for a varDeclare
	private string[] generateVarDeclareByteCode(ASTNode varDeclare){
		// make sure it is a varDeclare
		if (varDeclare.type == ASTNode.Type.VarDeclare){
			// make sure there are vars
			if (varDeclare.subNodes.length > 0){
				// make sure all subNodes are vars, and generate the instruction
				string r = "\tinitVar";
				foreach (var; varDeclare.subNodes){
					r ~= " s\""~var.data~'"';
				}
				return [r];
			}else{
				compileErrors.append(CompileError(varDeclare.lineno, "no variables declared in var()"));
				return [];
			}
		}else{
			compileErrors.append(CompileError(varDeclare.lineno, "not a variable declaration"));
			return [];
		}
	}

	/// generates byte code for an if statement
	private string[] generateIfByteCode(ASTNode ifStatement){
		// make sure it's an if statement
		if (ifStatement.type == ASTNode.Type.IfStatement){
			static uinteger ifCount = 0;
			// first, push the 
		}
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
	push s" World" s"Hello"
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
	push i2
	getVar s"i"
	execFuncP s"isEqual" i2
	skipTrue i1
	jump s"if0end"
	getVar s"i"
	execFuncI s"writeln" i1
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
	initVar s"i"
	while0start:
	push i2
	getVar s"i"
	execFuncP s"isLesser" i2
	skipTrue i1
	jump s"while0end"
	getVar s"i"
	execFuncI s"writeln" i1
	jump s"while0start"
	while0end:
```  
  
### List of instructions:
#### Instructions for executing functions:
* execFuncI 	- executes a function, arg0 is function name (string), arg1 is number (uint) of arguments to pop from stack for the function. ignores the return value of the function.
* execFuncP		- same as execFuncI, except, the return value is pushed to stack

#### Instructions for handling variables:
* initVar		- to declare vars, each argument is a var name as string
* getVar		- pushes value of a variable to stack, arg0 is name (string) of the var
* setVar		- sets value of a var of the last value pushed to stack, arg0 is name (string) of the var

#### Instructions for mathematical operators:
* add			- adds last two inegers/doubles pushed to stack, pushes the result to stack
* subtract		- subtracts last two inegers/doubles pushed to stack, pushes the result to stack
* multiply		- multiplies last two inegers/doubles pushed to stack, pushes the result to stack
* divide		- divides last two inegers/doubles pushed to stack, pushes the result to stack
* mod			- divides last two inegers/doubles pushed to stack, pushes the remainder to stack
* concat		- concatenates last two arrays/strings pushed to stack, pushes the result to stack

#### Instructions for comparing 2 vals:
* isSame 		- pops 2 values, if both are same, pushes 1(int) to stack, else, pushes 0(int)
* isLesser 		- pops 2 values(int), if second value is less, pushes 1(int) to stack, else, pushes 0(int)
* isGreater		- pops 2 values(int), if second value is larger, pushes 1(int) to stack, else, pushes 0(int)
* isLesserSame	- pops 2 values(int), if second value is less or equal, pushes 1(int) to stack, else, pushes 0(int)
* isGreaterSame	- pops 2 values(int), if second value is larger or equal, pushes 1(int) to stack, else, pushes 0(int)
* isNotSame		- pops 2 values, if both are not same, pushes 1(int) to stack, else, pushes 0(int)

#### Misc. instructions:
* push 			- pushes all arguments to stack
* clear 		- clears the stack, pops all elements
* pop			- clears a number of elements from the stack, the number is arg0 (integer)
* jump			- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: "%someString%:" and arg0 of jump should be that %someString% (string).
* skipTrue		- pops a number of nodes (ints) from stack, the number is arg0(int). If each of them ==1, then the next instruction is skipped. This is used to construct if/while statements

#### Instructions for arrays
* setLen		- modifies length of an array, the array-to-modify, and new-length are pop-ed from stack, new array is pushed
* getLen		- pops array from stack, pushes the length (integer) of the array
* readElement	- pops an array from stack, and the element-index, pushes that element to the stack

---

### Format for arguments:  
string:			s"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENT%,%ELEMENT%] // ELEMENT is either string, double, integer, or static array
*/