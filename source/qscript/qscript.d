module qscript;

import utils.misc;
import utils.lists;
import compiler;
import std.stdio;
import std.conv:to;

/// This is the type of each script function, used in this module
private alias ScriptFunction = QVar delegate(QVar[]);
/// The type for `onExec`
public alias OnExecuteFunction = QVar delegate(string, QVar[]);
/// The type for `onError`
public alias OnErrorFunction = void delegate(QScriptError);

/// Each error is stored in `QScriptError`
struct QScriptError{
	string message;/// A short message teling what went wrong
	uinteger instructionIndex;/// And the instruction number (starting from zero)
}

/// Each interpreter instruction is stored in array as `Instruction`
private alias Instruction = void delegate(QVar);

///All variables and stuff are stored as QVar
union QVar{
	double d;
	string s;
	QVar[] array;
}

/// The main class you need
class QScript{
private:
	//script functions//String
	QVar strConcat(QVar[] args){
		QVar r;
		r.s = args[0].s~args[1].s;
		return r;
	}
	//MATHS
	QVar plusOp(QVar[] args){
		QVar r;
		r.d = args[0].d + args[1].d;
		return r;
	}
	QVar minusOp(QVar[] args){
		QVar r;
		r.d = args[0].d - args[1].d;
		return r;
	}
	QVar divOp(QVar[] args){
		QVar r;
		r.d = args[0].d / args[1].d;
		return r;
	}
	QVar mulOp(QVar[] args){
		QVar r;
		r.d = args[0].d * args[1].d;
		return r;
	}
	QVar moduloOp(QVar[] args){
		QVar r;
		r.d = args[0].d % args[1].d;
		return r;
	}
	//IF
	QVar doIf(QVar[] args){
		if (args[0].d==1){
			ind+=2;//skip the JMP-to-end
		}
		return args[0];
	}
	QVar isEqual(QVar[] args){
		QVar r;
		if (args[0].d==args[1].d || args[0].s == args[1].s){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	QVar isBigger(QVar[] args){
		QVar r;
		if (args[0].d>args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	QVar isBiggerEqual(QVar[] args){
		QVar r;
		if (args[0].d>=args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	QVar isSmaller(QVar[] args){
		QVar r;
		if (args[0].d<args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	QVar isSmalerEqual(QVar[] args){
		QVar r;
		if (args[0].d<=args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	//Datatype Conversion
	QVar toString(QVar[] args){
		QVar r;
		r.s = to!string(args[0].d);
		return r;
	}
	QVar toDouble(QVar[] args){
		QVar r;
		r.d = to!double(args[0].s);
		return r;
	}
	//arrays
	QVar setLength(QVar[] args){
		args[0].array.length = cast(uinteger)args[1].d;
		return args[0];
	}
	QVar getLength(QVar[] args){
		QVar r;
		r.d = args[0].array.length;
		return r;
	}
	QVar initArray(QVar[] args){
		QVar r;
		r.array = args;
		return r;
	}
	QVar readArray(QVar[] args){
		if (args[0].array.length<=args[1].d){
			throw new Exception("array index out of limit: "~to!string(args[1].d)~"/"~
				to!string(args[0].array.length));
		}
		return args[0].array[cast(uinteger)args[1].d];
	}
	QVar modifyArray(QVar[] args){
		QVar r = args[0];
		r.array[cast(uinteger)args[1].d] = args[2];
		return r;
	}
	//Vars
	QVar newVar(QVar[] args){
		QVar r;
		foreach(var; args){
			vars[cast(uinteger)var.d] = r;
		}
		return r;
	}
	//misc functions
	void push(QVar arg){
		stack.push(arg);
	}
	void clear(QVar arg){
		if (arg.d==1){
			stack.clear;
		}
	}
	void jmp(QVar arg){
		ind = cast(uinteger)arg.d;
	}
	void exf(QVar arg){
		string fName = stack.pop.s;
		ScriptFunction* func = fName in fList;
		QVar[] args = stack.pop(cast(uinteger)arg.d);
		if (func){
			(*func)(args);
		}else
		if (fName in calls){
			execF(fName,args);
		}else
		if (onExec){
			onExec(fName,args);
		}else{
			throw new Exception("unrecognized function call: "~fName);
		}
	}
	void exa(QVar arg){
		string fName = stack.pop.s;
		ScriptFunction* func = fName in fList;
		QVar[] args = stack.pop(cast(uinteger)arg.d);
		if (func){
			stack.push((*func)(args));
		}else
		if (fName in calls){
			stack.push(execF(fName,args));
		}else
		if (onExec){
			stack.push(onExec(fName,args));
		}else{
			throw new Exception("unrecognized function call: "~fName);
		}
	}
	void rtv(QVar arg){
		try{
			QVar* v = cast(uinteger)arg.d in vars;
			if (v){
				stack.push(*v);
			}else{
				throw new Exception("trying to retrieve value of undefined variable at index: "~to!string(arg.d));
			}
		}catch(Exception e){
			throw e;
		}
	}
	void stv(QVar arg){
		QVar newVal = stack.pop();
		vars[cast(uinteger)arg.d] = newVal;
	}

	//sdfsdf:
	QVar[uinteger] vars;//this is where the variables live

	//List!QVar stack;
	Stack!QVar stack;
	Instruction[][string] calls;
	uinteger ind;//stores the index of function-to-call from calls
	QVar[][string] callsArgs;

	ScriptFunction[string] fList;

	QVar delegate(string, QVar[]) onExec = null;
	OnErrorFunction onErrorF = null;

	//compile the bytecode into even simpler instructions - final stage of compiling
	void finalCompile(string[][string] script){
		string parseStr(string s){
			string r;
			for (uinteger i=0;i<s.length;i++){
				if (s[i]=='\\'){
					i++;
					switch (s[i]){
						case '\\':
							r~='\\';
							break;
						case 'n':
							r~='\n';
							break;
						case '"':
							r~='"';
							break;
						default:
							break;
					}
				}else{
					r~=s[i];
				}
			}
			return r;
		}
		uinteger i, lineno;
		string token, line;
		QVar arg;
		List!Instruction tmpCalls = new List!Instruction;
		List!QVar tmpArgs = new List!QVar;

		Instruction[string] mList = [
			"psh":&push,
			"clr":&clear,
			"jmp":&jmp,
			"exf":&exf,
			"exa":&exa,
			"rtv":&rtv,
			"stv":&stv
		];

		foreach(fName; script.keys){
			for (lineno=0;lineno<script[fName].length;lineno++){
				line = script[fName][lineno];
				for (i=0;i<line.length;i++){
					if (line[i]==' '){
						token = line[0..i];/*Be sure to not tamper with `token`'s value!
											it's a slice, so it'll modify line[0..i] too!*/
						if (token in mList){
							tmpCalls.add(mList[token]);
						}else{
							throw new Exception("unrecognized instruction: "~token);
						}
						if (i==line.length-1){
							tmpArgs.add(arg);
							//just so that the indexes are synced. this call doesn't need args
						}else{
							token = line[i+1..line.length];
							if (token[0]=='"'){
								//is string
								arg.s = parseStr(token[1..token.length-1]);
							}else{
								arg.d = to!double(token);
							}
							tmpArgs.add(arg);
						}
						break;
					}
				}
			}
			calls[fName] = tmpCalls.toArray;
			tmpCalls.clear;
			callsArgs[fName] = tmpArgs.toArray;
			tmpArgs.clear;
		}
		delete tmpCalls;
		delete tmpArgs;
	}
	QVar execF(string fName, QVar[] args){
		Stack!QVar oldStack = stack;
		uinteger oldInd = ind;
		stack = new Stack!QVar;
		//clear vars
		QVar[uinteger] oldVars;
		foreach(key; vars.keys){
			oldVars[key] = vars[key];
			vars.remove(key);
		}
		//set args
		QVar r;
		r.d = 0;
		vars[0] = r;//0 = result
		r.array = args;
		vars[1] = r;//1 = args

		QVar[] tmArgs;
		Instruction* func;
		QVar arg;
		//start executing
		for (ind = 0;ind<calls[fName].length;ind++){
			try{
				calls[fName][ind](callsArgs[fName][ind]);
			}catch(Exception e){
				if (onErrorF){
					QScriptError error;
					error.message = e.msg;
					error.instructionIndex = ind;
					onErrorF(error);
				}else{
					writeln("Something went wrong in instruction: ",ind,":\n",e.msg);
					write("Enter y to ignore, or just hit enter to abort:");
					if (readln!="y\n"){
						//they didn't enter 'y', they want me to die :(
						throw e;
					}
				}
			}
		}
		//restote previous state
		delete stack;
		stack = oldStack;
		r = vars[0];//o = result
		foreach(key; vars.keys){
			vars.remove(key);
		}
		vars = oldVars;
		ind = oldInd;

		return r;
	}

public:
	this(){
		fList = [
			"_/":&divOp,
			"_*":&mulOp,
			"_+":&plusOp,
			"_-":&minusOp,
			"_%":&moduloOp,
			"_~":&strConcat,
			"if":&doIf,
			"_==":&isEqual,
			"_>":&isBigger,
			"_<":&isSmaller,
			"_>=":&isBiggerEqual,
			"_<=":&isSmalerEqual,
			"string":&toString,
			"double":&toDouble,
			"setLength":&setLength,
			"getLength":&getLength,
			"array":&initArray,
			"_modifyArray":&modifyArray,
			"new":&newVar,
			"_readArray":&readArray,
		];
	}
	/// Loads and compiles a QScript from it's filename
	string[] loadScript(string fName){
		List!string script = new List!string;
		script.loadArray(fileToArray(fName));
		string[][string] byteCode;
		byteCode = compileQScript(script/*, true*/);//uncomment to see compiled output
		delete script;
		string[] r;
		if ("#errors" in byteCode){
			r = byteCode["#errors"];
		}else{
			finalCompile(byteCode);
		}
		return r;
	}
	/// Executes a function from the loaded QScript, that was loaded using `loadScript`
	/// 
	/// Returns what the function returned in the `result` variable
	QVar executeFunction(string name, QVar[] args){
		return execF(name,args);
	}
	/// Specifies the function to call when an undefined function has been called
	/// 
	/// This can be used to add new functions to QScript, and to create an error-reporter
	@property OnExecuteFunction onExecute(OnExecuteFunction execHandler){
		return onExec = execHandler;
	}
	/// Specifies the function to call when an error has occured
	@property OnErrorFunction onError(OnErrorFunction errorHandler){
		return onErrorF = errorHandler;
	}
}