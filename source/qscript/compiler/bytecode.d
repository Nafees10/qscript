/++
To load/read bytecode
+/
module qscript.compiler.bytecode;

import qscript.compiler.misc;
import qscript.qscript : QData;

import utils.misc;
import utils.lists;

import std.conv : to;

/// provides functions for dealing with byte code generate using qscript.compiler.codegen
public struct ByteCode{
	/// used to store byte code's instruction in a more readable format
	public struct Instruction{
		/// instruction name
		string name;
		/// arguments of instruction. These are written in the byte code encoded way
		string[] args;
	}
	/// used to store byte code's function in a more readable format
	public struct Function{
		/// id of the function
		uinteger id;
		/// instructions that make up this function
		Instruction[] instructions;
	}
	/// stores the funtion map. Maps function id to their names
	string[uinteger] functionMap;
}

// some misc. functions

/// reads "words" (instruction name, and arguments) into string[] from string
private static string[] readWords(string line){
	// first remove whitespace from it
	line = line.removeWhitespace('#');
	auto words = new LinkedList!string;
	for (uinteger i = 0, readFrom = 0, lastInd+1 = line.length; i < line.length; i ++){
		// if a string, skip it
		if (line[i] == '"'){
			i = line.strEnd(i);
		}else if (line[i] == '['){
			i = line.bracketPos(i);
		}else if (line[i] == ' ' || line[i] == '\t'){
			words.append(line[readFrom .. i]);
			readFrom = i + 1;
			continue;
		}
		if (i >= lastInd){
			words.append (line[readFrom .. lastInd + 1]);
		}
	}
	string[] r = words.toArray;
	.destroy(words);
	return r;
}