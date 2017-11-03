module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.conv : to;

/// contains functions to generate byte code from AST
package struct CodeGen{
	/// generates byte code for a script
	public string[] generateByteCode(ScriptNode scriptNode, ref CompileError[] errors){
		compileErrors = new LinkedList!CompileError;
		LinkedList!string byteCode = new LinkedList!string;
		// remove all previous errors
		compileErrors.clear;
		// prepare a list of script-defind functions
		scriptDefinedFunctions.length = scriptNode.functions.length;
		foreach (i, functionNode; scriptNode.functions){
			scriptDefinedFunctions[i] = functionNode.name;
		}
		// go through all nodes/ functions, and generate byte-code for them
		foreach (functionNode; scriptNode.functions){
			byteCode.append(generateByteCode(functionNode));
		}

		string[] r = byteCode.toArray;
		.destroy(byteCode);
		// put in errors
		errors = compileErrors.toArray;
		.destroy(compileErrors);
		return r;
	}

	/// provides functions to deal with converting vars to IDs
	private struct{
		/// stores IDs for vars
		private string[uinteger] varIDs;
		/// stores the scope "depth" for each varID
		private uinteger[uinteger] varScopeDepth;
		/// stores the current scope depth
		private uinteger scopeDepth;
		/// creates a new var, returns the ID, throws Exception if var already exists
		public uinteger getNewVarID(string varName){
			// check if already exists
			foreach (name; varIDs){
				if (varName == name){
					throw new Exception("variable '"~varName~"' declared twice");
				}
			}
			// find an empty ID
			uinteger newID = 0;
			while (newID in varIDs){
				newID ++;
			}
			varIDs[newID] = varName;
			// put it in varScopeDepth
			varScopeDepth[scopeDepth] = newID;
			return newID;
		}
		/// returns ID of a var. throws exception if var is not declared
		public uinteger getVarID(string varName){
			foreach (key; varIDs.keys){
				if (varIDs[key] == varName){
					return key;
				}
			}
			throw new Exception("variable '"~varName~"' not declared but used");
		}
		/// should/must be called when the next few calls of var-related functions will be from inside another block
		public void increaseScope(){
			scopeDepth ++;
		}
		/// should/must be called when all var related functions from inside a block are done
		public void decreaseScope(){
			// clear vars
			foreach (key; varScopeDepth.keys){
				if (key == scopeDepth){
					varScopeDepth.remove(key);
					varIDs.remove(key);
				}
			}
			if (scopeDepth > 0){
				scopeDepth --;
			}
		}
	}

	/// contains a list of script0-defined functions
	private string[] scriptDefinedFunctions;

	/// Returns true if a function is script-defined
	private bool isScriptDefined(string fName){
		foreach (scriptDefined; scriptDefinedFunctions){
			if (fName == scriptDefined){
				return true;
			}
		}
		return false;
	}

	/// stores the list of errors
	private LinkedList!CompileError compileErrors;

	/// generates byte code for FunctionNode
	private string[] generateByteCode(FunctionNode node){
		/// returns the number of max vars that exist at one time in a a Block
		uinteger getMaxVarCount(BlockNode node){
			uinteger r = 0;
			uinteger maxSub = 0;
			increaseScope();
			foreach (statement; node.statements){
				if (statement.type == StatementNode.Type.VarDeclare){
					// get the number of vars
					r += statement.node!(StatementNode.Type.VarDeclare).vars.length;
				}else if (statement.type == StatementNode.Type.Block){
					// recursion
					uinteger newMaxSub = getMaxVarCount (statement.node!(StatementNode.Type.Block));
					if (newMaxSub > maxSub){
						maxSub = newMaxSub;
					}
				}
			}
			return r + maxSub;
		}

		LinkedList!string byteCode = new LinkedList!string;
		// push the function name
		byteCode.append (node.name);
		// then set the max var count
		uinteger maxVars = getMaxVarCount(node.bodyBlock);
		// add the arguments count to this
		maxVars += node.arguments.length;
		byteCode.append("\tvarCount i"~to!string(maxVars));
		// then assign the arguments their var IDs
		foreach (arg; node.arguments){
			try{
				getNewVarID(arg.argName);
			}catch (Exception e){
				compileErrors.append(CompileError(0, "bug in compiler - argument name '"~arg.argName~"' not available"));
				.destroy (e);
			}
		}
		// then append the instructions
		byteCode.append (generateByteCode (node.bodyBlock));

		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for BlockNode
	private string[] generateByteCode(BlockNode node){
		LinkedList!string byteCode = new LinkedList!string;
		foreach (statement; node.statements){
			byteCode.append(generateByteCode(statement));
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for StatementNode
	private string[] generateByteCode(StatementNode node){
		if (node.type == StatementNode.Type.Assignment){
			return generateByteCode(node.node!(StatementNode.Type.Assignment));
		}else if (node.type == StatementNode.Type.Block){
			return generateByteCode(node.node!(StatementNode.Type.Block));
		}else if (node.type == StatementNode.Type.FunctionCall){
			return generateByteCode(node.node!(StatementNode.Type.FunctionCall));
		}else if (node.type == StatementNode.Type.If){
			return generateByteCode(node.node!(StatementNode.Type.If));
		}else if (node.type == StatementNode.Type.While){
			return generateByteCode(node.node!(StatementNode.Type.While));
		}else if (node.type == StatementNode.Type.VarDeclare){
			// VarDeclare wont be converted to anything, these only exist to tell FunctionNode the varCount
			return generateByteCode(node.node!(StatementNode.Type.VarDeclare));
		}else{
			compileErrors.append(CompileError(0, "invalid AST generated"));
			return [];
		}
	}

	/// generates byte code for FunctionCallNode
	private string[] generateByteCode(FunctionCallNode node){
		// stores if this function's return value is needed on stack or not. ==1: return not required, >1: return required
		static callCount = 0;
		callCount ++;
		auto byteCode = new LinkedList!string;
		// push the args
		uinteger argCount = 0;
		foreach (arg; node.arguments){
			byteCode.append(generateByteCode(arg));
			argCount ++;
		}
		// then append the instruction to execute this function
		if (isScriptDefined(node.fName)){
			byteCode.append("\texecFuncS s\""~node.fName~"\" i"~to!string(argCount));
		}else{
			byteCode.append("\texecFuncE s\""~node.fName~"\" i"~to!string(argCount));
		}
		// pop the return, if result not required
		if (callCount == 1){
			byteCode.append("\tpop i1");
		}
		callCount --;
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for CodeNode
	private string[] generateByteCode(CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			return generateByteCode(node.node!(CodeNode.Type.FunctionCall));
		}else if (node.type == CodeNode.Type.Literal){
			return generateByteCode(node.node!(CodeNode.Type.Literal));
		}else if (node.type == CodeNode.Type.Operator){
			return generateByteCode(node.node!(CodeNode.Type.Operator));
		}else if (node.type == CodeNode.Type.Variable){
			return generateByteCode(node.node!(CodeNode.Type.Variable));
		}else{
			compileErrors.append(CompileError(0, "invalid AST generated"));
			return [];
		}
	}

	/// generates byte code for OperatorNode
	private string[] generateByteCode(OperatorNode node){
		const string[string] operatorInstructions = [
			"*" : "multiply",
			"/" : "divide",
			"+" : "add",
			"-" : "subtract",
			"%" : "mod",
			"~" : "concat",
			"<" : "isLesser",
			"==": "isSame",
			">" : "isGreater"
		];
		// check if types are ok
		const static string[] ArtithmaticOperators = ["*", "/", "+", "-", "%", "<", ">"];
		const static string[] ArrayStringOperators = ["~"];
		const static string[] NonArrayOperators = ["=="];
		bool errorFree = true;
		// first make sure both operands are of same type
		if (node.operands[0].returnType != node.operands[1].returnType){
			compileErrors.append(CompileError(0, "data type of both operands must be same"));
		}
		if (ArtithmaticOperators.hasElement(node.operator)){
			// must be either int, or double
			if (node.operands[0].returnType.isArray == true){
				compileErrors.append(CompileError(0, "arithmatic operators cannot be used on arrays"));
				errorFree = false;
			}
			if (node.operands[0].returnType.type != DataType.Type.Double &&
				node.operands[0].returnType.type != DataType.Type.Integer){
				compileErrors.append(CompileError(0, "arithmatic operators can only be used on integer or double"));
				errorFree = false;
			}
		}else if (ArrayStringOperators.hasElement(node.operator)){
			if (!node.operands[0].returnType.isArray && node.operands[0].returnType.type != DataType.Type.String){
				compileErrors.append(CompileError(0, "cannot use this operator on non-string and non-array data"));
				errorFree = false;
			}
		}else if (NonArrayOperators.hasElement(node.operator)){
			// make sure type's not array
			if (node.operands[0].returnType.isArray){
				compileErrors.append(CompileError(0, node.operator~" cannot be used with arrays"));
				errorFree = false;
			}
		}else{
			compileErrors.append(CompileError(0, "invalid operator"));
			errorFree = false;
		}
		if (errorFree){
			// now push the operands
			auto byteCode = new LinkedList!string;
			byteCode.append(generateByteCode(node.operands[0])~generateByteCode(node.operands[1]));
			// now get the operator instruction name
			string instruction = operatorInstructions[node.operator];
			// append the data type at the end to get the exact name
			if (node.operands[0].returnType.isArray){
				instruction ~= "Array";
			}else if (node.operands[0].returnType.type == DataType.Type.String){
				instruction ~= "String";
			}else if (node.operands[0].returnType.type == DataType.Type.Integer){
				instruction ~= "Int";
			}else if (node.operands[0].returnType.type == DataType.Type.Double){
				instruction ~= "Double";
			}else{
				compileErrors.append(CompileError(0, "unsupported data type"));
			}
			// call the instruction
			byteCode.append("\t"~instruction);
			string[] r = byteCode.toArray;
			.destroy(byteCode);
			return r;
		}else{
			return [];
		}
	}

	/// generates byte code for VariableNode
	private string[] generateByteCode(VariableNode node){
		auto byteCode = new LinkedList!string;
		// first get the var's value on stack
		uinteger varID;
		try{
			varID = getVarID(node.varName);
		}catch (Exception e){
			compileErrors.append(CompileError(0, e.msg));
			.destroy(e);
		}
		byteCode.append("\tgetVar i"~to!string(varID));
		// then get the index required
		foreach (index; node.indexes){
			byteCode.append(
					generateByteCode(index)~
					["\treadElement"]);
		}
		// done
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for AssignmentNode
	private string[] generateByteCode(AssignmentNode node){
		uinteger varID;
		try{
			varID = getVarID(node.var.varName);
		}catch (Exception e){
			compileErrors.append(CompileError(0, e.msg));
			.destroy(e);
		}
		// first check if the var is an array
		if (node.var.isArray){
			// push the original value of var, then push all the indexes, then call modifyAray, and setVar
			auto byteCode = new LinkedList!string;
			byteCode.append("\tgetVar i"~to!string(varID));
			// now the indexes
			foreach (index; node.var.indexes){
				byteCode.append(generateByteCode(index));
			}
			// now call push the val
			byteCode.append(generateByteCode(node.val));
			// then modifyArray
			byteCode.append("\tmodifyArray i"~to!string(node.var.indexes.length));
			// finally, set the new array back
			byteCode.append("\tsetVar i"~to!string(varID));
			string[] r = byteCode.toArray;
			.destroy(byteCode);
			return r;
		}else{
			// just push the val, and call setVar on the varID
			return generateByteCode(node.val)~
			["\tsetVar i"~to!string(varID)];
		}
	}

	/// generates byte code for VarDeclareNode
	private string[] generateByteCode(VarDeclareNode node){
		// no byte code is generated for varDeclare, just call the addVarID function
		foreach (var; node.vars){
			try{
				getNewVarID(var);
			}catch (Exception e){
				compileErrors.append(CompileError(0, e.msg));
			}
		}
		return [];
	}

	/// generates byte code for IfNode
	private string[] generateByteCode(IfNode node){
		// stores the `ID` of this if statement
		static uinteger ifCount = 0;
		auto byteCode = new LinkedList!string;
		// first push the condition
		byteCode.append(generateByteCode(node.condition));
		// then the skipTrue, to skip the jump to else
		byteCode.append([
				"\tskipTrue i1",
				"\tjump s\"ifEnd"~to!string(ifCount)~"\""
			]);
		// then comes the if-on-true body
		byteCode.append(generateByteCode(BlockNode(node.statements)));
		// then then jump to elseEnd to skip the else statements
		if (node.hasElse){
			byteCode.append("\tjump s\"elseEnd"~to!string(ifCount)~"\"");
		}
		byteCode.append("\tifEnd"~to!string(ifCount)~":");
		// now the elseBody
		if (node.hasElse){
			byteCode.append(generateByteCode(BlockNode(node.elseStatements))~
					["\telseEnd"~to!string(ifCount)~":"]);
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		ifCount ++;
		return r;
	}

	/// generates byte code for WhileNode
	private string[] generateByteCode(WhileNode node){
		auto byteCode = new LinkedList!string;
		// stores the `ID` of the while statement
		static uinteger whileCount = 0;
		// first comes the jump-back-here position
		byteCode.append("\twhileStart"~to!string(whileCount)~":");
		// then comes the condition
		byteCode.append(generateByteCode(node.condition));
		// then skip the jump-to-end if true
		byteCode.append([
				"\tskipTrue i1",
				"\tjump s\"whileEnd"~to!string(whileCount)~"\""
			]);
		// then the loop body
		byteCode.append(generateByteCode(BlockNode(node.statements)));
		// then jump back to condition, to see if it'll start again
		byteCode.append("\tjump s\"whileStart"~to!string(whileCount)~"\"");
		// then mark the loop end
		byteCode.append("\twhileEnd"~to!string(whileCount)~":");
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		whileCount ++;
		return r;
	}

	/// generates byte code for a LiteralNode
	private string[] generateByteCode(LiteralNode node){
		// just use LiteralNode.toByteCode
		string literal;
		try{
			literal = node.toByteCode;
		}catch (Exception e){
			compileErrors.append(CompileError(0, e.msg));
		}
		return ["\tpush "~literal];
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
  
### List of instructions:
#### Instructions for executing functions:
* execFuncS 	- executes a script-defined function, arg0 is function name (string), arg1 is number (int) of arguments to pop from stack for the function. Result is pushed to stack
* execFuncE		- executes an external function, arg0 is function name (string), arg1 is number (int) of arguments to pop from stack for the function. Result is pushed to stack

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

#### Misc. instructions:
* push 			- pushes all arguments to stack
* clear 		- clears the stack, pops all elements
* pop			- clears a number of elements from the stack, the number is arg0 (integer)
* jump			- jumps to another instruction. The instruction to jump to is specified by preceding that instruction by: "%someString%:" and arg0 of jump should be that %someString% (string).
* skipTrue		- skips the next instrcution if the last element on stack == 1 (int)
* not			- if last element pushed == 1(int), then pushes 0(int), else, pushes 1(int)
* and			- if last 2 elements on stack (int) == 1, pushes 1, else pushes 0
* or			- if either of last 2 elements on stack == 1 (int), pushes 1, else pushes 0

#### Instructions for arrays
* setLen		- modifies length of an array, the array-to-modify, and new-length are pop-ed from stack, new array is pushed
* getLen		- pops array from stack, pushes the length (integer) of the array
* readElement	- pops an array, and element-index(int), pushes that element to the stack
* modifyArray	- pops an array, and a newVal from stack. Then pops `n` nodes from stack, where n is specfied by arg0(int). The does something like: `array[poped0][poped1].. = newVal` and pushes the array
* array			- arg0(int) is count. pops `count` number of elements/nodes from stack, puts them in an array, pushes the array to stack

---

### Format for arguments:  
string:			s"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENT%,%ELEMENT%] // ELEMENT is either string, double, integer, or static array
*/