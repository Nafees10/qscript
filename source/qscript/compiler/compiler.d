/++
All the compiler modules packaged into one, this one module should be used to compile scripts.
+/
module qscript.compiler.compiler;

import qscript.compiler.tokengen;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.astcheck;
import qscript.compiler.codegen;
import qscript.compiler.astreadable;

import std.json;
import std.range;
import std.traits;
import std.conv : to;

import utils.misc;

/// An array containing all chars that an identifier can contain
package const char[] IDENT_CHARS = iota('a', 'z'+1).array~iota('A', 'Z'+1).array~iota('0', '9'+1).array~[cast(int)'_'];
/// An array containing all keywords
package const string[] KEYWORDS = [
	"import",
	"function",
	"struct",
	"enum",
	"var",
	"return",
	"if",
	"else",
	"while",
	"for",
	"do",
	"null",
	"true",
	"false"
] ~ DATA_TYPES ~ VISIBILITY_SPECIFIERS;
/// Visibility Specifier keywords
package const string[] VISIBILITY_SPECIFIERS = ["public", "private"];
/// data types
package const string[] DATA_TYPES = ["void", "int", "uint", "double", "char", "bool", "byte", "ubyte"];
/// An array containing double-operand operators
package const string[] OPERATORS = [".", "/", "*", "+", "-", "%", "~", "<", ">", ">=", "<=", "==", "=", "&&", "||"];
/// single-operand operators
package const string[] SOPERATORS = ["!", "@"];
/// An array containing all bool-operators (operators that return true/false)
package const string[] BOOL_OPERATORS = ["<", ">", ">=", "<=", "==", "&&", "||"];
/// Stores what types can be converted to what other types implicitly.
/// **THESE ARE NOT SUPPORTED RIGHT NOW, just stick with integer, char, and double**
package const DataType.Type[][] IMPLICIT_CAST_TYPES = [
	[DataType.Type.Int, DataType.Type.Uint],
	[DataType.Type.Double],
	[DataType.Type.Byte, DataType.Type.Ubyte],
	[DataType.Type.Char, DataType.Type.Ubyte],
	[DataType.Type.Bool, DataType.Type.Ubyte],
	[DataType.Type.Void],
];
/// Stores numerical data types (where numbers are stored)
package const DataType.Type[] NUMERICAL_DATA_TYPES = [
	DataType.Type.Int,
	DataType.Type.Uint,
	DataType.Type.Double,
	DataType.Type.Byte,
	DataType.Type.Ubyte,
];
/// only these data types are currently available
public const DataType.Type[] AVAILABLE_DATA_TYPES = [
	DataType.Type.Int, DataType.Type.Double, DataType.Type.Char
];

/// Used by compiler's functions to return error
public struct CompileError{
	string msg; /// The error stored in a string
	uinteger lineno; /// The line number on which the error is
	/// constructor
	this(uinteger lineNumber, string errorMessage){
		lineno = lineNumber;
		msg = errorMessage;
	}
}

/// Visibility Specifiers
package enum Visibility{
	Public,
	Private
}

/// Returns: Visibilty from a string
/// 
/// Throws: Exception if invalid input provided
package Visibility visibility(string s){
	foreach (curVisibility; EnumMembers!Visibility){
		if (curVisibility.to!string.lowercase == s)
			return curVisibility;
	}
	throw new Exception(s~" is not a visibility option");
}

/// Checks if a type can be implicitly casted to another type. does not work for custom types, returns false
/// 
/// Returns: true if can cast implicitely
package bool canImplicitCast(DataType.Type type1, DataType.Type type2){
	if (type1 == DataType.Type.Custom || type2 == DataType.Type.Custom)
		return false;
	foreach(list; IMPLICIT_CAST_TYPES){
		if (list.hasElement(type1) && list.hasElement(type2))
			return true;
	}
	return false;
}
/// ditto
package bool canImplicitCast(DataType type1, DataType type2){
	if (type1.arrayDimensionCount == type1.arrayDimensionCount && type1.isRef == type2.isRef){
		if (type1.type == DataType.Type.Custom || type2.type == DataType.Type.Custom)
			return type1.typeName == type2.typeName;
		return canImplicitCast(type1.type, type2.type);
	}
	return false;
}

/// To store information about a function
public struct Function{
	/// the name of the function
	string name;
	/// the data type of the value returned by this function
	DataType returnType;
	/// stores the data type of the arguments received by this function
	private DataType[] _argTypes;
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes() return{
		return _argTypes;
	}
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(DataType[] newArray) return{
		return _argTypes = newArray.dup;
	}
	/// constructor
	this (string functionName, DataType functionReturnType, DataType[] functionArgTypes){
		name = functionName;
		returnType = functionReturnType;
		_argTypes = functionArgTypes.dup;
	}
	/// postblit
	this (this){
		this._argTypes = this._argTypes.dup;
	}
}

/// To store information about a library (what a library exports)
public class Library{
private:
	/// if this library is automatically imported
	bool _autoImport;
	/// name of library
	string _name;
	/// functions exported by library. The index is function ID.
	Function[] _functions;
	/// global variables exported by this library. index is ID
	Library.Variable[] _vars;
	/// structs exported by library
	Library.Struct[] _structs;
	/// Enums exported by library
	Library.Enum[] _enums;

public:
	/// To store information about a struct
	struct Struct{
		/// the name of this struct
		private string _name;
		/// ditto
		@property string name(){
			return _name;
		}
		/// ditto 
		@property string name(string newName){
			return _name = newName;
		}
		/// name of members of this struct
		private string[] _membersName;
		/// ditto
		@property ref string[] membersName() return{
			return _membersName;
		}
		/// ditto
		@property ref string[] membersName(string[] newVal) return{
			return _membersName = newVal;
		}
		/// data types of members of this struct
		private DataType[] _membersDataType;
		/// ditto
		@property ref DataType[] membersDataType() return{
			return _membersDataType;
		}
		/// ditto
		@property ref DataType[] membersDataType(DataType[] newVal) return{
			return _membersDataType = newVal;
		}
		/// postblit
		this (this){
			this._membersName = this._membersName.dup;
			this._membersDataType = this._membersDataType.dup;
		}
	}
	/// To store information about a enum
	struct Enum{
		/// name of the enum
		private string _name;
		/// ditto
		@property string name(){
			return _name;
		}
		/// ditto
		@property string name(string newName){
			return _name = newName;
		}
		/// members names, index is their value
		private string[] _members;
		/// ditto
		@property ref string[] members() return{
			return _members;
		}
		/// ditto
		@property ref string[] members(string[] newVal) return{
			return _members = newVal;
		}
		/// postblit
		this (this){
			this._members = this._members.dup;
		}
	}
	/// To store information about a global variable
	struct Variable{
		/// name of var
		private  string _name;
		/// ditto
		@property string name(){
			return _name;
		}
		/// ditto
		@property string name(string newName){
			return _name = newName;
		}
		/// data type
		private DataType _type;
		/// ditto
		@property DataType type(){
			return _type;
		}
		/// ditto
		@property DataType type(DataType newType){
			return _type = newType;
		}
	}
	/// constructor
	this(bool autoImport){
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
	@property ref Library.Variable[] vars(){
		return _vars;
	}
	/// Adds a new variable.
	/// 
	/// Returns: Variable ID, or -1 if it already exists
	integer addVar(Library.Variable var){
		if (this.hasVar(var.name))
			return -1;
		_vars ~= var;
		return cast(integer)_vars.length-1;
	}
	/// HACK
	/// DO NOT USE THIS FUNCTION, except for the one place in astcheck where I used it
	package void setVarCount(uinteger count){
		_vars.length = count;
	}
	/// structs exported by library
	@property ref Library.Struct[] structs(){
		return _structs;
	}
	/// Adds a new struct
	/// 
	/// Returns: struct ID, or -1 if already exists
	integer addStruct(Library.Struct str){
		if (this.hasStruct(str.name))
			return -1;
		_structs ~= str;
		return cast(integer)_structs.length-1;
	}
	/// Enums exported by library
	@property ref Library.Enum[] enums() {
		return _enums;
	}
	/// Adds a new enum
	/// 
	/// Returns: enum ID, or -1 if it already exists
	integer addEnum(Library.Enum enu){
		if (this.hasEnum(enu.name))
			return -1;
		_enums ~= enu;
		return cast(integer)_enums.length-1;
	}
	/// Returns: true if struct exists
	bool hasStruct(string name, ref Library.Struct str){
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
	bool hasEnum(string name, ref Library.Enum enu){
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
}

/// used to store data types for data at compile time
public struct DataType{
	/// enum defining all data types. These are all lowercase of what they're written here
	public enum Type{
		Void, /// .
		Char, /// .
		Int, /// .
		Uint, /// .
		Double, /// .
		Bool, /// .
		Byte, /// signed 8 bit int
		Ubyte, /// unsigned 8 bit int
		Custom, /// some other type
	}
	/// the actual data type
	Type type = DataType.Type.Void;
	/// stores if it's an array. If type is `int`, it will be 0, if `int[]` it will be 1, if `int[][]`, then 2 ...
	uinteger arrayDimensionCount = 0;
	/// stores if it's a reference to a type
	bool isRef = false;
	/// stores the type name in case of Type.Custom
	private string _name;
	/// Returns: this data type in human readable string.
	@property string name(){
		char[] r = cast(char[])(this.type == Type.Custom ? _name.dup : this.type.to!string.lowercase);
		if (this.isRef)
			r = '@' ~ r;
		uinteger i = r.length;
		if (this.isArray){
			r.length += this.arrayDimensionCount * 2;
			for (; i < r.length; i += 2){
				r[i .. i + 2] = "[]";
			}
		}
		return cast(string)r;
	}
	/// Just calls fromString()
	@property string name(string newName){
		this.fromString(newName);
		return newName;
	}
	/// Returns: only the type name, exlcuding [] or @ if present
	@property string typeName(){
		return type == Type.Custom ? _name : type.to!string;
	}
	/// Returns: true if the type is a custom one
	@property bool isCustom(){
		return type == Type.Custom;
	}
	/// returns: true if it's an array. Strings are arrays too (char[])
	@property bool isArray(){
		if (arrayDimensionCount > 0){
			return true;
		}
		return false;
	}
	/// Returns: true if arithmatic operators can be used on a data type
	@property bool isNumerical(){
		if (this.isArray || this.isRef)
			return false;
		return NUMERICAL_DATA_TYPES.hasElement(this.type);
	}
	/// constructor.
	/// 
	/// dataType is the type to store
	/// arrayDimension is the number of nested arrays
	/// isRef is whether the type is a reference to the actual type
	this (DataType.Type dataType, uinteger arrayDimension = 0, bool isReference = false){
		type = dataType;
		arrayDimensionCount = arrayDimension;
		isRef = isReference;
	}
	/// constructor.
	/// 
	/// dataType is the name of type to store
	/// arrayDimension is the number of nested arrays
	/// isRef is whether the type is a reference to the actual type
	this (string dataType, uinteger arrayDimension = 0, bool isReference = false){
		this.name = dataType;
		arrayDimensionCount = arrayDimension;
		isRef = isReference;
	}
	
	/// constructor.
	/// 
	/// `sType` is the type in string form
	this (string sType){
		fromString(sType);
	}
	/// constructor.
	/// 
	/// `data` is the data to infer type from
	this (Token data){
		fromData(data);
	}
	/// reads DataType from a string, works for base types and custom types
	/// 
	/// Throws: Exception in case of failure or bad format in string
	void fromString(string s){
		isRef = false;
		string sType = null;
		uinteger indexCount = 0;
		// check if it's a ref
		if (s.length > 0 && s[0] == '@'){
			isRef = true;
			s = s[1 .. s.length].dup;
		}
		// read the type
		for (uinteger i = 0, lastInd = s.length-1; i < s.length; i ++){
			if (s[i] == '['){
				sType = s[0 .. i];
				break;
			}else if (i == lastInd){
				sType = s;
				break;
			}
		}
		// now read the index
		for (uinteger i = sType.length; i < s.length; i ++){
			if (s[i] == '['){
				// make sure next char is a ']'
				i ++;
				if (s[i] != ']'){
					throw new Exception("invalid data type format");
				}
				indexCount ++;
			}else{
				throw new Exception("invalid data type");
			}
		}
		bool isCustom = true;
		foreach (curType; EnumMembers!Type){
			if (curType != Type.Custom && curType.to!string.lowercase == sType){
				this.type = curType;
				isCustom = false;
			}
		}
		if (isCustom){
			this.type = Type.Custom;
			this._name = sType;
		}
		arrayDimensionCount = indexCount;
	}

	/// identifies the data type from the actual data. Only works for base types, and with only 1 token. So arrays dont work.
	/// keep in mind, this won't be able to identify if the data type is a reference or not
	/// 
	/// throws Exception on failure
	void fromData(Token data){
		isRef = false;
		arrayDimensionCount = 0;
		if (data.type == Token.Type.String){
			arrayDimensionCount ++;
			type = DataType.Type.Char;
		}else if (data.type == Token.Type.Char){
			type = DataType.Type.Char;
		}else if (data.type == Token.Type.Integer){
			type = DataType.Type.Int;
		}else if (data.type == Token.Type.Double){
			type = DataType.Type.Double;
		}else if (data.type == Token.Type.Bool){
			type = DataType.Type.Bool;
		}else if (data.type == Token.Type.Keyword && data.token == "null"){
			isRef = true;
			type = DataType.Type.Void;
		}else{
			throw new Exception("failed to read data type");
		}
	}
}
/// 
unittest{
	assert(DataType("int") == DataType(DataType.Type.Int, 0));
	assert(DataType("char[][]") == DataType(DataType.Type.Char, 2));
	assert(DataType("double[][]") == DataType(DataType.Type.Double, 2));
	assert(DataType("void") == DataType(DataType.Type.Void, 0));
	// unittests for `fromData`
	DataType dType;
	dType.fromData(Token("\"bla bla\""));
	assert(dType == DataType("char[]"));
	dType.fromData(Token("20"));
	assert(dType == DataType("int"), dType.name);
	dType.fromData(Token("2.5"));
	assert(dType == DataType("double"));
	// unittests for `.name()`
	assert(DataType("potatoType[][]").name == "potatoType[][]");
	assert(DataType("double[]").name == "double[]");
	
}

/// all the compiler modules wrapped into a single class. This is all that should be needed to compile scripts
public class QSCompiler{
private:

}

/// compiles a script from string[] to bytecode (in NaFunction[]).
/// 
/// `script` is the script to compile
/// `functions` is an array containing data about a function in Function[]
/// `errors` is the array to which errors will be appended
/// 
/// Returns: ByteCode class with the compiled byte code. or null if errors.length > 0
public string[] compileScript(string[] script, Library[] libraries, ref CompileError[] errors,
ref Function[] functionMap){
	TokenList tokens = toTokens(script, errors);
	if (errors.length > 0)
		return null;
	ASTGen astMake;
	ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
	if (errors.length > 0)
		return null;
	ASTCheck check = new ASTCheck(libraries);
	errors = check.checkAST(scrNode);
	if (errors.length > 0)
		return null;
	.destroy(check);
	// time for the final thing, to byte code
	/*CodeGen bCodeGen = new CodeGen();
	bCodeGen.generateByteCode(scrNode);
	string[] byteCode = bCodeGen.getByteCode();
	functionMap = bCodeGen.getFunctionMap;*/
	//return byteCode;
	return [];
}

/// Generates an AST for a script, uses ASTCheck.checkAST on it.
/// 
/// Returns: the final AST in readable JSON.
public string compileScriptAST(string[] script, Library[] libraries, ref CompileError[] errors){
	TokenList tokens = toTokens(script, errors);
	if (errors.length == 0){
		ASTGen astMake;
		ScriptNode scrNode = astMake.generateScriptAST(tokens, errors);
		if (errors.length == 0){
			ASTCheck check = new ASTCheck(libraries);
			errors = check.checkAST(scrNode);
			.destroy(check);
			JSONValue jsonAST = scrNode.toJSON;
			return jsonAST.toPrettyString();
		}
	}
	return "";
}