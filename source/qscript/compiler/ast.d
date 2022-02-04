module qscript.compiler.ast;

import utils.misc;
import utils.ds;

import qscript.compiler.compiler;
import qscript.compiler.tokens;

debug{import std.stdio;}
import std.conv : to;

/// for storing [namespace, namespace, .., parent, .., name]
alias Identifier = string[];

/// reads tokens into ident
/// 
/// Returns: number of tokens read
package uint fromTokens(ref Identifier ident, Token[] tokens){
	uint index = 0;
	if (index < tokens.length && tokens[index].token.isIdentifier){
		ident = [tokens[index].token];
		index ++;
	}else
		return 0;
	while (index + 1 < tokens.length && tokens[index].type == TokenType.OpMemberSelect &&
	tokens[index + 1].token.isIdentifier){
		ident ~= tokens[index + 1].token;
		index += 2;
	}
	return index;
}
/// 
unittest{
	Token[] tok = [
		Token(TokenType.Identifier,"qscript"), Token(TokenType.OpMemberSelect,"."),
		Token(TokenType.Identifier,"std"), Token(TokenType.OpMemberSelect,"."),
		Token(TokenType.Identifier,"io"), Token(TokenType.OpMemberSelect,".")
	];
	Identifier ident;
	assert(ident.fromTokens(tok) == 5);
	assert(ident.toString == "qscript.std.io");
}

/// Returns: string representation of Identifier
package string toString(Identifier ident){
	string ret;
	foreach (name; ident[0 .. $ - 1])
		ret ~= name ~ '.';
	return ret ~ ident[$-1];
}

/// Data Type
class DataType{
private:
	/// its identifier (name). not valid if _refTo !is null
	Identifier _ident;
	/// array dimensions (zero if not array)
	uint _dimensions = 0;
	/// reference to type. if this is not null, then _ident is not valid
	DataType _refTo = null;
	/// number of bytes that will be occupied, 0 if unknown
	uint _byteCount = 0;
public:
	/// constructor
	this (){}
	/// constructor
	/// be aware ident will be destroyed along with this
	this(Identifier ident, uint dimensions = 0){
		this._ident = ident;
		_dimensions = dimensions;
	}
	~this(){
		this.clear();
	}
	/// clone from another DataType
	void clone(DataType from){
		this.clear();
		if (!from)
			return;
		_dimensions = from._dimensions;
		_byteCount = from._byteCount;
		if (from._refTo){
			_refTo = new DataType();
			_refTo.clone(from._refTo);
		}else{
			_ident = from._ident.dup;
		}
	}
	/// turn it into a reference of itself
	void makeRef(){
		DataType refTo = new DataType();
		// dont use clone here, that will clone everything, inefficient
		refTo._ident = _ident;
		refTo._dimensions = _dimensions;
		refTo._refTo = _refTo;
		refTo._byteCount = _byteCount;
		_ident = null;
		_dimensions = 0;
		_refTo = refTo;
		_byteCount = 0;
	}
	/// Clears itself
	void clear(){
		if (_refTo)
			.destroy(_refTo);
		_ident = [];
		_refTo = null;
		_dimensions = 0;
		_byteCount = 0;
	}
	/// Identifier (name) for this type
	@property ref Identifier ident(){
		return _ident;
	}
	/// Returns: dimensions, in case array, otherwise 0
	@property uint dimensions(){
		return _dimensions;
	}
	/// ditto
	@property uint dimensions(uint newDim){
		return _dimensions = newDim;
	}
	/// Data type this is a reference to (or null if this is not a reference)
	@property DataType refTo(){
		return _refTo;
	}
	/// ditto
	@property DataType refTo(DataType newT){
		if (_refTo)
			.destroy(_refTo);
		return _refTo = newT;
	}
	/// this data as string  
	/// 
	/// only use for debug or error reporting. reading back string to DataType is not a thing
	override string toString(){
		char[] r;
		if (_refTo)
			r = cast(char[])_refTo.toString ~ '@';
		else if (_ident)
			r = cast(char[])_ident.toString;
		uint index = cast(uint)r.length;
		r.length += 2*_dimensions;
		for (; index < r.length; index += 2)
			r[index .. index + 2] = "[]";
		return cast(string)r;
	}
	/// Read from tokens
	/// 
	/// Returns: number of tokens read, or 0 if not a type
	uint fromTokens(Token[] tokens){
		this.clear();
		uint index = 0;
		while (index < tokens.length){
			if (tokens[index].type == TokenType.OpRef){
				if (!_refTo && !_ident.length)
					break;
				DataType refTo = new DataType();
				refTo.clone(this);
				this.clear();
				this._refTo = refTo;
				index ++;
			}else if (tokens[index].type == TokenType.IndexOpen){
				if ((!_ident.length && !_refTo) || index + 1 >= tokens.length ||
				tokens[index + 1].type != TokenType.IndexClose)
					break;
				_dimensions ++;
				index += 2;
			}else if (tokens[index].token.isIdentifier){
				if (_ident.length)
					break;
				_ident = [tokens[index].token];
				index ++;
			}else
				break;
		}
		return index;
	}
	/// == operator
	bool opBinary(string op : "==")(DataType rhs){
		return rhs !is null && rhs._dimensions == _dimensions && 
			(!_refTo || _refTo == rhs._refTo) && (_ident == rhs._ident);
	}
}
/// 
unittest{
	Token[] tok = [ // int [ ] @ [ ] # array of references, to array of int
		Token(TokenType.KeywordInt,"int"),Token(TokenType.IndexOpen,"["),
		Token(TokenType.IndexClose,"]"),Token(TokenType.OpRef,"@"),
		Token(TokenType.IndexOpen,"["),Token(TokenType.IndexClose,"]")
	];
	DataType type = new DataType();
	assert(type.fromTokens(tok) == tok.length, type.fromTokens(tok).to!string);
	assert(type.toString == "int[]@[]");
	.destroy (type);
}

/// an AST Node
package abstract class ASTNode{
protected:
	/// line number and column number
	uint[2] _location;
	/// parent node
	ASTNode _parent = null;
public:
	/// Returns: line number
	@property uint lineno(){
		return _location[0];
	}
	/// ditto
	@property uint lineno(uint newVal){
		return _location[0] = newVal;
	}
	/// Returns: column number
	@property uint colno(){
		return _location[1];
	}
	/// ditto
	@property uint colno(uint newVal){
		return _location[1] = newVal;
	}
	/// Finds ASTNode for an Identifier
}

/// Declaration Node (function decl, struct decl, enum decl...)
package abstract class DeclNode : ASTNode{
protected:
	/// visibility
	Visibility _visibility = DEFAULT_VISIBILITY;
	/// identifier of what is being declared
	Identifier _ident;
public:
	/// constuctor
	this(){}
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
	/// Returns: identifier
	@property ref Identifier ident(){
		return _ident;
	}
}

/// Expression
package abstract class ExpressionNode : ASTNode{
protected:
	/// Return type of expression, can be void
	DataType _returnType;
public:
	/// constructor
	this(){
		_returnType = new DataType();
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

/// Statement
package abstract class StatementNode : ExpressionNode{
protected:
	/// void return type
	DataType _voidType;
public:
	/// constructor
	this (){
		_voidType = new DataType([TYPENAME.VOID]);
	}
	/// destructor
	~this (){
		.destroy(_voidType);
	}
	/// return type is always void
	override @property DataType returnType(){
		return _voidType;
	}
}
/// Binary operator expression
package abstract class OperatorBin : ExpressionNode{
protected:
	/// Operator
	string _operator;
	/// Operator function
	FuncDeclNode _opFunc;
	/// Operator function name
	string _opFuncName;
	/// Left side operand
	ExpressionNode _operandL;
	/// Right side operand
	ExpressionNode _operandR;
	/// Called to generate _opFunc
	void _generateOpFunc(){
		if (!_operandL || !_operandR)
			return;
		if (_opFunc)
			.destroy(_opFunc);
		DataType lType = new DataType(), rType = new DataType();
		lType.clone(_operandL.returnType);
		rType.clone(_operandR.returnType);
		_opFunc = new FuncDeclNode(null, _opFuncName, [lType, rType]);
	}
public:
	/// constructor
	this (){}
	/// destructor
	~this (){
		if (_opFunc)
			.destroy(_opFunc);
		if (_operandL)
			.destroy(_operandL);
		if (_operandR)
			.destroy(_operandR);
	}
	/// Operator
	@property string operator(){
		return _operator;
	}
	/// Operator function 
	@property FuncDeclNode opFunc(){
		if (!_opFunc)
			_generateOpFunc();
		return _opFunc;
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
package abstract class OperatorUn : ExpressionNode{
protected:
	/// Operator
	string _operator;
	/// Operator function
	FuncDeclNode _opFunc;
	/// Operator function name
	string _opFuncName;
	/// if this is prefixed 
	bool _prefix = true;
	/// Operand
	ExpressionNode _operand;
	/// Called to generate _opFunc
	void _generateOpFunc(){
		if (!_operand)
			return;
		if (_opFunc)
			.destroy(_opFunc);
		DataType operandType = new DataType();
		operandType.clone(_operand.returnType);
		_opFunc = new FuncDeclNode(null, _opFuncName, [operandType]);
	}
public:
	/// constructor
	this (){}
	/// destructor
	~this (){
		if (_opFunc)
			.destroy(_opFunc);
		if (_operand)
			.destroy(_operand);
	}
	/// Returns: the operator
	@property string operator(){
		return _operator;
	}
	/// Operator function 
	@property FuncDeclNode opFunc(){
		if (!_opFunc)
			_generateOpFunc();
		return _opFunc;
	}
	/// Returns: true if this is prefixed, false if postfixed
	@property bool prefix(){
		return _prefix;
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

/// Namespace Node
package abstract class NamespaceNode : DeclNode{
protected:
	/// declarations
	DeclNode[] _declarations;
public:
	/// constructor
	this(){}
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

/// Script Node
package class ScriptNode : NamespaceNode{
public:
	/// Returns: script name
	@property string scriptName(){
		if (_ident.length)
			return _ident[$ - 1];
		return DEFAULT_SCRIPT_NAME;
	}
	/// ditto
	@property string scriptName(string newName){
		if (_ident.length)
			return _ident[$-1] = newName;
		return (_ident = [newName])[0];
	}
}

/// Variable declaration template
private class GenericVarDefNode(T) : T{
protected:
	/// Data type
	DataType _dataType;
	/// names of variables
	string[] _varName;
	/// default value, if not null
	ExpressionNode[] _varValue;
public:
	/// constuctor
	this(){
		_dataType = new DataType();
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
package alias GlobVarDefNode = GenericVarDefNode!DeclNode;

/// Local variable declaration
package alias LocalVarDefNode = GenericVarDefNode!StatementNode;

/// Struct declaration
package class StructDefNode : NamespaceNode{
public:
	/// constructor
	this(string name){
		_ident = [name];
	}
	/// Returns: struct name
	@property string name(){
		if (_ident.length)
			return _ident[$-1];
		return "";
	}
	/// ditto
	@property string name(string newName){
		if (_ident.length)
			return _ident[$-1] = newName;
		return (_ident = [newName])[0];
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
public:
	/// constructor
	this(){
		_dataType = new DataType();
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
	/// Argument types
	DataType[] _argType;
	/// Argument names
	string[] _argName;
public:
	/// constructor
	this(DataType returnType, string name, DataType[] argType, string[] argName = []){
		assert(argName.length == 0 || argName.length == _argType.length,
			"argName.length doesnt match argType.length");
		_returnType = returnType;
		_ident = [name];
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
public:
	/// constructor
	this(DataType returnType, string name, DataType[] argType, string[] argName){
		super(returnType, name, argType, argName);
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
package class BlockNode : StatementNode{
protected:
	StatementNode[] _statement;
public:
	/// constructor
	this (){}
	/// destructor
	~this (){
		foreach (node; _statement)
			.destroy(node);
	}
	/// Returns: number of statements
	@property uint statementCount(){
		return cast(uint)_statement.length;
	}
	/// Returns: statement at index
	/// 
	/// Throws: Exception if index out of bounds
	StatementNode statementGet(uint index){
		if (index >= _statement.length)
			throw new Exception("index out of bounds");
		return _statement[index];
	}
	/// appends statement
	/// 
	/// Returns: index
	uint statementAppend(StatementNode node){
		immutable uint r = cast(uint)_statement.length;
		if (node)
			node._parent = this;
		_statement ~= node;
		return r;
	}
}

/// Function call expression
package class FunctionCallExp : ExpressionNode{
protected:
	/// Identifier of function being called
	Identifier _ident;
	/// Arguments of function call
	ExpressionNode[] _args;
public:
	/// constructor
	this (){}
	/// destructor
	~this (){
		foreach (arg; _args)
			.destroy (arg);
	}
	/// Returns: function identifier
	@property ref Identifier ident(){
		return _ident;
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

/// Integer Literal
package class LiteralInt : ExpressionNode{
protected:
	/// token
	Token _tok;
	/// integer value
	ptrdiff_t _val;
	/// if value has been updated since _tok was last updated
	bool _updated = false;
	/// Reads _val from _tok
	/// 
	/// Throws: Exception if invalid format
	void readVal(){
		_val = 0;
		if (_tok.type == TokenType.LiteralInt)
			_val = _tok.token.to!ptrdiff_t;
		else if (_tok.type == TokenType.LiteralBinary && _tok.token.length > 2)
			_val = _tok.token.readBinary();
		else if (_tok.type == TokenType.LiteralHexadecimal && _tok.token.length > 2)
			_val = _tok.token.readHexadecimal();
		else
			throw new Exception("invalid token to read integer from");
		_updated = true;
	}
public:
	/// constructor
	this (){
		// set return type
		_returnType.clear();
		_returnType.ident = [TYPENAME.INT];
	}
	/// Returns: token
	@property Token token(){
		return _tok;
	}
	/// ditto
	@property Token token(Token newTok){
		_updated = false;
		return _tok = newTok;
	}
	/// Returns: value
	@property ptrdiff_t value(){
		if (_updated)
			return _val;
		readVal();
		return _val;
	}
}

/// Float literal
package class LiteralFloat : ExpressionNode{
protected:
	/// token
	Token _tok;
	/// value
	float _val;
	/// if _val updated after changing _tok
	bool _updated = false;
	/// reads _val from _tok
	/// 
	/// Throws: Exception if invalid format
	void readVal(){
		_val = 0;
		if (_tok.type != TokenType.LiteralFloat)
			throw new Exception("invalid token to read float from");
		_updated = true;
		_val = _tok.token.to!float;
	}
public:
	/// constructor
	this (){
		// set return type
		_returnType.clear();
		_returnType.ident = [TYPENAME.FLOAT];
	}
	/// Returns: token
	@property Token token(){
		return _tok;
	}
	/// ditto
	@property Token token(Token newTok){
		_updated = false;
		return _tok = newTok;
	}
	/// Returns: the value
	@property float value(){
		if (_updated)
			return _val;
		readVal();
		return _val;
	}
}

/// Character Literal
package class LiteralChar : ExpressionNode{
protected:
	/// Token
	Token _tok;
	/// value as a character
	char _val;
	/// if value is valid
	bool _updated = false;
	/// Reads _val from _tok
	/// 
	/// Throws: Exception if invalid format
	void readVal(){
		if (_tok.type != TokenType.LiteralChar || _tok.token.length < 3)
			throw new Exception("invalid token to read character from");
		char[] unesc = strUnescape(_tok.token[1 .. $-1]);
		if (unesc.length != 1)
			throw new Exception("character literal should store 1 character");
		_updated = true;
		_val = unesc[0];
	}
public:
	/// constructor
	this (){
		// set data type
		_returnType.clear();
		_returnType.ident = [TYPENAME.CHAR];
	}
	/// Returns: token
	@property Token token(){
		return _tok;
	}
	/// ditoo
	@property Token token(Token newTok){
		_updated = false;
		return _tok = newTok;
	}
	/// Returns: value
	@property char value(){
		if (_updated)
			return _val;
		readVal();
		return _val;
	}
}

/// Boolean Literal
package class LiteralBool : ExpressionNode{
protected:
	/// token
	Token _tok;
	/// value
	bool _val;
	/// if _val updated since last _tok was updated
	bool _updated = false;
	/// Reads _val from _tok
	/// 
	/// Throws: Exception if invalid format
	void readVal(){
		if (_tok.type == TokenType.KeywordTrue)
			_val = true;
		else if (_tok.type == TokenType.KeywordFalse)
			_val = false;
		else
			throw new Exception("invalid token to read boolean from");
		_updated = true;
	}
public:
	this(){
		// set data type
		_returnType.clear();
		_returnType.ident = [TYPENAME.BOOL];
	}
	/// Returns: token
	@property Token token(){
		return _tok;
	}
	/// ditto
	@property Token token(Token newTok){
		_updated = false;
		return _tok = newTok;
	}
	/// Returns: value
	@property bool value(){
		if (_updated)
			return _val;
		readVal();
		return _val;
	}
}

/// String literal
package class LiteralString : ExpressionNode{
protected:
	/// token
	Token _tok;
	/// value
	string _val;
	/// if _val updated after _tok updated
	bool _updated = false;
	/// Reads _val from _tok
	/// 
	/// Throws: Exception if invalid token
	void readVal(){
		if (_tok.type != TokenType.LiteralString || _tok.token.length < 2)
			throw new Exception("invalid token to read string from");
		_updated = true;
		_val = cast(string)strUnescape(_tok.token[1 .. $ - 1]);
	}
public:
	/// constructor
	this (){
		// set data type
		_returnType.clear();
		_returnType.ident = [TYPENAME.CHAR];
		_returnType.dimensions = 1;
	}
	/// Returns: oken
	@property Token token(){
		return _tok;
	}
	/// ditto
	@property Token token(Token newTok){
		_updated = false;
		return _tok = newTok;
	}
	/// Returns: value
	@property string value(){
		if (_updated)
			return _val;
		readVal();
		return _val;
	}
}

/// member select operator
package class OperatorMemberSelect : OperatorBin{
protected:
	/// Called to generate _opFunc
	void _generateOpFunc(){
		if (!_operandL || !_operandR)
			return;
		if (_opFunc)
			.destroy(_opFunc);
		DataType lType = new DataType(), rType = new DataType([TYPENAME.CHAR], 1);
		lType.clone(_operandL.returnType);
		_opFunc = new FuncDeclNode(null, _opFuncName, [lType, rType]);
	}
public:
	/// constructor
	this(){
		_operator = ".";
		_opFuncName = "opMemberSelect";
	}
}
/// index read operator
package class OperatorIndexRead : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "[";
		_opFuncName = "opIndexRead";
	}
}
/// dereference operator
package class OperatorDeref : OperatorUn{
public:
	/// constructor
	this (){
		_operator = "@";
		_opFuncName = "opDeref";
		_prefix = false;
	}
}
/// post increment operator
package class OperatorIncPost : OperatorUn{
public:
	/// constructor
	this(){
		_operator = "++";
		_opFuncName = "opIncPost";
		_prefix = false;
	}
}
/// post decrement operator
package class OperatorDecPost : OperatorUn{
public:
	/// constructor
	this(){
		_operator = "--";
		_opFuncName = "opDecPost";
		_prefix = false;
	}
}
/// reference operator
package class OperatorRef : OperatorUn{
public:
	/// constructor
	this (){
		_operator = "@";
		_opFuncName = "opRef";
		_prefix = true;
	}
}
/// boolean not operator
package class OperatorBoolNot : OperatorUn{
public:
	/// constructor
	this (){
		_operator = "!";
		_opFuncName = "opBoolNot";
		_prefix = true;
	}
}
/// pre increment operator
package class OperatorIncPre : OperatorUn{
public:
	/// constructor
	this(){
		_operator = "++";
		_opFuncName = "opIncPre";
		_prefix = true;
	}
}
/// pre decrement operator
package class OperatorDecPre : OperatorUn{
public:
	/// constructor
	this(){
		_operator = "--";
		_opFuncName = "opDecPre";
		_prefix = true;
	}
}
/// multiply operator
package class OperatorMultiply : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "*";
		_opFuncName = "opMultiply";
	}
}
/// divide operator
package class OperatorDivide : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "/";
		_opFuncName = "opDivide";
	}
}
/// mod operator
package class OperatorMod : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "%";
		_opFuncName = "opMod";
	}
}
/// add operator
package class OperatorAdd : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "+";
		_opFuncName = "opAdd";
	}
}
/// subtract operator
package class OperatorSubtract : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "-";
		_opFuncName = "opSubtract";
	}
}
/// concat operator
package class OperatorConcat : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "~";
		_opFuncName = "opConcat";
	}
}
/// bitshift left operator
package class OperatorBitshiftLeft : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "<<";
		_opFuncName = "opBitshiftLeft";
	}
}
/// bitshift right operator
package class OperatorBitshiftRight : OperatorBin{
public:
	/// constructor
	this(){
		_operator = ">>";
		_opFuncName = "opBitshiftRight";
	}
}
/// IsSame operator
package class OperatorIsSame : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "==";
		_opFuncName = "opIsSame";
	}
}
/// IsNotSame operator
package class OperatorIsNotSame : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "!=";
		_opFuncName = "opIsNotSame";
	}
}
/// IsGreaterOrSame operator
package class OperatorIsGreaterOrSame : OperatorBin{
public:
	/// constructor
	this(){
		_operator = ">=";
		_opFuncName = "opIsGreaterOrSame";
	}
}
/// IsSmallerOrSame operator
package class OperatorIsSmallerOrSame : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "<=";
		_opFuncName = "opIsSmallerOrSame";
	}
}
/// IsGreater operator
package class OperatorIsGreater : OperatorBin{
public:
	/// constructor
	this(){
		_operator = ">";
		_opFuncName = "opIsGreater";
	}
}
/// IsSmaller operator
package class OperatorIsSmaller : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "<";
		_opFuncName = "opIsSmaller";
	}
}
/// Binary And operator
package class OperatorBinAnd : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "&";
		_opFuncName = "opBinAnd";
	}
}
/// Binary Or operator
package class OperatorBinOr : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "|";
		_opFuncName = "opBinOr";
	}
}
/// Binary Xor operator
package class OperatorBinXor : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "^";
		_opFuncName = "opBinXor";
	}
}
/// Boolean And operator
package class OperatorBoolAnd : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "&&";
		_opFuncName = "opBoolAnd";
	}
}
/// Boolean Or operator
package class OperatorBoolOr : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "||";
		_opFuncName = "opBoolOr";
	}
}
/// Assign operator
package class OperatorAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "=";
		_opFuncName = "opAssign";
	}
}
/// Add Assign operator
package class OperatorAddAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "+=";
		_opFuncName = "opAssAssign";
	}
}
/// Subtract Assign operator
package class OperatorSubtractAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "-=";
		_opFuncName = "opSubtractAssign";
	}
}
/// Multiply Assign operator
package class OperatorMultiplyAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "*=";
		_opFuncName = "opMultiplyAssign";
	}
}
/// Divide Assign operator
package class OperatorDivideAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "/=";
		_opFuncName = "opDivideAssign";
	}
}
/// Mod Assign operator
package class OperatorModAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "%=";
		_opFuncName = "opModAssign";
	}
}
/// Concat Assign operator
package class OperatorConcatAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "~=";
		_opFuncName = "opConcatAssign";
	}
}
/// Binary And Assign operator
package class OperatorBinAndAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "&=";
		_opFuncName = "opBinAndAssign";
	}
}
/// Binary Or Assign operator
package class OperatorBinOrAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "|=";
		_opFuncName = "opBinOrAssign";
	}
}
/// Binary Xor Assign operator
package class OperatorBinXorAssign : OperatorBin{
public:
	/// constructor
	this(){
		_operator = "^=";
		_opFuncName = "opBinXorAssign";
	}
}