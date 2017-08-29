module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.conv : to;

/// contains functions to generate byte code from AST
public struct CodeGen{
	/// generates byte code for an ASTNdode
	/// 
	/// `node` is the node to generate AST for
	/// `pushToStack` is to specify whether the result should be pushed to stack or not, this only works for node with type==FunctionCall
	public string[] generateByteCode(ASTNode node, bool pushToStack = true){
		// check the type, call the function
		if (node.type == ASTNode.Type.Assign){
			return generateAssignmentByteCode(node);
		}else if (node.type == ASTNode.Type.Block){
			return generateBlockByteCode(node);
		}else if (node.type == ASTNode.Type.Function){
			return generateFunctionByteCode(node);
		}else if (node.type == ASTNode.Type.FunctionCall){
			return generateFunctionCallByteCode(node, pushToStack);
		}else if (node.type == ASTNode.Type.IfStatement){
			return generateIfByteCode(node);
		}else if (node.type == ASTNode.Type.WhileStatement){
			return generateWhileByteCode(node);
		}else if (node.type == ASTNode.Type.Operator){
			return generateOperatorByteCode(node);
		}else if (node.type == ASTNode.Type.Script){
			return generateScriptByteCode(node);
		}else if (node.type == ASTNode.Type.VarDeclare){
			return generateVarDeclareByteCode(node);
		}else if (node.type == ASTNode.Type.NumberLiteral){
			return generateLiteralByteCode(node);
		}else if (node.type == ASTNode.Type.StringLiteral){
			return generateLiteralByteCode(node);
		}else if (node.type == ASTNode.Type.StaticArray){
			return generateStaticArrayByteCode(node);
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
		ASTNode block;
		block = functionNode.subNodes[functionNode.readSubNode(ASTNode.Type.Block)];
		return [functionNode.data]~generateBlockByteCode(block);
	}

	/// generates byte code for a block
	private string[] generateBlockByteCode(ASTNode block){
		// make sure it's a block
		LinkedList!string byteCode = new LinkedList!string;
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
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for a function call
	private string[] generateFunctionCallByteCode(ASTNode fCall, bool pushResult = true){
		// first push the arguments to the stack, last arg first pushed
		ASTNode args;
		LinkedList!string byteCode = new LinkedList!string;
		args = fCall.subNodes[fCall.readSubNode(ASTNode.Type.Arguments)];
		uinteger argCount = 0;
		argCount = args.subNodes.length;
		// now start pushing them
		foreach(arg; args.subNodes){
			generateByteCode(arg);
		}
		/// now exec this function
		byteCode.append("\t"~(pushResult ? "execFuncP" : "execFuncI")~" "~fCall.data~" "~to!string(argCount));
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
	}

	/// generates byte code for a varDeclare
	private string[] generateVarDeclareByteCode(ASTNode varDeclare){
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
	}

	/// generates byte code for an if statement
	private string[] generateIfByteCode(ASTNode ifStatement){
		static uinteger ifCount = 0;
		ASTNode block = ifStatement.subNodes[1], condition = ifStatement.subNodes[0];
		if (ifStatement.subNodes[0].type == ASTNode.Type.Block){
			block = ifStatement.subNodes[0];
			condition = ifStatement.subNodes[1];
		}
		LinkedList!string byteCode = new LinkedList!string;
		// first, push the condition
		byteCode.append(generateByteCode(condition));
		// then add the skipTrue
		byteCode.append([
				"\tskipTrue i1",
				"\tjump s\"if"~to!string(ifCount)~"end\""
			]);
		// then comes the block
		byteCode.append(generateByteCode(block));
		// then end the end
		byteCode.append("\tif"~to!string(ifCount)~"end:");
		ifCount ++;
		// then return it!
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for while statement
	private string[] generateWhileByteCode(ASTNode whileStatement){
		static uinteger whileCount = 0;
		ASTNode block = whileStatement.subNodes[1], condition = whileStatement.subNodes[0];
		if (whileStatement.subNodes[0].type == ASTNode.Type.Block){
			block = whileStatement.subNodes[0];
			condition = whileStatement.subNodes[1];
		}
		LinkedList!string byteCode = new LinkedList!string;
		// first push the loop start position
		byteCode.append("\twhile"~to!string(whileCount)~"start:");
		// then push the condition
		byteCode.append(generateByteCode(condition));
		// then add the skipTrue
		byteCode.append([
				"\tskipTrue i1",
				"\tjump s\"while"~to!string(whileCount)~"end\""
			]);
		// then the block
		byteCode.append(generateByteCode(block));
		//  then end it!
		byteCode.append("\twhile"~to!string(whileCount)~"end:");
		whileCount ++;
		// now return it
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for assignment statement
	private string[] generateAssignmentByteCode(ASTNode assign){
		ASTNode var = assign.subNodes[0], val = assign.subNodes[1];
		LinkedList!string byteCode = new LinkedList!string;
		// check if is any array, then use `modifyElement`, otherwise, just a simple `setVar`
		if (var.subNodes.length > 0){
			// is array, needs to use `modifyElement` + `setVar`
			byteCode.append("\tgetVar s\""~var.data~'"');
			uinteger indexCount = 0;
			foreach (index; var.subNodes){
				indexCount ++;
				byteCode.append(generateByteCode(index));
			}
			// then call `modifyArray` with new value,and set the new val
			byteCode.append(generateByteCode(val));
			byteCode.append([
					"\tmodifyArray i"~to!string(indexCount),
					"\tsetVar s\""~var.data~'"'
				]);
			// done
		}else{
			// just set the new Val
			byteCode.append(generateByteCode(val));
			byteCode.append("\tsetVar s\""~var.data~'"');
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for operators
	private string[] generateOperatorByteCode(ASTNode operator){
		const string[string] operatorInstructions = [
			"/": "divide",
			"*": "multiply",
			"+": "add",
			"-": "subtract",
			"%": "mod",
			"~": "concat",
			// bool operators
			"==": "isSame",
			"!=": "isNotSame",
			">": "isLesser",
			"<": "isGreater",
			">=": "isGreaterSame",
			"<=": "isLesserSame"
		];
		LinkedList!string byteCode = new LinkedList!string;
		// push the operands first
		byteCode.append(generateByteCode(operator.subNodes[0]));
		byteCode.append(generateByteCode(operator.subNodes[1]));
		// then do the operation
		byteCode.append("\t"~operatorInstructions[operator.data]);
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}
	
	/// generates byte code for static array, i.e `[x, y, z]`
	private string[] generateStaticArrayByteCode(ASTNode array){
		/// returns true if the value of a static array is literal
		bool isStatic(ASTNode array){
			foreach(node; array.subNodes){
				if (![ASTNode.Type.NumberLiteral, ASTNode.Type.StringLiteral].hasElement(node.type)){
					if (node.type == ASTNode.Type.StaticArray && !isStatic(node)){
						return false;
					}
					return false;
				}
			}
			return true;
		}
		/// returns an ASTNode array encoded in a string, only works if isStatic returned true on it
		string arrayToString(ASTNode array){
			char[] r = ['['];
			foreach (node; array.subNodes){
				if (node.type == ASTNode.Type.StaticArray){
					r ~= cast(char[])arrayToString(node)~',';
				}
				r ~= cast(char[])node.data~',';
			}
			if (r.length <= 1){
				r = cast(char[])"[]";
			}else{
				r[r.length - 1] = ']';
			}
			return cast(string)r;
		}

		// check if needs to use `makeArray` or it's static
		if (isStatic(array)){
			return ["\tpush "~arrayToString(array)];
		}else{
			LinkedList!string byteCode = new LinkedList!string;
			uinteger elementCount = 0;
			// push all the subNodes, then call makeArray
			foreach (node; array.subNodes){
				byteCode.append(generateByteCode(node));
				elementCount ++;
			}
			// call `makeArray`
			byteCode.append("\tmakeArray i"~to!string(elementCount));
			string[] r = byteCode.toArray;
			.destroy(byteCode);
			return r;
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
	isSame
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
	isLesser
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
* isLesser 		- pops 2 values(int), if first value is less, pushes 1(int) to stack, else, pushes 0(int)
* isGreater		- pops 2 values(int), if first value is larger, pushes 1(int) to stack, else, pushes 0(int)
* isLesserSame	- pops 2 values(int), if first value is less or equal, pushes 1(int) to stack, else, pushes 0(int)
* isGreaterSame	- pops 2 values(int), if first value is larger or equal, pushes 1(int) to stack, else, pushes 0(int)
* isNotSame		- pops 2 values, if both are not same, pushes 1(int) to stack, else, pushes 0(int)

#### Misc. instructions:
* push 			- pushes all arguments to stack
* clear 		- clears the stack, pops all elements
* pop			- clears a number of elements from the stack, the number is arg0 (integer)
* jump			- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: "%someString%:" and arg0 of jump should be that %someString% (string).
* skipTrue		- pops a number of nodes (ints) from stack, the number is arg0(int). If each of them ==1(int), then the next instruction is skipped. This is used to construct if/while statements

#### Instructions for arrays
* setLen		- modifies length of an array, the array-to-modify, and new-length are pop-ed from stack, new array is pushed
* getLen		- pops array from stack, pushes the length (integer) of the array
* readElement	- pops an array, and element-index(int), pushes that element to the stack
* modifyArray	- pops an array, and a newVal from stack. Then pops `n` nodes from stack, where n is specfied by arg0(int). The does something like: `array[poped0][poped1].. = newVal` and pushes the array
* makeArray		- arg0(int) is count. pops `count` number of elements/nodes from stack, puts them in an array, pushes the array to stack

---

### Format for arguments:  
string:			s"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENT%,%ELEMENT%] // ELEMENT is either string, double, integer, or static array
*/