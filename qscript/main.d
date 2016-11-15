module main;

import misc;
import lists;
import qscript;
import compiler;
import std.stdio;

class Tqfuncs{
private:
	Tqvar qwrite(Tqvar[] args){
		foreach(arg; args){
			write(arg.s);
		}
		Tqvar r;
		return r;
	}
	Tqvar qread(Tqvar[] args){
		Tqvar r;
		r.s = readln;
		r.s.length--;
		return r;
	}
	Tqvar delegate(Tqvar[])[string] pList;
public:
	this(){
		pList = [
			"qwrite":&qwrite,
			"qread":&qread
		];
	}
	Tqvar call(string name, Tqvar[] args){
		Tqvar r;
		if (name in pList){
			r = pList[name](args);
		}else{
			throw new Exception("unrecognized function call "~name);
		}
		return r;
	}
}

void main(string[] args){
	/*Tlist!string script = new Tlist!string;
	script.loadArray(fileToArray("/home/nafees/Desktop/q.qod"));
	compileQScript(script, true);*/
	Tqscript scr = new Tqscript;
	Tqfuncs scrF = new Tqfuncs;
	scr.loadScript(args[0]);
	scr.setOnExec(&scrF.call);
	scr.executeFunction("main",[]);
	delete scr;
	delete scrF;
}