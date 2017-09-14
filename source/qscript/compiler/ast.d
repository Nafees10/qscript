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

	/// the actual node is stored here:
	private enum{

	}
	
	private{
		/// Stores type of this Node. It's private so as to keep it unchanged after constructor
		Type nodeType;
		uinteger ln; /// Stores the line number on which the node is - for error reporting
	}
	
	/// initializes the node, nType is the type of node.
	this(Type nType, uinteger lineNumber){
		nodeType = nType;
		ln = lineNumber;
	}
	/// returns the type of the node
	@property Type type(){
		return nodeType;
	}
	/// returns the line number this node was on
	@property uinteger lineno(){
		return ln;
	}
}

/// a node representing the script
package struct ScriptNode{
	/// list of functions defined in this script
	private FunctionNode[] definedFunctions;
	/// constructor
	this (FunctionNode[] scriptFunctions){
		functions = scriptFunctions.dup;
	}
	/// returns array of functions stored in this node
	@property FunctionNode[] 
}

/// a node representing a function definition
package struct FunctionNode{
	private StatementNode[] statements;

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