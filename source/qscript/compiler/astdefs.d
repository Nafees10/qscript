module qscript.compiler.astdefs;

import utils.misc;
import utils.ds;

import qscript.compiler.compiler;
import qscript.compiler.tokens;

debug{import std.stdio;}
import std.conv : to;

import qscript.compiler.astgen : ASTNode, Identifier;

/// reads tokens into ident
/// 
/// Returns: number of tokens read
package uint identFromTokens(ref Identifier ident, Token[] tokens){
	uint index = 0;
	if (index < tokens.length && tokens[index].token.isIdentifier){
		ident = [tokens[index].token];
		index ++;
	}else
		return 0;
	while (index + 1 < tokens.length && tokens[index].type == TokenType.Operator &&
	tokens[index].token == "." && tokens[index + 1].token.isIdentifier){
		ident ~= tokens[index + 1].token;
		index += 2;
	}
	return index;
}
/// 
unittest{
	Token[] tok = [
		Token(TokenType.Identifier,"qscript"), Token(TokenType.Operator,"."),
		Token(TokenType.Identifier,"std"), Token(TokenType.Operator,"."),
		Token(TokenType.Identifier,"io"), Token(TokenType.Operator,".")
	];
	Identifier ident;
	assert(ident.identFromTokens(tok) == 5);
	assert(ident.toString == "qscript.std.io");
}

/// Returns: string representation of Identifier
package string toString(const Identifier ident){
	string ret;
	foreach (name; ident[0 .. $ - 1])
		ret ~= name ~ '.';
	return ret ~ ident[$-1];
}

/// Data Type
class DataType : ASTNode{
private:
	/// if it is a ref
	bool _isRef = false;
	/// array dimensions (zero if not array)
	uint _dimensions = 0;
	/// name of data type
	string _type;
	/// number of bytes that will be occupied, 0 if unknown
	uint _byteCount = 0;
protected:
	override @property ASTNode[] _children(){
		return null;
	}
public:
	/// default constructor, creates void type
	this (){
		_type = TYPENAME.VOID;
	}
	/// copy constructor
	this (DataType from){
		if (!from)
			return;
		_dimensions = from._dimensions;
		_byteCount = from._byteCount;
		_isRef = from._isRef;
		_location = from._location;
		_type = from._type;
	}
	/// constructor
	this(string name, uint dimensions = 0){
		_type = name;
		_dimensions = dimensions;
	}
	~this(){
		this.clear();
	}
	/// Clears itself
	void clear(){
		_location = [0,0];
		_type = null;
		_isRef = false;
		_dimensions = 0;
		_byteCount = 0;
	}
	/// if it is a reference to this type
	@property bool isRef(){
		return _isRef;
	}
	/// ditto
	@property bool isRef(bool newVal){
		return _isRef = newVal;
	}
	/// type name
	@property string type(){
		return _type;
	}
	/// ditto
	@property string type(string newType){
		return _type = newType;
	}
	/// Returns: dimensions, in case array, otherwise 0
	@property uint dimensions(){
		return _dimensions;
	}
	/// ditto
	@property uint dimensions(uint newDim){
		return _dimensions = newDim;
	}
	/// this data as string  
	/// 
	/// only use for debug or error reporting. reading back string to DataType is not a thing
	override string toString() const{
		char[] r;
		if (_isRef)
			r = cast(char[])"ref " ~ _type;
		else
			r = _type.dup;
		uint index = cast(uint)r.length;
		r.length += 2 * _dimensions;
		for (; index < r.length; index += 2)
			r[index .. index + 2] = "[]";
		return cast(string)r;
	}
	/// Read from tokens
	/// 
	/// Returns: number of tokens read, or 0 if not a type
	uint fromToken(Token[] tokens){
		this.clear();
		uint index = 0;
		if (index >= tokens.length || !isIdentifier(tokens[index]))
			return 0;
		if (tokens[index].type == TokenType.KeywordRef){
			index ++;
			if (index >= tokens.length || !isIdentifier(tokens[index]))
				return 0;
			_isRef = true;
		}
		_type = tokens[index].token;
		index ++;
		while (index + 1 < tokens.length &&
				tokens[index] == Token(TokenType.Operator, "[") &&
				tokens[index + 1].type == TokenType.IndexClose){
			_dimensions ++;
			index += 2;
		}
		return index;
	}
	/// == operator
	bool opBinary(string op : "==")(DataType rhs){
		return rhs !is null && rhs._dimensions == _dimensions && 
			_type == rhs._type;
	}
}
/// 
unittest{
	Token[] tok = [ // int [ ] [ ] # array of pointers, to array of int
		Token(TokenType.KeywordInt,"int"),
		Token(TokenType.Operator,"["),Token(TokenType.IndexClose,"]"),
		Token(TokenType.Operator,"["),Token(TokenType.IndexClose,"]")
	];
	DataType type = new DataType();
	assert(type.fromToken(tok) == tok.length, type.fromToken(tok).to!string);
	assert(type.toString == "int[][]");
	type.clear();
	tok = [
		Token(TokenType.KeywordRef, "ref"), Token(TokenType.KeywordInt, "int")
	];
	assert(type.fromToken(tok) == 2);
	assert(type.toString == "ref int", type.toString);
	.destroy (type);
}

/// Declaration Node (function decl, struct decl, enum decl...)
package abstract class DeclNode : ASTNode{
protected:
	/// visibility
	Visibility _visibility;
public:
	/// constuctor
	this(Visibility visibility = DEFAULT_VISIBILITY){
		_visibility = visibility;
	}
	/// destructor
	~this(){}
	/// visibility
	@property Visibility visibility(){
		return _visibility;
	}
	/// ditto
	@property Visibility visibility(Visibility newVal){
		return _visibility = newVal;
	}
}

/// Expression. By default, it has void return type, so its a statement
package abstract class ExpressionNode : ASTNode{
protected:
	/// Return type of expression, can be void
	DataType _returnType;

	override @property ASTNode[] _children(){
		if (_returnType)
			return [_returnType];
		return [];
	}
public:
	/// constructor
	this(DataType retType = new DataType()){
		_returnType = retType;
	}
	/// destructor
	~this(){
		.destroy(_returnType);
	}
	/// Returns: return type
	@property DataType returnType(){
		return _returnType;
	}
}

/// Operator expression
package abstract class Operator : ExpressionNode{
protected:
	/// operator
	string _operator;
	/// if this comes before a operandA (binary will always be false)
	bool _prefix;
	/// priority (higher evaluated first)
	uint _priority;
	/// operator function
	FuncDeclNode _opFunc;
	/// called to generate _opFunc
	abstract void _generateOpFunc();
	
	override @property ASTNode[] _children(){
		if (_opFunc)
			return super._children ~ _opFunc;
		return super._children;
	}
public:
	/// constructor
	this(string operator = null, bool prefix = false, uint priority = 0, DataType retType = new DataType()){
		_operator = operator;
		_prefix = prefix;
		_priority = priority;
		super(retType);
	}
	/// destructor
	~this(){
		if (_opFunc)
			.destroy (_opFunc);
	}
	/// Operator
	@property string operator(){
		return _operator;
	}
	/// if this comes before a operandA (binary will always be false)
	@property bool prefix(){
		return _prefix;
	}
	/// priority (higher -> evaluated first)
	@property uint priority(){
		return _priority;
	}
	/// Operator function 
	@property FuncDeclNode opFunc(){
		if (!_opFunc)
			_generateOpFunc();
		return _opFunc;
	}
}

/// Binary operator expression
package abstract class OperatorBin : Operator{
protected:
	/// Operator function name
	string _opFuncName;
	/// Left side operand
	ExpressionNode _operandL;
	/// Right side operand
	ExpressionNode _operandR;
	/// Called to generate _opFunc
	override void _generateOpFunc(){
		if (!_operandL || !_operandR)
			return;
		if (_opFunc)
			.destroy(_opFunc);
		DataType lType = new DataType(_operandL.returnType), 
			rType = new DataType(_operandR.returnType);
		_opFunc = new FuncDeclNode(DEFAULT_VISIBILITY, null, _opFuncName, [lType, rType]);
	}

	override @property ASTNode[] _children(){
		ASTNode[] ret;
		if (_operandL)
			ret ~= _operandL;
		if (_operandR)
			ret ~= _operandR;
		return super._children ~ ret;
	}
public:
	/// constructor
	this (string operator = null, string opFuncName = null, uint priority = 0,
			DataType retType = new DataType(), ExpressionNode operandL = null, ExpressionNode operandR = null){
		super(operator, false, priority, retType);
		_opFuncName = opFuncName;
		_operandL = operandL;
		_operandR = operandR;
	}
	/// destructor
	~this (){
		if (_operandL)
			.destroy(_operandL);
		if (_operandR)
			.destroy(_operandR);
	}
	/// Left operand
	@property ExpressionNode operandL(){
		return _operandL;
	}
	/// ditto
	@property ExpressionNode operandL(ExpressionNode newL){
		if (_operandL)
			.destroy (_operandL);
		if (_opFunc){
			.destroy(_opFunc);
			_opFunc = null;
		}
		return _operandL = newL;
	}
	/// Right operand
	@property ExpressionNode operandR(){
		return _operandR;
	}
	/// ditto
	@property ExpressionNode operandR(ExpressionNode newR){
		if (_operandR)
			.destroy (_operandR);
		if (_opFunc){
			.destroy(_opFunc);
			_opFunc = null;
		}
		return _operandR = newR;
	}
}

/// Unary operator expression
package abstract class OperatorUn : Operator{
protected:
	/// Operator function name
	string _opFuncName;
	/// Operand
	ExpressionNode _operand;
	/// Called to generate _opFunc
	override void _generateOpFunc(){
		if (!_operand)
			return;
		if (_opFunc)
			.destroy(_opFunc);
		DataType operandType = new DataType(_operand.returnType);
		_opFunc = new FuncDeclNode(DEFAULT_VISIBILITY, null, _opFuncName, [operandType]);
	}

	override @property ASTNode[] _children(){
		if (_operand)
			return super._children ~ _operand;
		return super._children;
	}
public:
	/// constructor
	this (string operator = null, bool prefix = false, string opFuncName = null, uint priority = 0,
			DataType retType = new DataType(), ExpressionNode operand = null){
		super (operator, prefix, priority, retType);
		_opFuncName = opFuncName;
		_operand = operand;
	}
	/// destructor
	~this (){
		if (_operand)
			.destroy(_operand);
	}
	/// Returns: the operand
	@property ExpressionNode operand(){
		return _operand;
	}
	/// ditto
	@property ExpressionNode operand(ExpressionNode newOp){
		if (_operand)
			.destroy(_operand);
		if (_opFunc){
			.destroy(_opFunc);
			_opFunc = null;
		}
		return _operand = newOp;
	}
}

/// Script Node
package class ScriptNode : ASTNode{
protected:
	/// declarations
	DeclNode[] _declarations;

	override @property ASTNode[] _children(){
		// parent class has no children
		return cast(ASTNode[])_declarations;
	}
public:
	/// constructor
	this(DeclNode[] declarations){
		_declarations = declarations.dup;
	}
	/// destructor
	~this(){
		foreach (dec; _declarations)
			.destroy(dec);
	}
	/// count of declaration
	@property uint declCount(){
		return cast(uint)_declarations.length;
	}
	/// Returns: a declaration
	/// 
	/// Throws: Exception in case index out of bounds
	DeclNode declGet(uint index){
		if (index >= _declarations.length)
			throw new Exception("index out of bounds");
		return _declarations[index];
	}
	/// appends a DeclarationNode
	/// 
	/// Returns: its index
	uint declAppend(DeclNode node){
		immutable uint r = cast(uint)_declarations.length;
		if (node)
			node._parent = this;
		_declarations ~= node;
		return r;
	}
}

/// Variable declaration
private class VarDefNode(T = ASTNode) : T if (is (T : ASTNode)){
protected:
	/// Data type
	DataType _dataType;
	/// names of variables
	string[] _varName;
	/// default value, if not null
	ExpressionNode[] _varValue;

	override @property ASTNode[] _children(){
		ASTNode[] ret;
		if (_dataType)
			ret ~= _dataType;
		foreach (val; _varValue){
			if (val)
				ret ~= val;
		}
		return ret;
	}
public:
	/// constuctor
	this(DataType dataType = new DataType()){
		_dataType = dataType;
	}
	/// destructor
	~this(){
		foreach (node; _varValue)
			.destroy(node);
		.destroy(_dataType);
	}
	/// Returns: number of variables defined
	@property uint varCount(){
		return cast(uint)_varName.length;
	}
	/// Returns: variable name
	string varName(uint index){
		if (index >= _varName.length)
			throw new Exception("index out of bounds");
		return _varName[index];
	}
	/// Returns: variable default value
	ExpressionNode varValue(uint index){
		if (index >= _varValue.length)
			throw new Exception("index out of bounds");
		return _varValue[index];
	}
	/// appends a variable
	/// 
	/// Returns: its index
	int varAppend(string name, ExpressionNode value = null){
		immutable uint r = cast(uint)_varName.length;
		if (value)
			value._parent = this;
		_varName ~= name;
		_varValue ~= value;
		return r;
	}
	/// Returns: data type of defined variables
	@property DataType dataType(){
		return _dataType;
	}
}

/// global variable declaration
package alias GlobVarDefNode = VarDefNode!DeclNode;

/// Local variable declaration
package alias LocalVarDefNode = VarDefNode!ExpressionNode;

/// Struct declaration
package class StructDefNode : DeclNode{
protected:
	/// Variables.
	VarDefNode!ASTNode[] _member;

	override @property ASTNode[] _children(){
		return cast(ASTNode[])_member;
	}
public:
	/// constructor
	this(Visibility visibility = DEFAULT_VISIBILITY, string name = null){
		super(visibility);
		this.name = name;
	}
	/// Returns: number of members
	@property uint memberCount(){
		return cast(uint)_member.length;
	}
	/// Returns: member name
	VarDefNode!ASTNode member(uint index){
		if (index >= _member.length)
			throw new Exception("StructDefNode.member index out of bounds");
		return _member[index];
	}
	/// appends a member
	/// 
	/// Returns: index
	uint memberAppend(VarDefNode!ASTNode member){
		immutable uint r = cast(uint)_member.length;
		if (member)
			member._parent = this;
		_member ~= member;
		return r;
	}
}

/// Enum declaration
package class EnumDefNode : DeclNode{
protected:
	/// Base data type
	DataType _dataType;
	/// member names
	string[] _memberName;
	/// member values, if not null
	ExpressionNode[] _memberValue;

	override @property ASTNode[] _children(){
		ASTNode[] ret;
		if (_dataType)
			ret ~= _dataType;
		foreach (val; _memberValue){
			if (val)
				ret ~= val;
		}
		return ret;
	}
public:
	/// constructor
	this(Visibility visibility = DEFAULT_VISIBILITY, string name = null,
			DataType dataType = new DataType(), string[] memberName = null){
		super(visibility);
		_dataType = dataType;
		_name = name;
		_memberName = memberName.dup;
		_memberValue.length = _memberName.length;
	}
	/// destructor
	~this(){
		foreach (node; _memberValue)
			.destroy(node);
		.destroy(_dataType);
	}
	/// Returns: data type
	@property DataType dataType(){
		return _dataType;
	}
	/// Returns: number of members
	@property uint memberCount(){
		return cast(uint)_memberName.length;
	}
	/// Returns: member name
	string memberName(uint index){
		if (index >= _memberName.length)
			throw new Exception("EnumDefNode.memberName index out of bounds");
		return _memberName[index];
	}
	/// Returns: member value
	ExpressionNode memberValue(uint index){
		if (index >= _memberValue.length)
			throw new Exception("EnumDefNode.memberValue index out of bounds");
		return _memberValue[index];
	}
	/// appends a member
	/// 
	/// Returns: index
	uint memberAppend(string name, ExpressionNode value = null){
		immutable uint r = cast(uint)_memberName.length;
		if (value)
			value._parent = this;
		_memberName ~= name;
		_memberValue ~= value;
		return r;
	}
}

/// Function declaration (return type, name, args + arg types)
package class FuncDeclNode : DeclNode{
protected:
	/// Returns type
	DataType _returnType;
	/// function name
	string _name;
	/// Argument types
	DataType[] _argType;
	/// Argument names
	string[] _argName;

	override @property ASTNode[] _children(){
		if (_returnType)
			return cast(ASTNode)_returnType ~ cast(ASTNode[])_argType;
		return cast(ASTNode[])_argType;
	}
public:
	/// constructor
	this(Visibility visibility = DEFAULT_VISIBILITY, DataType returnType = new DataType(),
			string name = null, DataType[] argType = null, string[] argName = null){
		
		assert(argName.length == 0 || argName.length == _argType.length,
			"argName.length doesnt match argType.length");
		super(visibility);
		_returnType = returnType;
		_name = name;
		_argType = argType.dup;
		if (_argName.length)
			_argName = argName.dup;
	}
	/// destructor
	~this(){
		foreach (type; _argType)
			.destroy(type);
		.destroy(_returnType);
	}
	/// Returns: function return type
	@property DataType returnType(){
		return _returnType;
	}
	/// ditto
	@property DataType returnType(DataType newT){
		if (_returnType)
			.destroy(_returnType);
		return _returnType = newT;
	}
	/// Returns: argument count
	@property uint argCount(){
		return cast(uint)_argType.length;
	}
	/// Returns: argument name at index
	/// 
	/// Throws: Exception if index out of bounds
	string argName(uint index){
		if (index >= _argName.length)
			throw new Exception("index out of bounds");
		return _argName[index];
	}
	/// Returns: argument type at index
	/// 
	/// Throws: Exception if index out of bounds
	DataType argType(uint index){
		if (index >= _argType.length)
			throw new Exception("index out of bounds");
		return _argType[index];
	}
	/// append an argument
	/// 
	/// Returns: index
	uint argAppend(DataType type, string name = null){
		immutable uint r = cast(uint)_argType.length;
		if (_argName)
			_argName ~= name;
		_argType ~= type;
		return r;
	}
}

/// Function definition
package class FuncDefNode : FuncDeclNode{
protected:
	BlockNode _body;

	override @property ASTNode[] _children(){
		if (_body)
			return super._children ~ _body;
		return super._children;
	}
public:
	/// constructor
	this(Visibility visibility = DEFAULT_VISIBILITY, DataType returnType = new DataType(),
			string name = null, DataType[] argType = null, string[] argName = null){
		super(visibility, returnType, name, argType, argName);
		_body = new BlockNode();
		_body._parent = this;
	}
	/// destructor
	~this(){
		.destroy(_body);
	}
	/// Returns: body
	@property BlockNode bodyBlock(){
		return _body;
	}
}

/// Block
package class BlockNode : ExpressionNode{
protected:
	ExpressionNode[] _expression;

	override @property ASTNode[] _children(){
		return super._children ~ cast(ASTNode[])_expression;
	}
public:
	/// constructor
	this (){
		super(new DataType()); // void return type
	}
	/// destructor
	~this (){
		foreach (node; _expression)
			.destroy(node);
	}
	/// Returns: number of expressions
	@property uint expressionCount(){
		return cast(uint)_expression.length;
	}
	/// Returns: expression at index
	/// 
	/// Throws: Exception if index out of bounds
	ExpressionNode expressionGet(uint index){
		if (index >= _expression.length)
			throw new Exception("index out of bounds");
		return _expression[index];
	}
	/// appends expression
	/// 
	/// Returns: index
	uint expressionAppend(ExpressionNode node){
		immutable uint r = cast(uint)_expression.length;
		if (node)
			node._parent = this;
		_expression ~= node;
		return r;
	}
}

/// Function call expression
package class FuncCall : ExpressionNode{
protected:
	/// Identifier of function to call
	Identifier _funcIdent;
	/// Arguments of function call
	ExpressionNode[] _args;

	override @property ASTNode[] _children(){
		return super._children ~ cast(ASTNode[])_args;
	}
public:
	/// constructor
	this (Identifier funcIdent = null){
		_funcIdent = funcIdent;
		super(new DataType()); // return type is unknown for now.
	}
	/// destructor
	~this (){
		foreach (arg; _args)
			.destroy (arg);
	}
	/// Returns: Identifier of function to call
	@property ref Identifier funcIdent(){
		return _funcIdent;
	}
	/// ditto
	@property ref Identifier funcIdent(Identifier newIdent){
		return _funcIdent = newIdent;
	}
	/// Returns: number of arguments
	@property uint argCount(){
		return cast(uint)_args.length;
	}
	/// Returns: argument with index
	/// 
	/// Throws: Exception if index out of bounds
	ExpressionNode argGet(uint index){
		if (index >= _args.length)
			throw new Exception("index out of bounds");
		return _args[index];
	}
	/// Appends argument
	/// 
	/// Returns: index
	uint argAppend(ExpressionNode arg){
		immutable uint r = cast(uint)_args.length;
		arg._parent = this;
		_args ~= arg;
		return r;
	}
}

/// Literal ExpressionNode template
private class LiteralExpression(T, string typename, uint dim = 0) : ExpressionNode{
protected:
	/// value
	T _val;
public:
	/// constructor
	this (T val = T.init){
		super (new DataType(typename, dim));
		_val = val;
	}
	/// Returns: value
	@property T val(){
		return _val;
	}
	/// ditto
	@property T val(T newVal){
		return _val = newVal;
	}
}

/// Integer Literal
package alias LiteralInt = LiteralExpression!(ptrdiff_t, TYPENAME.INT, 0);
/// Float Literal
package alias LiteralFloat = LiteralExpression!(double, TYPENAME.FLOAT, 0);
/// Character Literal
package alias LiteralChar = LiteralExpression!(char, TYPENAME.CHAR, 0);
/// Boolean Literal
package alias LiteralBool = LiteralExpression!(bool, TYPENAME.BOOL, 0);
/// String Literal
package alias LiteralString = LiteralExpression!(string, TYPENAME.CHAR, 1);

/// member select operator
package class OperatorMemberSelect : OperatorBin{
protected:
	/// Called to generate _opFunc
	override void _generateOpFunc(){
		if (!_operandL || !_operandR)
			return;
		if (_opFunc)
			.destroy(_opFunc);
		DataType lType = new DataType(_operandL.returnType),
			rType = new DataType(TYPENAME.CHAR, 1);
		_opFunc = new FuncDeclNode(DEFAULT_VISIBILITY, null, _opFuncName, [lType, rType]);
	}
public:
	/// constructor
	this(){
		super(".", "opMemberSelect", 10);
	}
}
/// index read operator
package class OperatorIndexRead : OperatorBin{
public:
	/// constructor
	this(){
		super("[", "opIndexRead", 10);
	}
}
/// dereference operator
package class OperatorDeref : OperatorUn{
public:
	/// constructor
	this (){
		super("@", false, "opDeref", 9);
	}
}
/// post increment operator
package class OperatorIncPost : OperatorUn{
public:
	/// constructor
	this(){
		super("++", false, "opIncPost", 9);
	}
}
/// post decrement operator
package class OperatorDecPost : OperatorUn{
public:
	/// constructor
	this(){
		super("--", false, "opDecPost", 9);
	}
}
/// reference operator
package class OperatorRef : OperatorUn{
public:
	/// constructor
	this (){
		super("@", true, "opRef", 8);
	}
}
/// boolean not operator
package class OperatorBoolNot : OperatorUn{
public:
	/// constructor
	this (){
		super ("!", true, "opBoolNot", 8);
	}
}
/// pre increment operator
package class OperatorIncPre : OperatorUn{
public:
	/// constructor
	this(){
		super ("++", true, "opIncPre", 8);
	}
}
/// pre decrement operator
package class OperatorDecPre : OperatorUn{
public:
	/// constructor
	this(){
		super ("--", true, "opDecPre", 8);
	}
}
/// multiply operator
package class OperatorMultiply : OperatorBin{
public:
	/// constructor
	this(){
		super ("*", "opMultiply", 7);
	}
}
/// divide operator
package class OperatorDivide : OperatorBin{
public:
	/// constructor
	this(){
		super ("/", "opDivide", 7);
	}
}
/// mod operator
package class OperatorMod : OperatorBin{
public:
	/// constructor
	this(){
		super ("%", "opMod", 7);
	}
}
/// add operator
package class OperatorAdd : OperatorBin{
public:
	/// constructor
	this(){
		super ("+", "opAdd", 6);
	}
}
/// subtract operator
package class OperatorSubtract : OperatorBin{
public:
	/// constructor
	this(){
		super ("-", "opSubtract", 6);
	}
}
/// concat operator
package class OperatorConcat : OperatorBin{
public:
	/// constructor
	this(){
		super ("~", "opConcat", 6);
	}
}
/// bitshift left operator
package class OperatorBitshiftLeft : OperatorBin{
public:
	/// constructor
	this(){
		super ("<<", "opBitshiftLeft", 5);
	}
}
/// bitshift right operator
package class OperatorBitshiftRight : OperatorBin{
public:
	/// constructor
	this(){
		super (">>", "opBitshiftRight", 5);
	}
}
/// IsSame operator
package class OperatorIsSame : OperatorBin{
public:
	/// constructor
	this(){
		super ("==", "opIsSame", 4);
	}
}
/// IsNotSame operator
package class OperatorIsNotSame : OperatorBin{
public:
	/// constructor
	this(){
		super ("!=", "opIsNotSame", 4);
	}
}
/// IsGreaterOrSame operator
package class OperatorIsGreaterOrSame : OperatorBin{
public:
	/// constructor
	this(){
		super (">=", "opIsGreaterOrSame", 4);
	}
}
/// IsSmallerOrSame operator
package class OperatorIsSmallerOrSame : OperatorBin{
public:
	/// constructor
	this(){
		super ("<=", "opIsSmallerOrSame", 4);
	}
}
/// IsGreater operator
package class OperatorIsGreater : OperatorBin{
public:
	/// constructor
	this(){
		super (">", "opIsGreater", 4);
	}
}
/// IsSmaller operator
package class OperatorIsSmaller : OperatorBin{
public:
	/// constructor
	this(){
		super ("<", "opIsSmaller", 4);
	}
}
/// Binary And operator
package class OperatorBinAnd : OperatorBin{
public:
	/// constructor
	this(){
		super ("&", "opBinAnd", 3);
	}
}
/// Binary Or operator
package class OperatorBinOr : OperatorBin{
public:
	/// constructor
	this(){
		super ("|", "opBinOr", 3);
	}
}
/// Binary Xor operator
package class OperatorBinXor : OperatorBin{
public:
	/// constructor
	this(){
		super ("^", "opBinXor", 3);
	}
}
/// Boolean And operator
package class OperatorBoolAnd : OperatorBin{
public:
	/// constructor
	this(){
		super ("&&", "opBoolAnd", 2);
	}
}
/// Boolean Or operator
package class OperatorBoolOr : OperatorBin{
public:
	/// constructor
	this(){
		super ("||", "opBoolOr", 2);
	}
}
/// Assign operator
package class OperatorAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("=", "opAssign", 1);
	}
}
/// Add Assign operator
package class OperatorAddAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("+=", "opAddAssign", 1);
	}
}
/// Subtract Assign operator
package class OperatorSubtractAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("-=", "opSubtractAssign", 1);
	}
}
/// Multiply Assign operator
package class OperatorMultiplyAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("*=", "opMultiplyAssign", 1);
	}
}
/// Divide Assign operator
package class OperatorDivideAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("/=", "opDivideAssign", 1);
	}
}
/// Mod Assign operator
package class OperatorModAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("%=", "opModAssign", 1);
	}
}
/// Concat Assign operator
package class OperatorConcatAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("~=", "opConcatAssign", 1);
	}
}
/// Binary And Assign operator
package class OperatorBinAndAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("&=", "opBinAndAssign", 1);
	}
}
/// Binary Or Assign operator
package class OperatorBinOrAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("|=", "opBinOrAssign", 1);
	}
}
/// Binary Xor Assign operator
package class OperatorBinXorAssign : OperatorBin{
public:
	/// constructor
	this(){
		super ("^=", "opbinXorAssign", 1);
	}
}