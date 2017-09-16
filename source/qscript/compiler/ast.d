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
		if (is (T == IfNode)){
			storedType = StatementNode.Type.If;
			ifNode = newNode;
		}else if (is (T == WhileNode)){
			storedType = StatementNode.Type.While;
			whileNode = newNode;
		}else if (is (T == BlockNode)){
			storedType = StatementNode.Type.Block;
			blockNode = newNode;
		}else if (is (T == FunctionCallNode)){
			storedType = StatementNode.Type.FunctionCall;
			functionCallNode = newNode;
		}else if (is (T == VarDeclareNode)){
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
		if (T == StatementNode.Type.If){
			return ifNode;
		}else if (T == StatementNode.Type.While){
			return whileNode;
		}else if (T == StatementNode.Type.Block){
			return blockNode;
		}else if (T == StatementNode.Type.FunctionCall){
			return functionCallNode;
		}else if (T == StatementNode.Type.VarDeclare){
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