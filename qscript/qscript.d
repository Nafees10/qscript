module qscript;

import misc;
import lists;
import compiler;

class Tqscript{
private:
	//script functions
	void clearStack(){
		stack.clear;
	}
	void callExternal(){
		//TODO: Implement this
	}
	void mathOp(){
		Tqvar[3] args;
	}
	//vars:
	uint index;
	Tqvar[string] vars;
	scrFunction*[][string] fCalls;
	uint[][string] stackInd;
	Tqvar[][string] pStack;
	Tlist!Tqvar stack;


}