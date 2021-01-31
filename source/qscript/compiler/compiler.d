﻿/++
All the compiler modules packaged into one, this one module should be used to compile scripts.
+/
module qscript.compiler.compiler;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.astcheck;
import qscript.compiler.codegen;
import qscript.compiler.astreadable;

import std.json;
import std.range;
import std.traits;
import std.conv : to;

import utils.misc;



/// all the compiler modules wrapped into a single class. This is all that should be needed to compile scripts
public class QSCompiler{
private:

}

/// compiles a script from string[] to bytecode (in NaFunction[]).
/// 
/// `script` is the script to compile
/// `functions` is an array containing data about a function in Function[]
/// `errors` is the array to which errors will be appended
/// 
/// Returns: ByteCode class with the compiled byte code. or null if errors.length > 0
public string[] compileScript(string[] script, Library[] libraries, ref CompileError[] errors,
ref Function[] functionMap){
	TokenList tokens = toTokens(script, errors);
	if (errors.length > 0)
		return null;
	ASTGen astMake;
	ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
	if (errors.length > 0)
		return null;
	ASTCheck check = new ASTCheck(libraries);
	errors = check.checkAST(scrNode);
	if (errors.length > 0)
		return null;
	.destroy(check);
	// time for the final thing, to byte code
	/*CodeGen bCodeGen = new CodeGen();
	bCodeGen.generateByteCode(scrNode);
	string[] byteCode = bCodeGen.getByteCode();
	functionMap = bCodeGen.getFunctionMap;*/
	//return byteCode;
	return [];
}

/// Generates an AST for a script, uses ASTCheck.checkAST on it.
/// 
/// Returns: the final AST in readable JSON.
public string compileScriptAST(string[] script, Library[] libraries, ref CompileError[] errors){
	TokenList tokens = toTokens(script, errors);
	if (errors.length == 0){
		ASTGen astMake;
		ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
		if (errors.length == 0){
			ASTCheck check = new ASTCheck(libraries);
			errors = check.checkAST(scrNode);
			.destroy(check);
			JSONValue jsonAST = scrNode.toJSON;
			return jsonAST.toPrettyString();
		}
	}
	return "";
}