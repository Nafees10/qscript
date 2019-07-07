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
public class ByteCode{
	/// stores an element on the fucntion stack. The stack is made by simply making aray of this
	public struct StackElement{
		/// possible types of element
		enum Type{
			Reference, /// a reference to another element in same stack
			Literal, /// a literal QData
		}
		/// stores the type this StackElement is
		public Type type;
		/// stores the literal QData in byte code encoded format. Only valid if type==Type.literal
		public string literal;
		/// stores the index of the element being referenced. Only valid if type==Type.Reference
		public uinteger refIndex;
	}
	/// used to store byte code's instruction in a more readable format
	public struct Instruction{
		/// instruction name
		string name;
		/// arguments of instruction. These are written in the byte code encoded way
		///
		/// these are stored as string instead of QData so its possible to generate readable byte code\
		string[] args;
	}
	/// used to store byte code's function in a more readable format
	public struct Function{
		/// id of the function
		uinteger id;
		/// instructions that make up this function
		Instruction[] instructions;
		/// The stack that's loaded before this function is executed
		StackElement[] stack;
	}
	/// stores the funtion map. Maps function id to their names
	public string[uinteger] functionMap;
	/// stores the functions with their instructions. id is the function id
	public Function[uinteger] functions;
	// functions to help codegen generate byte code
	package{
		// TODO add functions to help codegen
	}
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
