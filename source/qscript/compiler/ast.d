module qscript.compiler.ast;

import utils.misc;
import utils.ds;

import qscript.compiler.compiler;
import qscript.compiler.tokens;

debug{import std.stdio;}
import std.conv : to;

class Identifier{
private:
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
	this (Identifier namespace, string name){
		_namespace = namespace;
		_name = name;
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
			tokens[index + 1].type == TokenType.OpMemberSelect && tokens[index + 2].token.isIdentifier){
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
		Token(TokenType.Identifier,"qscript"),Token(TokenType.OpMemberSelect,"."),Token(TokenType.Identifier,"std"),
		Token(TokenType.OpMemberSelect,"."),Token(TokenType.Identifier,"io"),Token(TokenType.OpMemberSelect,".")
	];
	Identifier ident = new Identifier();
	assert(ident.fromTokens(tok) == 5);
	assert(ident.toString == "qscript.std.io");
	.destroy(ident);
}

/// Data Type
class DataType{
private:
	/// its identifier (name)
	Identifier _ident = null;
	/// array dimensions (zero if not array)
	uint _dimensions = 0;
	/// reference to type. if this is not null (i.e it is valid), then _name and _type are not valid
	DataType _refTo = null;
	/// number of bytes that will be occupied, 0 if unknown
	uint _byteCount = 0;
public:
	/// constructor
	this (){}
	/// constructor
	this(Identifier ident, uint dimensions = 0){
		this._ident = ident;
		_dimensions = dimensions;
	}
	~this(){
		this.clear();
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
				refTo._ident = this._ident;
				refTo._dimensions = this._dimensions;
				refTo._refTo = this._refTo;
				refTo._byteCount = this._byteCount;
				this._ident = null; // so clear doesnt free it
				this._refTo = null; // same reason
				this.clear();
				this._refTo = refTo;
				index ++;
			}else if (tokens[index].type == TokenType.IndexOpen){
				if ((!_ident && !_refTo) || index + 1 >= tokens.length || tokens[index + 1].type != TokenType.IndexClose)
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
	Token[] tok = [
		Token(TokenType.KeywordInt,"int"),Token(TokenType.IndexOpen,"["),Token(TokenType.IndexClose,"]"),
		Token(TokenType.OpRef,"@"),Token(TokenType.IndexOpen,"["),Token(TokenType.IndexClose,"]")
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
	ASTNode _parent;
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
package abstract class DefinitionNode : ASTNode{
protected:
	/// visibility
	Visibility _visibility = Visibility.DEFAULT;
	/// identifier of what is being defined
	Identifier _ident;
public:
	/// constuctor
	this(){}
	/// destructor
	~this(){
		if (_ident)
			.destroy(_ident);
	}
	/// visibility
	@property Visibility visibility(){
		return _visibility;
	}
	/// Returns: identifier
	@property Identifier ident(){
		return _ident;
	}
}

/// Namespace Node
package abstract class NamespaceNode : DefinitionNode{
protected:
	/// definitions
	DefinitionNode[] _definitions;
public:
	/// constructor
	this(){}
	/// destructor
	~this(){
		foreach (def; _definitions)
			.destroy(def);
		if (_ident)
			.destroy(_ident);
	}
}

/// Script Node
package class ScriptNode : NamespaceNode{
public:
	/// Returns: script name
	@property string scriptName(){
		return _ident.name;
	}
	/// ditto
	@property string scriptName(string newName){
		return _ident.name = newName;
	}
}

/// Variable definition
package class VarDefNode : DefinitionNode{
protected:
	/// Data type
	DataType _dataType;
	/// names of variables
	string[] _varName;
	/// default value, if not null
	ExpressionNode[] _varValue;
public:
	/// constuctor
	this(){}
	/// destructor
	~this(){
		foreach (node; _varValue){
			if (node)
				.destroy(node);
		}
		if (_dataType)
			.destroy(_dataType);
	}
	/// Returns: number of variables defined
	@property uint varCount(){
		return cast(uint)_varName.length;
	}
	/// Returns: variable name
	@property string varName(uint index){
		if (index >= _varName.length)
			throw new Exception("VarDefNode.varName index out of bounds");
		return _varName[index];
	}
	/// Returns: variable default value
	@property ExpressionNode varValue(uint index){
		if (index >= _varValue.length)
			throw new Exception("VarDefNode.varValue index out of bounds");
		return _varValue[index];
	}
	/// Returns: data type of defined variables
	@property DataType dataType(){
		return _dataType;
	}
}

/// Struct definition
package class StructDefNode : NamespaceNode{

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
	this(){}
	/// destructor
	~this(){
		foreach (node; _memberValue){
			if (node)
				.destroy(node);
		}
		if (_dataType)
			.destroy(_dataType);
	}
	/// Returns: number of members
	@property uint memberCount(){
		return cast(uint)_memberName.length;
	}
	/// Returns: data type
	@property DataType dataType(){
		return _dataType;
	}
	/// Returns: member name
	@property string memberName(uint index){
		if (index >= _memberName.length)
			throw new Exception("EnumDefNode.memberName index out of bounds");
		return _memberName[index];
	}
	/// Returns: member value
	@property ExpressionNode memberValue(uint index){
		if (index >= _memberValue.length)
			throw new Exception("EnumDefNode.memberValue index out of bounds");
		return _memberValue[index];
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
	
}

/// Expression
package abstract class ExpressionNode : ASTNode{
protected:
	/// Return type of expression, can be void
	DataType _returnType;
	/// if this is static (i.e known at compile time)
	bool _isStatic = false;
public:
	/// constructor
	this(){}
	/// destructor
	~this(){
		if (_returnType)
			.destroy(_returnType);
	}
	/// Returns: whether this can be evaluated at compile time
	bool isStatic(){
		return _isStatic;
	}
}

/// Statement
package abstract class StatementNode : ExpressionNode{

}