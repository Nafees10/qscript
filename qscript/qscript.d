module qscript;

import misc;
import lists;
import compiler;

class Tqscript{
private:
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
	Tqvar doIf(Tqvar[] args){
		if (args[0].d!=1){
			index = cast(uint)args[1].d;
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
					throw new Exception("index out of bounds");
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
	//vars:
	uint index;
	Tqvar[string] vars;
	scrFunction*[] fCalls;
	uint[] stackInd;
	Tqvar[] pStack;
	Tlist!Tqvar stack;

}