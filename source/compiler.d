/++
To create a executable which serves as a front end to just the compiler.  

This can be used to:
* convert script to AST, and output the AST in JSON
* convert script to byte code, and output the byte code (to be added)
* optimize existing byte code, and output new optimized byte code (to be added)
* convert script to byte code, optimize it, and output optimized byte code (to be added)
+/
module compiler;

import std.stdio;
import std.file;

import qscript.compiler.asttest;
import qscript.compiler.compiler : CompileError;

import utils.misc;

version(compiler){
	void main(string[] args){
		debug{
			args = ["", "ast", "sample.qs"];
		}
		if (args.length < 3){
			writeln ("not enough args. Usage:\n./compiler CompilationType path/to/script");
			writeln ("CompilationType can be:\n* ast - output AST in JSON");
		}else if (!["ast"].hasElement(args[1])){
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
			if (args[1] == "ast"){
				string json = astJSONTest(script,[],errors);
				if (errors.length > 0){
					stderr.writeln ("There are errors:");
					foreach (error; errors){
						stderr.writeln("Line#",error.lineno,": ",error.msg);
					}
				}
				writeln (json);
			}
		}
	}
}