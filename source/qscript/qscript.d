/++
Contains everything needed to run QScript scripts.
+/
module qscript.qscript;

import utils.misc;
import utils.lists;

import qscript.compiler.compiler;

import std.conv:to;

import navm.navm;
import navm.bytecode;
import navm.defs : ArrayStack;

alias ExternFunction = NaData delegate(NaData[]);
alias NaData = navm.navm.NaData;
alias CompileError = qscript.compiler.compiler.CompileError;

/// To store a library (could be a script as a library as well)
public class Library{
private:
	/// if this library is automatically imported
	bool _autoImport;
	/// name of library
	string _name;
	/// functions exported by library. The index is function ID.
	Function[] _functions;
	/// global variables exported by this library. index is ID
	Variable[] _vars;
	/// structs exported by library
	Struct[] _structs;
	/// Enums exported by library
	Enum[] _enums;
public:
	/// constructor
	this(string name, bool autoImport = false){
		_name = name;
		this._autoImport = autoImport;
	}
	/// if this library is automatically imported
	@property bool autoImport(){
		return _autoImport;
	}
	/// library name
	@property string name(){
		return _name;
	}
	/// functions exported by library. The index is function ID.
	@property Function[] functions(){
		return _functions;
	}
	/// Adds a new function
	/// 
	/// Returns: function ID, or -1 if function already exists
	integer addFunction(Function func){
		if (this.hasFunction(func.name, func.argTypes)!=-1)
			return -1;
		_functions ~= func;
		return cast(integer)_functions.length-1;
	}
	/// global variables exported by this library. index is ID
	@property ref Variable[] vars(){
		return _vars;
	}
	/// Adds a new variable.
	/// 
	/// Returns: Variable ID, or -1 if it already exists
	integer addVar(Variable var){
		if (this.hasVar(var.name))
			return -1;
		_vars ~= var;
		return cast(integer)_vars.length-1;
	}
	/// structs exported by library
	@property ref Struct[] structs(){
		return _structs;
	}
	/// Adds a new struct
	/// 
	/// Returns: struct ID, or -1 if already exists
	integer addStruct(Struct str){
		if (this.hasStruct(str.name))
			return -1;
		_structs ~= str;
		return cast(integer)_structs.length-1;
	}
	/// Enums exported by library
	@property ref Enum[] enums() {
		return _enums;
	}
	/// Adds a new enum
	/// 
	/// Returns: enum ID, or -1 if it already exists
	integer addEnum(Enum enu){
		if (this.hasEnum(enu.name))
			return -1;
		_enums ~= enu;
		return cast(integer)_enums.length-1;
	}
	/// Returns: true if struct exists
	bool hasStruct(string name, ref Struct str){
		foreach (currentStruct; _structs){
			if (currentStruct.name == name){
				str = currentStruct;
				return true;
			}
		}
		return false;
	}
	/// ditto
	bool hasStruct(string name){
		foreach (currentStruct; _structs){
			if (currentStruct.name == name)
				return true;
		}
		return false;
	}
	/// Returns: true if enum exists
	bool hasEnum(string name, ref Enum enu){
		foreach (currentEnum; _enums){
			if (currentEnum.name == name){
				enu = currentEnum;
				return true;
			}
		}
		return false;
	}
	/// ditto
	bool hasEnum(string name){
		foreach (currentEnum; _enums){
			if (currentEnum.name == name)
				return true;
		}
		return false;
	}
	/// Returns: variable ID, or -1 if doesnt exist
	integer hasVar(string name, ref DataType type){
		foreach (i, var; _vars){
			if (var.name == name){
				type = var.type;
				return i;
			}
		}
		return -1;
	}
	/// Returns: true if variable exists
	bool hasVar(string name){
		foreach (var; _vars){
			if (var.name == name)
				return true;
		}
		return false;
	}
	/// Returns: function ID, or -1 if doesnt exist
	integer hasFunction(string name, DataType[] argsType, ref bool argTypesMatch, ref DataType returnType){
		argTypesMatch = false;
		foreach (i, func; _functions){
			if (func.name == name){
				if (argsType.length == func.argTypes.length){
					foreach (j; 0 .. argsType.length){
						if (!argsType[j].canImplicitCast(func.argTypes[j])){
							argTypesMatch = false;
							break;
						}
					}
				}
				returnType = func.returnType;
				return i;
			}
		}
		return -1;
	}
	/// ditto
	integer hasFunction(string name, DataType[] argsType){
		bool argsTypesMatch;
		DataType returnType;
		return this.hasFunction(name, argsType, argsTypesMatch, returnType);
	}
	/// Returns: true if a function by a name exists
	bool hasFunction(string name){
		foreach (func; _functions){
			if (func.name == name)
				return true;
		}
		return false;
	}
	/// Generates bytecode for a function call, or return false
	/// 
	/// Returns: true if it added code for the function call, false if codegen.d should
	bool generateFunctionCallCode(NaBytecode bytecode, uinteger functionId, DataType[] argTypes){
		return false;
	}
	/// Generates bytecode that will push value of a variable to stack, or return false
	/// 
	/// Returns: true if it added code, false if codegen.d should
	bool generateVariableValueCode(NaBytecode bytecode, uinteger variableId){
		return false;
	}
	/// Generates bytecode that will push reference of a variable to stack, or return false
	/// 
	/// Returns: true if code added, false if not
	bool generateVariableRefCode(NaBytecode bytecode, uinteger variableId){
		return false;
	}
	/// Generates code that will write a value to a variable, or return false
	/// 
	/// Returns: true if code added, false if not
	bool generateVariableWriteCode(NaBytecode bytecode, uinteger variableId){
		return false;
	}
	/// Executes a library function
	/// 
	/// Returns: whatever that function returned
	NaData execute(uinteger functionId, NaData[] args){
		return NaData(0);
	}
	/// Returns: value of a variable
	NaData getVar(uinteger varId){
		return NaData(0);
	}
	/// Sets value of a variable
	void setVar(uinteger varId, NaData value){}
	/// Writes this library to a single printable string
	/// 
	/// Returns: string representing contents of this library
	override string toString(){
		char[] r = cast(char[])"library|"~name~'|'~_autoImport.to!string~'|';
		foreach (func; _functions)
			r ~= func.toString ~ '/';
		r ~= '|';
		foreach (str; _structs)
			r ~= str.toString ~ '/';
		r ~= '|';
		foreach (enu; _enums)
			r ~= enu.toString ~ '/';
		r ~= '|';
		foreach (var; _vars)
			r ~= var.toString ~ '/';
		r ~= '|';
		return cast(string)r;
	}
	/// Reads this library from a string (reverse of toString)
	/// 
	/// Returns: empty string in case of success, error in string in case of error
	string fromString(string libraryString){
		string[] vals = commaSeparate!('|',false)(libraryString);
		if (vals.length < 7 || vals[0] != "library")
			return "invalid string to read Library from";
		_name = vals[1];
		_autoImport = vals[2] == "true" ? true : false;
		vals = vals[3 .. $];
		string[] subVals = vals[0].commaSeparate!'/';
		string error;
		_functions = [];
		_structs = [];
		_enums = [];
		_vars = [];
		_functions.length = subVals.length;
		foreach (i, val; subVals){
			error = _functions[i].fromString(val);
			if (error.length)
				return error;
		}
		subVals = vals[1].commaSeparate!'/';
		_structs.length = subVals.length;
		foreach (i, val; subVals){
			error = _structs[i].fromString(val);
			if (error.length)
				return error;
		}
		subVals = vals[2].commaSeparate!'/';
		_enums.length = subVals.length;
		foreach (i, val; subVals){
			error = _enums[i].fromString(val);
			if (error.length)
				return error;
		}
		subVals = vals[3].commaSeparate!'/';
		_vars.length = subVals.length;
		foreach (i, val; subVals){
			error = _vars[i].fromString(val);
			if (error.length)
				return error;
		}
		return [];
	}
}
/// 
unittest{
	Library dummyLib = new Library("dummyLib",true);
	dummyLib.addEnum(Enum("Potatoes",["red","brown"]));
	dummyLib.addEnum(Enum("Colors", ["red", "brown"]));
	dummyLib.addFunction(Function("main",DataType("void"),[DataType("char[][]")]));
	dummyLib.addFunction(Function("add",DataType("int"),[DataType("int"),DataType("int")]));
	dummyLib.addVar(Variable("abc",DataType("char[]")));
	Library loadedLib = new Library("blabla",false);
	loadedLib.fromString(dummyLib.toString);
	assert(loadedLib.name == dummyLib.name);
	assert(loadedLib._autoImport == dummyLib._autoImport);
	assert(loadedLib._functions == dummyLib._functions);
	assert(loadedLib._structs == dummyLib._structs);
	assert(loadedLib._enums == dummyLib._enums);
	assert(loadedLib._vars == dummyLib._vars);
}

private class QScriptVM : NaVM{
private:
	Library[] _libraries;
	NaData _retVal;
protected:
	void call(){
		immutable uinteger libId = _stack.pop.intVal, funcID = _stack.pop.intVal;
		NaData[] args = _stack.pop(_arg.intVal-2);
		_stack.push(_libraries[libId].execute(funcID, args));
	}
	void retValSet(){
		_retVal = _stack.pop;
	}
	void retValPush(){
		_stack.push(_retVal);
		_retVal.intVal = 0;
	}

	void arrayCopy(){
		_stack.push(NaData(_stack.pop.arrayVal));
	}
	void arrayElement(){
		_stack.push(*(_stack.pop.ptrVal + _arg.intVal));
	}
	void arrayElementWrite(){
		// left side should evaluate first (if my old comments are right)
		*(_stack.pop.ptrVal + _arg.intVal) = _stack.pop;
	}

	void jumpFrameN(){
		import navm.defs : StackFrame;
		immutable uinteger offset = _stack.pop.intVal;
		_jumpStack.push(StackFrame(_inst, _arg, _stackIndex));
		_inst = &(_instructions)[_arg.intVal] - 1;
		_arg = &(_arguments)[_arg.intVal] - 1;
		_stackIndex = _stack.count - offset;
	}
public:
	/// constructor
	this(uinteger stackLength = 65_536){
		super(stackLength);
		addInstruction(NaInstruction("call",0x40,true,255,1,&call));
		addInstruction(NaInstruction("retValSet",0x41,1,0,&retValSet));
		addInstruction(NaInstruction("retValPush",0x42,0,1,&retValPush));
		addInstruction(NaInstruction("arrayCopy",0x43,1,1,&arrayCopy));
		addInstruction(NaInstruction("arrayElement",0x44,true,1,1,&arrayElement));
		addInstruction(NaInstruction("arrayElementWrite",0x45,true,2,0,&arrayElementWrite));
		addInstruction(NaInstruction("jumpFrameN",0x56,true,true,1,0,&jumpFrameN));
	}
	/// The VM's stack
	@property ArrayStack!NaData stack(){
		return _stack;
	}
	/// The VM's _stackIndex
	@property uinteger stackIndex(){
		return _stackIndex;
	}
	/// ditto
	@property uinteger stackIndex(uinteger newVal){
		return _stackIndex = newVal;
	}
	/// pushes some data, set _stackIndex=0, and start execution at an instruction
	/// 
	/// Returns: return value
	NaData execute(uinteger index, NaData[] toPush){
		_stack.push(toPush);
		super.execute(index);
		NaData r = _retVal;
		_retVal = 0;
		return r;
	}
}

/// to execute a script, or use a script as a library
public class QScript : Library{
private:
	QScriptVM _vm;
public:
	/// constructor.
	/// 
	/// Set stack length of VM here, default should be more than enough
	this(string scriptName, bool autoImport, uinteger stackLength = 65_536){
		super(scriptName, autoImport);
		_vm = new QScriptVM(stackLength);
	}
	// overriding public functions that wont be needed
	override integer addFunction(Function){
		return -1;
	}
	override integer addStruct(Struct){
		return -1;
	}
	override integer addEnum(Enum){
		return -1;
	}
	override integer addVar(Variable){
		return -1;
	}
	/// Sets the available libraries. the indexes must be library ID
	void setLibraries(Library[] libs){
		_vm._libraries = libs;
	}
	/// Executes a function from script
	/// 
	/// Returns: whatever that function returned, or random data
	override NaData execute(uinteger functionId, NaData[] args){
		return _vm.execute(functionId, args);
	}
	override NaData getVar(uinteger varId){
		return _vm.stack.read(varId);
	}
	override void setVar(uinteger varId, NaData value){
		_vm.stack.write(varId, value);
	}
}