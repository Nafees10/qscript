module demo;
version (qscriptdemo){
	import utils.misc;
	import qscript.qscript;
	import std.datetime.stopwatch;
	import std.stdio;

	void main (string[] args){
		if (args.length < 2){
			writeln("not enough args. Usage:");
			writeln("./demo script/path # to execute script");
			writeln("./demo bcode script/path # to print compiled bytecode");
			return;
		}
		StopWatch sw;
		// create an instance of qscript, script name is "demo", not auto imported if used as library, no additional libraries, and enable builtin libraries
		QScript scr = new QScript("demo", false, [], true);
		string[] script = fileToArray(args[$-1]);
		CompileError[] errors;
		QScriptBytecode code = scr.compileScript(script, errors);
		if (errors.length > 0 || code is null){
			writeln("Compilation errors:");
			foreach (err; errors){
				writeln ("line#",err.lineno, ": ",err.msg);
			}
			return;
		}
		if (args.length > 2 && args[1] == "bcode"){
			foreach (i, line; code.getBytecodePretty)
				writeln(cast(integer)i-2, '\t', line);
			return;
		}
		// now execute main
		sw.start;
		scr.execute(0, []);
		sw.stop;
		writeln("execution took: ", sw.peek.total!"msecs", "msecs");
		.destroy(scr);
	}
}
