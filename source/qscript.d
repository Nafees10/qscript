module qscript;

import misc;
import lists;
import compiler;
import std.conv:to;


alias scrFunction = Tqvar delegate(Tqvar[]);

private alias inst = void delegate(Tqvar);

union Tqvar{
	double d;
	string s;
	Tqvar[] array;
}

class Tqscript{
private:
	//script functions//String
	Tqvar strConcat(Tqvar[] args){
		Tqvar r;
		r.s = args[0].s~args[1].s;
		return r;
	}
	//MATHS
	Tqvar plusOp(Tqvar[] args){
		Tqvar r;
		r.d = args[0].d + args[1].d;
		return r;
	}
	Tqvar minusOp(Tqvar[] args){
		Tqvar r;
		r.d = args[0].d - args[1].d;
		return r;
	}
	Tqvar divOp(Tqvar[] args){
		Tqvar r;
		r.d = args[0].d / args[1].d;
		return r;
	}
	Tqvar mulOp(Tqvar[] args){
		Tqvar r;
		r.d = args[0].d * args[1].d;
		return r;
	}
	Tqvar modulusOp(Tqvar[] args){
		Tqvar r;
		r.d = args[0].d % args[1].d;
		return r;
	}
	//IF
	Tqvar doIf(Tqvar[] args){
		uinteger skipBlock=0;
		if (args[0].d!=1){
			ind = cast(uinteger)args[1].d;
		}
		return args[0];
	}
	Tqvar isEqual(Tqvar[] args){
		Tqvar r;
		if (args[0].d==args[1].d || args[0].s == args[1].s){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	Tqvar isBigger(Tqvar[] args){
		Tqvar r;
		if (args[0].d>args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	Tqvar isBiggerEqual(Tqvar[] args){
		Tqvar r;
		if (args[0].d>=args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	Tqvar isSmaller(Tqvar[] args){
		Tqvar r;
		if (args[0].d<args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	Tqvar isSmalerEqual(Tqvar[] args){
		Tqvar r;
		if (args[0].d<=args[1].d){
			r.d=1;
		}else{
			r.d = 0;
		}
		return r;
	}
	//Conversion
	Tqvar toString(Tqvar[] args){
		Tqvar r;
		r.s = to!string(args[0].d);
		return r;
	}
	Tqvar toDouble(Tqvar[] args){
		Tqvar r;
		r.d = to!double(args[0].s);
		return r;
	}
	//arrays
	Tqvar setLength(Tqvar[] args){
		Tqvar* curVar = &vars[args[0].s];
		if (args.length>2){
			uinteger i;
			uinteger till = args.length-1;
			for (i=1;i<till;i++){
				if (args[i].d >= curVar.array.length){
					throw new Exception("index out of limit");
				}
				curVar = &curVar.array[cast(uinteger)args[i].d];
			}
		}
		(*curVar).array.length = cast(uinteger)args[args.length-1].d;
		return args[1];
	}
	Tqvar getLength(Tqvar[] args){
		Tqvar r;
		r.d = args[0].array.length;
		return r;
	}
	//Vars
	Tqvar newVar(Tqvar[] args){
		Tqvar r;
		foreach(var; args){
			vars[var.s] = r;
		}
		return r;
	}
	Tqvar readArray(Tqvar[] args){
		if (args[0].array.length<=args[1].d){
			throw new Exception("index out of limit"~to!string(args[1].d)~"/"~
				to!string(args[0].array.length));
		}
		return args[0].array[cast(uinteger)args[1].d];
	}
	Tqvar getVar(Tqvar[] args){
		if (!(args[0].s in vars)){
			throw new Exception("undefined variable "~args[0].s);
		}
		return vars[args[0].s];
	}
	Tqvar setVar(Tqvar[] args){
		Tqvar val = args[args.length-1];
		if (!(args[0].s in vars)){
			throw new Exception("undefined variable "~args[0].s);
		}
		Tqvar* curVar = &vars[args[0].s];
		Tqvar r;
		if (args.length>2){
			uinteger i;
			uinteger till = args.length-1;
			for (i=1;i<till;i++){
				if (args[i].d >= curVar.array.length){
					throw new Exception("index out of limit");
				}
				curVar = &curVar.array[cast(uinteger)args[i].d];
			}
		}
		(*curVar) = val;
		return r;
	}
	//misc functions
	void push(Tqvar arg){
		stack.push(arg);
	}
	void jmp(Tqvar arg){
		ind = cast(uinteger)arg.d;
	}
	void exf(Tqvar arg){
		string fName = stack.pop.s;
		scrFunction* func = fName in fList;
		Tqvar[] args = stack.pop(cast(uinteger)arg.d);
		if (func){
			(*func)(args);
		}else
		if (fName in calls){
			execF(fName,args);
		}else
		if (onExec){
			onExec(fName,args);
		}else{
			throw new Exception("unrecognized function call "~fName);
		}
	}
	void exa(Tqvar arg){
		string fName = stack.pop.s;
		scrFunction* func = fName in fList;
		Tqvar[] args = stack.pop(cast(uinteger)arg.d);
		if (func){
			stack.push((*func)(args));
		}else
		if (fName in calls){
			stack.push(execF(fName,args));
		}else
		if (onExec){
			stack.push(onExec(fName,args));
		}else{
			throw new Exception("unrecognized function call "~fName);
		}
	}

	//sdfsdf:
	Tqvar[string] vars;

	//List!Tqvar stack;
	Stack!Tqvar stack;
	inst[][string] calls;
	uinteger ind;//stores the index of function-to-call from calls
	Tqvar[][string] callsArgs;

	scrFunction[string] fList;

	Tqvar delegate(string, Tqvar[]) onExec = null;

	//compile2 & all the other functions
	void finalCompile(string[][string] script){
		uinteger i, lineno;
		string token, line;
		Tqvar arg;
		List!inst tmpCalls = new List!inst;
		List!Tqvar tmpArgs = new List!Tqvar;

		inst[string] mList = [
			"psh":&push,
			"jmp":&jmp,
			"exf":&exf,
			"exa":&exa
		];

		foreach(fName; script.keys){
			for (lineno=0;lineno<script[fName].length;lineno++){
				line = script[fName][lineno];
				for (i=0;i<line.length;i++){
					if (line[i]==' '){
						token = line[0..i];
						if (token in mList){
							tmpCalls.add(mList[token]);
						}else{
							throw new Exception("unrecognized function call "~token);
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
	Tqvar execF(string fName, Tqvar[] args){
		Stack!Tqvar oldStack = stack;
		uinteger oldInd = ind;
		stack = new Stack!Tqvar;
		//clear vars
		Tqvar[string] oldVars;
		foreach(key; vars.keys){
			oldVars[key] = vars[key];
			vars.remove(key);
		}
		//set args
		Tqvar r;
		r.d = 0;
		vars["result"] = r;
		r.array = args;
		vars["args"] = r;

		Tqvar[] tmArgs;
		inst* func;
		Tqvar arg;
		//start executing
		for (ind = 0;ind<calls[fName].length;ind++){
			calls[fName][ind](callsArgs[fName][ind]);
		}
		delete stack;
		//restote previous state
		stack = oldStack;
		r = vars["result"];
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
			"_%":&modulusOp,
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
			"new":&newVar,
			"_readArray":&readArray,
			"_?":&getVar,
			"_=":&setVar,
		];
	}
	string[] loadScript(string fName){
		List!string script = new List!string;
		script.loadArray(fileToArray(fName));
		string[][string] byteCode;
		//byteCode = compileQScript(script/*, true*/);//uncomment to see compiled output
		string[] r;
		if ("#####" in calls){
			r = byteCode["#####"];
		}else{
			finalCompile(byteCode);
		}
		return r;
	}
	Tqvar executeFunction(string name, Tqvar[] args){
		return execF(name,args);
	}
	void setOnExec(Tqvar delegate(string, Tqvar[]) e){
		onExec = e;
	}
}