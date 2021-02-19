/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.compiler;
import qscript.qscript : Library, QScriptBytecode;

import navm.bytecode;

import utils.misc;
import utils.lists;

import std.conv : to;

/// just an inherited NaBytecode that makes it easier to check if it failed to add some instruction
private class ByteCodeWriter : QScriptBytecode{
private:
	bool _errorFree;
public:
	this(NaInstruction[] instructionTable){
		super(instructionTable);
		_errorFree = true;
	}
	/// Returns: true if an error occurred, now, or previously
	override bool addInstruction(string instName, string argument){
		_errorFree = _errorFree && super.addInstruction(instName, argument);
		return _errorFree;
	}
	/// sets errorOccurred to false
	void resetError(){
		_errorFree = true;
	}
	/// if its error free
	@property bool errorFree(){
		return _errorFree;
	}
}

/// Contains functions to generate NaByteCode from AST nodes
class CodeGen{
private:
	ByteCodeWriter _code;
	NaInstruction[] _instTable;
	ScriptNode _script;
	Library _scriptLib;
	Library[] _libs;
protected:
	/// Generates bytecode for FunctionNode
	void generateCode(FunctionNode node, CodeGenFlags flags = CodeGenFlags.None){
		_code.addJumpPos("__qscriptFunction"~node.id.to!string);
		if (node.name == "this"){
			// gotta do global variables too now
			foreach(varDecl; _script.variables)
				foreach (i; 0 .. varDecl.vars.length)
					_code.addInstruction("push", "0");
			foreach(varDecl; _script.variables)
				generateCode(varDecl);
		}else{
			// use jumpFrameN to adjust _stackIndex
			_code.addInstruction("push", node.arguments.length.to!string);
			_code.addInstruction("jumpFrameN", "__qscriptFunction"~node.id.to!string~"start");
			_code.addJumpPos("__qscriptFunction"~node.id.to!string~"start");
		}
		// make space for variables
		foreach (i; 0 .. node.varStackCount)
			_code.addInstruction("push","0");
		generateCode(node.bodyBlock, CodeGenFlags.None);
		_code.addInstruction("jumpBack","");
	}
	/// generates bytecode for BlockNode
	void generateCode(BlockNode node, CodeGenFlags flags = CodeGenFlags.None){
		foreach (statement; node.statements)
			generateCode(statement, CodeGenFlags.None);
	}
	/// generates bytecode for CodeNode
	void generateCode(CodeNode node, CodeGenFlags flags = CodeGenFlags.None){
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
	void generateCode(MemberSelectorNode node, CodeGenFlags flags = CodeGenFlags.None){
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
	/// generates bytecode for VariableNode.
	/// 
	/// Valid flags:  
	/// * PushRef - only if node.type == Type.StructMemberRead
	void generateCode(VariableNode node, CodeGenFlags flags = CodeGenFlags.None){
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
	void generateCode(ArrayNode node, CodeGenFlags flags = CodeGenFlags.None){
		foreach (elem; node.elements)
			generateCode(elem, CodeGenFlags.None);
		_code.addInstruction("arrayFromElements", node.elements.length.to!string);
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for LiteralNode.
	void generateCode(LiteralNode node, CodeGenFlags flags = CodeGenFlags.None){
		_code.addInstruction("push", node.literal); // ez
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for NegativeValueNode.
	void generateCode(NegativeValueNode node, CodeGenFlags flags = CodeGenFlags.None){
		generateCode(node.value, CodeGenFlags.None);
		_code.addInstruction("push", "-1");
		if (node.value.returnType == DataType(DataType.Type.Int))
			_code.addInstruction("mathMultiplyInt", "");
		else if (node.value.returnType == DataType(DataType.Type.Double))
			_code.addInstruction("mathMultiplyDouble", "");
		else
			// this'll never happen, is checked for in ASTCheck
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for OperatorNode.
	void generateCode(OperatorNode node, CodeGenFlags flags = CodeGenFlags.None){
		// just generator code for the function call
		generateCode(node.fCall, CodeGenFlags.None);
		if (flags & CodeGenFlags.PushRef)
			_code.addInstruction("pushRefFromPop","");
	}
	/// generates bytecode for SOperatorNode. 
	/// 
	/// Valid flags are:  
	/// * PushRef
	void generateCode(SOperatorNode node, CodeGenFlags flags = CodeGenFlags.None){
		// opRef is hardcoded
		if (node.operator == "@"){
			// dont care about flags, just get ref
			generateCode(node.operand, CodeGenFlags.PushRef);
			return;
		}
		// make sure only PushRef is passed, coz the function will see other flags too
		generateCode(node.fCall, cast(CodeGenFlags)(flags & CodeGenFlags.PushRef));
	}
	/// generates bytecode for ReadElement
	/// 
	/// Valid flags are:
	/// * pushRef
	void generateCode(ReadElement node, CodeGenFlags flags = CodeGenFlags.None){
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
	void generateCode(StatementNode node, CodeGenFlags flags = CodeGenFlags.None){
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
	/// generates bytecode for VarDeclareNode
	void generateCode(VarDeclareNode node, CodeGenFlags flags = CodeGenFlags.None){
		// just push 0 or 0.0 to id
		foreach (i, varName; node.vars){
			if (node.hasValue(varName))
				generateCode(node.getValue(varName));
			else if ([DataType.Type.Int, DataType.Type.Bool, DataType.Type.Char].hasElement(node.type.type))
				_code.addInstruction("push", "0");
			else if (node.type.type == DataType.Type.Double)
				_code.addInstruction("push", "0.0");
			else if (node.type == DataType(DataType.Type.Custom)){
				// create an array of length so members can be accomodated
				_code.addInstruction("makeArrayN", node.type.customLength.to!string);
			}
			_code.addInstruction("writeTo", node.varIDs[varName].to!string);
		}
	}
	/// generates bytecode for AssignmentNode
	void generateCode(AssignmentNode node, CodeGenFlags flags = CodeGenFlags.None){
		generateCode(node.rvalue, CodeGenFlags.None);
		generateCode(node.lvalue, node.deref ? CodeGenFlags.None : CodeGenFlags.PushRef);
		_code.addInstruction("writeToRef", "");
	}
	/// generates bytecode for IfNode
	void generateCode(IfNode node, CodeGenFlags flags = CodeGenFlags.None){
		static uinteger jumpCount = 0;
		uinteger currentJumpCount = jumpCount;
		jumpCount++;
		generateCode(node.condition, CodeGenFlags.None);
		_code.addInstruction("If", "");
		_code.addInstruction("Jump", "if"~currentJumpCount.to!string~"OnTrue");
		if (node.hasElse)
			generateCode(node.elseStatement, CodeGenFlags.None);
		_code.addInstruction("Jump", "if"~currentJumpCount.to!string~"End");
		_code.addJumpPos("if"~currentJumpCount.to!string~"OnTrue");
		generateCode(node.statement, CodeGenFlags.None);
		if (node.hasElse)
			_code.addJumpPos("if"~currentJumpCount.to!string~"End");
	}
	/// generates bytecode for WhileNode
	void generateCode(WhileNode node, CodeGenFlags flags = CodeGenFlags.None){
		static uinteger jumpCount = 0;
		uinteger currentJumpCount = jumpCount;
		jumpCount++;
		// its less instructions if a modified do-while loop is used
		_code.addJumpPos("While"~currentJumpCount.to!string~"Start");
		_code.addInstruction("Jump", "While"~currentJumpCount.to!string~"Condition");
		generateCode(node.statement, CodeGenFlags.None);
		_code.addJumpPos("While"~currentJumpCount.to!string~"Condition");
		generateCode(node.condition);
		_code.addInstruction("If","");
		_code.addInstruction("Jump", "While"~currentJumpCount.to!string~"Start");
	}
	/// generates bytecode for DoWhileNode
	void generateCode(DoWhileNode node, CodeGenFlags flags = CodeGenFlags.None){
		static uinteger jumpCount = 0;
		uinteger currentJumpCount = jumpCount;
		jumpCount++;
		// its less instructions if a modified do-while loop is used
		_code.addJumpPos("DoWhile"~currentJumpCount.to!string~"Start");
		generateCode(node.statement, CodeGenFlags.None);
		generateCode(node.condition);
		_code.addInstruction("If","");
		_code.addInstruction("Jump", "DoWhile"~currentJumpCount.to!string~"Start");
	}
	/// generates bytecode for ForNode
	void generateCode(ForNode node, CodeGenFlags flags = CodeGenFlags.None){
		static uinteger jumpCount = 0;
		uinteger currentJumpCount = jumpCount;
		jumpCount++;
		generateCode(node.initStatement);
		_code.addInstruction("Jump", "For"~currentJumpCount.to!string~"Condition");
		_code.addJumpPos("For"~currentJumpCount.to!string~"Start");
		generateCode(node.statement);
		generateCode(node.incStatement);
		_code.addJumpPos("For"~currentJumpCount.to!string~"Condition");
		generateCode(node.condition);
		_code.addInstruction("If", "");
		_code.addInstruction("Jump", "For"~currentJumpCount.to!string~"Start");
	}
	/// generates bytecode for FunctionCallNode
	void generateCode(FunctionCallNode node, CodeGenFlags flags = CodeGenFlags.None){
		foreach (arg; node.arguments)
			generateCode(arg);
		// if a local call, just use JumpStackN
		if (node.libraryId == -1){
			_code.addInstruction("jumpStackN", node.arguments.length.to!string);
		}else{
			// try to generate it's code, if no, then just use Call
			Library lib = _libs[node.libraryId];
			if (!lib.generateFunctionCallCode(_code, node.id, flags))
				_code.addInstruction("Call", node.id.to!string);
		}
		if (flags & CodeGenFlags.PushFunctionReturn){
			_code.addInstruction("retValPush", "");
			if (flags & CodeGenFlags.PushRef && !node.returnType.isRef)
				_code.addInstruction("pushRefFromPop", "");
		}
	}
	/// generates bytecode for ReturnNode
	void generateCode(ReturnNode node, CodeGenFlags flags = CodeGenFlags.None){
		generateCode(node.value);
		_code.addInstruction("retValSet", "");
		_code.addInstruction("jumpBack", "");
	}
public:
	/// constructor
	this(Library[] libraries, NaInstruction[] instructionTable){
		_libs = libraries;
		_instTable = instructionTable;
	}
	~this(){
	}
	/// generates byte code for a ScriptNode. Use CodeGen.bytecode to get the generated bytecode
	/// 
	/// `node` is the ScriptNode to generate bytecode for  
	/// `scriptLibrary` is the private & public declarations of the script (allDeclarations from `ASTCheck.checkAST(..,x)`)
	/// 
	/// Returns: true if successfully generated, false if there were errors
	bool generateCode(ScriptNode node, Library scriptLibrary){
		_code = new ByteCodeWriter(_instTable);
		_script = node;
		_scriptLib = scriptLibrary;
		// make space for jumps for function calls
		foreach (i; 0 .. _script.functions.length)
			_code.addInstruction("jump", "__qscriptFunction"~i.to!string);
		foreach (func; _script.functions)
			generateCode(func);
		// put link info on it
		_code.linkInfo = _scriptLib.toString;
		return _code.errorFree;
	}
	/// Returns: generated bytecode
	@property QScriptBytecode bytecode(){
		return _code;
	}
}
