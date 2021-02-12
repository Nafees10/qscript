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

import std.conv : to;

/// Flags passed to `generateCode` functions
private enum CodeGenFlag : ubyte{
	None = 0, /// all flags zero
	PushRef = 1 << 0, /// if the code should push a reference to the needed data, or the value.
	PopReturn = 1 << 1, /// if the return value should be popped
}

/// just an inherited NaBytecode that makes it easier to check if it failed to add some instruction
private class ByteCodeWriter : NaBytecode{
private:
	bool _error;
public:
	this(NaInstruction[] instructionTable){
		super(instructionTable);
		_error = false;
	}
	/// Returns: true if an error occurred, now, or previously
	override bool addInstruction(string instName, string argument){
		_error = _error || super.addInstruction(instName, argument);
		return _error;
	}
	/// sets errorOccurred to false
	void resetError(){
		_error = false;
	}
	/// whether an error has occured
	@property bool error(){
		return _error;
	}
}

/// added at start of most error messages where the errors never should've happened
const string ERROR_PREFIX = "possible compiler bug, please report it: ";

/// Contains functions to generate NaByteCode from AST nodes
class CodeGen{
private:
	ByteCodeWriter _code;
	NaInstruction[] _instTable;
	ScriptNode _script;
	Library _scriptLib;
	Library[] _libs;
	List!CompileError _errors;
	uinteger _jumpPosNum;
protected:
	// TODO write functions to generate code for all AST Nodes

	/// Generates bytecode for FunctionNode
	void generateCode(FunctionNode node, CodeGenFlag flags){
		_code.addJumpPos("__qscriptFunction"~node.id.to!string);
		// make space for variables
		foreach (i; 0 .. node.varStackCount)
			_code.addInstruction("push","0");
		generateCode(node.bodyBlock, flags);
		_code.addInstruction("jumpBack","");
	}
	/// generates bytecode for BlockNode
	void generateCode(BlockNode node, CodeGenFlag flags){
		foreach (statement; node.statements)
			generateCode(statement, flags);
	}
	/// generates bytecode for CodeNode
	void generateCode(CodeNode node, CodeGenFlag flags){
		if (node.type == CodeNode.Type.Array){
			generateCode(node.node!CodeNode.Type.Array, flags);
		}else if (node.type == CodeNode.Type.FunctionCall){
			generateCode(node.node!CodeNode.Type.FunctionCall, flags);
		}else if (node.type == CodeNode.Type.Literal){
			generateCode(node.node!CodeNode.Type.Literal, flags);
		}else if (node.type == CodeNode.Type.Negative){
			generateCode(node.node!CodeNode.Type.Negative, flags);
		}else if (node.type == CodeNode.Type.Operator){
			generateCode(node.node!CodeNode.Type.Operator, flags);
		}else if (node.type == CodeNode.Type.ReadElement){
			generateCode(node.node!CodeNode.Type.ReadElement, flags);
		}else if (node.type == CodeNode.Type.SOperator){
			generateCode(node.node!CodeNode.Type.SOperator, flags);
		}else if (node.type == CodeNode.Type.Variable){
			generateCode(node.node!CodeNode.Type.Variable, flags);
		}else if (node.type == CodeNode.Type.MemberSelector){
			generateCode(node.node!CodeNode.Type.MemberSelector, flags);
		}
	}
	/// generates bytecode for MemberSelectorNode
	/// 
	/// Valid flags:  
	/// * PushRef - only if node.type == Type.StructMemberRead
	void generateCode(MemberSelectorNode node, CodeGenFlag flags){
		if (node.type == MemberSelectorNode.Type.EnumMemberRead){
			_code.addInstruction("push", node.memberNameIndex.to!string);
			return;
		}
		if (flags & CodeGenFlag.PushRef){
			_code.addInstruction("push",node.memberNameIndex.to!string);
			generateCode(node.parent, CodeGenFlag.None);
			_code.addInstruction("IncRef","");
		}else{
			// use the `arrayElement` from QScriptVM
			generateCode(node.parent, CodeGenFlag.None);
			_code.addInstruction("arrayElement", node.memberNameIndex.to!string);
		}
	}
	/// generates bytecode for VariableNode. This function can report error, see this._errors  
	/// after this.
	/// 
	/// Valid flags:  
	/// * PushRef - only if node.type == Type.StructMemberRead
	void generateCode(VariableNode node, CodeGenFlag flags){
		// check if local to script
		if (node.libraryId == -1){
			if (node.isGlobal){
				_code.addInstruction(flags & CodeGenFlag.PushRef ? "PushRefFromAbs" : "pushFromAbs", 
					node.id.to!string);
				return;
			}
			_code.addInstruction(flags & CodeGenFlag.PushRef ? "pushRefFrom" : "pushFrom", 
				node.id.to!string);
			return;
		}
		if (node.libraryId >= _libs.length){
			_errors.append(CompileError(node.lineno, ERROR_PREFIX~"[VariableNode] invalid library"));
			return;
		}
		// try to use the library's own code generators if they exist
		Library lib = _libs[node.libraryId];
		if (flags & CodeGenFlag.PushRef && lib.generateVariableRefCode(_code,node.id))
			return;
		if (lib.generateVariableValueCode(_code, node.id))
			return;
		// Fine, I'll do it myself
		_code.addInstruction("push", node.id.to!string);
		_code.addInstruction(flags & CodeGenFlag.PushRef ? "VarGetRef" : "VarGet",
			node.libraryId.to!string);
	}
public:
	/// constructor
	this(Library[] libraries, NaInstruction[] instructionTable){
		_libs = libraries;
		_instTable = instructionTable;
		_code = new ByteCodeWriter(instructionTable);
		_errors = new List!CompileError;
	}
	~this(){
		.destroy(_code);
		.destroy(_errors);
	}
	/// generates byte code for a ScriptNode.
	/// 
	/// `node` is the ScriptNode to generate bytecode for  
	/// `scriptLibrary` is the private & public declarations of the script (allDeclarations from `ASTCheck.checkAST(..,x)`)
	/// 
	/// Returns: true if successfully generated, false if there were errors
	bool generateCode(ScriptNode node, Library scriptLibrary){
		_code.resetError();
		_errors.clear;
		_script = node;
		_scriptLib = scriptLibrary;
		_jumpPosNum = 0;
		// TODO write code for this node

		// make space for jumps for function calls
		foreach (i; 0 .. _script.functions.length)
			_code.addInstruction("jump", "__qscriptFunction"~i.to!string);
		// TODO write this thing

		return _code.error;
	}
	/// Returns: errors occurred
	@property CompileError[] errors(){
		return _errors.toArray;
	}
	/// Returns: generated bytecode
	@property NaBytecode bytecode(){
		return _code;
	}
}
