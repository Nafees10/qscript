module qscript.compiler.ast;

import utils.misc;
import utils.lists;
import qscript.compiler.misc;

import std.conv : to;

/// a struct to store nodes for the Syntax-Tree
package struct ASTNode{
	/// Enum defining types of ASTNode
	enum Type{
		Script, /// The top-most node
		Function, /// Function declaration
		IfStatement, /// If statement
		WhileStatement, /// just like IfStatement, but used for while loop
		Block, /// Used to store body nodes for ifwhilestatement, Function etc
		Assign, /// Assignment operator
		Operator, /// Any operator aside from Assignment operator and comparison operators like `==` and `>=`...
		FunctionCall, /// Function Call,
		StringLiteral, /// String Literal
		NumberLiteral, /// Number Literal
		VarDeclare, /// For variable declaration
		Variable, /// variable name
		Arguments, /// stores arguments for a function
		ArrayIndex, /// Stores index for an array, in an `ASTNode`
		StaticArray, /// For storing elements of a static array, i.e: `[x, y, z]`
	}
	/// the line number on which this node was on
	uinteger lineNumber;
	/// the actual type of the stored node
	ASTNode.Type type;
}

/// a node representing the script
package struct ScriptNode{
	/// list of functions defined in this script
	public FunctionNode[] functions;
	/// constructor
	this (FunctionNode[] scriptFunctions){
		functions = scriptFunctions.dup;
	}
	/// postblit
	this (this){
		this.functions = functions.dup;
	}
}

/// a node representing a function definition
package struct FunctionNode{
	/// body block of this function
	public BlockNode bodyBlock;
	/// the data type of the return value of this function
	public DataType returnType = DataType.Void;
	/// constructor
	this (BlockNode fBody, DataType returnDataType){
		bodyBlock = fBody;
		returnType = returnType;
	}
	/// constructor 
	this (DataType returnDataType){
		returnType = returnDataType;
	}
}

/// a node representing a "set-of-statements" AKA a "block"
package struct BlockNode{
	/// an array of statements that make this block
	public StatementNode[] statements;
	/// constructor
	this (StatementNode[] blockStatements){
		statements = blockStatements.dup;
	}
	/// postblit
	this (this){
		this.statements = this.statements.dup;
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
		Variable
	}
	/// the stored type
	private Type storedType;
	/// union storing all possible nodes
	private union{
		FunctionCallNode fCall;
		LiteralNode literal;
		OperatorNode operator;
		Variable var;
	}
	/// returns the type of the stored type
	@property CodeNode.Type type(){
		return storedType;
	}
	/// sets the stored node
	@property auto node(T)(T newNode){
		static if (is (T == FunctionCallNode)){
			fCall = newNode;
			storedType = CodeNode.Type.FunctionCall;
		}else static if (is (T == LiteralNode)){
			literal = newNode;
			storedType = CodeNode.Type.Literal;
		}else static if (is (T == OperatorNode)){
			operator = newNode;
			storedType = CodeNode.Type.Operator;
		}else static if (is (T == VariableNode)){
			var = newNode;
			storedType = CodeNode.Type.Variable;
		}else{
			throw new Exception("attempting to store unsupported type in CodeNode.node");
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
		}else{
			throw new Exception("attempting to retrieve invalid type from CodeNode.node");
		}
	}
	/// constructor
	this (T)(T newNode){
		node = newNode;
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

/// to store if statements
package struct IfNode{
	/// the condition for this if statement
	public CodeNode condition;
	/// the block to execute if the condition is true
	public BlockNode block;
	/// the block to execute if the condition is false. This block will be empty in case there was no else block
	public BlockNode elseBlock;
	/// constructor
	this (CodeNode conditionNode, BlockNode blockToExecute, BlockNode elseBlockToExecute){
		condition = conditionNode;
		block = blockToExecute;
		elseBlock = elseBlockToExecute;
	}
	/// constructor
	this (CodeNode conditionNode, BlockNode blockToExecute){
		condition = conditionNode;
		block = blockToExecute;
		elseBlock = BlockNode([]);
	}
	/// returns true if the else block has a body
	@property bool hasElse(){
		if (elseBlock.statements.length > 0){
			return true;
		}
		return false;
	}
}

/// to store while statements
package struct WhileNode{
	/// the condition for this while statement
	public CodeNode condition;
	/// the block to execute in loop if the condition is true
	public BlockNode block;
	/// constructor
	this (CodeNode conditionNode, BlockNode blockToExecute){
		condition = conditionNode;
		block = blockToExecute;
	}
}

/// to store functionCall nodes
package struct FunctionCallNode{
	/// the name of the function
	public string fName;
	/// the arguments for this function
	public CodeNode[] arguments;
	/// postblit
	this (this){
		arguments = arguments.dup;
	}
	/// constructor
	this (string functionName, CodeNode[] functionArguments){
		fName = functionName;
		arguments = functionArguments.dup;
	}
}




debug{
	/// returns a string representing a type of ASTNode given the ASTNode.Type
	string getNodeTypeString(ASTNode.Type type){
		const string[ASTNode.Type] typeString = [
			ASTNode.Type.Arguments: "arguments",
			ASTNode.Type.ArrayIndex: "array-index",
			ASTNode.Type.Assign: "assignment-statement",
			ASTNode.Type.Block: "block",
			ASTNode.Type.Function: "function-definition",
			ASTNode.Type.FunctionCall: "function-call",
			ASTNode.Type.IfStatement: "if-statement",
			ASTNode.Type.NumberLiteral: "number-literal",
			ASTNode.Type.Operator: "operator",
			ASTNode.Type.Script: "script",
			ASTNode.Type.StringLiteral: "string-literal",
			ASTNode.Type.VarDeclare: "variable-declaration",
			ASTNode.Type.Variable: "variable",
			ASTNode.Type.WhileStatement: "while-statement",
			ASTNode.Type.StaticArray: "static-array"
		];
		return typeString[type];
	}
	/// converts an AST to an html/xml-like file, only available in debug
	string[] toXML(ASTNode mainNode, uinteger tabLevel = 0){
		string getTab(uinteger length){
			char[] tab;
			tab.length = length;
			if (tab.length > 0){
				tab[] = '\t';
			}
			return cast(string)tab;
		}
		
		LinkedList!string xml = new LinkedList!string;
		
		string tab = getTab(tabLevel);
		
		string type = getNodeTypeString(mainNode.type);
		string tag = tab~"<node type=\""~type~"\">";
		xml.append(tag);
		tabLevel ++;
		tab = getTab(tabLevel);
		
		//tag = tab~"<type>"~type~"</type>";
		//xml.append(tag);
		
		if (mainNode.data.length > 0){
			tag = tab~"<data>"~mainNode.data~"</data>";
			xml.append(tag);
		}
		
		// if there are subnodes, do recursion
		ASTNode[] subNodes = mainNode.subNodes;
		if (subNodes.length > 0){
			foreach (subNode; subNodes){
				xml.append(toXML(subNode, tabLevel));
			}
		}
		tabLevel --;
		tab = getTab(tabLevel);
		// closing tag
		tag = tab~"</node>";
		xml.append(tag);
		
		string[] r = xml.toArray;
		.destroy(xml);
		return r;
	}
}