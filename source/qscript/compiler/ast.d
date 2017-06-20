module qscript.compiler.ast;

import utils.misc;

package struct ASTNode{
	/// Enum defining types of ASTNode
	enum Type{
		Script, /// The top-most node
		Function, /// Function declaration
		IfStatement, /// If statement
		WhileStatement, /// just like IfStatement, but used for while loop
		Block, /// Code block, like {this}, a block following an if statement, while loop, or function declaration is not a block
		Assign, /// Assignment operator
		Operator, /// Any operator aside from Assignment operator and comparison operators like `==` and `>=`...
		FunctionCall, /// Function Call,
		StringLiteral, /// String Literal
		NumberLiteral, /// Number Literal
		HexLiteral, /// A Literal in form `0x1AB`
		VarDeclare, /// For variable declaration
		Variable, /// variable name
		Arguments, /// stores arguments for a function
		ArrayIndex, /// Stores index for an array, in an `ASTNode`
	}
	/// Enum defining types of child-nodes
	enum ChildType{
		Function, /// Function inside a Script
		FunctionBody, /// To point to function body contents
		Body, /// To point to body for nodes like IfStatement, WhileStatement ...
		Condition, /// To point to conition for IfStatement and WhileStatement
		AssignLValue, /// To point to lvalue for Assign
		AssignRValue, /// To point to rvalue for Assign
		OperatorOperand1, /// To point to the first oprand for an Operator
		OperatorOperand2, /// To point to the second operand for an operator
		FunctionArguments, /// To point to arguments for a function
		ArrayIndex, /// To point to index
	}

	private{
		/// Stores type of this Node. It's private so as to keep it unchanged after constructor
		Type nodeType;
		string nodeData; /// For storing data for some nodes, like functionName for `Type.Function`
		union{
			ASTNode[ChildType] childNodes; /// used for things like storing the FunctionBody (Block) for a Function and Function inside Script
			ASTNode[] bodyNodes; /// This is used for .. example: in a function body to store statements like FunctionCall...
		}
		uinteger ln; /// Stores the line number on which the node is - for error reporting
	}

	/// initializes the node, nType is the type of node.
	this(Type nType, uinteger lineNumber){
		nodeType = nType;
		ln = lineNumber;
	}
	/// initializes the node, nType is the type of node.
	/// nData varies for different Types
	/// for `Type.Function`, it is the name of the function declared
	/// for `Type.FunctionCall`, it is the function name to call
	/// for `Type.StringLiteral`, it is the string (witout the quotation marks)
	/// for `Type.NumberLiteral`, it is the number (in a string)
	/// for `Type.Variable`, it is the variable name
	this(Type nType, string nData, uinteger lineNumber){
		nodeType = nType;
		nodeData = nData;
		ln = lineNumber;
	}

	/// returns nodeData
	/// for `Type.Function`, it is the name of the function declared
	/// for `Type.FunctionCall`, it is the function name to call
	/// for `Type.StringLiteral`, it is the string (witout the quotation marks)
	/// for `Type.NumberLiteral`, it is the number (in a string)
	/// for `Type.Variable`, it is the variable name
	@property string data(){
		return nodeData;
	}
	/// returns the type of the node
	@property Type type(){
		return nodeType;
	}
	/// returns the sub-nodes/child-nodes of this node by the type of child node
	ASTNode getChild(ChildType t){
		return childNodes[t];
	}
	/// Only for nodes which have a body. Like `Type.IfStatement` has nodes in its ifbody...
	ASTNode[] getBodyNodes(){
		return bodyNodes.dup;
	}
	//functions to moditfy node contents
	/// Adds a child node, with the childType
	void addChild(ASTNode child, ChildType cType){
		childNodes[cType] = child;
	}
	/// Adds a body node
	void addBodyNode(ASTNode bNode){
		if (bodyNodes is null || bodyNodes.length == 0){
			bodyNodes = [bNode];
		}else{
			bodyNodes ~= bNode;
		}
	}
	/// Adds an array of nodes as body nodes
	void addBodyNode(ASTNode[] bNodes){
		if (bodyNodes is null || bodyNodes.length == 0){
			bodyNodes = bNodes.dup;
		}else{
			bodyNodes ~= bNodes.dup;
		}
	}
}