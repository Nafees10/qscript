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

/// Contains functions to generate NaByteCode from AST nodes
class CodeGen{
private:
	List!(string[2]) _code;
	NaInstruction[] _instTable;
	ScriptNode _script;
	Library _scriptLib;
	Library[] _libs;
	List!CompileError _errors;
	uinteger _jumpPosNum;
protected:
	// TODO write functions to generate code for all AST Nodes

	/// Generates bytecode for FunctionNode
	void generateCode(FunctionNode node){
		// make space for variables
		foreach (i; 0 .. node.varStackCount)
			_code.append(["push", "0"]);
		generateCode(node.bodyBlock);
		_code.append(["jumpBack", ""]);
	}
	/// generates bytecode for BlockNode
	void generateCode(BlockNode node){
		foreach (statement; node.statements)
			generateCode(statement);
	}
	/// generates bytecode for CodeNode
	void generateCode(CodeNode node){
		if (node.type == CodeNode.Type.Array){
			generateCode(node.node!CodeNode.Type.Array);
		}else if (node.type == CodeNode.Type.FunctionCall){
			generateCode(node.node!CodeNode.Type.FunctionCall);
		}else if (node.type == CodeNode.Type.Literal){
			generateCode(node.node!CodeNode.Type.Literal);
		}else if (node.type == CodeNode.Type.Negative){
			generateCode(node.node!CodeNode.Type.Negative);
		}else if (node.type == CodeNode.Type.Operator){
			generateCode(node.node!CodeNode.Type.Operator);
		}else if (node.type == CodeNode.Type.ReadElement){
			generateCode(node.node!CodeNode.Type.ReadElement);
		}else if (node.type == CodeNode.Type.SOperator){
			generateCode(node.node!CodeNode.Type.SOperator);
		}else if (node.type == CodeNode.Type.Variable){
			generateCode(node.node!CodeNode.Type.Variable);
		}else if (node.type == CodeNode.Type.MemberSelector){
			generateCode(node.node!CodeNode.Type.MemberSelector);
		}
	}
	/// generates bytecode for MemberSelectorNode
	void generateCode(MemberSelectorNode node){
		if (node.type == MemberSelectorNode.Type.EnumMemberRead){
			_code.append(["push", node.memberNameIndex.to!string]);
			return;
		}
		_code.append(["push",node.memberNameIndex.to!string]);
		generateCode(node.parent);
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
	/// `node` is the ScriptNode to generate bytecode for  
	/// `scriptLibrary` is the private & public declarations of the script (allDeclarations from `ASTCheck.checkAST(..,x)`)
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
