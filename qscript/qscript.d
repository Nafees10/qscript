module qscript;

import misc;
import lists;
import qcompiler;
import std.stdio;
import std.conv:to;

alias scriptFunction = Tqvar delegate(Tqvar[]);
alias execProc = Tqvar delegate(string name,Tqvar[]);

class Tqscript{
private:
	//String
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
		uint skipBlock=0;
		if (!args[0].d){
			if (scr.read==codes["endAt"]){
				skipBlock = decodeNum(scr.read);
				scr.position(scr.position+skipBlock-1);
			}
		}
		return args[0];
	}
	Tqvar isEqual(Tqvar[] args){
		Tqvar r;
		if (args[0]==args[1]){
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
			uint i;
			uint till = args.length-1;
			for (i=1;i<till;i++){
				if (args[i].d >= curVar.array.length){
					throw new Exception("index out of limit");
				}
				curVar = &curVar.array[cast(uint)args[i].d];
			}
		}
		(*curVar).array.length = cast(uint)args[args.length-1].d;
		return args[1];
	}
	Tqvar getLength(Tqvar[] args){
		Tqvar r;
		r.d = args[0].array.length;
		return r;
	}
	//loop again
	Tqvar again(Tqvar[] args){
		scr.position(loops.readLast);
		loops.del(loops.count-1);
		Tqvar r;
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
		return args[0].array[cast(uint)args[1].d];
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
			uint i;
			uint till = args.length-1;
			for (i=1;i<till;i++){
				if (args[i].d >= curVar.array.length){
					throw new Exception("index out of limit");
				}
				curVar = &curVar.array[cast(uint)args[i].d];
			}
		}
		(*curVar) = val;
		return r;
	}

	//Args fetcher
	Tqvar[] solveArgs(){
		Tlist!Tqvar r = new Tlist!Tqvar;
		Tqvar tmVar;
		string line;
		uint dcs=1;
		while (true){
			line = cast(string)scr.read;
			if (line==codes["end"]){
				break;
			}else
			if (line==codes["call"]){
				r.add(call);
			}else
			if (line==codes["numArg"]){
				tmVar.d = decodeNum(cast(string)scr.read);
				r.add(tmVar);
			}else
			if (line==codes["strArg"]){
				tmVar.s = cast(string)scr.read;
				r.add(tmVar);
			}
		}
		Tqvar[] ret = r.toArray;
		delete r;
		return ret;
	}

	Tqvar call(){
		uint currPos = scr.position-1;//current pos is towards name, but we want \002
		string name = scr.read;
		scriptFunction* f;
		Tqvar r;
		Tqvar[] tmArgs = solveArgs;

		if (name[0]=='!'){
			f = name in pList;
			if (f){
				r = (*f)(tmArgs);
				if (name=="!while"){
					loops.add(currPos);
				}
			}else{
				throw new Exception("undefined function call: "~name);
			}
		}else if (name in fStream){
			r = execF(name, tmArgs);
		}else{
			r = onExec(name, tmArgs);
		}
		return r;
	}
	//To execute functions defined in script

	Tqvar execF(string name, Tqvar[] args){
		Tqvar r;
		Tqvar[string] currVars = vars;
		TbinReader prevScr = scr;
		scr = new TbinReader(fStream[name]);
		//clear the var container
		foreach (key; vars.keys){
			vars.remove(key);
		}
		//Put args in vars
		vars["args"]=r;//r is just a placeholder, just put any Tqvar, so I placed r
		vars["args"].array.length=args.length;
		for (uint i=0;i<args.length;i++){
			vars["args"].array[i]=args[i];
		}
		//init the var that'll contain result;
		vars["result"]=r;
		//start executing;
		uint till = scr.size;
		while (scr.position<till){
			if (scr.read()==codes["call"]){
				call;
			}
		}

		r=vars["result"];

		scr = prevScr;
		vars = currVars;
		return r;
	}

	Tqvar[string] vars;//use as vars[varname][index]
	string[][string] fStream;//stream, to contain extracted functions

	string[string] codes;
	TbinReader script=null;//To contain the compiled script
	TbinReader scr=null;//To contain byte code for currently executng function
	Tlist!uint loops;//To contain address to previous while-start to make loops faster
	scriptFunction[string] pList;//To contain all script functions

	execProc onExec;
public:
	this(){
		//define the binary codes for interpretation
		codes=[
			"sp":cast(string)[0],
			"function":cast(string)[1],
			"call":cast(string)[2],
			//IDK why I didn't use \003
			"numArg":cast(string)[4],
			"strArg":cast(string)[5],
			"end":cast(string)[6],
			"endAt":cast(string)[7],
			"endF":cast(string)[8],
			//"startAt":to!string(cast(char)9)//again, I have no idea why I wrote it, but I don't want to remove it...
		];
		//And put together the list of builtin functions
		pList=[
			"!/":&divOp,
			"!*":&mulOp,
			"!+":&plusOp,
			"!-":&minusOp,
			"!%":&modulusOp,
			"!~":&strConcat,
			"!if":&doIf,
			"!while":&doIf,
			"!==":&isEqual,
			"!>":&isBigger,
			"!<":&isSmaller,
			"!>=":&isBiggerEqual,
			"!<=":&isSmalerEqual,
			"!string":&toString,
			"!double":&toDouble,
			"!setLength":&setLength,
			"!getLength":&getLength,
			"!again":&again,
			"!new":&newVar,
			"![":&readArray,
			"!?":&getVar,
			"!=":&setVar
		];
		loops = new Tlist!uint;
	}
	~this(){
		delete script;
		delete loops;
		delete scr;
	}
	string[] loadScript(string[] s){
		//If previously loaded, free it!
		if (script){delete script;}

		Tlist!string sLst = new Tlist!string();
		sLst.loadArray(s);
		writeln(sLst.count," lines loaded.");
		writeln("original length:",s.length);
		string[] errors = compile(sLst);
		//Then create it
		if (errors.length==0){
			delete errors;
			errors = null;
			//Load the functions/script
			script = new TbinReader(sLst.toArray);
			fStream = script.extractFunctions;
		}
		delete sLst;

		return errors;
	}
	void execute(string name, Tqvar[] args=[]){
		if (!script){
			throw new Exception("no script loaded");
		}else{
			execF(name,args);
		}
	}
	void setExecProc(execProc e){
		onExec = e;
	}
}