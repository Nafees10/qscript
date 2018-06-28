/++
Functions to check if a script is valid (or certain nodes) by its generated AST
+/
module qscript.compiler.astcheck;

import qscript.compiler.misc;
import qscript.compiler.ast;
import qscript.compiler.compiler : Function;

import utils.misc;
import utils.lists;

/// Contains functions to check ASTs for errors  
/// One instance of this class can be used to check for errors in a script's AST.
class ASTCheck{
private:
	/// the function to call to check if a predefined function is being called with the correct argument data types
	/// 
	/// it will be called with the function name, and the data types of the arguments
	bool delegate(string, DataType[]) _onCheckArgTypes;
	/// the function to call to get the return-data-type of a predefined-function
	/// 
	/// this function will be called with the function name, and the data types of the arguments it is called with in script  
	/// this function is only called if `onCheckArgTypes` return true
	DataType delegate(string, DataType[]) _onGetFunctionReturnType;
	/// stores the script defined functions' names, arg types, and return types
	Function[] scriptDefFunctions;
	/// stores all the errors that are there in the AST being checked
	LinkedList!CompileError compileErrors;
	
	/// stores data types of variables in currently-being-checked-FunctionNode
	DataType[string] varTypes;
	/// stores the scope-depth of each var in currently-being-checked-FunctionNode which is currently in scope
	uinteger[string] varScope;
	/// stores current scope-depth
	uinteger scopeDepth;
	/// registers a new var in current scope
	/// 
	/// Returns: false if it was already registered, true if it was successful
	bool addVar(string name, DataType type){
		if (name in varTypes){
			return false;
		}
		varTypes[name] = type;
		varScope[name] = scopeDepth;
		return true;
	}
	/// Returns: the data type of a variable
	/// 
	/// Throws: Exception if that variable was not declared, or is not available in current scope
	DataType getVarType(string name){
		if (name in varTypes){
			return varTypes[name];
		}
		throw new Exception("variable "~name~" was not declared, or is out of scope");
	}
	/// increases the scope-depth
	/// 
	/// this function should be called before any AST-checking in a sub-BlockNode or anything like that is started
	void increaseScope(){
		scopeDepth ++;
	}
	/// decreases the scope-depth
	/// 
	/// this function should be called right after checking in a sub-BlockNode or anything like that is finished  
	/// it will put the vars declared inside that scope go out of scope
	void decreaseScope(){
		foreach (key; varScope.keys){
			if (varScope[key] == scopeDepth){
				varScope.remove(key);
				// remove from varDataTypes too!
				varTypes.remove(key);
			}
		}
		if (scopeDepth > 0){
			scopeDepth --;
		}
	}
	/// reads all FunctionNode from ScriptNode and writes them into `scriptDefFunctions`
	/// 
	/// any error is appended to compileErrors
	void readFunctions(ScriptNode node){
		/// stores index of functions in scriptDefFunctions
		uinteger[][string] funcIndex;
		scriptDefFunctions.length = node.functions.length;
		foreach (i, func; node.functions){
			// read arg types into a single array
			DataType[] argTypes;
			argTypes.length = func.arguments.length;
			foreach (index, arg; func.arguments)
				argTypes[i] = arg.argType;
			scriptDefFunctions[i] = Function(func.name, func.returnType, argTypes);
			if (func.name in funcIndex)
				funcIndex[func.name] ~= i;
			else
				funcIndex[func.name] = [i];
		}
		// now make sure that all functions with same names have different arg types
		foreach (funcName; funcIndex.keys){
			if (funcIndex[funcName].length > 1){
				// check these indexes
				uinteger[] indexes = funcIndex[funcName];
				/// stores the arg type combinations which have already been used
				DataType[][] usedArgCombinations;
				usedArgCombinations.length = indexes.length;
				foreach (i, index; indexes){
					if (usedArgCombinations[0 .. i].indexOf(scriptDefFunctions[index].argTypes) >= 0){
						compileErrors.append(CompileError(node.functions[index].lineno,
								"functions with same name must have different argument types"
							));
					}
					usedArgCombinations[i] = scriptDefFunctions[index].argTypes;
				}
			}
		}
	}
protected:
	/// checks if a FunctionNode is valid
	void checkAST(FunctionNode node){
		increaseScope();
		// add the arg's to the var scope. make sure one arg name is not used more than once
		foreach (i, arg; node.arguments){
			if (!addVar(arg.argName, arg.argType)){
				compileErrors.append(CompileError(node.lineno, "argument name '"~arg.argName~"' has been used more than once"));
			}
		}
		// now check the statements
	}
	/// checks if a StatementNode is valid
	void checkAST(StatementNode node){
		
	}
public:
	this (bool delegate(string, DataType[]) onCheckArgTypes, DataType delegate(string, DataType[]) onGetFunctionReturnType){
		compileErrors = new LinkedList!CompileError;
		_onCheckArgTypes = onCheckArgTypes;
		_onGetFunctionReturnType = onGetFunctionReturnType;
	}
	~this(){
		.destroy(compileErrors);
	}
	/// loads an makes an AST ready for checking
	void loadAST(ScriptNode node){
		// call loadAST and empty everything
		scriptDefFunctions = [];
		compileErrors.clear;
		varTypes.clear;
		varScope.clear;
		scopeDepth = 0;
		readFunctions(node);
	}
}
