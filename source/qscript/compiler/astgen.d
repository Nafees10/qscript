module qscript.compiler.astgen;

import qscript.compiler.compiler;
import qscript.compiler.tokens.tokens;

/// an AST Node
package abstract class ASTNode{
protected:
	/// line number and column number
	uint[2] _location;
	/// parent node
	ASTNode _parent = null;
	/// name
	string _name;

	abstract @property const(ASTNode)[] _children() const;

public:
	/// Returns: line number
	@property uint lineno() const {
		return _location[0];
	}
	/// ditto
	@property uint lineno(uint newVal){
		return _location[0] = newVal;
	}

	/// Returns: column number
	@property uint colno() const {
		return _location[1];
	}
	/// ditto
	@property uint colno(uint newVal){
		return _location[1] = newVal;
	}

	/// name
	@property string name() const {
		return _name;
	}
	/// ditto
	@property string name(string newName){
		return _name = newName;
	}

	/// Finds ASTNode(s) for an Identifier
	final const (ASTNode)[] find(string[] toFind) const {
		if (!toFind.length)
			return [];
		if (toFind[0] != _name){
			if (!_parent)
				return [];
			return _parent.find(toFind);
		}
		if (toFind.length == 1)
			return [this];
		const (ASTNode)[] ret;
		foreach (const ASTNode child; _children){
			if (toFind[1] == child._name)
				ret ~= child.find(toFind[1 .. $]);
		}
		return ret;
	}
}

/// Factory function for an ASTNode
///
/// Params:
/// * tokens
/// * starting index (should be modified to point to token after last token this read)
/// * ASTGen, which calls it
///
/// Returns:
/// ASTNode generated, or null
alias ASTFactoryFunc = ASTNode delegate(Token[], ref uint, ASTGen);

/// AST Generator
class ASTGen{
private:
	/// AST Node factory functions, with hook (token type) as key
	ASTFactoryFunc[uint] _factories;
	/// tokens
	Token[] _source;
	/// Errors
	CompileError[] _errors;
public:
	/// constructor
	this(){}
	~this(){}
	/// adds a factory
	///
	/// Returns: true if done, false if hook already used
	bool factoryAdd(uint hook, ASTFactoryFunc fact){
		if (hook in _factories || !fact)
			return false;
		_factories[hook] = fact;
		return true;
	}
	/// Returns: true if a factory exists for a hook
	bool factoryExists(uint hook){
		return (hook in _factories) !is null;
	}
	/// Source
	@property Token[] source(){
		return _source;
	}
	/// ditto
	@property Token[] source(Token[] newVal){
		return _source = newVal;
	}
	/// Generates ASTNodes (starting at index, default 0)
	///
	/// Returns: generated ASTNodes
	ASTNode[] generate(uint index = 0){
		if (index >= _source.length)
			return null;
		ASTNode[] ret;
		for (; index < _source.length; index ++){
			immutable Token tok = _source[index];
			ASTFactoryFunc* func = tok.type in _factories;
			ASTNode node;
			if (func)
				node = (*func)(_source, index, this);
			if (!node){
				errorAdd(CompileError(CompileError.Type.TokenUnexpected, tok.where));
				return ret;
			}
			ret ~= node;
		}
		return ret;
	}
	/// Adds an error
	void errorAdd(CompileError err){
		// just append, use the errorsSort to sort
		_errors ~= err;
	}
	/// Sorts errors, by line number, and col number
	void errorsSort(){
		// TODO implement
	}
	/// Returns: errors
	@property CompileError[] errors(){
		return _errors;
	}
	/// Returns: true if there are any errors
	@property bool error(){
		return _errors.length != 0;
	}
}
