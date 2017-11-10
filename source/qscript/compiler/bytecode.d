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
		string name;
		string[] args;
	}
	/// used to store byte code's function in a more readable format
	public struct Function{
		string name;
		Instruction[] instructions;
	}
	/// used to store a function-pointers for instructions in byte code, along with arguments for each of them
	public struct ByteCodeFunction(T){
		string name; /// the name of the function
		T[] instructions; /// the function-pointers
		QData[][] args; /// the arguments for each instruction
	}
	/// reads byte code from string[] into Function[] structs
	public static Function[] readByteCode (string[] byteCode){
		LinkedList!Instruction instructions = new LinkedList!Instruction;
		LinkedList!Function functions = new LinkedList!Function;
		string fName = null;

		for (uinteger i = 0, readFrom = 0, lastind = byteCode.length-1; i < byteCode.length; i ++){
			string[] lineWords = byteCode[i].readWords;
			if (lineWords.length == 0){
				continue;
			}
			// if only one word && byteCode[i][0]==space/tab, then it's a functionDef start
			if (lineWords.length == 1 && byteCode[i][0] != ' ' && byteCode[i][0] != '\t'){
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
	/// converts byte code into array of ByteCodeFunction
	public static ByteCodeFunction!(T)[] toFunctionPtr(T)(string[] byteCode, T[string] instructionsPtr){
		/// searches for jump positions, returns assoc_array containing their indexes
		static uinteger[string] searchJumpPos(Instruction[] instructions){
			uinteger[string] r;
			uinteger instructionCount = 0;
			foreach (i, inst; instructions){
				if (inst.args.length == 0 && inst.name[inst.name.length-1] == ':'){
					// make sure there's actually a name there, not just the colon
					if (inst.name.length <= 1){
						throw new Exception
							("line#"~to!string(i)~": jump position has no name");
					}
					r[cast(string)inst.name[0 .. inst.name.length-1].dup] = instructionCount;
					continue;
				}else{
					instructionCount ++;
				}
			}
			return r;
		}
		/// stores jump indexes
		uinteger[string] jumpIndexes;
		// first, convert it all to Function[]
		Function[] functionsByteCode = readByteCode(byteCode);
		/// makes the array to return
		auto functions = new LinkedList!(ByteCodeFunction!T);
		/// new instructions are appended to this
		auto instructions = new LinkedList!T;
		/// new instructions' args are appended to this
		auto instructionArgs = new LinkedList!(QData[]);
		// do the magic
		foreach (currentFunction; functionsByteCode){
			// get the jump positions
			try{
				jumpIndexes = searchJumpPos(currentFunction.instructions);
			}catch (Exception e){
				e.msg = "function: "~currentFunction.name~' '~e.msg;
				throw e;
			}

			// convert deal with all the jumps
			foreach (i, inst; currentFunction.instructions){
				// check if it's a jump index
				if (inst.name == "jump"){
					// it's a jump 
					// the only arg is typeLess, and in string format, is name of the jumpIndex
					if (inst.args.length != 1){
						throw new Exception
							("function: "~currentFunction.name~" line#"~to!string(i)~": invalid arguments for jump instruction");
					}
					if (inst.args[0] !in jumpIndexes){
						throw new Exception
							("function: "~currentFunction.name~" line#"~to!string(i)~": invalid jump position");
					}
					inst.args[0] = "i"~to!string(jumpIndexes[inst.args[0]]-1);
				}
				// or if it's a jump position marker
				if (inst.name[inst.name.length-1] == ':'){
					continue;
				}
				// finally convert the instruction
				if (inst.name in instructionsPtr){
					instructions.append (instructionsPtr[inst.name]);
					instructionArgs.append (stringToQData(inst.args));
				}else{
					throw new Exception
						("function: "~currentFunction.name~" line#"~to!string(i)~": instruction '"~inst.name~"' not available");
				}
			}
			// put it all in a ByteCodeFunction
			functions.append(ByteCodeFunction!(void delegate())(
					currentFunction.name, // name
					instructions.toArray, // instructions
					instructionArgs.toArray // args
					));
			// clear stuff
			instructions.clear;
			instructionArgs.clear;
		}
		ByteCodeFunction!(T)[] r = functions.toArray;
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