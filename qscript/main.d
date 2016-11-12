module main;

import misc;
import lists;
import std.stdio;
import compiler;

void main(string[] args){
	Tlist!string script = new Tlist!string;
	script.loadArray(fileToArray("/home/nafees/Desktop/q.qod"));
	compileQScript(script);
	readln;
}