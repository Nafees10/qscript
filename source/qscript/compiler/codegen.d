/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.compiler;
import qscript.qscript : Library;

import navm.bytecode;

import utils.misc;
import utils.lists;

/// Contains functions to generate NaByteCode from AST nodes
class CodeGen{
private:
	List!(string[2]) _code;
	NaInstruction[] _instTable;
	ScriptNode _script;
	Library _scriptLib;
	Library[] _libs;
	List!CompileError _errors;
protected:
	// TODO write functions to generate code for all AST Nodes

	/// Generates bytecode for FunctionNode
	void generateCode(FunctionNode node){
		
	}
public:
	/// constructor
	this(Library[] libraries, NaInstruction[] instructionTable){
		_libs = libraries;
		_instTable = instructionTable;
		_code = new List!(string[2]);
		_errors = new List!CompileError;
	}
	~this(){
		.destroy(_code);
		.destroy(_errors);
	}
	/// generates byte code for a ScriptNode.
	/// 
	/// Returns: compiled bytecode
	QScriptBytecode generateCode(ScriptNode node, Library scriptLibrary){
		_errors.clear;
		_script = node;
		_scriptLib = scriptLibrary;
		// TODO write code for this node

		// make space for jumps for function calls
		foreach (i; 0 .. _script.functions.length)
			_code.append(["jump", ""]);

		NaBytecode bytecode = new NaBytecode(_instTable);
		// TODO read _code into bytecode
		QScriptBytecode code = QScriptBytecode(bytecode, _scriptLib.toString);
		return code;
	}
}
