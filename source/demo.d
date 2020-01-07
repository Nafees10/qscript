module demo;
version (demo){
	import utils.misc;
	import qscript.qscript;
	import std.datetime.stopwatch;
	import std.stdio;
	/// runs the scripts using QScript
	class ScriptExec{
	private:
		/// where the magic happens
		QScript _qscript;
		/// writeln function
		NaData writeln(NaData[] args){
			std.stdio.writeln (args[0].strVal);
			return NaData(0);
		}
		/// write function
		NaData write(NaData[] args){
			std.stdio.write (args[0].strVal);
			return NaData(0);
		}
		/// write int
		NaData writeInt(NaData[] args){
			std.stdio.write(args[0].intVal);
			return NaData(0);
		}
		/// write double
		NaData writeDbl(NaData[] args){
			std.stdio.write(args[0].doubleVal);
			return NaData(0);
		}
		/// readln function
		NaData readln(NaData[] args){
			string s = std.stdio.readln;
			s.length--;
			return NaData(s);
		}
	public:
		/// constructor
		this (){
			_qscript = new QScript(
				[
					Function("writeln", DataType("void"), [DataType("string")]),
					Function("write", DataType("void"), [DataType("string")]),
					Function("write", DataType("void"), [DataType("int")]),
					Function("write", DataType("void"), [DataType("double")]),
					Function("readln", DataType("string"), [])
				],
				[
					&writeln,
					&write,
					&writeInt,
					&writeDbl,
					&this.readln
				]
			);
			// all functions are already loaded, so initialize can be called right away
			_qscript.initialize();
		}
		/// compiles & returns byte code
		string[] compileToByteCode(string[] script, ref CompileError[] errors){
			string[] byteCode;
			errors = _qscript.loadScript(script, byteCode);
			return byteCode;
		}
		/// executes the first function in script
		NaData execute(uinteger functionID, NaData[] args){
			return _qscript.execute(functionID, args);
		}
	}

	void main (string[] args){
		debug{
			args = args[0]~["sample.qs", "out.bcode"];
		}
		if (args.length < 2){
			writeln("not enough args. Usage:");
			writeln("./demo [script] [bytecode, output, optional]");
		}else{
			StopWatch sw;
			ScriptExec scr = new ScriptExec();
			CompileError[] errors;
			string[] byteCode = scr.compileToByteCode(fileToArray(args[1]), errors);
			if (errors.length > 0){
				writeln("Compilation errors:");
				foreach (err; errors){
					writeln ("line#",err.lineno, ": ",err.msg);
				}
			}else{
				if (args.length > 2){
					byteCode.arrayToFile(args[2]);
				}
				// now execute main
				sw.start;
				scr.execute(0, []);
				sw.stop;
				writeln("execution took: ", sw.peek.total!"msecs", "msecs");
			}
		}
	}
}
