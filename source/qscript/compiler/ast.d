﻿/++
Contains definitions for "nodes" making the AST
+/
module qscript.compiler.ast;

import utils.misc;
import utils.lists;
import qscript.compiler.misc;

import std.conv : to;

/// a node representing the script
package struct ScriptNode{
	/// list of functions defined in this script
	public FunctionNode[] functions;
	/// constructor
	this (FunctionNode[] scriptFunctions){
		functions = scriptFunctions.dup;
	}
}

/// a node representing a function definition
package struct FunctionNode{
	/// struct to store arguments for function
	public struct Argument{
		string argName; /// the name of the var storing the arg
		DataType argType; /// the data type of the arg
		/// constructor
		this (string name, DataType type){
			argName = name;
			argType = type;
		}
	}
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores arguments with their data type
	public FunctionNode.Argument[] arguments;
	/// the name of the function
	public string name;
	/// body block of this function
	public BlockNode bodyBlock;
	/// the data type of the return value of this function
	public DataType returnType = DataType(DataType.Type.Void);
	/// constructor
	this (DataType returnDataType, string fName, FunctionNode.Argument[] funcArgs, BlockNode fBody){
		bodyBlock = fBody;
		name = fName;
		arguments = funcArgs.dup;
		returnType = returnType;
	}
}

/// a node representing a "set-of-statements" AKA a "block"
package struct BlockNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// an array of statements that make this block
	public StatementNode[] statements;
	/// constructor
	this (StatementNode[] blockStatements){
		statements = blockStatements.dup;
	}
}

/// a node to represent code that evaluates to some data.
/// 
/// This node can contain:  
/// 1. Function call - to only those functions that return some data
/// 2. Literals
/// 3. Operators
/// 4. Variables
/// 5. Arrays (Literal, or with variable elements)
package struct CodeNode{
	/// Returns: the line number (starts from 1) from which this node begins, or ends
	@property uinteger lineno(){
		if (storedType == Type.FunctionCall){
			return fCall.lineno;
		}else if (storedType == Type.Literal){
			return literal.lineno;
		}else if (storedType == Type.Operator){
			return operator.lineno;
		}else if (storedType == Type.Variable){
			return var.lineno;
		}else if (storedType == Type.ReadElement){
			return arrayRead.lineno;
		}else if (storedType == Type.Array){
			return array.lineno;
		}else if (storedType == Type.SOperator){
			return sOperator.lineno;
		}
		return 0;
	}
	/// ditto
	@property uinteger lineno(uinteger newLineno){
		if (storedType == Type.FunctionCall){
			return fCall.lineno = newLineno;
		}else if (storedType == Type.Literal){
			return literal.lineno = newLineno;
		}else if (storedType == Type.Operator){
			return operator.lineno = newLineno;
		}else if (storedType == Type.Variable){
			return var.lineno = newLineno;
		}else if (storedType == Type.ReadElement){
			return arrayRead.lineno = newLineno;
		}else if (storedType == Type.Array){
			return array.lineno = newLineno;
		}else if (storedType == Type.SOperator){
			return sOperator.lineno = newLineno;
		}
		return 0;
	}
	/// enum defining the possible types this node can store
	public enum Type{
		FunctionCall,
		Literal,
		Operator, // double operand operator
		SOperator, // single operand operator
		Variable,
		ReadElement,
		Array
	}
	/// the stored type
	private Type storedType;
	/// union storing all possible nodes
	private union{
		FunctionCallNode fCall;
		LiteralNode literal;
		OperatorNode operator;
		SOperatorNode sOperator;
		VariableNode var;
		ReadElement arrayRead;
		ArrayNode array;
	}
	/// returns the type of the stored type
	@property CodeNode.Type type(){
		return storedType;
	}
	/// sets the stored node
	@property auto ref node (T)(T newNode){
		static if (is (T == FunctionCallNode)){
			storedType = CodeNode.Type.FunctionCall;
			return fCall = newNode;
		}else static if (is (T == LiteralNode)){
			storedType = CodeNode.Type.Literal;
			return literal = newNode;
		}else static if (is (T == OperatorNode)){
			storedType = CodeNode.Type.Operator;
			return operator = newNode;
		}else static if (is (T == VariableNode)){
			storedType = CodeNode.Type.Variable;
			return var = newNode;
		}else static if (is (T == ReadElement)){
			storedType = CodeNode.Type.ReadElement;
			return arrayRead = newNode;
		}else static if(is (T == ArrayNode)){
			storedType = CodeNode.Type.Array;
			return array = newNode;
		}else static if (is (T == SOperatorNode)){
			storedType = CodeNode.Type.SOperator;
			return sOperator = newNode;
		}
	}
	/// returns the stored type
	@property auto ref node(CodeNode.Type T)(){
		// make sure it's the correct type
		if (T != storedType){
			throw new Exception("attempting to retrieve invalid type from CodeNode.node");
		}
		static if (T == CodeNode.Type.FunctionCall){
			return fCall;
		}else static if (T == CodeNode.Type.Literal){
			return literal;
		}else static if (T == CodeNode.Type.Operator){
			return operator;
		}else static if (T == CodeNode.Type.Variable){
			return var;
		}else static if (T == CodeNode.Type.ReadElement){
			return arrayRead;
		}else static if (T == CodeNode.Type.Array){
			return array;
		}else static if (T == CodeNode.Type.SOperator){
			return sOperator;
		}else{
			throw new Exception("attempting to retrieve invalid type from CodeNode.node");
		}
	}
	/// Returns: true if the stored data is literal
	public @property bool isLiteral (){
		if (storedType == CodeNode.Type.Literal)
			return true;
		if (storedType == CodeNode.Type.Array)
			return array.isLiteral;
		if (storedType == CodeNode.Type.Operator)
			return operator.isLiteral;
		if (storedType == CodeNode.Type.ReadElement)
			return arrayRead.isLiteral;
		if (storedType == CodeNode.Type.SOperator)
			return sOperator.isLiteral;
		if (storedType == CodeNode.Type.Variable)
			return var.isLiteral;
		return false;
	}
	/// the return type, only available after ASTCheck has checked it
	@property DataType returnType (){
		if (storedType == CodeNode.Type.Array){
			return array.returnType;
		}else if (storedType == CodeNode.Type.FunctionCall){
			return fCall.returnType;
		}else if (storedType == CodeNode.Type.Literal){
			return literal.returnType;
		}else if (storedType == CodeNode.Type.Operator){
			return operator.returnType;
		}else if (storedType == CodeNode.Type.ReadElement){
			return arrayRead.returnType;
		}else if (storedType == CodeNode.Type.SOperator){
			return sOperator.returnType;
		}else if (storedType == CodeNode.Type.Variable){
			return var.returnType;
		}
		return DataType();
	}
	/// ditto
	@property DataType returnType (DataType newType){
		if (storedType == CodeNode.Type.Array){
			return array.returnType = newType;
		}else if (storedType == CodeNode.Type.FunctionCall){
			return fCall.returnType = newType;
		}else if (storedType == CodeNode.Type.Literal){
			return literal.returnType = newType;
		}else if (storedType == CodeNode.Type.Operator){
			return operator.returnType = newType;
		}else if (storedType == CodeNode.Type.ReadElement){
			return arrayRead.returnType = newType;
		}else if (storedType == CodeNode.Type.SOperator){
			return sOperator.returnType = newType;
		}else if (storedType == CodeNode.Type.Variable){
			return var.returnType = newType;
		}
		return DataType();
	}
	/// constructor
	this (T)(T newNode){
		node = newNode;
	}
}

/// stores a variable
package struct VariableNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the name of this var
	public string varName;
	/// the ID of the variable. This is assigned in the ASTCheck stage, not in ASTGen
	public uinteger id;
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType;
	/// true if its return value is static, i.e, will always return same value when executed
	/// 
	/// determined by ASTCheck
	/// 
	/// TODO yet to be implemented, probably won't be done till 0.7.1
	public bool isLiteral = false;
	/// constructor
	this (string name){
		varName = name;
		isLiteral = false;
	}
}

/// stores array, for example, `[0, 1, x, y]` will be stored using this
package struct ArrayNode{
	/// the line number (starts from 1) from which this node begins, or ends
	uinteger lineno;
	/// stores the elements
	public CodeNode[] elements;
	/// Returns: true if its return value is static, i.e, will always return same value when executed
	public @property bool isLiteral (){
		foreach (element; elements)
			if (!element.isLiteral)
				return false;
		return true;
	}
	/// the return type
	@property DataType returnType (){
		if (elements.length == 0)
			return DataType(DataType.Type.Void,1);
		DataType r = elements[0].returnType;
		r.arrayDimensionCount++;
		return r;
	}
	/// does nothing (besides existing)
	@property DataType returnType(DataType newType){
		return this.returnType;
	}
	/// constructor
	this (CodeNode[] elements){
		this.elements = elements;
	}
}

/// stores literal data, i.e data that was availabe at runtime. Can store strings, double, integer,  
/// but arrays (even ones without variables, only literals) are stored in ArrayNode
package struct LiteralNode{
	private import qscript.qscript : QData;
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the data type for the literal
	public DataType returnType;
	/// stores the literal in a QData
	public QData literal;
	/// constructor
	this (QData data, DataType dataType){
		literal = data;
		returnType = dataType;
	}
	/// constructor using `fromTokens`
	this (Token[] tokensLiteral){
		fromTokens(tokensLiteral);
	}
	/// reads the literal from a string
	/// 
	/// throws Exception on error
	void fromTokens(Token[] tokensLiteral){
		// check if is empty array
		literal = tokensToQData(tokensLiteral, returnType);
	}
	/// returns this literal as in a string-representation, for the bytecode
	string toByteCode(){
		/// returns array in byte code representation
		static string fromDataOrArray(QData data, DataType type){
			if (type.arrayDimensionCount > 0){
				char[] array = ['['];
				// the type of the elements
				DataType subType = type;
				subType.arrayDimensionCount --;
				// use recursion
				foreach (element; data.arrayVal){
					array ~= cast(char[])fromDataOrArray(element, subType) ~ ',';
				}
				if (array.length == 1){
					array ~= ']';
				}else{
					array[array.length - 1] = ']';
				}
				return cast(string)array;
			}else{
				if (type.type == DataType.Type.Double){
					return "d"~to!string(data.doubleVal);
				}else if (type.type == DataType.Type.Integer){
					return "i"~to!string(data.intVal);
				}else if (type.type == DataType.Type.String){
					return "s\""~encodeString(data.strVal)~'"';
				}else{
					throw new Exception("invalid type stored");
				}
			}
		}
		return fromDataOrArray(literal, returnType);
	}
}

/// stores an operator with two operands
package struct OperatorNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the operator (like '+' ...)
	public string operator;
	/// operands. [0] = left, [1] = right
	public CodeNode[] operands;
	/// Returns: true if its return value is static, i.e, will always return same value when executed
	public @property bool isLiteral (){
		foreach (operand; operands){
			if (!operand.isLiteral)
				return false;
		}
		return true;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType;
	/// constructor
	this (string operatorString, CodeNode a, CodeNode b){
		operator = operatorString;
		operands.length = 2;
		operands[0] = a;
		operands[1] = b;
	}
}

/// stores an operator with single operand (like ! and @)
package struct SOperatorNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the operator string
	public string operator;
	/// the stored operand
	private CodeNode* operandPtr;
	/// the operand
	public @property ref CodeNode operand(CodeNode newOperand){
		if (operandPtr is null){
			operandPtr = new CodeNode;
		}
		return *operandPtr = newOperand;
	}
	/// the operand
	public @property ref CodeNode operand(){
		return *operandPtr;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType;
	/// Returns: true if its return value is static, i.e will always be same when executed
	@property bool isLiteral(){
		return (operandPtr !is null && operand.isLiteral);
	}
}

/// stores an "array-read" (instruction `readElement` or for string, `readChar`)
package struct ReadElement{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the node to read from
	private CodeNode* readFromPtr = null;
	/// the index to read at
	private CodeNode* readIndexPtr = null;
	/// the node to read from
	public @property ref CodeNode readFromNode(){
		if (readFromPtr is null)
			readFromPtr = new CodeNode;
		return *readFromPtr;
	}
	/// the node to read from
	public @property ref CodeNode readFromNode(CodeNode newNode){
		if (readFromPtr is null)
			readFromPtr = new CodeNode;
		return *readFromPtr = newNode;
	}
	/// the index to read at
	public @property ref CodeNode index(){
		if (readIndexPtr is null)
			readIndexPtr = new CodeNode;
		return *readIndexPtr;
	}
	/// the index to read at
	public @property ref CodeNode index(CodeNode newNode){
		if (readIndexPtr is null)
			readIndexPtr = new CodeNode;
		return *readIndexPtr = newNode;
	}
	/// returns the data type this node will return
	public @property DataType returnType(){
		DataType r = (*readFromPtr).returnType;
		if (r.arrayDimensionCount == 0 && r.type == DataType.Type.String){
			return DataType(DataType.Type.String);
		}
		r.arrayDimensionCount --;
		return r;
	}
	/// does nothing, besides existing but needed for compiling
	public @property DataType returnType(DataType newType){
		return this.returnType;
	}
	/// Returns: true if its return value is static, i.e, will always return same value when executed
	@property bool isLiteral(){
		return (readFromPtr !is null && readIndexPtr !is null && readFromNode.isLiteral && index.isLiteral);
	}
	/// constructor
	this (CodeNode toReadNode, CodeNode index){
		this.readFromNode = toReadNode;
		this.index = index;
	}
}

/// a node representing statements, including: if, while, function-call..
package struct StatementNode{
	/// types of a statement
	public enum Type{
		If,
		While,
		For,
		DoWhile,
		Block,
		Assignment,
		FunctionCall,
		VarDeclare
	}
	/// Returns: the line number (starts from 1) from which this node begins, or ends
	public @property uinteger lineno(){
		if (storedType == Type.If){
			return ifNode.lineno;
		}else if (storedType == Type.While){
			return whileNode.lineno;
		}else if (storedType == Type.For){
			return forNode.lineno;
		}else if (storedType == Type.DoWhile){
			return doWhile.lineno;
		}else if (storedType == Type.Block){
			return blockNode.lineno;
		}else if (storedType == Type.Assignment){
			return assignNode.lineno;
		}else if (storedType == Type.FunctionCall){
			return functionCallNode.lineno;
		}else if (storedType == Type.VarDeclare){
			return varDeclareNode.lineno;
		}
		return 0;
	}
	/// ditto
	public @property uinteger lineno(uinteger newLineno){
		if (storedType == Type.If){
			return ifNode.lineno = newLineno;
		}else if (storedType == Type.While){
			return whileNode.lineno = newLineno;
		}else if (storedType == Type.For){
			return forNode.lineno = newLineno;
		}else if (storedType == Type.DoWhile){
			return doWhile.lineno = newLineno;
		}else if (storedType == Type.Block){
			return blockNode.lineno = newLineno;
		}else if (storedType == Type.Assignment){
			return assignNode.lineno = newLineno;
		}else if (storedType == Type.FunctionCall){
			return functionCallNode.lineno = newLineno;
		}else if (storedType == Type.VarDeclare){
			return varDeclareNode.lineno = newLineno;
		}
		return 0;
	}
	/// type of this statement
	private Type storedType;
	/// the stored node, is in this union
	private union{
		IfNode ifNode;
		WhileNode whileNode;
		ForNode forNode;
		DoWhileNode doWhile;
		BlockNode blockNode;
		FunctionCallNode functionCallNode;
		VarDeclareNode varDeclareNode;
		AssignmentNode assignNode;
	}
	/// modifies the stored node
	@property auto ref node(T)(T newNode){
		static if (is (T == IfNode)){
			storedType = StatementNode.Type.If;
			ifNode = newNode;
		}else static if (is (T == WhileNode)){
			storedType = StatementNode.Type.While;
			whileNode = newNode;
		}else static if (is (T == ForNode)){
			storedType = StatementNode.Type.For;
			forNode = newNode;
		}else static if (is (T == DoWhileNode)){
			storedType = StatementNode.Type.DoWhile;
			doWhile = newNode;
		}else static if (is (T == BlockNode)){
			storedType = StatementNode.Type.Block;
			blockNode = newNode;
		}else static if (is (T == FunctionCallNode)){
			storedType = StatementNode.Type.FunctionCall;
			functionCallNode = newNode;
		}else static if (is (T == VarDeclareNode)){
			storedType = StatementNode.Type.VarDeclare;
			varDeclareNode = newNode;
		}else if (is (T == AssignmentNode)){
			storedType = StatementNode.Type.Assignment;
			assignNode = newNode;
		}else{
			throw new Exception("attempting to assign invalid node type to StatementNode.node");
		}
	}
	/// returns the stored type
	@property auto ref node(StatementNode.Type T)(){
		// make sure type is correct
		if (T != storedType){
			throw new Exception("stored type does not match with type being retrieved");
		}
		static if (T == StatementNode.Type.If){
			return ifNode;
		}else static if (T == StatementNode.Type.While){
			return whileNode;
		}else static if (T == StatementNode.Type.For){
			return forNode;
		}else static if (T == StatementNode.Type.DoWhile){
			return doWhile;
		}else static if (T == StatementNode.Type.Block){
			return blockNode;
		}else static  if (T == StatementNode.Type.FunctionCall){
			return functionCallNode;
		}else static if (T == StatementNode.Type.VarDeclare){
			return varDeclareNode;
		}else if (T == StatementNode.Type.Assignment){
			return assignNode;
		}else{
			throw new Exception("attempting to retrieve invalid type from StatementNode.node");
		}
	}
	/// returns the type of the stored node
	@property StatementNode.Type type(){
		return storedType;
	}
	/// constructor
	this (T)(T newNode){
		node = newNode;
	}
}

/// to store assignment statements
package struct AssignmentNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores whether the assignment is to a variable (false) or if it has to dereference first (true)
	public bool deref = false;
	/// the variable to assign to
	public VariableNode var;
	/// stores the how "deeper" dimension of the array the value has to be assigned to
	public CodeNode[] indexes;
	/// the value to assign
	public CodeNode val;
	/// constructor
	this (VariableNode variable, CodeNode[] varIndexes, CodeNode value, bool deref = false){
		var = variable;
		indexes = varIndexes.dup;
		val = value;
		this.deref = deref;
	}
}

/// to store if statements
package struct IfNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the condition for this if statement
	public CodeNode condition;
	/// stores the pointer to the statement to execute
	private StatementNode* statementPtr;
	/// returns the statement to execute, if true
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// sets the statement to execute, if true
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// stores the pointer to the statement to execute if the condition is false.
	private StatementNode* elseStatementPtr;
	/// returns the statement to execute, if false
	public @property ref StatementNode elseStatement(){
		if (elseStatementPtr is null)
			elseStatementPtr = new StatementNode;
		return *elseStatementPtr;
	}
	/// sets the statement to execute, if true
	public @property ref StatementNode elseStatement(StatementNode newElseStatement){
		if (elseStatementPtr is null){
			elseStatementPtr = new StatementNode;
		}
		return *elseStatementPtr = newElseStatement;
	}

	/// stores whether this if has an else statement too
	public bool hasElse = false;
	/// constructor
	this (CodeNode conditionNode, StatementNode statementToExecute, StatementNode elseStatementToExec){
		condition = conditionNode;
		statement = statementToExecute;
		elseStatement = elseStatementToExec;
		hasElse = true;
	}
	/// constructor
	this (CodeNode conditionNode,  StatementNode statementsToExecute){
		condition = conditionNode;
		statement = statementsToExecute;
		hasElse = false;
	}
}

/// to store while statements
package struct WhileNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the condition for this while statement
	public CodeNode condition;
	/// stores the pointer to the statement to execute in loop while the condition is true
	private StatementNode* statementPtr;
	/// returns the statement to execute, while true
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// sets the statement to execute, while true
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// constructor
	this (CodeNode conditionNode, StatementNode statementToExec){
		condition = conditionNode;
		statement = statementToExec;
	}
}

/// to store do-while statements
package struct DoWhileNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the condition for this do-while statement
	public CodeNode condition;
	/// stores pointer to the statement to execute in this loop
	private StatementNode* statementPtr;
	/// the statement to execute in this loop
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// ditto
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// constructor
	this (CodeNode conditionNode, StatementNode statementToExec){
		condition = conditionNode;
		statement = statementToExec;
	}
}

/// to store for loop statements
package struct ForNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the pointer to initialization statement, i.e: `for (<this one>; bla; bla)...`
	private StatementNode* initStatementPtr;
	/// stores the pointer to the increment statement, i.e: `for (bla; bla; <this one>)...`
	private StatementNode* incStatementPtr;
	/// stores the condition CodeNode
	public CodeNode condition;
	/// stores the pointer to the statement to execute in loop
	private StatementNode* statementPtr;
	/// the init statement for this for loop
	public @property ref StatementNode initStatement(){
		if (initStatementPtr is null)
			initStatementPtr = new StatementNode;
		return *initStatementPtr;
	}
	/// ditto
	public @property ref StatementNode initStatement(StatementNode newStatement){
		if (initStatementPtr is null){
			initStatementPtr = new StatementNode;
		}
		return *initStatementPtr = newStatement;
	}
	/// the increment statement for this for loop
	public @property ref StatementNode incStatement(){
		if (incStatementPtr is null)
			incStatementPtr = new StatementNode;
		return *incStatementPtr;
	}
	/// ditto
	public @property ref StatementNode incStatement(StatementNode newStatement){
		if (incStatementPtr is null){
			incStatementPtr = new StatementNode;
		}
		return *incStatementPtr = newStatement;
	}
	/// the statement to execute in loop
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// ditto
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// constructor
	this (StatementNode initNode, CodeNode conditionNode, StatementNode incNode, StatementNode statementToExec){
		initStatement = initNode;
		condition = conditionNode;
		incStatement = incNode;
		statement = statementToExec;
	}
}

/// to store functionCall nodes
package struct FunctionCallNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the name of the function
	public string fName;
	/// the arguments for this function.
	private CodeNode[] storedArguments;
	/// returns the values for arguments
	@property ref CodeNode[] arguments(){
		return storedArguments;
	}
	/// sets value for storedArguments
	@property ref CodeNode[] arguments(CodeNode[] newArgs){
		return storedArguments = newArgs.dup;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType;
	/// constructor
	this (string functionName, CodeNode[] functionArguments){
		fName = functionName;
		arguments = functionArguments;
	}
}

/// to store var declaration
package struct VarDeclareNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the data typre of defined vars
	public DataType type;
	/// stores names of vars declared
	private string[] varNames;
	/// stores IDs of vars declared, only assigned after ASTCheck has checked it
	private uinteger[string] _varIDs;
	/// stores vars' assigned values, with key=varName
	private CodeNode[string] varValues;
	/// returns: array contataining names of declared vars. Modifying this array won't have any effect
	public @property string[] vars(){
		return varNames.dup;
	}
	/// returns: array containig ID's of variables in assoc_array
	public @property uinteger[string] varIDs(){
		return _varIDs.dup;
	}
	/// Returns: assigned value for a var
	/// 
	/// Throws: Exception if that variable was not assigned in this statement, or no value was assigned to it
	public ref CodeNode getValue(string varName){
		if (varName in varValues){
			return varValues[varName];
		}
		throw new Exception ("variable "~varName~" does not exist in array");
	}
	/// Returns: true if a variable has a value assigned to it
	public bool hasValue(string varName){
		if (varName in varValues)
			return true;
		return false;
	}
	/// adds a variable to the list
	public void addVar(string varName){
		varNames = varNames ~ varName;
	}
	/// adds a variable to the list, along with it's assigned value
	public void addVar(string varName, CodeNode value){
		varValues[varName] = value;
		varNames = varNames ~ varName;
	}
	/// sets a stored var's assigned value
	public void setVarValue(string varName, CodeNode value){
		varValues[varName] = value;
	}
	/// sets a stored var's ID
	public void setVarID(string varName, uinteger id){
		_varIDs[varName] = id;
	}
	/// constructor
	this (string[] vars){
		varNames = vars.dup;
	}
}
