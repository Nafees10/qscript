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
	/// ditto
	@property Identifier namespace(Identifier newNS){
		if (_namespace)
			.destroy(_namespace);
		return _namespace = newNS;
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
	/// ditto
	@property Identifier ident(Identifier newIdent){
		if (_ident)
			.destroy(_ident);
		return _ident = newIdent;
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
			}
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
	assert(type.toString == "int[]@[]");
}

/// an AST Node
package class ASTNode{
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

/// Script Node
package class ScriptNode : ASTNode{
protected:
	/// definitions
	DefinitionNode[] _definitions;
public:
	/// constructor
	this(){

	}
	~this(){
		foreach (def; _definitions)
			.destroy(def);
	}
}

/// Definition Node (function def, struct def, enum def...)
package class DefinitionNode : ASTNode{
protected:
	/// visibility
	Visibility _visibility;
	/// name of what is defined
	string _name;
public:
	/// visibility
	@property Visibility visibility(){
		return _visibility;
	}
	/// name of what is being defined
	@property string name(){
		return _name;
	}
}

/// Variable definition
package class VarDefNode : DefinitionNode{
protected:
	/// names of variables

}