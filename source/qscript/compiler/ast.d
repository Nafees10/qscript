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
			if (type.arrayNestCount > 0){
				char[] array = ['['];
				// the type of the elements
				DataType subType = type;
				subType.arrayNestCount --;
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
	/// stores the operator (like '+' ...)
	public string operator;
	/// returns the result data type
	/// 
	/// the data type is determined by the data type of the first operand
	@property DataType returnType(){
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
		if (r.arrayNestCount == 0 && r.type == DataType.Type.String){
			return DataType(DataType.Type.String);
		}
		r.arrayNestCount --;
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
		Block,
		Assignment,
		FunctionCall,
		VarDeclare
	}
	/// type of this statement
	private Type storedType;
	/// the stored node, is in this union
	private union{
		IfNode ifNode;
		WhileNode whileNode;
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
	/// the condition for this if statement
	public CodeNode condition;
	/// the statements to execute if the condition is true
	private StatementNode[] storedStatements;
	/// returns array containing statements to execute
	public @property ref StatementNode[] statements(){
		return storedStatements;
	}
	/// to modify the stored statements
	public @property ref StatementNode[] statements(StatementNode[] newArray){
		return storedStatements = newArray.dup;
	}
	/// the statements to execute if the condition is false. This block will be empty in case there was no else block
	private StatementNode[] storedElseStatements;
	/// returns array containing statements to execute on eles
	public @property ref StatementNode[] elseStatements(){
		return storedElseStatements;
	}
	/// to modify the stored statements to execute on eles
	public @property ref StatementNode[] elseStatements(StatementNode[] newArray){
		return storedElseStatements = newArray.dup;
	}
	/// constructor
	this (CodeNode conditionNode, StatementNode[] statementsToExecute, StatementNode[] elseStatementsToExec){
		condition = conditionNode;
		storedStatements = statementsToExecute.dup;
		storedElseStatements = elseStatementsToExec.dup;
	}
	/// constructor
	this (CodeNode conditionNode,  StatementNode[] statementsToExecute){
		condition = conditionNode;
		storedStatements = statementsToExecute.dup;
		storedElseStatements = [];
	}
	/// returns true if the else block has a body
	@property bool hasElse(){
		if (storedElseStatements.length > 0){
			return true;
		}
		return false;
	}
}

/// to store while statements
package struct WhileNode{
	/// the condition for this while statement
	public CodeNode condition;
	/// the statements to execute in loop if the condition is true
	private StatementNode[] storedStatements;
	/// returns array containing statements to execute
	public @property ref StatementNode[] statements(){
		return storedStatements;
	}
	/// to modify the stored statements
	public @property ref StatementNode[] statements(StatementNode[] newArray){
		return storedStatements = newArray.dup;
	}
	/// constructor
	this (CodeNode conditionNode, StatementNode[] statementsToExec){
		condition = conditionNode;
		storedStatements = statementsToExec.dup;
	}
}

/// to store functionCall nodes
package struct FunctionCallNode{
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
	/// the data typre of defined vars
	public DataType type;
	/// stores names of variables declared
	private string[] storedVars;
	/// returns array contataining declared vars
	public @property ref string[] vars(){
		return storedVars;
	}
	/// sets value for declared vars
	public @property ref string[] vars(string[] newVars){
		return storedVars = newVars.dup;
	}
	/// constructor
	this (DataType varDataType, string[] varNames){
		type = varDataType;
		vars = varNames.dup;
	}
}