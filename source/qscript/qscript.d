/++
Contains everything needed to run QScript scripts.
+/
module qscript.qscript;

import utils.misc;
import utils.lists;

import qscript.compiler.compiler;
import qscript.stdlib;

import std.conv:to;

import navm.navm;
import navm.bytecode;
import navm.defs : ArrayStack;

alias ExternFunction = NaData delegate(NaData[]);
alias NaData = navm.navm.NaData;
alias CompileError = qscript.compiler.compiler.CompileError;

/// To store a library (could be a script as a library as well)
public class Library{
protected:
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
	integer hasFunction(string name, DataType[] argsType, ref DataType returnType){
		foreach (i, func; _functions){
			if (func.name == name){
				if (argsType.length == func.argTypes.length){
					foreach (j; 0 .. argsType.length){
						if (!argsType[j].canImplicitCast(func.argTypes[j]))
							return -1;
					}
					returnType = func.returnType;
					return i;
				}
			}
		}
		return -1;
	}
	/// ditto
	integer hasFunction(string name, DataType[] argsType){
		DataType returnType;
		return this.hasFunction(name, argsType, returnType);
	}
	/// Returns: true if a function by a name exists
	bool hasFunction(string name){
		foreach (func; _functions){
			if (func.name == name)
				return true;
		}
		return false;
	}
	/// For use with generateFunctionCallCode. Use this to change what order arguments are pushed to stack
	/// before the bytecode for functionCall is generated
	/// 
	/// Returns: the order of arguments to push (`[1,0]` will push 2 arguments in reverse),  or [] for default
	uinteger[] functionCallArgumentsPushOrder(uinteger functionId){
		return [];
	}
	/// Generates bytecode for a function call, or return false
	/// 
	/// This function must consider all flags
	/// 
	/// Returns: true if it added code for the function call, false if codegen.d should
	bool generateFunctionCallCode(QScriptBytecode bytecode, uinteger functionId, CodeGenFlags flags){
		return false;
	}
	/// Generates bytecode that will push value of a variable to stack, or return false
	/// 
	/// This function must consider all flags
	/// 
	/// Returns: true if it added code, false if codegen.d should
	bool generateVariableCode(QScriptBytecode bytecode, uinteger variableId, CodeGenFlags flags){
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
	NaData getVarRef(uinteger varId){
		return NaData(null);
	}
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
		_retVal = _libraries[libId].execute(funcID, _stack.pop(_arg.intVal-2));
	}
	void retValSet(){
		_retVal = _stack.pop;
	}
	void retValPush(){
		_stack.push(_retVal);
		_retVal.intVal = 0;
	}

	void makeArrayN(){
		NaData array;
		array.makeArray(_arg.intVal);
		_stack.push(array);
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
	void arrayConcat(){
		NaData array, a, b;
		b = _stack.pop;
		a = _stack.pop;
		array.makeArray(a.arrayValLength + b.arrayValLength);
		array.arrayVal[0 .. a.arrayValLength] = a.arrayVal;
		array.arrayVal[a.arrayValLength+1 .. $] = b.arrayVal;
		_stack.push(array);
	}
	void incRefN(){
		_stack.push(NaData(cast(NaData*)(_stack.pop.ptrVal + _arg.intVal)));
	}
	void pushRefFromPop(){
		_stack.push(NaData(&(_stack.pop)));
	}

	void jumpFrameN(){
		import navm.defs : StackFrame;
		immutable uinteger offset = _stack.pop.intVal;
		_jumpStack.push(StackFrame(_inst, _arg, _stackIndex));
		_inst = &(_instructions)[_arg.intVal] - 1;
		_arg = &(_arguments)[_arg.intVal] - 1;
		_stackIndex = _stack.count - offset;
		_stack.setIndex(_stackIndex);
	}
public:
	/// constructor
	this(uinteger stackLength = 65_536){
		super(stackLength);
		addInstruction(NaInstruction("call",0x40,true,255,1,&call));
		addInstruction(NaInstruction("retValSet",0x41,1,0,&retValSet));
		addInstruction(NaInstruction("retValPush",0x42,0,1,&retValPush));
		addInstruction(NaInstruction("makeArrayN",0x43,true,0,1,&makeArrayN));
		addInstruction(NaInstruction("arrayCopy",0x44,1,1,&arrayCopy));
		addInstruction(NaInstruction("arrayElement",0x45,true,1,1,&arrayElement));
		addInstruction(NaInstruction("arrayElementWrite",0x46,true,2,0,&arrayElementWrite));
		addInstruction(NaInstruction("arrayConcat",0x47,2,1,&arrayConcat));
		addInstruction(NaInstruction("incRefN",0x48,true,1,1,&incRefN));
		addInstruction(NaInstruction("pushRefFromPop",0x49,1,1,&pushRefFromPop));
		addInstruction(NaInstruction("jumpFrameN",0x4A,true,true,1,0,&jumpFrameN));
	}
	/// gets element at an index on stack
	/// 
	/// Returns: the element
	NaData getElement(uinteger index){
		return _stack.readAbs(index);
	}
	/// gets pointer to element at an index on stack
	/// 
	/// Returns: the pointer to element
	NaData* getElementPtr(uinteger index){
		return _stack.readPtrAbs(index);
	}
	/// pushes some data, set _stackIndex=0, and start execution at an instruction
	/// 
	/// Returns: return value
	NaData executeFunction(uinteger index, NaData[] toPush){
		_stack.push(toPush);
		execute(index);
		NaData r = _retVal;
		_retVal = NaData(0);
		return r;
	}
}

/// Stores QScript bytecode
class QScriptBytecode : NaBytecode{
private:
	string _linkInfo;
	
public:
	/// constructor
	this(NaInstruction[] instructionTable){
		super(instructionTable);
	}
	/// link info
	@property string linkInfo(){
		return _linkInfo;
	}
	/// ditto
	@property string linkInfo(string newVal){
		return _linkInfo = newVal;
	}
	/// Returns: the bytecode in a readable format
	override string[] getBytecodePretty(){
		return [
			"#","#"~linkInfo
		]~super.getBytecodePretty();
	}
	/// Reads from a string[] (follows spec/syntax.md)
	/// 
	/// Returns: errors in a string[], or [] if no errors
	override string[] readByteCode(string[] input){
		if (input.length < 2 || input[1].length < 2 || input[1][0] != '#')
			return ["not a valid QScript Bytecode"];
		_linkInfo = input[1][1 .. $];
		return super.readByteCode(input[2 .. $]);
	}
}

/// to execute a script, or use a script as a library
public class QScript : Library{
private:
	QScriptVM _vm;
	QSCompiler _compiler;
	/// number of default libraries
	uinteger _defLibCount;
public:
	/// constructor.
	/// 
	/// Set stack length of VM here, default should be more than enough
	this(string scriptName, bool autoImport, Library[] libraries, bool defaultLibs = true, bool extraLibs = true){
		super(scriptName, autoImport);
		_vm = new QScriptVM();
		_defLibCount = 0;
		if (defaultLibs){
			_vm._libraries = [
				new OpLibrary(),
				new ArrayLibrary(),
				new TypeConvLibrary(),
			];
			_defLibCount = _vm._libraries.length;
		}
		if (extraLibs){
			_vm._libraries ~= new StdIOLibrary();
			_defLibCount += 1;
		}
		_vm._libraries ~= libraries.dup;
		_compiler = new QSCompiler(_vm._libraries, _vm.instructionTable);
	}
	~this(){
		.destroy(_compiler);
		foreach (i; 0 .. _defLibCount)
			.destroy(_vm._libraries[i]);
		.destroy(_vm);
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
	/// Executes a function from script
	/// 
	/// Returns: whatever that function returned, or random data
	override NaData execute(uinteger functionId, NaData[] args){
		return _vm.executeFunction(functionId, args);
	}
	override NaData getVar(uinteger varId){
		return _vm.getElement(varId);
	}
	override NaData getVarRef(uinteger varId){
		return NaData(_vm.getElementPtr(varId));
	}
	/// compiles a script, and prepares it for execution with this class
	/// 
	/// Returns: bytecode, or null in case of error
	/// the returned bytecode will not be freed by this class, so you should do it when not needed
	QScriptBytecode compileScript(string[] script, ref CompileError[] errors){
		// clear itself
		_functions.length = 0;
		_vars.length = 0;
		_structs.length = 0;
		_enums.length = 0;
		// prepare compiler
		_compiler.scriptExports = this;
		_compiler.errorsClear;
		_compiler.loadScript(script);
		// start compiling
		if (!_compiler.generateTokens || !_compiler.generateAST || !_compiler.finaliseAST || !_compiler.generateCode){
			errors = _compiler.errors;
			return null;
		}
		QScriptBytecode bytecode = _compiler.bytecode;
		string[] sErrors;
		if (!this.load(bytecode, sErrors))
			foreach (err; sErrors)
				errors ~= CompileError(0, err);
		return bytecode;
	}
	/// compiles a script, and prepares it for execution with this class
	/// 
	/// Returns: errors, if any, or empty array
	CompileError[] compileScript(string[] script){
		CompileError[] r;
		this.compileScript(script, r).destroy();
		return r;
	}

	/// Loads bytecode and library info
	/// 
	/// the bytecode will not be freed by this class, so you should do it when not needed
	bool load(QScriptBytecode bytecode, string[] errors){
		errors = bytecode.resolve;
		if (errors.length)
			return false;
		errors = [this.fromString(bytecode.linkInfo)];
		if (errors[0] != "")
			return false;
		errors = [];
		errors = _vm.load(bytecode);
		if (errors.length)
			return false;
		return true;
	}
}