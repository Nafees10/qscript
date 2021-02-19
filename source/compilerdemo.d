/++
To create a executable which serves as a front end to just the compiler.  

This can be used to:
* convert script to AST, and output the AST in JSON
* convert script to byte code, and output the byte code (to be added)
* optimize existing byte code, and output new optimized byte code (to be added, when optimizer is added)
* convert script to byte code, optimize it, and output optimized byte code (to be added, when optimizer is added)
+/
module compilerdemo;

import std.stdio;
import std.file;

import qscript.compiler.compiler;
import qscript.qscript;

import utils.misc;

version(compiler){
	void main(string[] args){
		if (args.length < 3){
			writeln ("not enough args. Usage:\n./compiler CompilationType path/to/script");
			writeln ("CompilationType can be:\n* ast - output AST in JSON\n* bytecode - output Byte Code");
		}else if (!["ast", "bytecode"].hasElement(args[1])){
			writeln ("invalid CompilationType");
		}else if (!exists(args[2])){
			writeln ("file "~args[2]~" doesn't exist");
		}else{
			string[] script;
			try{
				script = fileToArray(args[2]);
			}catch (Exception e){
				.destroy(e);
				writeln ("Error reading file");
			}
			CompileError[] errors;
			QScript qs = new QScript("script",false,[]);
			if (args[1] == "ast"){
				QSCompiler compiler = new QSCompiler([],[]);
				compiler.loadScript(script);
				compiler.scriptExports = qs;
				if (!compiler.generateTokens || !compiler.generateAST || !compiler.finaliseAST){
					stderr.writeln ("There are errors:");
					foreach (error; compiler.errors)
						stderr.writeln("Line#",error.lineno,": ",error.msg);
				}
				writeln (compiler.prettyAST);
				.destroy(compiler);
			}else if (args[1] == "bytecode"){
				QScriptBytecode bytecodeObject = qs.compileScript(script, errors);
				if (errors.length > 0 || bytecodeObject is null){
					stderr.writeln ("There are errors:");
					foreach (error; errors){
						stderr.writeln("Line#",error.lineno,": ",error.msg);
					}
					return;
				}
				string[] byteCode = bytecodeObject.getBytecodePretty;
				foreach (int i, line; byteCode){
					writeln(i-2,'\t',line);
				}
				.destroy(bytecodeObject);
			}
			.destroy(qs);
		}
	}
}