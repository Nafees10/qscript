module app;

import utils.misc;
import utils.lists;

import qscript.compiler.tokengen;
import qscript.compiler.ast;
import qscript.compiler.misc;

void main(){
	const SCR_PATH = "/home/nafees/Desktop/q.qod";
	const XML_PATH = "/home/nafees/Desktop/q.xml";
	string[] script = fileToArray(SCR_PATH);
	TokenList tokens = script.toTokens();
	//make sure there are no errors
	if (compileErrors.count > 0){
		// print the errors
		printErrors(compileErrors.toArray, "tokengen");
	}else{
		// now do the ASTgen
		ASTGen astgen;
		ASTNode scriptNode = astgen.generateAST(tokens);
		// check if errors
		if (compileErrors.count > 0){
			printErrors(compileErrors.toArray, "ASTgen");
		}else{
			// save it in xml form
			string[] xml = toXML(scriptNode);
			// save it to file
			arrayToFile(XML_PATH, xml);
		}
	}
}

void printErrors(CompileError[] errors, string stage){
	import std.stdio;
	writeln("There were errors in ",stage);
	foreach(error; errors){
		writeln("Line#",error.lineno,"; ",error.msg);
	}
}