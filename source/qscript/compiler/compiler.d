/++
Provides an "interface" to all the compiler modules.
+/
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
	/// 
	/// if an argType is defined as void, with array dimensions=0, it means accept any type.
	/// if an argType is defined as void with array dimensions>0, it means array of any type of that dimensions
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

/// stores data type
public alias DataType = qscript.compiler.misc.DataType;

/// compiles a script from string[] to bytecode (in string[]).
/// 
/// `script` is the script to compile
/// `predefinedFunctions` is an array containing data about a function in Function[]
/// `errors` is the array to which errors will be appended
/*public string[] compileQScriptToByteCode(string[] script, Function[] predefinedFunctions, ref CompileError[] errors){
	/// called by ASTGen to get return type of pre-defined functions
	DataType onGetReturnType(string name, DataType[] argTypes){
		// some hardcoded stuff
		if (name == "setLength"){
			// return type will be same as the first argument type
			if (argTypes.length != 2){
				throw new Exception ("setLength called with invalid arguments");
			}
			return argTypes[0];
		}else if (name == "getLength"){
			// int
			return DataType(DataType.Type.Integer);
		}else if (name == "array"){
			// return array of the type received
			if (argTypes.length < 1){
				throw new Exception ("cannot make an empty array using 'array()', use [] instead");
			}
			DataType r = argTypes[0];
			r.arrayDimensionCount ++;
			return r;
		}else if (name == "strLen"){
			// returns length, int
			return DataType(DataType.Type.Integer);
		}else if (name == "return"){
			return DataType(DataType.Type.Void);
		}else if (name == "not"){
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
			if (argTypes.length == 2 && argTypes[0].arrayDimensionCount > 0 &&
				argTypes[1].type == DataType.Type.Integer && argTypes[1].arrayDimensionCount == 0){
				return true;
			}else{
				return false;
			}
		}else if (name == "getLength"){
			// first arg, the array, that's it!
			if (argTypes.length == 1 && argTypes[0].arrayDimensionCount > 0){
				return true;
			}else{
				return false;
			}
		}else if (name == "array"){
			// must be at least one arg
			if (argTypes.length < 1){
				return false;
			}
			// and all args must be of same type
			foreach (type; argTypes){
				if (type != argTypes[0]){
					return false;
				}
			}
			return true;
		}else if (name == "strLen"){
			// one arg, must be string
			if (argTypes.length != 1){
				return false;
			}else if (argTypes[0] == DataType(DataType.Type.String)){
				return true;
			}
			return false;
		}else if (name == "return"){
			// real type checking for this was done at compile-time (AST generator)
			if (argTypes.length == 1){
				return true;
			}
			return false;
		}else if (name == "not"){
			if (argTypes.length == 1 && argTypes[0] == DataType(DataType.Type.Integer)){
				return true;
			}
			return false;
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
	// add some other predefined QScript functions
	predefinedFunctions = predefinedFunctions.dup;
	predefinedFunctions ~= [
		Function("strToInt", DataType(DataType.Type.Integer), [DataType(DataType.Type.String)]),
		Function("strToDouble", DataType(DataType.Type.Double), [DataType(DataType.Type.String)]),
		
		Function("intToStr", DataType(DataType.Type.String), [DataType(DataType.Type.Integer)]),
		Function("intToDouble", DataType(DataType.Type.Double), [DataType(DataType.Type.Integer)]),
		
		Function("doubleToStr", DataType(DataType.Type.String), [DataType(DataType.Type.Double)]),
		Function("doubleToInt", DataType(DataType.Type.Integer), [DataType(DataType.Type.Double)])
	];
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
}*/
