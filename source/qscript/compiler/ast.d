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
		return scriptNode;
	}
	private{
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
				uinteger brackEnd = tokens.tokens.bracketPos!(true)(index);
				blockNode.addSubNode(generateStatementsAST(tokens, index+1, brackEnd-1));
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
					// TODO implement a check to see if it's an asignment statement
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
					}else if (type == StatementType.Assignment){
						// TODO implement a function to generate AST for assignment
					}else if (type == StatementType.FunctionCall){

					}
				}else if (tokens.tokens[i].type == Token.Type.BlockStart){
					// add it
					nodeList.append(generateBlockAST(tokens, i));
					// skip the block's body
					i = tokens.tokens.bracketPos(i);
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
				uinteger brackEnd = tokens.tokens.bracketPos(index + 1);
				if (brackEnd+1 <= endIndex && tokens.tokens[brackEnd+1].type == Token.Type.StatementEnd){
					ASTNode functionCallNode = ASTNode(ASTNode.Type.FunctionCall,
						tokens.tokens[index].token, 
						tokens.getTokenLine(index));

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
				if (!separatorExpected){
					// an identifier, or literal (i.e some data) was expected
					lastNode = generateNodeAST(tokens, i);
					separatorExpected = true;
					i --;
				}else{
					// an operator or something that deals with data was expected
					if (token.type == Token.Type.Operator){
						lastNode = generateOperatorAST(tokens, lastNode, i);
						i --;
					}else{
						compileErrors.append(CompileError(tokens.getTokenLine(i), "unexpected token"));
					}
				}
			}
			return r;
		}

		/// generates AST for operators like +, -...
		/// 
		/// `firstOperand` is the first operand for the operator.
		/// `index` is the index of the token which is the operator
		/// 
		/// changes `index` to the index of the token after the last token related to the operator
		ASTNode generateOperatorAST(TokenList tokens, ASTNode firstOperand, ref uinteger index){
			ASTNode operator = ASTNode(ASTNode.Type.Operator, tokens.tokens[index].token, tokens.getTokenLine(index));
			// make sure it's an operator, and there is a second operand
			if (tokens.tokens[index].type == Token.Type.Operator && index+1 < tokens.tokens.length){
				// read the next operand
				ASTNode secondOperand;
				uinteger i = index + 1;
				secondOperand = generateNodeAST(tokens, i);
				index = i;
				// put both operands under one node
				operator.addSubNode([firstOperand, secondOperand]);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "no second operand found"));
			}
			return operator;
		}

		/// generates AST for a variable (or array) and changes value of index to the token after variable ends
		ASTNode generateVariableAST(TokenList tokens, ref uinteger index){
			ASTNode var;
			// make sure first token is identifier
			if (tokens.tokens[index].type == Token.Type.Identifier){
				// set var name
				var = ASTNode(ASTNode.Type.Variable, tokens.tokens[index].token, tokens.getTokenLine(index));
				index ++;
				// check if indexes are specified, case yes, add em
				for (index = index+1; index < tokens.tokens.length; index ++){
					if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
						// add it
						ASTNode indexNode = ASTNode(ASTNode.Type.ArrayIndex, tokens.getTokenLine(index));
						uinteger brackEnd = tokens.tokens.bracketPos!true(index);
						var.addSubNode(indexNode);
					}else{
						break;
					}
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a variable"));
			}
			return var;
		}

		/// returns a node representing either of the following:
		/// 
		/// 1. String literal
		/// 2. Number literal
		/// 3. Function Call (uses `generateFunctionCallAST`)
		/// 4. Variable (uses `generateVariableAST`)
		/// 5. Some code inside parantheses (uses `generateCodeAST`)
		/// 
		/// This function is used by `generateCodeAST` to separate nodes, and by `generateOperatorAST` to read operands
		ASTNode generateNodeAST(TokenList tokens, ref uinteger index){
			Token token = tokens.tokens[index];
			ASTNode node;
			// an identifier, or literal (i.e some data) was expected
			if (token.type == Token.Type.Identifier){
				if (index+1 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					uinteger brackEnd = tokens.tokens.bracketPos(index+1);
					node = generateFunctionCallAST(tokens, index, brackEnd);
					index = brackEnd+1;
				}else{
					// just a var
					node = generateVariableAST(tokens, index);
				}
				
			}else if (token.type == Token.Type.ParanthesesOpen){
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				node = generateCodeAST(tokens, index+1, brackEnd-1);
				index = brackEnd+1;

			}else if (token.type == Token.Type.Number){
				node = ASTNode(ASTNode.Type.NumberLiteral, token.token, tokens.getTokenLine(index));
				index ++;
			}else if (token.type == Token.Type.String){
				node = ASTNode(ASTNode.Type.StringLiteral, token.token, tokens.getTokenLine(index));
				index ++;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "unexpected token"));
			}
			return node;
		}


	}
}