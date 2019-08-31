﻿/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.astcheck;
import qscript.compiler.misc;
import qscript.compiler.compiler : Function;
import qscript.compiler.bytecode;
import qscript.qscript : QData;

import utils.misc;
import utils.lists;

import std.conv : to;

/// Contains functions to generate ByteCode from AST nodes
class CodeGen{
private:
	/// the generated byte code
	ByteCode code;
	/// class used to write to ByteCode
	ByteCodeWriter writer;
	/// the stack of the function currently being converted to byte code
	List!(ByteCode.Data) stack;
	/// the instructions of the function currently being converted to byte code
	List!(ByteCode.Instruction) instructions;
protected:
	/// generates byte code for a FunctionNode
	void generateByteCode(FunctionNode node){
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		foreach (i, arg; node.arguments){
			argTypes[i] = arg.argType;
		}
		writer.setCurrentFunction(encodeFunctionName(node.name, argTypes), node.id);
		// make space for vars
		for (uinteger i=0; i < node.varCount; i++)
			writer.appendStack(ByteCode.Data());
		generateByteCode(node.bodyBlock);
		// resolve refs, so ref-to-ref becomes ref-to-element
		writer.resolveRefs();
		writer.appendFunction();
	}
	/// generates byte code for a BlockNode
	void generateByteCode(BlockNode node){
		foreach (statement; node.statements){
			generateByteCode(statement);
		}
	}
	/// generates byte code for a StatementNode
	void generateByteCode(StatementNode node){
		if (node.type == StatementNode.Type.Assignment){
			generateByteCode(node.node!(StatementNode.Type.Assignment));
		}else if (node.type == StatementNode.Type.Block){
			generateByteCode(node.node!(StatementNode.Type.Block));
		}else if (node.type == StatementNode.Type.DoWhile){
			generateByteCode(node.node!(StatementNode.Type.DoWhile));
		}else if (node.type == StatementNode.Type.For){
			generateByteCode(node.node!(StatementNode.Type.For));
		}else if (node.type == StatementNode.Type.FunctionCall){
			generateByteCode(node.node!(StatementNode.Type.FunctionCall));
			// skip the return value element on stack, wont be needing that
			writer.appendInstruction(ByteCode.Instruction("peek", writer.stackElementCount));
		}else if (node.type == StatementNode.Type.If){
			generateByteCode(node.node!(StatementNode.Type.If));
		}else if (node.type == StatementNode.Type.VarDeclare){
			generateByteCode(node.node!(StatementNode.Type.VarDeclare));
		}else if (node.type == StatementNode.Type.While){
			generateByteCode(node.node!(StatementNode.Type.While));
		}else if (node.type == StatementNode.Type.Return){
			generateByteCode(node.node!(StatementNode.Type.Return));
		}
	}
	/// generates byte code for AssignmentNode
	void generateByteCode(AssignmentNode node){
		uinteger bundle = writer.newBundle();
		if (node.indexes.length > 0){
			// write the array-ref if array is being deref-ed
			if (node.indexes.length > 0 && node.deref){
				generateByteCode(node.var);
				writer.appendToBundle(bundle);
			}
			// write the indexes
			foreach (index; node.indexes){
				generateByteCode(index);
				writer.appendToBundle(bundle);
			}
			// get ref to element
			writer.appendBundle(bundle);
			writer.appendStack(ByteCode.Data()); // empty space for getRefRefArray/getRefRefArray to write its return to
			if (node.deref)
				writer.appendInstruction(ByteCode.Instruction("getRefRefArray", node.indexes.length));
			else
				writer.appendInstruction(ByteCode.Instruction("getRefArray", node.var.id, node.indexes.length));
			// now we have the ref to write to, prepare new bundle for writeRef
			bundle = writer.newBundle();
			writer.appendToBundle(bundle);
			// now comes the data
			generateByteCode(node.val);
			writer.appendToBundle(bundle);
			// append the bundle, and the instruction
			writer.appendBundle(bundle);
			writer.appendInstruction(ByteCode.Instruction("writeRef"));
		}else if (node.deref){
			// put the ref on bundle
			writer.appendToBundle(bundle, node.var.id);
			// now get the data, on the bundle
			generateByteCode(node.val);
			writer.appendToBundle(bundle);
			writer.appendInstruction(ByteCode.Instruction("writeRef"));
		}else if (node.val.returnType.isRef){
			// use makeRef to make this var ref to val
			generateByteCode(node.val);
			writer.appendInstruction(ByteCode.Instruction("makeRef", node.var.id, writer.lastStackElementIndex));
		}else{
			// put data on bundle
			generateByteCode(node.val);
			writer.appendToBundle(bundle);
			writer.appendBundle(bundle);
			writer.appendInstruction(ByteCode.Instruction("write", node.var.id));
		}
	}
	/// generates ByteCode for DoWhileNode
	void generateByteCode(DoWhileNode node){
		// the peek index to jump back to
		uinteger peekBack = writer.stackElementCount;
		// the instruction to jump back to
		uinteger jumpBack = writer.instructionCount;
		// execute the statement
		generateByteCode(node.statement);
		// now comes time for condition
		generateByteCode(node.condition);
		writer.appendInstruction(ByteCode.Instruction("jumpIf", jumpBack, peekBack));
	}
	/// generates byte code for ForNode
	void generateByteCode(ForNode node){
		generateByteCode(node.initStatement);
		/// the peek index to jump back to
		uinteger peekBack = writer.stackElementCount;
		/// the instruction to jump back to
		uinteger jumpBack = writer.instructionCount;
		// eval the condition
		generateByteCode(node.condition);
		// jump if not
		writer.appendInstruction(ByteCode.Instruction("jumpIfNot", 0, 0)); // the 0, 0 are placeholders.
		/// stores the index of the jump instruction, so the index to jump to can be later modified
		uinteger jumpInstruction = writer.lastInstructionIndex;
		// eval the statements
		generateByteCode(node.statement);
		generateByteCode(node.incStatement);
		// jump back to condition
		writer.appendInstruction(ByteCode.Instruction("jump", jumpBack, peekBack));
		// put in the correct indexes in jump-to-exit
		writer.setInstruction(jumpInstruction, ByteCode.Instruction("jumpIfNot", writer.instructionCount+1,
				writer.stackElementCount));
		// done
	}
	/// generates byte code for FunctionCallNode
	void generateByteCode(FunctionCallNode node){
		if (!node.isScriptDefined && node.isInBuilt){
			generateInBuiltFunctionByteCode(node);
		}else{
			uinteger bundle = writer.newBundle();
			// add args to stack
			foreach (arg; node.arguments){
				generateByteCode(arg);
				writer.appendToBundle(bundle);
			}
			writer.appendBundle(bundle);
			writer.appendInstruction(ByteCode.Instruction(node.isScriptDefined ? "execFuncS" : "execFuncE",
					node.id, node.arguments.length));
			writer.appendStack(ByteCode.Data()); // empty space for execFunc output
		}
	}
	/// generates byte code for inbuilt QScript functions (`length(void[])` and stuff)
	void generateInBuiltFunctionByteCode(FunctionCallNode node){
		/// argument types of function call
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		foreach (i, arg; node.arguments){
			argTypes[i] = arg.returnType;
		}
		/// encoded name of function
		string fName = encodeFunctionName(node.fName, argTypes);
		/// length(@void[], int)
		if (fName == encodeFunctionName("length",
			[DataType(DataType.Type.Void, 1, true), DataType(DataType.Type.Integer)])){
			// use `setLen`
			uinteger bundle = writer.newBundle();
			generateByteCode(node.arguments[0]);
			writer.appendToBundle(bundle);
			generateByteCode(node.arguments[1]);
			writer.appendToBundle(bundle);
			writer.appendBundle(bundle);
			writer.appendInstruction(ByteCode.Instruction("setLen"));
		}else if (fName == encodeFunctionName("length", [DataType(DataType.Type.Void, 1)])){
			/// length (void[])
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("getLen"));
			writer.appendStack(ByteCode.Data()); // empty space for output from getLen
		}else if (fName == encodeFunctionName("length", [DataType(DataType.Type.String)])){
			/// length(string)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("strLen"));
			writer.appendStack(ByteCode.Data()); // empty space for output from strLen

		}else if (fName == encodeFunctionName("toInt", [DataType(DataType.Type.String)])){
			/// toInt(string)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("strToInt"));
			writer.appendStack(ByteCode.Data()); // empty space for output
		}else if (fName == encodeFunctionName("toInt", [DataType(DataType.Type.Double)])){
			/// toInt(double)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("doubleToInt"));
			writer.appendStack(ByteCode.Data()); // empty space for output
		}else if (fName == encodeFunctionName("toDouble", [DataType(DataType.Type.String)])){
			/// toDouble(string)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("strToDouble"));
			writer.appendStack(ByteCode.Data()); // empty space for output
		}else if (fName == encodeFunctionName("toDouble", [DataType(DataType.Type.Integer)])){
			/// toDouble(int)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("intToDouble"));
			writer.appendStack(ByteCode.Data()); // empty space for output
		}else if (fName == encodeFunctionName("toStr", [DataType(DataType.Type.Integer)])){
			/// toStr(int)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("intToStr"));
			writer.appendStack(ByteCode.Data()); // empty space for output
		}else if (fName == encodeFunctionName("toStr", [DataType(DataType.Type.Double)])){
			/// toStr(double)
			generateByteCode(node.arguments[0]);
			writer.appendInstruction(ByteCode.Instruction("doubleToStr"));
			writer.appendStack(ByteCode.Data()); // empty space for output
		}
	}
	/// generates byte code for IfNode
	void generateByteCode(IfNode node){
		// evaluate condition
		generateByteCode(node.condition);
		// if its true, jump to where the if-true statement is, otherwise keep going, the else statement begins there
		writer.appendInstruction(ByteCode.Instruction("jumpIf", 0, 0)); // 0,0 are placeholders
		uinteger jumpToTrue = writer.lastInstructionIndex;
		// do the else statement here
		if (node.hasElse)
			generateByteCode(node.elseStatement);
		// now the jump to skip the ifTrue statement
		writer.appendInstruction(ByteCode.Instruction("jump", 0)); // 0 is placeholder
		uinteger jumpSkipTrue = writer.lastInstructionIndex;
		writer.setInstruction(jumpToTrue, ByteCode.Instruction("jumpIf", writer.instructionCount+1,
				writer.stackElementCount ));
		// now the ifTrue statement
		generateByteCode(node.statement);
		writer.setInstruction(jumpSkipTrue, ByteCode.Instruction("jump", writer.instructionCount+1,
				writer.stackElementCount ));
	}
	/// generates byte code for VarDeclareNode - actually, just checks if a value is being assigned to it, if yes, makes var a ref to that val
	void generateByteCode(VarDeclareNode node){
		foreach (var; node.vars){
			if (node.hasValue(var)){
				generateByteCode(node.getValue(var));
				// make the var element a ref to this
				writer.setStackElement(node.varIDs[var], ByteCode.Data(writer.lastStackElementIndex, true));
				// make peek skip this
				writer.appendInstruction(ByteCode.Instruction("peek", writer.stackElementCount));
			}
		}
	}
	/// generates byte code for WhileNode
	void generateByteCode(WhileNode node){
		// the instruction index, and peek index to jump back to condition eval
		uinteger jumpBack = writer.instructionCount, peekBack = writer.stackElementCount;
		// eval the condition
		generateByteCode (node.condition);
		writer.appendInstruction(ByteCode.Instruction("jumpIfNot", 0, 0)); // placeholder
		uinteger exitJump = writer.lastInstructionIndex;
		generateByteCode(node.statement);
		// jump back
		writer.appendInstruction(ByteCode.Instruction("jump", jumpBack, peekBack));
		// fix that jump to exit placeholder
		writer.setInstruction(exitJump, ByteCode.Instruction("jumpIfNot", writer.instructionCount, writer.stackElementCount));
		// done
	}
	/// generates byte code for ReturnNode
	void generateByteCode(ReturnNode node){
		generateByteCode(node.value);
		writer.appendInstruction(ByteCode.Instruction("return"));
	}

	/// generates byte code for CodeNode
	void generateByteCode(CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			generateByteCode(node.node!(CodeNode.Type.FunctionCall));
		}else if (node.type == CodeNode.Type.Literal){
			generateByteCode(node.node!(CodeNode.Type.Literal));
		}else if (node.type == CodeNode.Type.Operator){
			generateByteCode(node.node!(CodeNode.Type.Operator));
		}else if (node.type == CodeNode.Type.SOperator){
			generateByteCode(node.node!(CodeNode.Type.SOperator));
		}else if (node.type == CodeNode.Type.ReadElement){
			generateByteCode(node.node!(CodeNode.Type.ReadElement));
		}else if (node.type == CodeNode.Type.Variable){
			generateByteCode(node.node!(CodeNode.Type.Variable));
		}else if (node.type == CodeNode.Type.Array){
			generateByteCode(node.node!(CodeNode.Type.Array));
		}
	}
	/// generates byte code for LiteralNode
	void generateByteCode(LiteralNode node){
		// it wont ever be Array, only double, int, or string
		writer.appendStack(ByteCode.Data(node.literal, node.returnType));
	}
	/// generates byte code for OperatorNode
	void generateByteCode(OperatorNode node){
		/// the instruction names for each operator (excluding the trailing data type)
		string[string] OPERATOR_INSTRUCTION = [
			"/" : "divide",
			"*" : "multiply",
			"+" : "add",
			"-" : "subtract",
			"%" : "mod",
			"~" : "concat",
			"<" : "isLesser",
			">" : "isGreater",
			"==" : "isSame",
			"&&" : "and",
			"||" : "or",
			"!" : "not"
		];
		// get the full instruction name.
		string instName = OPERATOR_INSTRUCTION[node.operator] ~ node.returnType.isArray ? "Array" :
			node.returnType.type == DataType.Type.String ? "String" : node.returnType.type == DataType.Type.Integer ? 
			"Int" : "Double";
		// push the operands
		uinteger bundle = writer.newBundle();
		foreach (operand; node.operands){
			generateByteCode(operand);
			writer.appendToBundle(bundle);
		}
		writer.appendBundle(bundle);
		writer.appendStack(ByteCode.Data()); // space for output from operator instruction
		writer.appendInstruction(ByteCode.Instruction(instName));
		// done
	}
	/// generates byte code for SOperatorNode
	void generateByteCode(SOperatorNode node){
		// only 2 SOperators exist at this point, ref/de-ref, and `!`
		if (node.operator == "@"){
			// check if its being de-ref-ed
			if (node.operand.returnType.isRef){
				generateByteCode(node.operand);
				writer.appendStack(ByteCode.Data());// empty for the deref-ed data
				writer.appendInstruction(ByteCode.Instruction("deref"));
			}else{
				// just make it reference 
				generateByteCode(node.operand);
				writer.appendStack(ByteCode.Data()); // empty space for ref
				writer.appendInstruction(ByteCode.Instruction("getRef", writer.lastStackElementIndex-1));
			}
		}else if (node.operator == "!"){
			generateByteCode(node.operand);
			writer.appendStack(ByteCode.Data());// space for not output
			writer.appendInstruction(ByteCode.Instruction("notInt"));
		}
	}
	/// generates byte code for ReadElement
	void generateByteCode(ReadElement node){
		// use `getRefRefArray` or `readChar`
		uinteger bundle = writer.newBundle();
		generateByteCode(node.readFromNode);
		writer.appendToBundle(bundle);
		generateByteCode(node.index);
		writer.appendToBundle(bundle);
		writer.appendBundle(bundle);
		writer.appendStack(ByteCode.Data()); // space for output from `getRefRefArray` or `readChar`
		if (node.readFromNode.returnType.arrayDimensionCount > 0){
			writer.appendInstruction(ByteCode.Instruction("getRefRefArray", 1));
		}else if (node.readFromNode.returnType.type == DataType.Type.String){
			writer.appendInstruction(ByteCode.Instruction("readChar"));
		}
	}
	/// generates byte code for VariableNode
	void generateByteCode(VariableNode node){
		// just throw a ref of that var here. spec dictates instructions dont modify what they read, so it should be safe.
		writer.appendStack(ByteCode.Data(node.id, true));
	}
	/// generates byte code for ArrayNode
	void generateByteCode(ArrayNode node){
		// use `makeArray` instruction
		uinteger bundle = writer.newBundle();
		foreach (element; node.elements){
			generateByteCode(element);
			writer.appendToBundle(bundle);
		}
		writer.appendBundle(bundle);
		writer.appendStack(ByteCode.Data()); // to hold array output from `makeAray`
		writer.appendInstruction(ByteCode.Instruction("makeArray", node.elements.length));
	}
public:
	/// constructor
	/// 
	/// `bCode` is the ByteCode to which the byte code is written
	this (ByteCode bCode){
		code = bCode;
		writer = new ByteCodeWriter(code);
	}
	/// destructor
	~this(){
		.destroy(writer);
	}
	/// generates byte code for ScriptNode
	void generateByteCode(ScriptNode node){
		foreach (func; node.functions){
			generateByteCode(func);
		}
	}
}
