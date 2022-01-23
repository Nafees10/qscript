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
		_dimensions = from._dimensions;
		_byteCount = from._byteCount;
		if (from._refTo){
			_refTo = new DataType();
			_refTo.clone(from._refTo);
		}else{
			_ident = from._ident.dup;
		}
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

/// Definition Node (function def, struct def, enum def...)
package abstract class DefinitionNode : ASTNode{
protected:
	/// visibility
	Visibility _visibility = DEFAULT_VISIBILITY;
	/// identifier of what is being defined
	Identifier _ident;
	/// if this is static (available without creating an instance)
	bool _static;
public:
	/// constuctor
	this(){
		_static = false;
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
		_voidType = new DataType([TYPENAME_VOID]);
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

/// Namespace Node
package abstract class NamespaceNode : DefinitionNode{
protected:
	/// definitions
	DefinitionNode[] _definition;
public:
	/// constructor
	this(){}
	/// destructor
	~this(){
		foreach (def; _definition)
			.destroy(def);
	}
	/// count of definitions
	@property uint defCount(){
		return cast(uint)_definition.length;
	}
	/// Returns: a definition
	/// 
	/// Throws: Exception in case index out of bounds
	DefinitionNode defGet(uint index){
		if (index >= _definition.length)
			throw new Exception("index out of bounds");
		return _definition[index];
	}
	/// appends a DefinitionNode
	/// 
	/// Returns: its index
	uint defAppend(DefinitionNode node){
		immutable uint r = cast(uint)_definition.length;
		if (node)
			node._parent = this;
		_definition ~= node;
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

/// Variable definition template
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

/// variable definition
package alias VarDefNode = GenericVarDefNode!DefinitionNode;

/// Local variable definition
package alias LocalVarDefNode = GenericVarDefNode!StatementNode;

/// Struct definition
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

/// Enum definition
package class EnumDefNode : DefinitionNode{
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

/// Function definition
package class FuncDefNode : DefinitionNode{
protected:
	/// Return type
	DataType _returnType;
	/// Argument types
	DataType[] _argType;
	/// Argument names
	string[] _argName;
	/// body
	BlockNode _body;
public:
	/// constructor
	this(string name, string[] argName, DataType[] argType){
		assert(argName.length == _argType.length, "argName.length doesnt match argType.length");
		_returnType = new DataType();
		_body = new BlockNode();
		_body._parent = this;
		_ident = [name];
		_argName = argName.dup;
		_argType = argType.dup;
	}
	/// destructor
	~this(){
		foreach (type; _argType)
			.destroy(type);
		.destroy(_body);
		.destroy(_returnType);
	}
	/// Returns: function return type
	@property DataType returnType(){
		return _returnType;
	}
	/// Returns: argument count
	@property uint argCount(){
		return cast(uint)_argName.length;
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
	uint argAppend(string name, DataType type){
		immutable uint r = cast(uint)_argName.length;
		_argName ~= name;
		_argType ~= type;
		return r;
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

/// Binary operator expression
package class OperatorBin : ExpressionNode{
protected:
	/// Operator
	string _operator;
	/// Left side operand
	ExpressionNode _operandL;
	/// Right side operand
	ExpressionNode _operandR;
public:
	/// constructor
	this (){}
	/// destructor
	~this (){
		if (_operandL)
			.destroy(_operandL);
		if (_operandR)
			.destroy(_operandR);
	}
	/// Operator
	@property string operator(){
		return _operator;
	}
	/// Left operand
	@property ExpressionNode operandL(){
		return _operandL;
	}
	/// ditto
	@property ExpressionNode operandL(ExpressionNode newL){
		if (_operandL)
			.destroy (_operandL);
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
		return _operandR = newR;
	}
}

/// Unary operator expression
package class OperatorUn : ExpressionNode{
protected:
	/// Operator
	string _operator;
	/// Operand
	ExpressionNode _operand;
public:
	/// constructor
	this (){}
	/// destructor
	~this (){
		if (_operand)
			.destroy(_operand);
	}
	/// Returns: the operator
	@property string operator(){
		return _operator;
	}
	/// Returns: the operand
	@property ExpressionNode operand(){
		return _operand;
	}
	/// ditto
	@property ExpressionNode operand(ExpressionNode newOp){
		if (_operand)
			.destroy(_operand);
		return _operand = newOp;
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
		_returnType.ident = [TYPENAME_INT];
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
		_returnType.ident = [TYPENAME_FLOAT];
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
		_returnType.ident = [TYPENAME_CHAR];
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
		_returnType.ident = [TYPENAME_BOOL];
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
		_returnType.ident = [TYPENAME_CHAR];
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
