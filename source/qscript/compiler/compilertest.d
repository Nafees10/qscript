/++
Provides function for partial compilation of scripts.  
Exists so I can debug the compiler.
+/
module qscript.compiler.compilertest;

import qscript.compiler.compiler;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.astcheck;
import qscript.compiler.astreadable;
import qscript.compiler.tokengen;
import qscript.compiler.misc;
import qscript.compiler.bytecode;

import utils.misc;
import std.json;

/// Generates an AST for a script, uses ASTCheck.checkAST on it.
/// 
/// Returns: the final AST in readable JSON.
public string astJSONTest(string[] script, Function[] functions, ref CompileError[] errors){
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

/// generates readable Byte Code for a script. ASTCheck is also used
/// 
/// Returns: Byte Code in a reacable string[]
public string[] byteCodeTest(string[] script, Function[] functions, ref CompileError[] errors){
	// just use compiler.compiler.compileScript to get the ByteCode directly
	ByteCode code = compileScript(script, functions, errors);
	if (errors.length > 0)
		return [];
	return code.tostring();
}