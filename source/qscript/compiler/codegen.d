module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.conv : to;

/// contains functions to generate byte code from AST
package struct CodeGen{
	/// constructor
	this (){
		compileErrors = new LinkedList!CompileError;
	}
	/// destructor
	~this (){
		.destroy(compileErrors);
	}
	/// generates byte code for a script
	public string[] generateByteCode(ScriptNode scriptNode, ref CompileError[] errors){
		LinkedList!string byteCode = new LinkedList!string;
		// remove all previous errors
		compileErrors.clear;
		// go through all nodes/ functions, and generate byte-code for them
		foreach (functionNode; scriptNode.functions){
			byteCode.append(generateByteCode(functionNode));
		}

		string[] r = byteCode.toArray;
		.destroy(byteCode);
		// put in errors
		errors = compileErrors.toArray;
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
			foreach (name; varIDs.keys){
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
			if (varName in varIDs){
				return varIDs[varName];
			}else{
				throw new Exception("variable '"~varName~"' not declared but used");
			}
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

	/// stores the list of errors
	private LinkedList!CompileError compileErrors;

	/// generates byte code for FunctionNode
	private string[] generateByteCode(FunctionNode node){
		/// returns the number of max vars that exist at one time in a a Block
		uinteger getMaxVarCount(BlockNode node){
			uinteger r = 0;
			uinteger maxSub = 0;
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
		byteCode.append("\tvarCount i"~to!string());
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
			return []; // VarDeclare wont be converted to anything, these only exist to tell FunctionNode the varCount
		}else{
			compileErrors.append(CompileError(0, "invalid AST generated"));
		}
	}

	/// generates byte code for FunctionCallNode
	private string[] generateFunctionCallByteCode(FunctionNode node){
		// push the args

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
* makeArray		- arg0(int) is count. pops `count` number of elements/nodes from stack, puts them in an array, pushes the array to stack

---

### Format for arguments:  
string:			s"%STRING%"
double:			d%DOUBLE%
integer:		i%INTEGER%
static array:	[%ELEMENT%,%ELEMENT%] // ELEMENT is either string, double, integer, or static array
*/