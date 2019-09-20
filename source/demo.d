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
		QData* writeln(QData*[] args){
			std.stdio.writeln (args[0].strVal);
			return new QData(0);
		}
		/// write function
		QData* write(QData*[] args){
			std.stdio.write (args[0].strVal);
			return new QData(0);
		}
		/// write int
		QData* writeInt(QData*[] args){
			std.stdio.write(args[0].intVal);
			return new QData(0);
		}
		/// write double
		QData* writeDbl(QData*[] args){
			std.stdio.write(args[0].doubleVal);
			return new QData(0);
		}
		/// readln function
		QData* readln(QData*[] args){
			string s = std.stdio.readln;
			s.length--;
			return new QData(s);
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
		}
		/// compiles & returns byte code
		string[] compileToByteCode(string[] script, ref CompileError[] errors){
			errors = _qscript.compile(script);
			return _qscript.byteCodeToString;
		}
		/// executes the first function in script
		QData execute(QData[] args){
			return _qscript.execute(0, args);
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
				scr.execute([]);
				sw.stop;
				writeln("execution took: ", sw.peek.total!"msecs", "msecs");
			}
		}
	}
}
