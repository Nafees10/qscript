module qscrmain;

import misc;
import qscript;
import std.string;
import core.memory;
import core.runtime;

Tqscript qscr;

export extern(C) void init(){
	rt_init;
	GC.disable;
	qscr = new Tqscript;
}
export extern(C) void term(){
	delete qscr;
	//rt_term;
}
export extern(C) void onExec(execFunc e){
	qscr.setExecFunc(e);
}
export extern(C) string[] loadScript(string fname){
	string[] er = qscr.loadScript(fileToArray(fname));
	return er;
}
export extern(C) void execute(string name, Tqvar[] args){
	qscr.execute(name,args);
}