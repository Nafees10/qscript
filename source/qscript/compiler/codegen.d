/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.astcheck;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

import navm.navm : Instruction, NaData;
import navm.bytecodedefs; // needed to check how many elements instruction wants from stack

import std.conv : to;

/// Contains functions to generate ByteCode from AST nodes
class CodeGen{
private:
	/// writer
	NaByteCodeWriter _writer;
	/// stores script defined functions
	Function[] _functions;
protected:
	/// generates byte code for a FunctionNode
	void generateByteCode(FunctionNode node){
		_writer.startFunction(node.arguments.length);
		// use push to reserve space on stack for variables
		foreach (i; 0 .. node.varCount - node.arguments.length){
			_writer.addInstruction(Instruction.Push, [NaData(0)]);
		}
		generateByteCode(node.bodyBlock);
		// don't forget to Terminate
		_writer.addInstruction(Instruction.Terminate);
		_writer.appendFunction();
		// add itself to _functions
		Function itself;
		itself.name = node.name;
		itself.returnType = node.returnType;
		itself.argTypes.length = node.arguments.length;
		foreach (i, arg; node.arguments)
			itself.argTypes[i] = arg.argType;
		_functions[node.id] = itself;
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
			_writer.addInstruction(Instruction.Pop);
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
		// first get the value
		generateByteCode(node.val);
		// if being assigned to ref, just use pushFrom + writeToRef, else, do writeTo
		if (node.deref){
			_writer.addInstruction(Instruction.PushFrom, [NaData(node.var.id)]); // this gets the ref
			_writer.addInstruction(Instruction.WriteToRef); // and this writes value to ref
		}else{
			// just do pushTo 
			_writer.addInstruction(Instruction.WriteTo, [NaData(node.var.id)]);
		}
	}
	/// generates ByteCode for DoWhileNode
	void generateByteCode(DoWhileNode node){
		// get the index of where the loop starts
		immutable uinteger startIndex = _writer.instructionCount;
		// now comes loop body
		generateByteCode(node.statement);
		// condition
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.JumpIf, [NaData(startIndex)]);// jump to startIndex if condition == 1
	}
	/// generates byte code for ForNode
	void generateByteCode(ForNode node){
		generateByteCode(node.initStatement);
		// condition
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.Not);
		immutable uinteger jumpInstIndex = _writer.instructionCount; // index of jump instruction
		_writer.addInstruction(Instruction.JumpIf, []); //placeholder, will write jumpToIndex later
		// loop body
		generateByteCode(node.statement);
		// now update the jump to jump ahead of this
		_writer.changeJumpArg(jumpInstIndex, _writer.instructionCount);
		// now the increment statement
		generateByteCode(node.incStatement);
	}
	/// generates byte code for FunctionCallNode
	void generateByteCode(FunctionCallNode node){
		if (!node.isScriptDefined && node.isInBuilt){
			generateInBuiltFunctionByteCode(node);
		}else{
			// push args
			foreach (arg; node.arguments){
				generateByteCode(arg);
			}
			_writer.addInstruction(node.isScriptDefined ? Instruction.ExecuteFunction : Instruction.ExecuteFunctionExternal,
				[NaData(node.id), NaData(node.arguments.length)]);
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
		if (node.fName == "length"){
			if (matchArguments([DataType(DataType.Type.Void, 1, true), DataType(DataType.Type.Integer)],argTypes)){
				// set array length
				generateByteCode(node.arguments[1]); // length comes first, coz it's popped later
				generateByteCode(node.arguments[0]);
				_writer.addInstruction(Instruction.ArrayLengthSet);
			}else if (matchArguments([DataType(DataType.Type.Void, 1)], argTypes) ||
			matchArguments([DataType(DataType.Type.String)], argTypes)){
				// get array/string length
				generateByteCode(node.arguments[0]);
				_writer.addInstruction(Instruction.ArrayLength);
			}
		}else if (fName == encodeFunctionName("toInt", [DataType(DataType.Type.String)])){
			/// toInt(string)
			generateByteCode(node.arguments[0]);
			_writer.addInstruction(Instruction.StringToInt);
		}else if (fName == encodeFunctionName("toInt", [DataType(DataType.Type.Double)])){
			/// toInt(double)
			generateByteCode(node.arguments[0]);
			_writer.addInstruction(Instruction.DoubleToInt);
		}else if (fName == encodeFunctionName("toDouble", [DataType(DataType.Type.String)])){
			/// toDouble(string)
			generateByteCode(node.arguments[0]);
			_writer.addInstruction(Instruction.StringToDouble);
		}else if (fName == encodeFunctionName("toDouble", [DataType(DataType.Type.Integer)])){
			/// toDouble(int)
			generateByteCode(node.arguments[0]);
			_writer.addInstruction(Instruction.IntToDouble);
		}else if (fName == encodeFunctionName("toStr", [DataType(DataType.Type.Integer)])){
			/// toStr(int)
			generateByteCode(node.arguments[0]);
			_writer.addInstruction(Instruction.IntToString);
		}else if (fName == encodeFunctionName("toStr", [DataType(DataType.Type.Double)])){
			/// toStr(double)
			generateByteCode(node.arguments[0]);
			_writer.addInstruction(Instruction.DoubleToString);
		}
	}
	/// generates byte code for IfNode
	void generateByteCode(IfNode node){
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.Not);
		immutable uinteger skipToElseInstIndex = _writer.instructionCount; /// index of jumpIf that jumps when false
		_writer.addInstruction(Instruction.JumpIf); // placeholder
		// now comes the if true part
		generateByteCode(node.statement);
		// update skipToElse jump
		_writer.changeJumpArg(skipToElseInstIndex, _writer.instructionCount);
		if (node.hasElse){
			// add a jump in the if-true statement to skip this (arg is placeholder)
			immutable skipToEndInst = _writer.instructionCount;
			_writer.addInstruction(Instruction.Jump);
			generateByteCode(node.elseStatement);
			// update the skipToEnd jump
			_writer.changeJumpArg(skipToEndInst, _writer.instructionCount);
		}
	}
	/// generates byte code for VarDeclareNode - actually, just checks if a value is being assigned to it, if yes, makes var a ref to that val
	void generateByteCode(VarDeclareNode node){
		foreach (varName; node.vars){
			if (node.hasValue(varName))
				generateByteCode(node.getValue(varName));
			else
				_writer.addInstruction(Instruction.Push, [NaData(0)]);
			_writer.addInstruction(Instruction.WriteTo, [NaData(node.varIDs[varName])]);
		}
	}
	/// generates byte code for WhileNode
	void generateByteCode(WhileNode node){
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.Not);
		immutable jumpInstIndex = _writer.instructionCount;
		_writer.addInstruction(Instruction.JumpIf);
		generateByteCode(node.statement);
		_writer.changeJumpArg(jumpInstIndex, _writer.instructionCount);
	}
	/// generates byte code for ReturnNode
	void generateByteCode(ReturnNode node){
		generateByteCode(node.value);
		_writer.addInstruction(Instruction.ReturnVal);
		// remember, return terminates execution in qscript, not in navm
		_writer.addInstruction(Instruction.Terminate);
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
		_writer.addInstruction(Instruction.Push, [NaData(node.literal)]);
	}
	/// generates byte code for OperatorNode
	void generateByteCode(OperatorNode node){
		bool isFloat = false;
		if (node.operands[0].returnType == DataType(DataType.Type.Double) ||
			node.operands[1].returnType == DataType(DataType.Type.Double)){
			isFloat = true;
		}
		Instruction opInst;
		switch (node.operator){
		case "/":
			opInst = isFloat ? Instruction.MathDivideDouble : Instruction.MathDivideInt;
			break;
		case "*":
			opInst = isFloat ? Instruction.MathMultiplyDouble : Instruction.MathMultiplyInt;
			break;
		case "+":
			opInst = isFloat ? Instruction.MathAddDouble : Instruction.MathAddInt;
			break;
		case "-":
			opInst = isFloat ? Instruction.MathSubtractDouble : Instruction.MathSubtractInt;
			break;
		case "%":
			opInst = isFloat ? Instruction.MathModDouble : Instruction.MathModInt;
			break;
		case "<":
			// the the end, just flip the oprands and use > (isGreater) because < doesnt exist in navm
			opInst = isFloat ? Instruction.IsGreaterDouble : Instruction.IsGreaterInt;
			break;
		case ">":
			opInst = isFloat ? Instruction.IsGreaterDouble : Instruction.IsGreaterInt;
			break;
		case "<=":
			// the the end, just flip the oprands and use >= (isGreaterSame) because <= doesnt exist in navm
			opInst = isFloat ? Instruction.IsGreaterSameDouble : Instruction.IsGreaterSameInt;
			break;
		case ">=":
			opInst = isFloat ? Instruction.IsGreaterSameDouble : Instruction.IsGreaterSameInt;
			break;
		case "==":
			opInst = Instruction.IsSame;
			break;
		case "&&":
			opInst = Instruction.And;
			break;
		case "||":
			opInst = Instruction.Or;
			break;
		default:
			break;
		}
		// if operator is < or <=, then need to flip operands and change operator to > or >=
		if (node.operator == "<" || node.operator == "<="){
			node.operator = node.operator == "<" ? ">" : ">=";
			CodeNode operand = node.operands[0];
			node.operands[0] = node.operands[1];
			node.operands[1] = operand;
		}
		generateByteCode(node.operands[1]);
		generateByteCode(node.operands[0]);
		_writer.addInstruction(opInst);
	}
	/// generates byte code for SOperatorNode
	void generateByteCode(SOperatorNode node){
		// only 2 SOperators exist at this point, ref/de-ref, and `!`
		if (node.operator == "@"){
			// check if its being de-ref-ed
			if (node.operand.returnType.isRef){
				// deref
			}else if (node.operand.type == CodeNode.Type.Variable){
				_writer.addInstruction(Instruction.PushRefFrom, [NaData(node.operand.node!(CodeNode.Type.Variable).id)]);
			}else if (node.operand.type == CodeNode.Type.ReadElement){
				generateByteCode(node.operand.node!(CodeNode.Type.ReadElement), true);
			}
		}else if (node.operator == "!"){
			generateByteCode(node.operand);
			_writer.addInstruction(Instruction.Not);
		}
	}
	/// generates byte code for ReadElement
	void generateByteCode(ReadElement node, bool pushRef = false){
		generateByteCode(node.index);
		// the array should be a ref to array, following if-else takes care of that
		if (node.readFromNode.type == CodeNode.Type.ReadElement){
			generateByteCode(node.readFromNode.node!(CodeNode.Type.ReadElement), pushRef);
		}else if (node.readFromNode.type == CodeNode.Type.Variable){
			generateByteCode(node.readFromNode.node!(CodeNode.Type.Variable), true);
		}
		_writer.addInstruction(Instruction.ReadElement);
		if (!pushRef)
			_writer.addInstruction(Instruction.Deref);
	}
	/// generates byte code for VariableNode
	void generateByteCode(VariableNode node, bool pushRef = false){
		_writer.addInstruction(pushRef ? Instruction.PushRefFrom : Instruction.PushFrom, [NaData(node.id)]);
	}
	/// generates byte code for ArrayNode
	void generateByteCode(ArrayNode node){
		foreach (element; node.elements){
			generateByteCode(element);
		}
		_writer.addInstruction(Instruction.MakeArray);
	}
public:
	/// constructor
	this (){
		_writer = new NaByteCodeWriter();
	}
	/// destructor
	~this(){
		.destroy(_writer);
	}
	/// Returns: generated bytecode
	NaFunction[] getByteCode(){
		return _writer.getCode;
	}
	/// Returns: array of functions defined in script. The index is the function id (used to call function at runtime)
	Function[] getFunctionMap(){
		return _functions.dup;
	}
	/// generates byte code for ScriptNode
	void generateByteCode(ScriptNode node){
		_functions.length = node.functions.length;
		foreach (func; node.functions){
			generateByteCode(func);
		}
	}
}

private class NaByteCodeWriter{
private:
	/// code for each function
	List!NaFunction _generatedCode;
	/// instructions of function currently being written to
	List!Instruction _currentInst;
	/// arguments of instructions of functions currently being written to
	List!(NaData[]) _currentInstArgs;
	/// number of elements used up on stack at a point
	uinteger _currentStackUsage;
	/// max number of elements used on on stack (reset to 0 before starting on a new function)
	uinteger _maxStackUsage;

	/// called to update _maxStackUsageg if necessary
	void updateStackUsage(){
		if (_currentStackUsage > _maxStackUsage)
			_maxStackUsage = _currentStackUsage;
	}
public:
	/// Stores types of errors given by `this.addInstruction`
	enum ErrorType : ubyte{
		StackElementsInsufficient, /// the instructions needs to pop more elements than there are, on the stack
		ArgumentCountMismatch, /// instruction needs different number of arguemnts than provided
		NoError, /// there was no error
	}
	/// constructor
	this(){
		_generatedCode = new List!NaFunction;
		_currentInst = new List!Instruction;
		_currentInstArgs = new List!(NaData[]);
	}
	/// destructor
	~this(){
		.destroy(_generatedCode);
		.destroy(_currentInst);
		.destroy(_currentInstArgs);
	}
	/// Returns: generated byte code in a NaFunction[]
	NaFunction[] getCode(){
		return _generatedCode.toArray;
	}
	/// Call to prepare writing a function
	void startFunction(uinteger argCount){
		// clear lists
		_currentInst.clear;
		_currentInstArgs.clear;
		// make space for arguments on stack
		_maxStackUsage = argCount;
		_currentStackUsage = argCount;
	}
	/// Call when a function has been completely written to.
	void appendFunction(){
		NaFunction func;
		func.instructions = _currentInst.toArray;
		func.arguments = _currentInstArgs.toArray;
		func.stackLength = _maxStackUsage;
		_generatedCode.append(func);
		// reset
		_currentInst.clear;
		_currentInstArgs.clear;
		_maxStackUsage = 0;
		_currentStackUsage = 0;
	}
	/// Returns: nunmber of elements currently on stack
	@property uinteger stackLength(){
		return _currentStackUsage;
	}
	/// Returns: number of instructions
	@property uinteger instructionCount(){
		return _currentInst.length;
	}
	/// Adds an instruction
	///
	/// Returns: type of error if any, else, ErrorType.NoError
	ErrorType addInstruction(Instruction inst, NaData[] args = []){
		if (args.length != INSTRUCTION_ARG_COUNT[inst])
			return ErrorType.ArgumentCountMismatch;
		immutable uinteger popCount = instructionPopCount(inst, args);
		if (popCount > _currentStackUsage)
			return ErrorType.StackElementsInsufficient;
		_currentStackUsage -= popCount;
		updateStackUsage;
		_currentInst.append(inst);
		_currentInstArgs.append(args.dup);
		return ErrorType.NoError;
	}
	/// Changes argument of jump/jumpIf instruction at an index
	/// 
	/// Returns: true if done, false if not, usually because the instruction there isn't a jump/jumpIf
	bool changeJumpArg(uinteger index, uinteger newJumpIndex){
		if (index >= _currentInst.length || ! [Instruction.Jump, Instruction.JumpIf].hasElement(_currentInst.read(index)))
			return false;
		_currentInstArgs.set(index, [NaData(newJumpIndex)]);
		return true;
	}
}