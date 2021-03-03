/++
QScript core libraries + some libraries providing some extra functions
+/
module qscript.stdlib;

import qscript.qscript;
import qscript.compiler.compiler;

import utils.misc;

/// library providing operators
public class OpLibrary : Library{
private:
	const NUM_OPERATORS = ["opDivide", "opMultiply", "opAdd", "opSubtract", "opMod", "opLesser", "opGreater",
		"opLesserSame", "opGreaterSame"];
public:
	/// constructor
	this(){
		super("qscript_operators",true);
	}
	/// Adds a new function
	/// 
	/// Returns: function ID, or -1 if function already exists
	override integer addFunction(Function func){
		DataType dummy;
		if (super.hasFunction(func.name, func.argTypes, dummy)!=-1)
			return -1;
		_functions ~= func;
		return cast(integer)_functions.length-1;
	}
	/// Returns: function ID, or -1 if doesnt exist
	override integer hasFunction(string name, DataType[] argsType, ref DataType returnType){
		// check if it previously assigned an ID to a function of this type
		integer r = super.hasFunction(name, argsType, returnType);
		if (r > -1)
			return r;
		if (argsType.length == 0) // I got nothing with zero arguments
			return -1;
		if (NUM_OPERATORS.hasElement(name)){
			returnType = argsType[0];
			if (argsType.length == 2 && argsType[0] == argsType[1] && (argsType[0] == DataType(DataType.Type.Int) ||
			argsType[0] == DataType(DataType.Type.Double)))
				// make a new ID for this
				return this.addFunction(Function(name, argsType[0], argsType));
			return -1;
		}
		if (name == "opSame"){
			returnType = DataType(DataType.Type.Bool);
			// must have 2 operands, both of same type, not arrays, and not custom(struct)
			if (argsType.length == 2 && argsType[0] == argsType[1] && !argsType[0].isArray && 
			!argsType[0].type == DataType.Type.Custom)
				return this.addFunction(Function(name, DataType(DataType.Type.Bool), argsType));
			return -1;
		}
		if (name == "opConcat"){
			returnType = argsType[0];
			// both must be arrays of same dimension with same base data type
			if (argsType.length == 2 && argsType[0] == argsType[1] && !argsType[0].isRef && argsType[0].arrayDimensionCount > 0)
				return this.addFunction(Function(name, argsType[0], argsType));
			return -1;
		}
		if (name == "opAndBool" || name == "opOrBool"){
			returnType = DataType(DataType.Type.Bool);
			if (argsType.length == 2 && argsType[0] == argsType[1] && argsType[0] == DataType(DataType.Type.Bool))
				return this.addFunction(Function(name, DataType(DataType.Type.Bool), argsType));
			return -1;
		}
		if (name == "opNot"){
			returnType = DataType(DataType.Type.Bool);
			if (argsType == [DataType(DataType.Type.Bool)])
				return this.addFunction(Function(name, DataType(DataType.Type.Bool), argsType));
			return -1;
		}
		return -1;
	}
	/// Generates bytecode for a function call, or return false
	/// 
	/// Returns: true if it added code for the function call, false if codegen.d should
	override bool generateFunctionCallCode(QScriptBytecode bytecode, uinteger functionId, CodeGenFlags flags){
		Function func;
		if (functionId >= this.functions.length)
			return false;
		func = this.functions[functionId];
		string typePostFix = func.argTypes[0].type == DataType.Type.Int ? "Int" : "Double";
		switch (func.name){
			case "opDivide":
				bytecode.addInstruction("mathDivide"~typePostFix, "");
				break;
			case "opMultiply":
				bytecode.addInstruction("mathMultiply"~typePostFix, "");
				break;
			case "opAdd":
				bytecode.addInstruction("mathAdd"~typePostFix, "");
				break;
			case "opSubtract":
				bytecode.addInstruction("mathSubtract"~typePostFix, "");
				break;
			case "opMod":
				bytecode.addInstruction("mathMod"~typePostFix, "");
				break;
			case "opLesser": // have to use the opposite instruction because of the order these instructions pop A and B in
				bytecode.addInstruction("isGreater"~typePostFix, "");
				break;
			case "opGreater":
				bytecode.addInstruction("isLesser"~typePostFix, "");
				break;
			case "opLesserSame":
				bytecode.addInstruction("isGreaterSame"~typePostFix, "");
				break;
			case "opGreaterSame":
				bytecode.addInstruction("isLesserSame"~typePostFix, "");
				break;
			case "opSame":
				bytecode.addInstruction("isSame", "");
				break;
			case "opConcat":
				bytecode.addInstruction("arrayConcat", "");
				break;
			case "opAndBool":
				bytecode.addInstruction("And", "");
				break;
			case "opOrBool":
				bytecode.addInstruction("Or", "");
				break;
			case "opNot":
				bytecode.addInstruction("Not", "");
				break;
			default:
				return false;
		}
		return true;
	}
}

/// Library for functions related to arrays
public class ArrayLibrary : Library{
public:
	/// constructor
	this (){
		super("qscript_arrays", true);
	}
	/// Adds a new function
	/// 
	/// Returns: function ID, or -1 if function already exists
	override integer addFunction(Function func){
		DataType dummy;
		if (super.hasFunction(func.name, func.argTypes, dummy)!=-1)
			return -1;
		_functions ~= func;
		return cast(integer)_functions.length-1;
	}
	/// Returns: function ID, or -1 if doesnt exist
	override integer hasFunction(string name, DataType[] argsType, ref DataType returnType){
		integer r = super.hasFunction(name, argsType, returnType);
		if (r > -1)
			return r;
		if (argsType.length == 0)
			return -1;
		if (name == "copy"){
			returnType = argsType[0];
			if (argsType.length == 1 && argsType[0].isArray)
				return this.addFunction(Function("copy",returnType, argsType));
			return -1;
		}
		if (name == "length"){
			if (!argsType[0].isArray)
				return -1;
			if (argsType.length == 1){
				returnType = DataType(DataType.Type.Int);
				return this.addFunction(Function("length",returnType,argsType));
			}
			return -1;
		}
		if (name == "setLength"){
			if (!argsType[0].isArray)
				return -1;
			if (argsType.length == 2 && argsType[1] == DataType(DataType.Type.Int)){
				returnType = DataType(DataType.Type.Void);
				return this.addFunction(Function("length",returnType,argsType));
			}
			return -1;
		}
		return -1;
	}
	/// setLength uses arrayLengthSet which wants arguments in opposite order
	override uinteger[] functionCallArgumentsPushOrder(uinteger functionId){
		if (functionId >= this.functions.length)
			return [];
		Function func = this.functions[functionId];
		if (func.name == "setLength")
			return [1,0];
		return [];
	}
	/// Generates bytecode for a function call, or return false
	/// 
	/// Returns: true if it added code for the function call, false if codegen.d should
	override bool generateFunctionCallCode(QScriptBytecode bytecode, uinteger functionId, CodeGenFlags flags){
		Function func;
		if (functionId >= this.functions.length)
			return false;
		func = this.functions[functionId];
		if (func.name == "copy"){
			bytecode.addInstruction("arrayCopy");
			return true;
		}
		if (func.name == "length"){
			bytecode.addInstruction("arrayLength");
			return true;
		}
		if (func.name == "setLength"){
			bytecode.addInstruction("arrayLengthSet");
			return true;
		}
		return false;
	}
}

/// Library for std input/output
public class StdIOLibrary : Library{
private:
	import std.stdio : write, writeln, readln;
	import std.string : chomp;
	NaData writelnStr(NaData[] args){
		foreach (arg; args)
			writeln(arg.strVal);
		return NaData(0);
	}
	NaData writeStr(NaData[] args){
		foreach (arg; args)
			write(arg.strVal);
		return NaData(0);
	}
	NaData readStr(){
		return NaData(readln.chomp());
	}
public:
	/// constructor
	this(){
		super("qscript_stdio", false);
	}
	/// Returns: function ID, or -1 if doesnt exist
	override integer hasFunction(string name, DataType[] argsType, ref DataType returnType){
		integer r = super.hasFunction(name, argsType, returnType);
		if (r > -1)
			return r;
		returnType = DataType(DataType.Type.Void);
		if (name == "writeln" && argsType.length > 0){
			foreach (argType; argsType){
				if (argType != DataType(DataType.Type.Char, 1))
					return -1;
			}
			/// just return 0 on it, its not like its gonna ask to send over function with id=0 (at least not yet)
			return 0;
		}
		if (name == "write" && argsType.length > 0){
			foreach (argType; argsType){
				if (argType != DataType(DataType.Type.Char, 1))
					return -1;
			}
			return 1;
		}
		if (name == "read" && argsType.length == 0){
			returnType = DataType(DataType.Type.Char,1);
			return 2;
		}
		return -1;
	}
	/// Executes a library function
	/// 
	/// Returns: whatever that function returned
	override NaData execute(uinteger functionId, NaData[] args){
		switch (functionId){
			case 0:
				return writelnStr(args);
			case 1:
				return writeStr(args);
			case 2:
				return readStr();
			default:
				return NaData(0);
		}
	}
}