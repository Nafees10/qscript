module qscript.compiler.ast;

import utils.misc;
import utils.lists;
import qscript.compiler.misc;

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
		HexLiteral, /// A Literal in form `0x1AB`
		VarDeclare, /// For variable declaration
		Variable, /// variable name
		Arguments, /// stores arguments for a function
		ArrayIndex, /// Stores index for an array, in an `ASTNode`
	}

	private{
		/// Stores type of this Node. It's private so as to keep it unchanged after constructor
		Type nodeType;
		string nodeData; /// For storing data for some nodes, like functionName for `Type.Function`
		ASTNode[] subNodes; /// This is used for .. example: in a function body to store statements like FunctionCall...

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
	/// Returns an array of subnodes that come under this node
	ASTNode[] getSubNodes(){
		return subNodes.dup;
	}
	/// Adds a body node. Use only with Node.Type.Body
	void addSubNode(ASTNode bNode){
		if (subNodes is null || subNodes.length == 0){
			subNodes = [bNode];
		}else{
			subNodes ~= bNode;
		}
	}
	/// Adds an array of nodes as body nodes
	void addSubNode(ASTNode[] bNodes){
		if (subNodes is null || subNodes.length == 0){
			subNodes = bNodes.dup;
		}else{
			subNodes ~= subNodes.dup;
		}
	}
}

/// contains functions and stuff to convert a QScript from tokens to Syntax Trees
struct ASTGen{
	/// generates an AST representing a script.
	/// 
	/// The script must be converted to tokens using `qscript.compiler.tokengen.toTokens`
	/// If any errors occur, they will be contanied in `qscript.compiler.misc.`
	public ASTNode generateAST(TokenList tokens){
		varList = new LinkedList!string;

		ASTNode scriptNode = ASTNode(ASTNode.Type.Script, 0);
		// go through the script, compile function nodes, link them to this node
		for (uinteger i = 0, lastIndex = tokens.tokens.length - 1; i < tokens.tokens.length; i ++){
			// look for TokenType.Keyword where token.token == "function"
			if (tokens.tokens[i].type == Token.Type.Keyword && tokens.tokens[i].token == "function"){
				uinteger errorCount = compileErrors.count;
				ASTNode functionNode = generateFunctionAST(tokens, i);
				// check if error free
				if (compileErrors.count > errorCount){
					// error
					break;
				}else{
					scriptNode.addSubNode(functionNode);
				}
			}
		}
		.destroy(varList);
		return scriptNode;
	}
	private{
		/// contains a list of vars that are available in the block currently being converted
		LinkedList!string varList;
		/// generates AST for a function definition 
		ASTNode generateFunctionAST(TokenList tokens, uinteger index){
			ASTNode functionNode;
			// make sure it's a function
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
				// make sure it's followed by a function-name which is followed by block
				if (index+3 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.Identifier && 
					tokens.tokens[index+2].type == Token.Type.BlockStart){
					// everything's good
					// add name
					functionNode = ASTNode(ASTNode.Type.Function, tokens.tokens[index+1].token, tokens.getTokenLine(index + 1));
					// convert the function body to ASTNodes using generateBlockAST
					functionNode.addSubNode(generateBlockAST(tokens, index+2).getSubNodes);
				}else{
					// not followed by a block of code and/or followed by EOF
					compileErrors.append(CompileError(tokens.getTokenLine(index), "function definition incomplete"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a function definition"));
			}
			return functionNode;
		}
		
		ASTNode generateBlockAST(TokenList tokens, uinteger index){
			ASTNode blockNode;
			// make sure it's a block
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				uinteger brackEnd = tokens.bracketPos(index);
				if (brackEnd >= 0){
					// everything's good
					// use generateStatementsAST to generateAST for statements
					blockNode.addSubNode(generateStatementsAST(tokens, index, brackEnd-1));
				}else{
					// an error that should have been killed in tokengen escaped here :(
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a block"));
			}
			return blockNode;
		}
		
		ASTNode[] generateStatementsAST(TokenList tokens, uinteger index, uinteger endIndex){
			enum StatementType{
				FunctionCall,
				IfWhile,
				Assignment,
				VarDeclare,
				NoValidType
			}
			StatementType getStatementType(TokenList tokens, uinteger index, uinteger endIndex){
				// check if its a function call, or if/while
				if (tokens.tokens.length-index >= 3 && tokens.tokens[index].type == Token.Type.Identifier && 
					tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					return StatementType.FunctionCall;
				}else if (tokens.tokens[index].type == Token.Type.Keyword){
					if (tokens.tokens[index].token == "if" || tokens.tokens[index].token == "while"){
						return StatementType.IfWhile;
					}else if (tokens.tokens[index].token == "var"){
						return StatementType.VarDeclare;
					}
				}else{
					// go through and check if it's an assignment
					for (uinteger i = index; i <= endIndex; i ++){
						if (tokens.tokens[i].type != Token.Type.Identifier){
							if (tokens.tokens[i].type == Token.Type.IndexBracketOpen){
								// is a valid statement till now
								i = tokens.bracketPos(i);
								if (i >= 0){
									// brackets are ok, check if is an assignment statement
									if (i < endIndex && tokens.tokens[i+1].type == Token.Type.Operator && 
										tokens.tokens[i+1].token == "="){
										return StatementType.Assignment;
									}else{
										compileErrors.append(CompileError(tokens.getTokenLine(i), "not an assignment statement"));
									}
								}
							}else{
								compileErrors.append(CompileError(tokens.getTokenLine(i), "not an assignment statement"));
							}
						}else{
							compileErrors.append(CompileError(tokens.getTokenLine(i), "not an assignment statement"));
						}
					}
				}
				return StatementType.NoValidType;
			}
			
			
			ASTNode[] statementNodes;
			LinkedList!ASTNode nodeList = new LinkedList!ASTNode;
			// separate statements
			for (uinteger i = index, readFrom = index; i <= endIndex; i ++){
				if (tokens.tokens[i].type == Token.Type.StatementEnd && readFrom < i){
					StatementType type = getStatementType(tokens, readFrom, i);
					if (type == StatementType.NoValidType){
						break;
					}else{
						//TODO act accordingly to the statement type
					}
				}else if (tokens.tokens[i].type == Token.Type.BlockStart){
					// add it
					nodeList.append(generateBlockAST(tokens, i));
					// skip the block's body
					i = tokens.bracketPos(i);
					if (i == -1){
						break;
					}
				}
			}
			statementNodes = nodeList.toArray;
			.destroy(nodeList);
			return statementNodes;
		}
		
		ASTNode generateFunctionCallAST(TokenList tokens, uinteger index, uinteger endIndex){
			// check if is function call
			if (tokens.tokens[index].type == Token.Type.Identifier && tokens.tokens[index + 1].type == Token.Type.ParanthesesOpen){
				// check if bracket is closed and there's a semicolon
				uinteger brackEnd = tokens.bracketPos(index + 1);
				if (brackEnd >= 0 && brackEnd+1 <= endIndex && tokens.tokens[brackEnd+1].type == Token.Type.StatementEnd){
					ASTNode functionCallNode = ASTNode(ASTNode.Type.FunctionCall, tokens.tokens[index].token, tokens.getTokenLine(index));
					functionCallNode.addSubNode(generateCodeAST(tokens, index+1, brackEnd-1));
					
					return functionCallNode;
				}
			}
			return ASTNode(ASTNode.Type.FunctionCall, 0);
		}
		
		/// generates AST for "actual code" like `2 + 2 - 6`.
		ASTNode generateCodeAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode r;
			ASTNode lastNode;
			bool separatorExpected = false;
			for (uinteger i = index; i <= endIndex; i ++){
				Token token = tokens.tokens[i];
				//TODO continue from here
				if (token.type == Token.Type.Identifier){
					// check if a "separator" like operator or something was expected
					if (separatorExpected){
						// bad syntax
						compileErrors.append(CompileError(tokens.getTokenLine(i), "unexpected token"));
					}else // check if it's a function-call
					if (i < endIndex && tokens.tokens[i+1].type == Token.Type.ParanthesesOpen){
						integer brackEnd = tokens.bracketPos(i+1);
						if (brackEnd >= 0){
							lastNode = generateFunctionCallAST(tokens, i, brackEnd);
						}
					}else{
						// just a var, make sure that the var was defined
						if (varList.hasElement(token.token)){
							// OK
							lastNode = ASTNode(ASTNode.Type.Variable, token.token, tokens.getTokenLine(i));
						}else{
							// var was not declared
							compileErrors.append(CompileError(tokens.getTokenLine(i), "variable '"~token.token~"' not declared"));
						}
					}
					separatorExpected = true;
				}else if (token.type == Token.Typ)
			}
			return r;
		}

		/// generates AST for a variable (or array) and changes value of index to the token aft
		ASTNode generateVariableAST(TokenList tokens, ref uinteger index){
			ASTNode var;
			// check if index is specified
			if (index + 1 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.IndexBracketOpen){
				// has an index
				uinteger brackEnd = tokens.bracketPos(index+1);
				if (brackEnd >= 0){
					// look if there are 1+ indexes

				}
			}
		}
	}
}