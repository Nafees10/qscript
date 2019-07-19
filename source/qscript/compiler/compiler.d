/++
Provides an "interface" to all the compiler modules.
+/
module qscript.compiler.compiler;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.astcheck;
import qscript.compiler.codegen;
import qscript.compiler.bytecode;

import utils.misc;

/// To store information about a pre-defined function, for use at compile-time
public struct Function{
	/// the name of the function
	string name;
	/// the data type of the value returned by this function
	DataType returnType;
	/// stores the data type of the arguments received by this function
	private DataType[] _argTypes;
	/// the data type of the arguments received by this function
	/// 
	/// if an argType is defined as void, with array dimensions=0, it means accept any type.
	/// if an argType is defined as void with array dimensions>0, it means array of any type of that dimensions
	@property ref DataType[] argTypes(){
		return _argTypes;
	}
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(DataType[] newArray){
		return _argTypes = newArray.dup;
	}
	/// constructor
	this (string functionName, DataType functionReturnType, DataType[] functionArgTypes){
		name = functionName;
		returnType = functionReturnType;
		_argTypes = functionArgTypes.dup;
	}
}

/// Stores compilation error
public alias CompileError = qscript.compiler.misc.CompileError;

/// stores data type
public alias DataType = qscript.compiler.misc.DataType;

/// compiles a script from string[] to bytecode (in string[]).
/// 
/// `script` is the script to compile
/// `functions` is an array containing data about a function in Function[]
/// `errors` is the array to which errors will be appended
/// 
/// Returns: ByteCode class with the compiled byte code. or null if errors.length > 0
public ByteCode compileScript(string[] script, Function[] functions, ref CompileError[] errors){
	TokenList tokens = toTokens(script, errors);
	if (errors.length > 0)
		return null;
	ASTGen astMake;
	ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
	if (errors.length > 0)
		return null;
	ASTCheck check = new ASTCheck(functions);
	errors = check.checkAST(scrNode);
	.destroy(check);
	// time for the final thing, to byte code
	ByteCode code = new ByteCode();
	CodeGen byteCodeMaker = new CodeGen(code);
	byteCodeMaker.generateByteCode(scrNode);
	.destroy(byteCodeMaker);
	return code;
}