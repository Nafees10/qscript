/++
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
	private FunctionNode[] storedFunctions;
	/// returns the array containing the functions
	@property ref FunctionNode[] functions(){
		return storedFunctions;
	}
	/// sets the storedFunctions array
	@property ref FunctionNode[] functions(FunctionNode[] scriptFunctions){
		return storedFunctions = scriptFunctions.dup;
	}
	/// constructor
	this (FunctionNode[] scriptFunctions){
		storedFunctions = scriptFunctions.dup;
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
	private FunctionNode.Argument[] args;
	/// returns an array of arguments this function receives and their types
	@property ref FunctionNode.Argument[] arguments(){
		return args;
	}
	/// sets value of array containing arguments + types
	@property ref FunctionNode.Argument[] arguments(FunctionNode.Argument[] newArgs){
		return args = newArgs.dup;
	}
	/// the name of the function
	string name;
	/// body block of this function
	public BlockNode bodyBlock;
	/// the data type of the return value of this function
	public DataType returnType = DataType(DataType.Type.Void);
	/// constructor
	this (DataType returnDataType, string fName, FunctionNode.Argument[] funcArgs, BlockNode fBody){
		bodyBlock = fBody;
		name = fName;
		args = funcArgs.dup;
		returnType = returnType;
	}
}

/// a node representing a "set-of-statements" AKA a "block"
package struct BlockNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// an array of statements that make this block
	private StatementNode[] storedStatements;
	/// returns the array containing the statements
	@property ref StatementNode[] statements(){
		return storedStatements;
	}
	/// sets the array containing statements
	@property ref StatementNode[] statements(StatementNode[] blockStatements){
		return storedStatements = blockStatements.dup;
	}
	/// constructor
	this (StatementNode[] blockStatements){
		storedStatements = blockStatements.dup;
	}
}

/// a node to represent code that evaluates to some data.
/// 
/// This node can contain:  
/// 1. Function call - to only those functions that return some data
/// 2. Literals
/// 3. Operators
/// 4. Variables
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
		}
		return 0;
	}
	/// enum defining the possible types this node can store
	public enum Type{
		FunctionCall,
		Literal,
		Operator,
		Variable,
		ReadElement
	}
	/// the stored type
	private Type storedType;
	/// union storing all possible nodes
	private union{
		FunctionCallNode fCall;
		LiteralNode literal;
		OperatorNode operator;
		VariableNode var;
		ReadElement arrayRead;
	}
	/// returns the type of the stored type
	@property CodeNode.Type type(){
		return storedType;
	}
	/// returns the data type that the node will return
	@property DataType returnType(){
		if (storedType == CodeNode.Type.FunctionCall){
			return fCall.returnType;
		}else if (storedType == CodeNode.Type.Literal){
			return literal.type;
		}else if (storedType == CodeNode.Type.Operator){
			return operator.returnType;
		}else if (storedType == CodeNode.Type.Variable){
			return var.varType;
		}else if (storedType == CodeNode.Type.ReadElement){
			return arrayRead.returnType;
		}else{
			throw new Exception("invalid type stored");
		}
	}
	/// sets the stored node
	@property auto node (T)(T newNode){
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
		}
	}
	/// returns the stored type
	@property auto node(CodeNode.Type T)(){
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
		}else{
			throw new Exception("attempting to retrieve invalid type from CodeNode.node");
		}
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
	/// the data type of the variable
	public DataType varType;
	/// the name of this var
	public string varName;
	/// constructor
	this (DataType type, string name, CodeNode[] index){
		varType = type;
		varName = name;
	}
	/// constructor
	this (DataType type, string name){
		varType = type;
		varName = name;
	}
}

/// stores literal data, i.e data that was availabe at runtime. Can store strings, double, integer, array
package struct LiteralNode{
	private import qscript.qscript : QData;
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the data type for the literal
	public DataType type;
	/// stores the literal in a QData
	public QData literal;
	/// constructor
	this (QData data, DataType dataType){
		literal = data;
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
		literal = tokensToQData(tokensLiteral, type);
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
		return fromDataOrArray(literal, type);
	}
}

/// stores an operator with operands
package struct OperatorNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the operator (like '+' ...)
	public string operator;
	/// returns the result data type
	/// 
	/// the data type is determined by the data type of the first operand
	@property DataType returnType(){
		// if is a bool_operator, then return int
		if (BOOL_OPERATORS.hasElement(operator)){
			return DataType(DataType.Type.Integer);
		}
		return operands[0].returnType;
	}
	/// operands. [0] = left, [1] = right
	private CodeNode[] storedOperands;
	/// returns an array of operands
	@property ref CodeNode[] operands(){
		return storedOperands;
	}
	/// sets value of array storing operands
	@property ref CodeNode[] operands(CodeNode[] newOperands){
		return storedOperands = newOperands.dup;
	}
	/// constructor
	this (string operatorString, CodeNode a, CodeNode b){
		operator = operatorString;
		storedOperands.length = 2;
		storedOperands[0] = a;
		storedOperands[1] = b;
	}
}

/// stores an "array-read" (instruction `readElement` or for string, `readChar`)
package struct ReadElement{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the nodes. [0] is the node to read from. [1] is the index
	private CodeNode[] nodes = [null, null];
	/// the node to read from
	public @property CodeNode readFromNode(){
		return nodes[0];
	}
	/// the node to read from
	public @property CodeNode readFromNode(CodeNode newNode){
		return nodes[0] = newNode;
	}
	/// the index to read at
	public @property CodeNode index(){
		return nodes[1];
	}
	/// the index to read at
	public @property CodeNode index(CodeNode newNode){
		return nodes[1] = newNode;
	}
	/// returns the data type this node will return
	public @property DataType returnType(){
		DataType r = nodes[0].returnType;
		if (r.arrayDimensionCount == 0 && r.type == DataType.Type.String){
			return DataType(DataType.Type.String);
		}
		r.arrayDimensionCount --;
		return r;
	}
	/// constructor
	this (CodeNode toReadNode, CodeNode index){
		nodes.length = 2;
		nodes[0] = toReadNode;
		nodes[1] = index;
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
	@property node(T)(T newNode){
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
	@property node(StatementNode.Type T)(){
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
	/// the variable to assign to
	public VariableNode var;
	/// stores the how "deeper" dimension of the array the value has to be assigned to
	private CodeNode[] storedIndexes;
	/// returns to which index(es) the val has to be assigned
	public @property ref CodeNode[] indexes(){
		return storedIndexes;
	}
	/// sets to which index(es) the val has to be assigned
	public @property ref CodeNode[] indexes(CodeNode[] newArray){
		return storedIndexes = newArray.dup;
	}
	/// the value to assign
	public CodeNode val;
	/// constructor
	this (VariableNode variable, CodeNode[] varIndexes, CodeNode value){
		var = variable;
		storedIndexes = varIndexes.dup;
		val = value;
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
	/// the data type of the returned data
	public DataType returnType;
	/// the arguments for this function.
	private CodeNode[] storedArguments;
	/// returns the assoc_array storing values for arguments
	@property ref CodeNode[] arguments(){
		return storedArguments;
	}
	/// sets value for storedArguments
	@property ref CodeNode[] arguments(CodeNode[] newArgs){
		return storedArguments = newArgs.dup;
	}
	/// constructor
	this (DataType returnDataType, string functionName, CodeNode[] functionArguments){
		returnType = returnDataType;
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
	/// stores vars' assigned values, with key=varName
	private CodeNode[string] varValues;
	/// returns: array contataining names of declared vars. Modifying this array won't have any effect
	public @property string[] vars(){
		return varNames.dup;
	}
	/// Returns: assigned value for a var
	/// 
	/// Throws: Exception if that variable was not assigned in this statement, or no value was assigned to it
	public CodeNode getValue(string varName){
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
	/// constructor
	this (string[] vars){
		varNames = vars.dup;
	}
}
