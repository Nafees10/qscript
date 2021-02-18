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

import navm.bytecode;

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
package const string[] DATA_TYPES = ["void", "int", "double", "char", "bool"];
/// An array containing double-operand operators
package const string[] OPERATORS = [".", "/", "*", "+", "-", "%", "~", "<", ">", ">=", "<=", "==", "=", "&&", "||"];
/// single-operand operators
package const string[] SOPERATORS = ["!", "@"];
/// An array containing all bool-operators (operators that return true/false)
package const string[] BOOL_OPERATORS = ["<", ">", ">=", "<=", "==", "&&", "||"];
/// function names corresponding to operators
package string[string] OPERATOR_FUNCTIONS;
static this(){
	OPERATOR_FUNCTIONS = [
		"." : "opMemberSelect",
		"/" : "opDivide",
		"*" : "opMultiply",
		"+" : "opAdd",
		"-" : "opSubtract",
		"%" : "opMod",
		"~" : "opConcat",
		"<" : "opLesser",
		">" : "opGreater",
		"<=" : "opLesserSame",
		">=" : "opGreaterSame",
		"==" : "opSame",
		"=" : "opAssign",
		"&&" : "opAndBool",
		"||" : "opOrBool",
		"!" : "opNot",
		"@" : "opRef",
	];
}
/// Stores what types can be converted to what other types implicitly.
package const DataType.Type[][] IMPLICIT_CAST_TYPES = [
	[DataType.Type.Int, DataType.Type.Bool],
	[DataType.Type.Double],
	[DataType.Type.Char],
	[DataType.Type.Bool],
	[DataType.Type.Void],
];
/// Stores numerical data types (where numbers are stored)
package const DataType.Type[] NUMERICAL_DATA_TYPES = [
	DataType.Type.Int,
	DataType.Type.Double,
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

/// Flags passed to bytecode generating functions
/// 
/// Not all functions look at each flag, some functions might ignore all flags
public enum CodeGenFlags : ubyte{
	None = 0, /// all flags zero
	PushRef = 1 << 0, /// if the code should push a reference to the needed data. By default, the actual data is pushed.
	PushFunctionReturn = 1 << 1, /// if the return value from FunctionCallNode should be pushed
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
public bool canImplicitCast(DataType.Type type1, DataType.Type type2){
	if (type1 == DataType.Type.Custom || type2 == DataType.Type.Custom)
		return false;
	foreach(list; IMPLICIT_CAST_TYPES){
		if (list.hasElement(type1) && list.hasElement(type2))
			return true;
	}
	return false;
}
/// ditto
public bool canImplicitCast(DataType type1, DataType type2){
	if (type1.arrayDimensionCount == type1.arrayDimensionCount && type1.isRef == type2.isRef){
		if (type1.type == DataType.Type.Custom || type2.type == DataType.Type.Custom)
			return type1.typeName == type2.typeName;
		return canImplicitCast(type1.type, type2.type);
	}
	return false;
}

/// comma separates a string.
/// 
/// Returns: the comma separated string
public string[] commaSeparate(char comma=',', bool excludeEmpty=false)(string str){
	string[] r;
	uinteger readFrom;
	for(uinteger i=0; i < str.length ; i ++){
		if (str[i] == comma || i+1 == str.length){
			if (readFrom < i)
				r ~= str[readFrom .. i];
			else static if (!excludeEmpty)
				r ~= "";
			readFrom = i+1;
		}
	}
	return r;
}

public import qscript.qscript : Library;

/// Function called to generate bytecode for a call to a macro function
public alias FunctionCallCodeGenFunc = void delegate (string name, DataType[] argTypes, NaBytecode bytecode);
/// Function called to generate bytecode for accessing a macro variable
public alias VariableCodeGenFunc = void delegate (string name, NaBytecode bytecode);
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
	/// constructor (reads from string generated by Function.toString)
	/// 
	/// Throws: Exception in case of error
	this (string functionString){
		string err = this.fromString(functionString);
		if (err.length)
			throw new Exception(err);
	}
	/// postblit
	this (this){
		this._argTypes = this._argTypes.dup;
	}
	/// Returns: a string representation of this Function
	string toString(){
		char[] r = cast(char[])"func,"~name~','~returnType.toString~',';
		foreach (type; _argTypes)
			r ~= type.toString~',';
		return cast(string)r;
	}
	/// Reads this Function from a string (reverse of toString)
	/// 
	/// Returns: zero length string if success, or error description in string if error
	string fromString(string str){
		if (str.length == 0)
			return "cannot read Function from empty string";
		string[] vals = commaSeparate(str);
		if (vals.length < 3 || vals[0] != "func")
			return "invalid string to read Function from";
		name = vals[1];
		try
			returnType = DataType(vals[2]);
		catch (Exception e){
			string r = e.msg;
			.destroy(e);
			return "error reading Function returnType: "~r;
		}
		_argTypes = [];
		if (vals.length > 3){
			_argTypes.length = vals.length - 3;
			foreach(i, arg; vals[3 .. $]){
				try
					_argTypes[i] = DataType(arg);
				catch (Exception e){
					string r = e.msg;
					.destroy(e);
					return "error reading Function arguments: "~r;
				}
			}
		}
		return [];
	}
}
/// 
unittest{
	Function func = Function("potato",DataType(DataType.Type.Void),[]);
	assert(Function(func.toString) == func, func.toString);
	func = Function("potato",DataType(DataType.Type.Int),[DataType("@potatoType[]")]);
	assert(Function(func.toString) == func, func.toString);
}
/// To store information about a struct
public struct Struct{
	/// the name of this struct
	string name;
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
	/// constructor, reads from string (uses fromString)
	/// 
	/// Throws: Exception in case of error
	this(string structString){
		string err = fromString(structString);
		if (err.length)
			throw new Exception(err);
	}
	/// constructor
	this (string name, string[] members, DataType[] dTypes){
		this.name = name;
		_membersName = members.dup;
		_membersDataType = dTypes.dup;
	}
	/// Returns: a string representation of this Struct
	string toString(){
		char[] r = cast(char[])"struct,"~name~',';
		foreach (memberName; _membersName)
			r ~= memberName ~ ',';
		foreach (type; _membersDataType)
			r~= type.toString ~ ',';
		return cast(string)r;
	}
	/// Reads this Struct from a string (reverse of toString)
	/// 
	/// Returns: empty string if success, or error in string in case of error
	string fromString(string str){
		string[] vals = commaSeparate(str);
		if (vals.length == 0 || vals[0] != "struct" || vals.length %  2 > 0)
			return "invalid string to read Struct from";
		name = vals[1];
		vals = vals[2 .. $];
		immutable uinteger dTypeStartIndex = vals.length/2;
		_membersDataType.length = dTypeStartIndex;
		_membersName.length = _membersDataType.length;
		foreach (i,val; vals[0 .. dTypeStartIndex]){
			_membersName[i] = val;
			try
				_membersDataType[i] = DataType(vals[dTypeStartIndex+i]);
			catch (Exception e){
				string r = e.msg;
				.destroy(e);
				return "error reading Struct member data type: " ~ r;
			}
		}
		return [];
	}
}
///
unittest{
	Struct str = Struct("potatoStruct",["a","b","c"],[DataType("int"),DataType("@double[]"),DataType("@char[]")]);
	assert(Struct(str.toString) == str);
}
/// To store information about a enum
public struct Enum{
	/// name of the enum
	string name;
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
	/// Constructor
	this (string name, string[] members){
		this.name = name;
		this._members = members.dup;
	}
	/// Constructor, reads from string (uses fromString)
	this (string enumString){
		fromString(enumString);
	}
	/// Returns: string representation of this enum
	string toString(){
		char[] r = cast(char[])"enum,"~name~',';
		foreach (member; _members)
			r ~= member ~ ',';
		return cast(string)r;
	}
	/// Reads this Enum from string (reverse of toString)
	/// 
	/// Returns: empty string in case of success, error in string in case of error
	string fromString(string str){
		string[] vals = commaSeparate(str);
		if (vals.length == 0 || vals[0] != "enum")
			return "invalid string to read Enum from";
		name = vals[1];
		vals = vals[2 .. $];
		_members = vals.dup; // ez
		return [];
	}
}
/// To store information about a global variable
public struct Variable{
	/// name of var
	string name;
	/// data type
	DataType type;
	/// constructor
	this(string name, DataType type){
		this.name = name;
		this.type = type;
	}
	/// Constructor, for reading from string (uses fromString)
	/// 
	/// Throws: Exception in case of error
	this(string varString){
		fromString(varString);
	}
	/// Returns: a string representation of this Variable
	string toString(){
		return "var,"~name~','~type.toString~',';
	}
	/// Reads this Variable from a string (reverse of toString)
	/// 
	/// Returns: empty string in case of success, or error in string in case of error
	string fromString(string str){
		string[] vals = commaSeparate(str);
		if (vals.length != 3 || vals[0] != "var")
			return "invalid string to read Variable from";
		name = vals[1];
		try
			type = DataType(vals[2]);
		catch (Exception e){
			string r = e.msg;
			.destroy (e);
			return "error reading Variable data type: " ~ r;
		}
		return [];
	}
}
///
unittest{
	Variable var = Variable("i",DataType("@int[][]"));
	assert (Variable(var.toString) == var);
}

/// used to store data types for data at compile time
public struct DataType{
	/// enum defining all data types. These are all lowercase of what they're written here
	public enum Type{
		Void, /// .
		Char, /// .
		Int, /// .
		Double, /// .
		Bool, /// .
		Custom, /// some other type
	}
	/// the actual data type
	Type type = DataType.Type.Void;
	/// stores if it's an array. If type is `int`, it will be 0, if `int[]` it will be 1, if `int[][]`, then 2 ...
	uinteger arrayDimensionCount = 0;
	/// stores length in case of Type.Custom
	uinteger customLength;
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
	/// Returns: human readable string of this (calls name())
	string toString(){
		return name;
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
	ASTGen _astgenerator;
	ASTCheck _astcheck;
	CodeGen _codegen;

	CompileError[] _errors;

	string[] _script;
	TokenList _tokens;
	ScriptNode _ast;
	NaBytecode _bytecode;

	Library _scriptExports;
	Library _scriptDeclarations;
public:
	/// constructor
	this(Library[] libraries, NaInstruction[] instructionTable){
		_astgenerator = new ASTGen();
		_astcheck = new ASTCheck(libraries);
		_codegen = new CodeGen(libraries, instructionTable);
	}
	/// destructor
	~this(){
		.destroy(_astgenerator);
		.destroy(_astcheck);
		.destroy(_codegen);
	}
	/// The Library to which script's exports will be written to
	@property Library scriptExports(){
		return _scriptExports;
	}
	/// ditto
	@property Library scriptExports(Library newVal){
		return _scriptExports = newVal;
	}
	/// what errors occurred
	@property CompileError[] errors(){
		return _errors.dup;
	}
	/// clears errors
	void errorsClear(){
		_errors.length = 0;
	}
	/// get a JSON representing the generated AST
	/// 
	/// Returns: pretty printed JSON
	string prettyAST(){
		return toJSON(_ast).toPrettyString;
	}
	/// the generated bytecode. This class will *NOT* be freed by QSCompiler.
	/// 
	/// Returns: the generated bytecode as NaBytecode
	NaBytecode bytecode(){
		return _bytecode;
	}
	/// load a script which is to be compiled.
	/// 
	/// Each element in the array should be a line, without the newline character(s) at end
	void loadScript(string[] script){
		_script = script.dup;
	}
	/// generates tokens for a script
	/// 
	/// Returns: true if done without errors, false if there were errors
	bool generateTokens(){
		_tokens = toTokens(_script, _errors);
		return _errors.length == 0;
	}
	/// generates AST from tokens
	/// 
	/// Returns: true if done without errors, false if there were errors
	bool generateAST(){
		_ast = _astgenerator.generateScriptAST(_tokens);
		CompileError[] astErrors = _astgenerator.errors;
		if (astErrors.length > 0){
			_errors ~= astErrors;
			return false;
		}
		return true;
	}
	/// checks and finalises generated AST
	/// 
	/// Returns: true if done without errors, false if there were errors
	bool finaliseAST(){
		if (_scriptExports is null){
			_errors ~= CompileError(0, "assign a value to QSCompiler.scriptExports before calling finaliseAST");
			return false;
		}
		if (_scriptDeclarations !is null)
			.destroy(_scriptDeclarations);
		_scriptDeclarations = new Library("_QSCRIPT_TEMP_LIB");
		CompileError[] checkErrors = _astcheck.checkAST(_ast, _scriptExports, _scriptDeclarations);
		if (checkErrors.length){
			_errors ~= checkErrors;
			return false;
		}
		return true;
	}
	/// ditto
	alias checkAST = finaliseAST;
	/// generates bytecode from AST.
	/// 
	/// Returns: true if done without errors, false if there was some error. The error itself cannot be known if happens in CodeGen, its likely to be a bug in CodeGen.
	bool generateCode(){
		if (_scriptDeclarations is null){
			_errors ~= CompileError(0,"QSCompiler.finaliseAST not called before calling QSCompiler.generateCode");
			return false;
		}
		immutable bool r = _codegen.generateCode(_ast, _scriptDeclarations);
		.destroy(_scriptDeclarations);
		_bytecode = _codegen.bytecode;
		string[] resolveErrors = _bytecode.resolve;
		if (resolveErrors.length){
			foreach (err; resolveErrors)
				_errors ~= CompileError(0, "[bytecode.resolve]: "~err);
			return false;
		}
		_scriptDeclarations = null;
		return r;
	}
}