/++
Provides function for debugging AST* parts of compiler
+/
module qscript.compiler.asttest;

import qscript.compiler.compiler;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.astcheck;
import qscript.compiler.astreadable;
import qscript.compiler.tokengen;
import qscript.compiler.misc;

import utils.misc;
import std.json;

public string astJSONTest(string[] script, Function[] preDefFunctions,ref CompileError[] errors){
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