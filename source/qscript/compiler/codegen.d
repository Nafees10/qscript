﻿/++
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
const string ERROR_PREFIX = "possible compiler bug, please report it:\n";

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
	void generateCode(FunctionNode node, CodeGenFlags flags){
		_code.addJumpPos("__qscriptFunction"~node.id.to!string);
		// make space for variables
		foreach (i; 0 .. node.varStackCount)
			_code.addInstruction("push","0");
		generateCode(node.bodyBlock, CodeGenFlags.None);
		_code.addInstruction("jumpBack","");
	}
	/// generates bytecode for BlockNode
	void generateCode(BlockNode node, CodeGenFlags flags){
		foreach (statement; node.statements)
			generateCode(statement, CodeGenFlags.None);
	}
	/// generates bytecode for CodeNode
	void generateCode(CodeNode node, CodeGenFlags flags){
		if (node.type == CodeNode.Type.Array){
			generateCode(node.node!(CodeNode.Type.Array), flags);
		}else if (node.type == CodeNode.Type.FunctionCall){
			generateCode(node.node!(CodeNode.Type.FunctionCall), flags);
		}else if (node.type == CodeNode.Type.Literal){
			generateCode(node.node!(CodeNode.Type.Literal), flags);
		}else if (node.type == CodeNode.Type.Negative){
			generateCode(node.node!(CodeNode.Type.Negative), flags);
		}else if (node.type == CodeNode.Type.Operator){
			generateCode(node.node!(CodeNode.Type.Operator), flags);
		}else if (node.type == CodeNode.Type.ReadElement){
			generateCode(node.node!(CodeNode.Type.ReadElement), flags);
		}else if (node.type == CodeNode.Type.SOperator){
			generateCode(node.node!(CodeNode.Type.SOperator), flags);
		}else if (node.type == CodeNode.Type.Variable){
			generateCode(node.node!(CodeNode.Type.Variable), flags);
		}else if (node.type == CodeNode.Type.MemberSelector){
			generateCode(node.node!(CodeNode.Type.MemberSelector), flags);
		}
	}
	/// generates bytecode for MemberSelectorNode
	/// 
	/// Valid flags:  
	/// * PushRef - only if node.type == Type.StructMemberRead
	void generateCode(MemberSelectorNode node, CodeGenFlags flags){
		if (node.type == MemberSelectorNode.Type.EnumMemberRead){
			_code.addInstruction("push", node.memberNameIndex.to!string);
			return;
		}
		if (flags & CodeGenFlags.PushRef){
			_code.addInstruction("push",node.memberNameIndex.to!string);
			generateCode(node.parent, CodeGenFlags.None);
			_code.addInstruction("IncRef","");
		}else{
			// use the `arrayElement` from QScriptVM
			generateCode(node.parent, CodeGenFlags.None);
			_code.addInstruction("arrayElement", node.memberNameIndex.to!string);
		}
	}
	/// generates bytecode for VariableNode. This function can report error, see this._errors  
	/// after this.
	/// 
	/// Valid flags:  
	/// * PushRef - only if node.type == Type.StructMemberRead
	void generateCode(VariableNode node, CodeGenFlags flags){
		// check if local to script
		if (node.libraryId == -1){
			if (node.isGlobal){
				_code.addInstruction(flags & CodeGenFlags.PushRef ? "PushRefFromAbs" : "pushFromAbs", 
					node.id.to!string);
				return;
			}
			_code.addInstruction(flags & CodeGenFlags.PushRef ? "pushRefFrom" : "pushFrom", 
				node.id.to!string);
			return;
		}
		if (node.libraryId >= _libs.length){
			_errors.append(CompileError(node.lineno, ERROR_PREFIX~"[VariableNode] invalid library"));
			return;
		}
		// try to use the library's own code generators if they exist
		Library lib = _libs[node.libraryId];
		if (flags & CodeGenFlags.PushRef && lib.generateVariableCode(_code,node.id, CodeGenFlags.PushRef))
			return;
		if (lib.generateVariableCode(_code, node.id, CodeGenFlags.None))
			return;
		// Fine, I'll do it myself
		_code.addInstruction("push", node.id.to!string);
		_code.addInstruction(flags & CodeGenFlags.PushRef ? "VarGetRef" : "VarGet",
			node.libraryId.to!string);
	}
	/// generates bytecode for ArrayNode.
	void generateCode(ArrayNode node, CodeGenFlags flags){
		foreach (elem; node.elements)
			generateCode(elem, CodeGenFlags.None);
		_code.addInstruction("arrayFromElements", node.elements.length.to!string);
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for LiteralNode.
	void generateCode(LiteralNode node, CodeGenFlags flags){
		_code.addInstruction("push", node.literal); // ez
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for NegativeValueNode.
	void generateCode(NegativeValueNode node, CodeGenFlags flags){
		generateCode(node.value, CodeGenFlags.None);
		_code.addInstruction("push", "-1");
		if (node.value.returnType == DataType(DataType.Type.Int))
			_code.addInstruction("mathMultiplyInt", "");
		else if (node.value.returnType == DataType(DataType.Type.Double))
			_code.addInstruction("mathMultiplyDouble", "");
		else
			_errors.append(CompileError(node.value.lineno, ERROR_PREFIX~
				"[NegativeValueNode] not a numerical data type"));
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for OperatorNode.
	void generateCode(OperatorNode node, CodeGenFlags flags){
		// just generator code for the function call
		generateCode(node.fCall, CodeGenFlags.None);
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for SOperatorNode. 
	/// 
	/// Valid flags are:  
	/// * PushRef
	void generateCode(SOperatorNode node, CodeGenFlags flags){
		// make sure only PushRef is passed, coz the function will see other flags too
		generateCode(node.fCall, flags & CodeGenFlags.PushRef);
	}
	/// generates bytecode for ReadElement
	/// 
	/// Valid flags are:
	/// * pushRef
	void generateCode(ReadElement node, CodeGenFlags flags){
		// if index is known, and it doesnt want ref, then there's a better way:
		if (node.index.type == CodeNode.Type.Literal && node.index.returnType == DataType(DataType.Type.Int) &&
		!(flags & CodeGenFlags.PushRef)){
			generateCode(node.readFromNode, CodeGenFlags.None);
			_code.addInstruction("arrayElement", node.index.node!(CodeNode.Type.Literal).literal);
			return;
		}
		// otherwise, use the multiple instructions method
		generateCode(node.index, CodeGenFlags.None);
		generateCode(node.readFromNode, CodeGenFlags.PushRef);
		_code.addInstruction("incRef", "");
		if (!(flags & CodeGenFlags.PushRef))
			_code.addInstruction("deref", "");
	}
	/// generates bytecode for StatementNode
	void generateCode(StatementNode node, CodeGenFlags flags){
		if (node.type == StatementNode.Type.Assignment){
			generateCode(node.node!(StatementNode.Type.Assignment), flags);
		}else if (node.type == StatementNode.Type.Block){
			generateCode(node.node!(StatementNode.Type.Block), flags);
		}else if (node.type == StatementNode.Type.DoWhile){
			generateCode(node.node!(StatementNode.Type.DoWhile), flags);
		}else if (node.type == StatementNode.Type.For){
			generateCode(node.node!(StatementNode.Type.For), flags);
		}else if (node.type == StatementNode.Type.FunctionCall){
			generateCode(node.node!(StatementNode.Type.FunctionCall), flags);
		}else if (node.type == StatementNode.Type.If){
			generateCode(node.node!(StatementNode.Type.If), flags);
		}else if (node.type == StatementNode.Type.VarDeclare){
			generateCode(node.node!(StatementNode.Type.VarDeclare), flags);
		}else if (node.type == StatementNode.Type.While){
			generateCode(node.node!(StatementNode.Type.While), flags);
		}else if (node.type == StatementNode.Type.Return){
			generateCode(node.node!(StatementNode.Type.Return), flags);
		}
	}
	/// generates bytecode for AssignmentNode
	/// 
	/// Flags are ignored
	void generateCode(AssignmentNode node, CodeGenFlags flags){
		generateCode(node.rvalue, CodeGenFlags.None);
		generateCode(node.lvalue, CodeGenFlags.PushRef);
		_code.addInstruction("writeToRef", "");
	}
	/// generates bytecode for IfNode
	void generateCode(IfNode node, CodeGenFlags flags){
		
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
