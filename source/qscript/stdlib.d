/++
QScript core libraries
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
		super("qscriptOperators",true);
	}
	/// Adds a new function
	/// 
	/// Returns: function ID, or -1 if function already exists
	override integer addFunction(Function func){
		bool dummy1;
		DataType dummy2;
		if (super.hasFunction(func.name, func.argTypes, dummy1, dummy2)!=-1)
			return -1;
		_functions ~= func;
		return cast(integer)_functions.length-1;
	}
	/// Returns: function ID, or -1 if doesnt exist
	override integer hasFunction(string name, DataType[] argsType, ref bool argTypesMatch, ref DataType returnType){
		if (argsType.length == 0) // I got nothing with zero arguments
			return -1;
		// check if it previously assigned an ID to a function of this type
		integer r = super.hasFunction(name, argsType, argTypesMatch, returnType);
		if (r > -1)
			return r;
		argTypesMatch = true;
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
			case "opLesser":
				bytecode.addInstruction("isLesser"~typePostFix, "");
				break;
			case "opGreater":
				bytecode.addInstruction("isGreater"~typePostFix, "");
				break;
			case "opLesserSame":
				bytecode.addInstruction("isLesserSame"~typePostFix, "");
				break;
			case "opGreaterSame":
				bytecode.addInstruction("isGreaterSame"~typePostFix, "");
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