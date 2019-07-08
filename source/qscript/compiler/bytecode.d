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
		/// these are stored as string instead of QData so its possible to generate readable byte code
		string[] args;
	}
	/// used to store byte code's function in a more readable format
	public struct Function{
		/// id of the function
		uinteger id;
		/// byte code style (byte code encoded) name of this function
		string name;
		/// instructions that make up this function
		Instruction[] instructions;
		/// The stack that's loaded before this function is executed
		StackElement[] stack;
	}

	/// stores the functions with their instructions
	public ByteCode.Function[] functions;
	/// generates a readable string representation of this byte code
	/// 
	/// Note: at this point, only generating this is supported, there is no way to generate a ByteCode back from this. Only for debugging
	public string[] tostring(){
		List!string code = new List!string;
		// append the function map
		code.append("functions:");
		/// same as this.functions, but sorted by id
		ByteCode.Function[] sortedFuncs;
		sortedFuncs.length = functions.length;
		for (uinteger i=0; i < functions.length; i ++){
			sortedFuncs[functions[i].id] = functions[i];
		}
		// write them to byte code
		foreach (func; sortedFuncs){
			code.append("\t"~func.name);
		}
		// now start with the functions
		foreach (func; sortedFuncs){
			code.append([to!string(func.id),
					"stack:"]);
			// first do the stack
			foreach (element; func.stack){
				if (element.type == ByteCode.StackElement.Type.Literal){
					code.append("\t"~element.literal);
				}else if (element.type == ByteCode.StackElement.Type.Reference){
					code.append("\t@"~to!string(element.refIndex));
				}
			}
			// then the instructions
			code.append("instructions:");
			foreach (instruction; func.instructions){
				// put the args in a single string
				string args = "";
				foreach (arg; instruction.args){
					args ~= arg;
				}
				code.append("\t"~instruction.name~" "~args);
			}
		}
	}
}

// some misc. functions

/// reads "words" (instruction name, and arguments) into string[] from string
private static string[] readWords(string line){
	// first remove whitespace from it
	line = line.removeWhitespace('#');
	auto words = new LinkedList!string;
	for (uinteger i = 0, readFrom = 0, lastInd = line.length-1; i < line.length; i ++){
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
