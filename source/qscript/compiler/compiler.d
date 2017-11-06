module qscript.compiler.compiler;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.codegen;

import utils.misc;

/// To store information about a pre-defined function, for use at compile-time
public struct Function{
	/// the name of the function
	string name;
	/// the data type of the value returned by this function
	DataType returnType;
	/// stores the data type of the arguments received by this function
	private DataType[] storedArgTypes;
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(){
		return storedArgTypes;
	}
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(DataType[] newArray){
		return storedArgTypes = newArray.dup;
	}
	/// constructor
	this (string functionName, DataType functionReturnType, DataType[] functionArgTypes){
		name = functionName;
		returnType = functionReturnType;
		storedArgTypes = functionArgTypes.dup;
	}
}

/// Stores compilation error
public alias CompileError = qscript.compiler.misc.CompileError;

/// compiles a script from string[] to bytecode (in string[]).
/// 
/// 
public string[] compileQScriptToByteCode(string[] script, Function[] predefinedFunctions, CompileError[] errors){
	/// called by ASTGen to get return type of pre-defined functions
	DataType onGetReturnType(string name, DataType[] argTypes){
		// some hardcoded stuff
		if (name == "setLength"){
			// return type will be same as the first argument type
			if (argTypes.length != 2){
				throw new Exception ("setLength called with invalid arguments");
			}
			return argTypes[1];
		}else if (name == "getLength"){
			// int
			return DataType(DataType.Type.Integer);
		}else{
			// search in `predefinedFunctions`
			foreach (currentFunction; predefinedFunctions){
				if (currentFunction.name == name){
					return currentFunction.returnType;
				}
			}
			throw new Exception ("function '"~name~"' not defined");
		}
	}
	/// called by ASTGen to check if a pre-defined function is called with arguments of ok-type
	bool onCheckArgsType(string name, DataType[] argTypes){
		// over here, the QScript pre-defined functions are hardcoded :(
		if (name == "setLength"){
			// first arg, must be array, second must be int
			if (argTypes.length == 2 && argTypes[0].arrayNestCount > 0 &&
				argTypes[1].type == DataType.Type.Integer && argTypes[1].arrayNestCount == 0){
				return true;
			}else{
				return false;
			}
		}else if (name == "getLength"){
			// first arg, the array, that's it!
			if (argTypes.length == 1 && argTypes[0].arrayNestCount > 0){
				return true;
			}else{
				return false;
			}
		}else{
			// now check the other functions
			foreach (currentFunction; predefinedFunctions){
				if (currentFunction.name == name){
					return matchArguments(currentFunction.argTypes.dup, argTypes);
				}
			}
			throw new Exception ("function '"~name~"' not defined");
		}
	}
	// first convert to tokens
	errors = [];
	TokenList tokens = toTokens(script.dup, errors);
	if (errors.length > 0){
		return [];
	}
	// then generate the AST
	ScriptNode scriptAST;
	ASTGen astGenerator = ASTGen(&onGetReturnType, &onCheckArgsType);
	// generate the ast
	scriptAST = astGenerator.generateScriptAST(tokens, errors);
	if (errors.length > 0){
		return [];
	}
	// now finally the byte code
	CodeGen byteCodeGenerator;
	string[] code = byteCodeGenerator.generateByteCode(scriptAST, errors);
	if (errors.length > 0){
		return [];
	}
	return code;
}