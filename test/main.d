module main;

import core.memory;
import std.stdio;
import qloader;

class Test{
private:
	Tqvar qwrite(Tqvar[] args){
		foreach(arg; args){
			write(arg.s);
		}
		return args[0];
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
			throw new Exception("unknow function "~name);
		}
		return r;
	}
}

void main(string[] args){
	GC.disable();
	Tqloader qscr = new Tqloader;
	Test tst = new Test;
	string[] r = qscr.loadScript("/home/nafees/Desktop/q.qod");
	if (r.length>0){
		writeln("There are errors:");
		foreach(err; r){
			writeln(err);
		}
	}else{
		qscr.setExec(&tst.call);
		qscr.execute("main",[/*NO ARGS*/]);
	}
	delete tst;
	delete qscr;
}