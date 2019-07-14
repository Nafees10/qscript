/++
To load/read bytecode
+/
module qscript.compiler.bytecode;

import qscript.compiler.misc;
import qscript.qscript : QData;

import utils.misc;
import utils.lists;

import std.conv : to;
import core.vararg;

/// provides functions for dealing with byte code generate using qscript.compiler.codegen
public class ByteCode{
	/// stores an element on the fucntion stack. The stack is made by simply making aray of this. Also used to store instruction args
	public struct Data{
		/// possible types of element
		enum Type{
			Reference, /// a reference to another element in same stack
			Literal, /// a literal QData
			Empty, /// leaves the element un-initialized. Use this if this space is to be used at runtime
			nill, /// would name this null but keyword. Use this if this just exists to eat space, never used
		}
		/// stores the type this StackElement is
		public Type type = this.Type.Empty;
		/// stores the literal QData in byte code encoded format. Only valid if type==Type.literal
		public string literal;
		/// stores the index of the element being referenced. Only valid if type==Type.Reference
		public uinteger refIndex;
		/// constructor - type only
		this (ByteCode.Data.Type type){
			this.type = type;
		}
		/// constructor - for type=Type.Literal (string)
		this (string literalString){
			this.literal = QData(literalString).toByteCode(DataType(DataType.Type.String));
			type = this.Type.Literal;
		}
		/// constructor - for type=Type.Literal (integer)
		this (integer literalInt){
			this.literal = QData(literalInt).toByteCode(DataType(DataType.Type.Integer));
			type = this.Type.Literal;
		}
		/// constructor - for integers and references.
		this (uinteger literalInt, bool isRef=false){
			if (isRef){
				this.refIndex = literalInt;
				this.type = this.Type.Reference;
			}else{
				this.literal = QData(cast(uinteger)literalInt).toByteCode(DataType(DataType.Type.Integer));
				type = this.Type.Literal;
			}
		}
		/// constructor - for type=Type.Literal (double)
		this (double literalDouble){
			this.literal = QData(literalDouble).toByteCode(DataType(DataType.Type.Double));
			type = this.Type.Literal;
		}
		/// constructor - for when type is some array
		this (QData data, DataType dataType){
			this.literal = data.toByteCode(dataType);
			type = this.Type.Literal;
		}
		/// Returns: a byte code representation of this in string
		string toByteCode(){
			if (this.type == this.Type.Reference)
				return "\t@"~to!string(refIndex);
			else if (this.type == this.Type.Empty)
				return "\t0";
			else if (this.type == this.Type.nill)
				return "\tnull";
			else
				return literal;
		}
	}
	/// used to store byte code's instruction in a more readable format
	public struct Instruction{
		/// instruction name
		string name;
		/// arguments of instruction.
		Data[] args;
		/// constructor
		this (string name, Data[] args){
			this.name = name;
			this.args = args.dup;
		}
		/// constructor. The var_args are args for instruction.
		/// 
		/// They can be of these types (in this constructor):  
		/// 1. ByteCode.Data.Type - for use with ByteCode.Data.Type.Empty  
		/// 2. string  
		/// 3. integer/uinteger (both are stored as a signed integer, refs not possible using this)  
		/// 4. double
		this (string name, ...){
			this.name = name;
			this.args.length = _arguments.length;
			for (uinteger i=0; i < _arguments.length; i++){
				if (_arguments[i] == typeid(ByteCode.Data.Type)){
					this.args[i] = Data(va_arg!(ByteCode.Data.Type)(_argptr));
				}else if (_arguments[i] == typeid(string)){
					this.args[i] = Data(va_arg!(string)(_argptr));
				}else if (_arguments[i] == typeid(integer)){
					this.args[i] = Data(va_arg!(integer)(_argptr));
				}else if (_arguments[i] == typeid(uinteger)){
					this.args[i] = Data(va_arg!(uinteger)(_argptr));
				}else if (_arguments[i] == typeid(double)){
					this.args[i] = Data(va_arg!(double)(_argptr));
				}
			}
		}
		/// Returns: a byte code representation of this in string
		string toByteCode(){
			// put the args in a single string
			string argsStr = "";
			foreach (arg; args){
				string argBC = arg.toByteCode;
				argsStr = argBC[1 .. argBC.length];// remove that `\t` from start
			}
			return "\t"~name~" "~argsStr;
		}
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
		Data[] stack;
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
				code.append(element.toByteCode);
			}
			// then the instructions
			code.append("instructions:");
			foreach (instruction; func.instructions){
				code.append(instruction.toByteCode);
			}
		}
		string[] r = code.toArray;
		.destroy(code);
		return r;
	}
}

/// contains some functions to make it easier to generate byte code in CodeGen
package class ByteCodeWriter{
private:
	/// the ByteCode to write to
	ByteCode code;
	/// the current function's id to which instructions and stack elements are added to
	uinteger funcId;
	/// the current function's name to which instruction and stack elements are added to
	string funcName;
	/// the stack of the current function
	List!(ByteCode.Data) funcStack;
	/// the instructions for the current function
	List!(ByteCode.Instruction) funcInstructions;
	/// stores indexes of elements to be added to a "bundle"
	List!uinteger[uinteger] bundles;
public:
	/// constructor
	this(ByteCode bCode){
		code =  bCode;
		funcStack = new List!(ByteCode.Data);
		funcInstructions = new List!(ByteCode.Instruction);
	}
	/// destructor
	~this(){
		.destroy (funcStack);
		.destroy (funcInstructions);
		foreach (id, bundle; bundles){
			.destroy (bundle);
			bundles.remove (id);
		}
	}
	/// sets current function to a new function
	/// 
	/// the `name` and `id` must be unique. And if any function was being edited before this, that must be appended first before calling this 
	/// 
	/// Returns: true if successful, false if not, in case name or id is already used, or if last function was not appended
	bool setCurrentFunction(string name, uinteger id){
		// make sure last function was appended
		if (funcStack.length + funcInstructions.length > 0)
			return false;
		// make sure name and id are unique
		foreach (func; code.functions){
			if (func.name == name || func.id == id)
				return false;
		}
		funcId = id;
		funcName = name;
		return true;
	}
	/// call this when done adding instructions and stack elements to a function.
	/// This adds that function to the ByteCode.
	/// 
	/// Returns: true if successful, false if not (in case funcName is empty, or id not unique)
	bool appendFunction(){
		// recheck if id and name are unique, this is necessary because `code` can be modified outside from this class
		foreach (func; code.functions){
			if (func.name == funcName || func.id == funcId)
				return false;
		}
		code.functions ~= ByteCode.Function(funcId, funcName, funcInstructions.toArray, funcStack.toArray);
		// clear the stack and instructions for next function
		funcStack.clear;
		funcInstructions.clear;
		return true;
	}
	/// adds an instruction
	void appendInstruction(ByteCode.Instruction inst){
		funcInstructions.append(inst);
	}
	/// adds a stack element
	void appendStack(ByteCode.Data element){
		funcStack.append(element);
	}
	/// sets the value of an instruction at an index
	/// 
	/// Returns: true if done, false if index out of bounds
	bool setInstruction(uinteger index, ByteCode.Instruction inst){
		if (index >= funcInstructions.length)
			return false;
		funcInstructions.set(index, inst);
		return true;
	}
	/// sets the value of a stack element at an index
	/// 
	/// Returns: true if done, false if index out of bounds
	bool setStackElement(uinteger index, ByteCode.Data element){
		if (index >= funcStack.length)
			return false;
		funcStack.set(index, element);
		return true;
	}
	/// Returns: index of last instruction appended
	///
	/// Throws: Exception if no instructions are present
	@property uinteger lastInstructionIndex(){
		if (funcInstructions.length == 0)
			throw new Exception("no instruction present");
		return funcInstructions.length-1;
	}
	/// Returns: index of last stack element appended
	///
	/// Throws: Exception if no stack elements are present
	@property uinteger lastStackElementIndex(){
		if (funcStack.length == 0)
			throw new Exception("no stack element present");
		return funcStack.length-1;
	}
	/// Returns: number of instructions
	@property uinteger instructionCount(){
		return funcInstructions.length;
	}
	/// Returns: number of stack elements
	@property uinteger stackElementCount(){
		return funcStack.length;
	}
	/// creates a new bundle.
	/// 
	/// A bundle is just consecutive elements in stack, that are references to other elements. This is necessary because instructions 
	/// need data on stack in certain order, and to be consecutive, in case it is not, a bundle is used.
	/// 
	/// Returns: the bundle id, this is used to identify this bundle in other functions.
	uinteger newBundle(){
		// look for a un-used id
		uinteger i;
		for (i = 0; ;i ++){
			if (i !in bundles)
				break;
		}
		bundles[i] = new List!uinteger;
		return i;
	}
	/// appends a stack element to bundle.
	/// 
	/// Returns: true if done, false if not (in case the bundle doesn't exist)
	bool appendToBundle(uinteger bundle, uinteger index){
		if (bundle !in bundles)
			return false;
		bundles[bundle].append(index);
		return true;
	}
	/// appends the last stack element to bundle.
	/// 
	/// Returns: true if done, false if not (in case the bundle doesn't exist, or no element on stack)
	bool appendToBundle(uinteger bundle){
		if (bundle !in bundles)
			return false;
		try{
			bundles[bundle].append(lastStackElementIndex);
		}catch (Exception e){
			.destroy (e);
			return false;
		}
		return true;
	}
	/// appends the bundle to stack, if necessary. If the elements are already in order, and consecutive, nothing is done.
	/// After calling this, that bundle id is disassociated.
	/// 
	/// Returns: true if done, false if that bundle doesn't exist
	bool appendBundle(uinteger bundle){
		if (bundle !in bundles)
			return false;
		List!uinteger bundleElements = bundles[bundle];
		// bundle needs to be appended at all
		if (bundleElements.length > 0){
			// if it needs to append bundle separately
			bool needsToAppend = false;
			// check if elements are already at end of stack
			if (bundleElements.readLast == lastInstructionIndex){
				// now just make sure they're in order
				for (uinteger i=1, lastRead=bundleElements.read(0); i < bundleElements.length; i++){
					if (bundleElements.read(i) != lastRead){
						needsToAppend = true;
						break;
					}
					lastRead = bundleElements.read(i);
				}
			}else
				needsToAppend = true;
			if (needsToAppend){
				foreach (index; bundleElements.toArray){
					funcStack.append(ByteCode.Data(index, true));
				}
			}
		}
		.destroy(bundles[bundle]);
		bundles.remove (bundle);
		return true;
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
