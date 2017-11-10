module qscript.compiler.bytecode;

import qscript.compiler.misc;
import qscript.qscript : QData;

import utils.misc;
import utils.lists;

import std.conv : to;

/// provides functions for dealing with byte code generate using qscript.compiler.codegen
public struct ByteCodeMan{
	/// used to store byte code's instruction in a more readable format
	private struct Instruction{
		string name;
		string[] args;
	}
	/// used to store byte code's function in a more readable format
	private struct Function{
		string name;
		Instruction[] instructions;
	}
	/// reads byte code from string[] into Function[] structs
	private static Function[] readByteCode (string[] byteCode){
		LinkedList!Instruction instructions = new LinkedList!Instruction;
		LinkedList!Function functions = new LinkedList!Function;
		string fName = null;

		for (uinteger i = 0, readFrom = 0, lastind = byteCode.length; i < byteCode.length; i ++){
			string[] lineWords = byteCode[i].readWords;
			if (lineWords.length == 0){
				continue;
			}
			// if only one word && byteCode[i][0]==space/tab, then it's a functionDef start
			if (lineWords.length == 1 && byteCode[i][0] != ' ' || byteCode[i][0] != '\t'){
				// new function start
				if (fName != null){
					// add previous function
					functions.append (Function(fName, instructions.toArray));
				}
				instructions.clear;
				fName = lineWords[0];
			}else{
				// probably a statement
				Instruction inst;
				if (lineWords.length > 1){
					inst = Instruction(lineWords[0], lineWords[1 .. lineWords.length].dup);
				}else{
					inst = Instruction(lineWords[0], []);
				}
				instructions.append(inst);
			}
			// if lastInd, append the last function
			if (i == lastind){
				functions.append (Function(fName, instructions.toArray));
				instructions.clear;
			}
		}
		.destroy(instructions);
		Function[] r = functions.toArray;
		.destroy(functions);
		return r;
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
			continue;
		}else if (line[i] == '['){
			i = line.bracketPos(i);
			continue;
		}else if (line[i] == ' ' || line[i] == '\t' || i == lastInd){
			words.append(line[readFrom .. i]);
			readFrom = i + 1;
			continue;
		}
	}
	string[] r = words.toArray;
	.destroy(words);
	return r;
}