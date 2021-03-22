module source.standalone;
version (qscriptstandalone){
	import utils.misc;
	import qscript.qscript;
	import qscript.compiler.compiler;
	import std.datetime.stopwatch;
	import std.stdio;

	void main (string[] args){
		if (args.length < 2){
			stderr.writeln("not enough args. Usage:");
			stderr.writeln("execute script:\n qscript script/path");
			stderr.writeln("print compiled bytecode:\n qscript --bcode script/path");
			stderr.writeln("pretty print generated AST:\n qscript --ast script/path");
			return;
		}
		StopWatch sw;
		// create an instance of qscript, script name is "demo", not auto imported if used as library, no additional libraries, and enable builtin libraries
		QScript scr = new QScript("demo", false, [], true);
		string[] script = fileToArray(args[$-1]);
		CompileError[] errors;
		if (args.length > 2 && args[1] == "--ast"){
			QSCompiler compiler = new QSCompiler([],[]); // no need to provide instruction table, we wont be using codeGen
			compiler.loadScript(script);
			compiler.scriptExports = scr;
			if (compiler.generateTokens || !compiler.generateAST || !compiler.checkAST){
				stderr.writeln("There are errors:");
				errors = compiler.errors;
				foreach (error; errors)
					stderr.writeln("Line#",error.lineno,": ",error.msg);
			}
			writeln(compiler.prettyAST);
			.destroy(scr);
			.destroy(compiler);
			return;
		}
		QScriptBytecode code = scr.compileScript(script, errors);
		if (errors.length > 0 || code is null){
			stderr.writeln("Compilation errors:");
			foreach (err; errors)
				stderr.writeln ("line#",err.lineno, ": ",err.msg);
			return;
		}
		if (args.length > 2 && args[1] == "--bcode"){
			foreach (i, line; code.getBytecodePretty)
				writeln(cast(integer)i-2, '\t', line);
			return;
		}
		// now execute main
		sw.start;
		scr.execute(0, []);
		sw.stop;
		stderr.writeln("execution took: ", sw.peek.total!"msecs", "msecs");
		.destroy(scr);
	}
}
