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
import navm.navm : readData;
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
			_writer.addInstruction(Instruction.Push, ["0"]);
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
			generateByteCode(node.node!(StatementNode.Type.FunctionCall), false, true);
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
		if (node.indexes.length > 0){
			// use ReadElement to get the element to write to
			for (integer i = node.indexes.length -1; i >= 0;i--){
				generateByteCode(node.indexes[i]);
			}
			_writer.addInstruction(node.deref ? Instruction.PushFrom : Instruction.PushRefFrom, [to!string(node.var.id)]); // this gets the ref ot array
			// now add readElement for each of those
			foreach (i; 0 .. node.indexes.length){
				_writer.addInstruction(Instruction.ArrayRefElement);
			}
			_writer.addInstruction(Instruction.WriteToRef); // and this writes value to ref
		}else if (node.deref){
			_writer.addInstruction(Instruction.PushFrom, [to!string(node.var.id)]); // this gets the ref
			_writer.addInstruction(Instruction.WriteToRef); // and this writes value to ref
		}else{
			// just do pushTo 
			_writer.addInstruction(Instruction.WriteTo, [to!string(node.var.id)]);
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
		_writer.addInstruction(Instruction.JumpIf, [to!string(startIndex)]);// jump to startIndex if condition == 1
	}
	/// generates byte code for ForNode
	void generateByteCode(ForNode node){
		generateByteCode(node.initStatement);
		// condition
		immutable uinteger conditionIndex = _writer.instructionCount;
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.Not);
		immutable uinteger jumpInstIndex = _writer.instructionCount; // index of jump instruction
		_writer.addInstruction(Instruction.JumpIf, ["0"]); //placeholder, will write jumpToIndex later
		// loop body
		generateByteCode(node.statement);
		// now the increment statement
		generateByteCode(node.incStatement);
		// jump back
		_writer.addInstruction(Instruction.Jump, [to!string(conditionIndex)]);
		// now update the jump to jump ahead of this
		_writer.changeJumpArg(jumpInstIndex, _writer.instructionCount);
	}
	/// generates byte code for FunctionCallNode
	/// 
	/// pushRef is ignored
	void generateByteCode(FunctionCallNode node, bool pushRef = false, bool popReturn = false){
		if (!node.isScriptDefined && node.isInBuilt){
			generateInBuiltFunctionByteCode(node, popReturn);
		}else{
			// push args
			foreach (arg; node.arguments){
				generateByteCode(arg);
			}
			_writer.addInstruction(node.isScriptDefined ? Instruction.ExecuteFunction : Instruction.ExecuteFunctionExternal,
				[to!string(node.id), to!string(node.arguments.length)]);
			if (popReturn)
				_writer.addInstruction(Instruction.Pop);
		}
	}
	/// generates byte code for inbuilt QScript functions (`length(void[])` and stuff)
	void generateInBuiltFunctionByteCode(FunctionCallNode node, bool popReturn = false){
		/// argument types of function call
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		foreach (i, arg; node.arguments){
			argTypes[i] = arg.returnType;
		}
		/// encoded name of function
		string fName = encodeFunctionName(node.fName, argTypes);
		/// stores if the instructions added push 1 element to stack, or zero (false)
		bool pushesToStack = true;
		/// length(@void[], int)
		if (node.fName == "length"){
			if (matchArguments([DataType(DataType.Type.Void, 1, true), DataType(DataType.Type.Integer)],argTypes)){
				// set array length
				generateByteCode(node.arguments[1]); // length comes first, coz it's popped later
				generateByteCode(node.arguments[0]);
				_writer.addInstruction(Instruction.ArrayLengthSet);
				// popReturn doesn't matter, ArrayLengthSet doesn't push anything
				pushesToStack = false;
			}else if (matchArguments([DataType(DataType.Type.Void, 1, false)], argTypes) ||
			matchArguments([DataType(DataType.Type.String, 0, true)], argTypes)){
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
		if (pushesToStack && popReturn)
			_writer.addInstruction(Instruction.Pop);
	}
	/// generates byte code for IfNode
	void generateByteCode(IfNode node){
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.Not);
		immutable uinteger skipToElseInstIndex = _writer.instructionCount; /// index of jumpIf that jumps when false
		_writer.addInstruction(Instruction.JumpIf, ["0"]); // placeholder
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
				_writer.addInstruction(Instruction.Push, ["0"]);
			_writer.addInstruction(Instruction.WriteTo, [to!string(node.varIDs[varName])]);
		}
	}
	/// generates byte code for WhileNode
	void generateByteCode(WhileNode node){
		immutable uinteger conditionIndex = _writer.instructionCount;
		generateByteCode(node.condition);
		_writer.addInstruction(Instruction.Not);
		immutable uinteger jumpInstIndex = _writer.instructionCount;
		_writer.addInstruction(Instruction.JumpIf, ["0"]);
		generateByteCode(node.statement);
		_writer.addInstruction(Instruction.Jump, [conditionIndex.to!string]);
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
	void generateByteCode(CodeNode node, bool pushRef = false){
		if (node.type == CodeNode.Type.FunctionCall){
			generateByteCode(node.node!(CodeNode.Type.FunctionCall), pushRef);
		}else if (node.type == CodeNode.Type.Literal){
			generateByteCode(node.node!(CodeNode.Type.Literal), pushRef);
		}else if (node.type == CodeNode.Type.Operator){
			generateByteCode(node.node!(CodeNode.Type.Operator), pushRef);
		}else if (node.type == CodeNode.Type.SOperator){
			generateByteCode(node.node!(CodeNode.Type.SOperator), pushRef);
		}else if (node.type == CodeNode.Type.ReadElement){
			generateByteCode(node.node!(CodeNode.Type.ReadElement), pushRef);
		}else if (node.type == CodeNode.Type.Variable){
			generateByteCode(node.node!(CodeNode.Type.Variable), pushRef);
		}else if (node.type == CodeNode.Type.Array){
			generateByteCode(node.node!(CodeNode.Type.Array), pushRef);
		}
	}
	/// generates byte code for LiteralNode
	/// 
	/// pushRef is ignored
	void generateByteCode(LiteralNode node, bool pushRef = false){
		_writer.addInstruction(Instruction.Push, [node.literal]);
	}
	/// generates byte code for OperatorNode
	/// 
	/// pushRef is ignored
	void generateByteCode(OperatorNode node, bool pushRef = false){
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
	/// 
	/// pushRef is ignored
	void generateByteCode(SOperatorNode node, bool pushRef = false){
		// only 2 SOperators exist at this point, ref/de-ref, and `!`
		if (node.operator == "@"){
			// check if its being de-ref-ed
			if (node.operand.returnType.isRef){
				generateByteCode(node.operand);
			}else if (node.operand.type == CodeNode.Type.Variable){
				generateByteCode(node.operand, true);
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
		if (node.readFromNode.type == CodeNode.Type.ReadElement || node.readFromNode.type == CodeNode.Type.Variable){
			generateByteCode(node.readFromNode, true);
			_writer.addInstruction(Instruction.ArrayRefElement);
		}else{
			generateByteCode(node.readFromNode);
			_writer.addInstruction(Instruction.ArrayElement);
		}
		if (!pushRef)
			_writer.addInstruction(Instruction.Deref);
	}
	/// generates byte code for VariableNode
	void generateByteCode(VariableNode node, bool pushRef = false){
		_writer.addInstruction(pushRef ? Instruction.PushRefFrom : Instruction.PushFrom, [to!string(node.id)]);
	}
	/// generates byte code for ArrayNode
	/// 
	/// pushRef is ignored
	void generateByteCode(ArrayNode node, bool pushRef = false){
		foreach (element; node.elements){
			generateByteCode(element);
		}
		_writer.addInstruction(Instruction.MakeArray, [node.elements.length.to!string]);
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
	string[] getByteCode(){
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

/// Used to generate byte code.
/// 
/// Code is really messy in here, needs improving
private class NaByteCodeWriter{
private:
	/// instructions of all functions
	List!(string[]) _generatedInstructions;
	/// arguments of all functions' instructions
	List!(string[][]) _generatedInstructionArgs;
	/// stackLength of each function
	List!uinteger _stackLengths;
	/// instructions of function currently being written to
	List!Instruction _currentInst;
	/// arguments of instructions of functions currently being written to
	List!(string[]) _currentInstArgs;
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
		_generatedInstructions = new List!(string[]);
		_generatedInstructionArgs = new List!(string[][]);
		_currentInst = new List!Instruction;
		_currentInstArgs = new List!(string[]);
		_stackLengths = new List!uinteger;
	}
	/// destructor
	~this(){
		.destroy(_generatedInstructions);
		.destroy(_generatedInstructionArgs);
		.destroy(_currentInst);
		.destroy(_currentInstArgs);
		.destroy(_stackLengths);
	}
	/// Returns: generated byte code in a NaFunction[]
	string[] getCode(){
		string[] r;
		{
			uinteger l = 0;
			foreach (instArray; _generatedInstructions.toArray){
				l += instArray.length+1;
			}
			r.length = l;
		}
		uinteger writeTo = 0;
		foreach (i, instList; _generatedInstructions.toArray){
			r[writeTo] = "def "~to!string(_stackLengths.read(i));
			writeTo ++;
			string[][] args = _generatedInstructionArgs.read(i);
			foreach (index, inst; instList){
				string argStr = "";
				foreach (arg; args[index]){
					argStr ~= ' ' ~ arg;
				}
				r[writeTo] = to!string(inst) ~ argStr;
				writeTo++;
			}
		}
		return r;
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
		string[] instructions;
			instructions.length = _currentInst.length;
			Instruction[] inst = _currentInst.toArray;
			foreach (i, instruction; inst){
				instructions[i] = '\t'~instruction.to!string;
			}
		_generatedInstructions.append(instructions);
		_generatedInstructionArgs.append(_currentInstArgs.toArray);
		_stackLengths.append(_maxStackUsage);
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
	ErrorType addInstruction(Instruction inst, string[] args = []){
		if (args.length != INSTRUCTION_ARG_COUNT[inst])
			return ErrorType.ArgumentCountMismatch;
		NaData[] argsNaData;
		argsNaData.length = args.length;
		foreach (i, arg; args){
			argsNaData[i] = readData(arg);
		}
		immutable uinteger popCount = instructionPopCount(inst, argsNaData);
		immutable uinteger pushCount = INSTRUCTION_PUSH_COUNT[inst];
		if (popCount > _currentStackUsage)
			return ErrorType.StackElementsInsufficient;
		_currentStackUsage -= popCount;
		_currentStackUsage += pushCount;
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
		_currentInstArgs.set(index, [to!string(newJumpIndex)]);
		return true;
	}
}