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
		writer.setCurrentFunction(node.name, node.id);
		generateByteCode(node.bodyBlock);
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
		}else if (node.type == StatementNode.Type.If){
			generateByteCode(node.node!(StatementNode.Type.If));
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
}
