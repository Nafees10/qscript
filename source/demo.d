module demo;
version(demo){
	import utils.misc : fileToArray;
	import qscript.qscript;
	import std.datetime;
	import std.stdio;

	class ScriptMan : QScript{
	protected:
		override bool onRuntimeError(RuntimeError error){
			std.stdio.writeln ("# Runtime Error #");
			std.stdio.writeln ("# Function: ", error.functionName, " Instruction: ",error.instructionIndex);
			std.stdio.writeln ("# ", error.error);
			std.stdio.writeln ("Enter n to return false, or just enter to return true");
			string input = std.stdio.readln;
			if (input == "n\n"){
				return false;
			}else{
				return true;
			}
		}

		override bool onUndefinedFunctionCall(string fName){
			std.stdio.writeln ("# undefined Function Called #");
			std.stdio.writeln ("# Function: ", fName);
			std.stdio.writeln ("Enter n to return false, or just enter to return true");
			string input = std.stdio.readln;
			if (input == "n\n"){
				return false;
			}else{
				return true;
			}
		}
	private:
		/// writeln function
		QData writeln(QData[] args){
			std.stdio.writeln (args[0].strVal);
			return QData(0);
		}
		/// write function
		QData write(QData[] args){
			std.stdio.write (args[0].strVal);
			return QData(0);
		}
		/// write int
		QData writeInt(QData[] args){
			std.stdio.write(args[0].intVal);
			return QData(0);
		}
		/// write double
		QData writeDbl(QData[] args){
			std.stdio.write(args[0].doubleVal);
			return QData(0);
		}
		/// readln function
		QData readln(QData[] args){
			string s = std.stdio.readln;
			s.length--;
			return QData(s);
		}
	public:
		/// constructor
		this (){
			this.addFunction(Function("writeln", DataType("void"), [DataType("string")]), &writeln);
			this.addFunction(Function("write", DataType("void"), [DataType("string")]), &write);
			this.addFunction(Function("writeInt", DataType("void"), [DataType("int")]), &writeInt);
			this.addFunction(Function("writeDbl", DataType("void"), [DataType("double")]), &writeDbl);
			this.addFunction(Function("readln", DataType("string"), []), &readln);
		}
	}

	void main (string[] args){
		if (args.length < 2){
			writeln("not enough args. Usage:");
			writeln("./demo [FILENAME]");
		}else{
			StopWatch sw;
			ScriptMan scr = new ScriptMan();
			CompileError[] errors = scr.loadScript(fileToArray(args[1]));
			if (errors.length > 0){
				writeln("Compilation errors:");
				foreach (err; errors){
					writeln ("line#",err.lineno, ": ",err.msg);
				}
			}
			// now execute main
			sw.start;
			scr.executeScriptFunction("main",[]);
			sw.stop;
			writeln("execution took: ", sw.peek.msecs, "msecs");
		}
	}
}