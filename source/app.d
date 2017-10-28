module app;

debug{
	import qscript.compiler.tokengen;
	import qscript.compiler.astgen;
	import qscript.compiler.asthtml;
	import qscript.compiler.misc;
	import qscript.compiler.ast;

	import std.stdio : write, writeln;

	import utils.misc;
	
	void main(){
		string[] scriptFile = [
			"function void main{",
			"int (i);",
			"}"
		];
		CompileError[] errors;
		TokenList tokens = toTokens(scriptFile, errors);
		if (errors.length > 0){
			writeln("errors in tokengen");
			foreach (err; errors){
				writeln("line#",err.lineno, ": ",err.msg);
			}
			assert(0);
		}
		ASTGen gen = ASTGen([
				"write": DataType("void")
			]);
		ScriptNode AST = gen.generateScriptAST(tokens, errors);
		if (errors.length > 0){
			writeln("errors in ASTGen");
			foreach (err; errors){
				writeln("line#",err.lineno, ": ",err.msg);
			}
			assert(0);
		}
		// check for errors
		.destroy(gen);
		// now export the AST to a html file
		//arrayToFile("/home/nafees/Desktop/q.html", AST.toHtml);
	}
}
