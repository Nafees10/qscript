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

import std.json;
import qscript.compiler.astreadable;

import utils.misc;

import navm.navm : NaFunction;

/// compiles a script from string[] to bytecode (in NaFunction[]).
/// 
/// `script` is the script to compile
/// `functions` is an array containing data about a function in Function[]
/// `errors` is the array to which errors will be appended
/// 
/// Returns: ByteCode class with the compiled byte code. or null if errors.length > 0
public string[] compileScript(string[] script, Function[] functions, ref CompileError[] errors,
ref Function[] functionMap){
	TokenList tokens = toTokens(script, errors);
	if (errors.length > 0)
		return null;
	ASTGen astMake;
	ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
	if (errors.length > 0)
		return null;
	ASTCheck check = new ASTCheck(functions);
	errors = check.checkAST(scrNode);
	if (errors.length > 0)
		return null;
	.destroy(check);
	// time for the final thing, to byte code
	CodeGen bCodeGen = new CodeGen();
	bCodeGen.generateByteCode(scrNode);
	string[] byteCode = bCodeGen.getByteCode();
	functionMap = bCodeGen.getFunctionMap;
	return byteCode;
}

/// Generates an AST for a script, uses ASTCheck.checkAST on it.
/// 
/// Returns: the final AST in readable JSON.
public string compileScriptAST(string[] script, Function[] functions, ref CompileError[] errors){
	TokenList tokens = toTokens(script, errors);
	if (errors.length == 0){
		ASTGen astMake;
		ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
		if (errors.length == 0){
			ASTCheck check = new ASTCheck(functions);
			errors = check.checkAST(scrNode);
			.destroy(check);
			JSONValue jsonAST = scrNode.toJSON;
			return jsonAST.toPrettyString();
		}
	}
	return "";
}