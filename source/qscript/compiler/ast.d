module qscript.compiler.ast;

import utils.misc;
import utils.ds;

import qscript.compiler.compiler;
import qscript.compiler.tokens;

debug{import std.stdio;}

/// Identifier with namespace
struct Ident{
	/// namespace and name
	string namespace, name;
	/// constructor
	this(string namespace, string name){
		this.namespace = namespace;
		this.name = name;
	}
	/// constructor
	this(string name){
		this.namespace = "";
		this.name = name;
	}
	/// Returns: string representation of this Ident
	string toString(){
		return namespace ~ '.' ~ name;
	}
}

/// Data Type
class DataType{
private:
	/// name of type
	string _name;
	/// array dimensions (zero if not array)
	uint _dimensions;
	/// reference to type. if this is not null (i.e it is valid), then _name and _type are not valid
	DataType _refTo;
	/// number of bytes that will be occupied
	uint _byteCount;
public:
	/// constructor
	this(string name, uint dimensions = 0){
		this.name = name;
		_dimensions = dimensions;
	}
	~this(){
		if (_refTo)
			.destroy(_refTo);
	}
	/// name of base type (excluding `[]` for array)
	@property string name(){
		return _name;
	}
	/// ditto
	@property string name(string newName){
		return _name = newName;
	}
	/// this data as string
	override string toString(){
		char[] r;
		if (_refTo)
			r = cast(char[])_refTo.toString ~ '@';
		else{
			r.length = name.length;
			r[] = name;
		}
		uint index = cast(uint)r.length;
		r.length += 2*_dimensions;
		for (; index < r.length; index += 2)
			r[index .. index + 2] = "[]";
		return cast(string)r;
	}
	/// read data type from string
	/// 
	/// Returns: true if read, false if not valid
	bool fromString(string s){
		// first empty itself
		if (_refTo)
			.destroy(_refTo);
		_refTo = null;
		
		return true;
	}
}

/// an AST Node
package class ASTNode{
protected:
	/// line number and column number
	uint[2] _location;
	/// parent node
	ASTNode _parent;
public:
	/// Returns: [line number, column number]
	@property uint[2] location(){
		return _location;
	}
	/// Returns: line number
	@property uint lineno(){
		return _location[0];
	}
	/// Returns: column number
	@property uint colno(){
		return _location[1];
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