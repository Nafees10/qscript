module qscript.compiler.ast;

import utils.misc;
import utils.ds;

import qscript.compiler.compiler;
import qscript.compiler.tokens;

debug{import std.stdio;}
import std.conv : to;

class Identifier{
protected:
	/// name of identifier
	string _name;
	/// namespace, if any
	Identifier _namespace = null;
public:
	/// constructor
	this(){}
	/// destructor
	~this(){
		this.clear();
	}
	/// constructor, name only
	this(string name){
		_name = name;
	}
	/// constructor, both namespace and name from string
	this (string namespace, string name){
		_namespace = new Identifier(namespace);
		_name = name;
	}
	/// constructor, both namespace and name
	/// be aware namespace will be destroyed along with this
	this (Identifier namespace, string name){
		_namespace = namespace;
		_name = name;
	}
	/// clone from another Identifier
	void clone(Identifier from){
		this.clear();
		_name = from._name;
		if (from._namespace){
			_namespace = new Identifier();
			_namespace.clone(from._namespace);
		}
	}
	/// clears itself
	void clear(){
		if (_namespace)
			.destroy(_namespace);
		_namespace = null;
		_name = "";
	}
	/// Returns: name
	@property string name(){
		return _name;
	}
	/// ditto
	@property string name(string newName){
		if (!newName.isIdentifier)
			return _name;
		return _name = newName;
	}
	/// Returns: namespace
	/// 
	/// **it will be destroyed when this is destroyed**
	@property Identifier namespace(){
		return _namespace;
	}
	/// Reads from tokens
	/// 
	/// Returns: number of tokens read
	uint fromTokens(Token[] tokens){
		uint index = 0;
		this.clear();
		while (index < tokens.length && tokens[index].token.isIdentifier){
			_name = tokens[index].token;
			if (index + 2 < tokens.length &&
			tokens[index + 1].type == TokenType.OpMemberSelect &&
			tokens[index + 2].token.isIdentifier){
				Identifier newNamespace = new Identifier();
				newNamespace._name = _name;
				newNamespace._namespace = _namespace;
				this._namespace = newNamespace;
				index += 2;
			}else{
				index ++;
				break;
			}
		}
		return index;
	}
	/// Returns: this identifier expressed as a string
	override string toString(){
		if (_namespace)
			return _namespace.toString ~ '.' ~ _name;
		return _name;
	}
}
/// 
unittest{
	Token[] tok = [
		Token(TokenType.Identifier,"qscript"), Token(TokenType.OpMemberSelect,"."),
		Token(TokenType.Identifier,"std"), Token(TokenType.OpMemberSelect,"."),
		Token(TokenType.Identifier,"io"), Token(TokenType.OpMemberSelect,".")
	];
	Identifier ident = new Identifier();
	assert(ident.fromTokens(tok) == 5);
	assert(ident.toString == "qscript.std.io");
	.destroy(ident);
}

/// Data Type
class DataType{
private:
	/// its identifier (name). not valid if _refTo !is null
	Identifier _ident = null;
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
		if (from._ident){
			_ident = new Identifier();
			_ident.clone(from._ident);
		}
		if (from._refTo){
			_refTo = new DataType();
			_refTo.clone(from._refTo);
		}
	}
	/// Clears itself
	void clear(){
		if (_ident)
			.destroy(_ident);
		if (_refTo)
			.destroy(_refTo);
		_ident = null;
		_refTo = null;
		_dimensions = 0;
		_byteCount = 0;
	}
	/// Identifier (name) for this type
	@property Identifier ident(){
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
				if (!_refTo && !_ident)
					break;
				DataType refTo = new DataType();
				refTo.clone(this);
				this.clear();
				this._refTo = refTo;
				index ++;
			}else if (tokens[index].type == TokenType.IndexOpen){
				if ((!_ident && !_refTo) || index + 1 >= tokens.length ||
				tokens[index + 1].type != TokenType.IndexClose)
					break;
				_dimensions ++;
				index += 2;
			}else if (tokens[index].token.isIdentifier){
				if (_ident)
					break;
				_ident = new Identifier(tokens[index].token);
				index ++;
			}else
				break;
		}
		return index;
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
	assert(type.toString == "int[]@[]"); // `(int[]*)[]`
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
}

/// Definition Node (function def, struct def, enum def...)
package class DefinitionNode : ASTNode{
protected:
	/// visibility
	Visibility _visibility = DEFAULT_VISIBILITY;
	/// identifier of what is being defined
	Identifier _ident;
public:
	/// constuctor
	this(){
		_ident = new Identifier();
	}
	/// destructor
	~this(){
		if (_ident)
			.destroy(_ident);
	}

	alias clone = typeof(super).clone;
	/// visibility
	@property Visibility visibility(){
		return _visibility;
	}
	/// ditto
	@property Visibility visibility(Visibility newVal){
		return _visibility = newVal;
	}
	/// Returns: identifier, might be null
	@property Identifier ident(){
		return _ident;
	}
}

/// Namespace Node
package class NamespaceNode : DefinitionNode{
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
		if (!_ident)
			return "";
		return _ident.name;
	}
	/// ditto
	@property string scriptName(string newName){
		if (!_ident){
			_ident = new Identifier(newName);
			return _ident.name;
		}
		return _ident.name = newName;
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
alias VarDefNode = GenericVarDefNode!DefinitionNode;

/// Local variable definition
alias LocalVarDefNode = GenericVarDefNode!StatementNode;

/// Struct definition
package class StructDefNode : NamespaceNode{
public:
	/// constructor
	this(string name){
		_ident.name = name;
	}
	/// Returns: struct name
	@property string name(){
		return _ident.name;
	}
	/// ditto
	@property string name(string newName){
		return _ident.name = newName;
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
		_body = new BlockNode();
		_ident.name = name;
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

/// Expression
package class ExpressionNode : ASTNode{
protected:
	/// Return type of expression, can be void
	DataType _returnType;
	/// if this is static (i.e known at compile time)
	bool _isStatic = false;
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
	/// Returns: whether this can be evaluated at compile time
	bool isStatic(){
		return _isStatic;
	}
}

/// Statement
package class StatementNode : ExpressionNode{
protected:
	/// void return type
	DataType _voidType;
public:
	/// constructor
	this (){
		_voidType = new DataType(new Identifier("void"));
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
		_statement ~= node;
		return r;
	}
}