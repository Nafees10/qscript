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

import utils.misc;
import std.json;

/// Generates an AST for a script, uses ASTCheck.checkAST on it.
/// 
/// Returns: the final AST in readable JSON.
public string astJSONTest(string[] script, Function[] preDefFunctions, ref CompileError[] errors){
	TokenList tokens = toTokens(script, errors);
	if (errors.length == 0){
		ASTGen astMake;
		ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
		if (errors.length == 0){
			ASTCheck check = new ASTCheck(preDefFunctions);
			errors = check.checkAST(scrNode);
			.destroy(check);
			JSONValue jsonAST = scrNode.toJSON;
			return jsonAST.toPrettyString();
		}
	}
	return "";
}