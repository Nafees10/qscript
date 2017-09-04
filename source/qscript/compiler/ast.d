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
		VarDeclare, /// For variable declaration
		Variable, /// variable name
		Arguments, /// stores arguments for a function
		ArrayIndex, /// Stores index for an array, in an `ASTNode`
		StaticArray, /// For storing elements of a static array, i.e: `[x, y, z]`
	}
	
	private{
		/// Stores type of this Node. It's private so as to keep it unchanged after constructor
		Type nodeType;
		string nodeData; /// For storing data for some nodes, like functionName for `Type.Function`
		
		uinteger ln; /// Stores the line number on which the node is - for error reporting
	}
	public ASTNode[] subNodes; /// This is used for .. example: in a function body to store statements like FunctionCall...
	
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
	/// for `Type.VarDeclare` it is the data type of the vars, in the format: `%type%[n]` where `n` is the number of nested arrays. For `int[][]`, it will be: `int[2]`
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
	/// for `Type.VarDeclare` it is the data type of the vars, in the format: `%type%[n]` where `n` is the number of nested arrays. For `int[][]`, it will be: `int[2]`
	@property string data(){
		return nodeData.dup;
	}
	/// returns the type of the node
	@property Type type(){
		return nodeType;
	}
	/// returns the line number this node was on
	@property uinteger lineno(){
		return ln;
	}
	/// returns all subNodes that match the given type
	ASTNode[] readSubNodes(ASTNode.Type matchType){
		LinkedList!ASTNode r = new LinkedList!ASTNode;
		foreach (subNode; subNodes){
			if (subNode.type == matchType){
				r.append(subNode);
			}
		}
		ASTNode[] resArray = r.toArray;
		.destroy(r);
		return resArray;
	}
	/// returns the index of the first subNode that matches with the given type, -1 if not found
	integer readSubNode(ASTNode.Type matchType){
		foreach (i, subNode; subNodes){
			if (subNode.type == matchType){
				return i;
			}
		}
		return -1;
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
	static public ASTNode generateAST(TokenList tokens){
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
	static private{
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
					functionNode.addSubNode(generateBlockAST(tokens, index+2));
				}else{
					// not followed by a block of code and/or followed by EOF
					compileErrors.append(CompileError(tokens.getTokenLine(index), "function definition incomplete"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a function definition"));
			}
			return functionNode;
		}
		
		/// generates AST for a {block-of-code}
		ASTNode generateBlockAST(TokenList tokens, uinteger index){
			ASTNode blockNode = ASTNode(ASTNode.Type.Block, tokens.getTokenLine(index));
			// make sure it's a block
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				uinteger brackEnd = tokens.tokens.bracketPos!(true)(index);
				blockNode.addSubNode(generateStatementsAST(tokens, index+1, brackEnd-1));
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a block"));
			}
			return blockNode;
		}
		
		/// generates ASTs for statements in a block
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
				if (tokens.tokens[index].type == Token.Type.Keyword){
					if (tokens.tokens[index].token == "if" || tokens.tokens[index].token == "while"){
						return StatementType.IfWhile;
					}else if (tokens.tokens[index].token == "int" || tokens.tokens[index].token == "double" ||
						tokens.tokens[index].token == "string"){
						return StatementType.VarDeclare;
					}
				}else if (index+3 <= endIndex && tokens.tokens[index].type == Token.Type.Identifier && 
					tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					return StatementType.FunctionCall;
				}else{
					// check if first token is var
					if (tokens.tokens[index].type == Token.Type.Identifier){
						// index brackets are expected
						uinteger i;
						for (i = index+1; i < endIndex; i ++){
							if (tokens.tokens[i].type == Token.Type.IndexBracketOpen){
								i = tokens.tokens.bracketPos(i);
							}else{
								break;
							}
						}
						// if it reached here, it means previous checks passed, now to see if there's an `=` token or not
						if (tokens.tokens[i].type == Token.Type.Operator && tokens.tokens[i].token == "="){
							return StatementType.Assignment;
						}
					}
				}
				return StatementType.NoValidType;
			}
			
			
			ASTNode[] statementNodes;
			LinkedList!ASTNode nodeList = new LinkedList!ASTNode;
			// separate statements
			for (uinteger i = index, readFrom = index; i <= endIndex; i ++){
				// check if is a block for if/while, then skip
				if (tokens.tokens[i].type == Token.Type.Keyword){
					if (tokens.tokens[i].token == "if" || tokens.tokens[i].token == "while"){
						// make sure its followed by a paranthese, then by a brace, and then skip that brace
						if (tokens.tokens[i+1].type == Token.Type.ParanthesesOpen){
							i = tokens.tokens.bracketPos(i+1)+1;
							// then skip the brace
							if (tokens.tokens[i].type == Token.Type.BlockStart){
								i = tokens.tokens.bracketPos(i);
							}else{
								compileErrors.append(CompileError(tokens.getTokenLine(i),
										"if/while statement not followed by a block"));
							}
						}else{
							compileErrors.append(CompileError(tokens.getTokenLine(i),
									"if/while statement not complete"));
						}
					}
				}
				if (tokens.tokens[i].type == Token.Type.StatementEnd && readFrom < i){
					StatementType type = getStatementType(tokens, readFrom, i);
					if (type == StatementType.NoValidType){
						compileErrors.append(CompileError(tokens.getTokenLine(readFrom), "invalid statement"));
						break;
					}else if (type == StatementType.Assignment){
						nodeList.append(generateAssignmentAST(tokens, readFrom, i-1));
					}else if (type == StatementType.FunctionCall){
						nodeList.append(generateFunctionCallAST(tokens, readFrom, i-1));
					}else if (type == StatementType.VarDeclare){
						nodeList.append(generateVarDeclareAST(tokens, readFrom, i-1));
					}else if (type == StatementType.IfWhile){
						nodeList.append(generateIfWhileAST(tokens, readFrom, i));
					}
					readFrom = i+1;
				}else if (tokens.tokens[i].type == Token.Type.BlockStart && readFrom < i){
					// add it
					nodeList.append(generateBlockAST(tokens, i));
					// skip the block's body
					i = tokens.tokens.bracketPos(i);
					readFrom = i+1;
				}
			}
			statementNodes = nodeList.toArray;
			.destroy(nodeList);
			return statementNodes;
		}
		
		ASTNode generateFunctionCallAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode functionCallNode;
			// check if is function call
			if (tokens.tokens[index].type == Token.Type.Identifier && tokens.tokens[index + 1].type == Token.Type.ParanthesesOpen){
				// check if there's a bracket
				uinteger brackEnd = tokens.tokens.bracketPos(index + 1);
				if (brackEnd <= endIndex){
					functionCallNode = ASTNode(ASTNode.Type.FunctionCall,
						tokens.tokens[index].token, 
						tokens.getTokenLine(index));

					ASTNode args = ASTNode(ASTNode.Type.Arguments, tokens.getTokenLine(index));

					// now for the arguments
					bool hasArgs = false;
					for (uinteger i = index+2, readFrom = index+2; i <= endIndex; i ++){
						Token token = tokens.tokens[i];
						if ([Token.Type.ParanthesesOpen, Token.Type.IndexBracketOpen, Token.Type.BlockStart].
							hasElement(token.type)){
							//skip to end of that bracket
							i = tokens.tokens.bracketPos(i);
						}
						if (readFrom < i && (token.type == Token.Type.Comma || token.type == Token.Type.ParanthesesClose)){
							ASTNode arg = generateCodeAST(tokens, readFrom, i-1);
							args.addSubNode(arg);
							readFrom = i+1;
							hasArgs = true;
						}
					}

					if (hasArgs){
						functionCallNode.addSubNode(args);
					}
					
					return functionCallNode;
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid function call"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid function call"));
			}
			return functionCallNode;
		}
		
		/// generates AST for "actual code" like `2 + 2 - 6`.
		ASTNode generateCodeAST(TokenList tokens, uinteger index, uinteger endIndex){
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
			return lastNode;
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
				if (BOOL_OPERATORS.hasElement(tokens.tokens[index].token)){
					// look where the operand is ending
					uinteger i;
					for (i = index + 1; i < tokens.tokens.length; i ++){
						Token token = tokens.tokens[i];
						if ([Token.Type.ParanthesesOpen, Token.Type.IndexBracketOpen, Token.Type.BlockStart].
							hasElement(token.type)){
							//skip to end of that bracket
							i = tokens.tokens.bracketPos(i);
						}
						if ([Token.Type.Comma, Token.Type.ParanthesesClose, Token.Type.StatementEnd].hasElement(token.type)){
							break;
						}
					}
					secondOperand = generateCodeAST(tokens, index + 1, i-1);
					index = i;
				}else{
					uinteger i = index + 1;
					secondOperand = generateNodeAST(tokens, i);
					index = i;
				}
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
				if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
					for (index = index; index < tokens.tokens.length; index ++){
						if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
							// add it
							ASTNode indexNode = ASTNode(ASTNode.Type.ArrayIndex, tokens.getTokenLine(index));
							uinteger brackEnd = tokens.tokens.bracketPos!true(index);
							var.addSubNode(indexNode);
						}else{
							break;
						}
					}
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a variable"));
			}
			return var;
		}
		
		/// generates AST for assignment operator
		ASTNode generateAssignmentAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode assignment;
			// get the variable to assign to
			ASTNode var = generateVariableAST(tokens, index);
			// now at index, the token should be a `=` operator
			if (tokens.tokens[index].type == Token.Type.Operator && tokens.tokens[index].token == "="){
				// everything's ok till the `=` operator
				ASTNode val = generateCodeAST(tokens, index+1, endIndex);
				assignment = ASTNode(ASTNode.Type.Assign, tokens.getTokenLine(index));
				assignment.addSubNode([var, val]);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not an assignment statement"));
			}
			return assignment;
		}
		
		/// generates AST for variable declarations
		/// TODO adapt this to the changes above
		ASTNode generateVarDeclareAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode varDeclare = ASTNode(ASTNode.Type.VarDeclare, tokens.getTokenLine(index));
			// make sure it's a var declaration, and the vars are enclosed in parantheses
			if (tokens.tokens[index].type == Token.Type.Keyword && 
				["int", "double", "string"].hasElement(tokens.tokens[index].token) &&
				index+1 < endIndex && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// read the type
				uinteger i;
				{
					char[] type = cast(char[])tokens.tokens[index].token;
					uinteger nestCount = 0;
					for (i = index+1; i <= endIndex; i ++){
						if (tokens.tokens[i].type == Token.Type.ParanthesesOpen){
							break;
						}else if (tokens.tokens[i].type == Token.Type.IndexBracketOpen){
							nestCount ++;
							i ++;
							if (i + 1 <= endIndex && tokens.tokens[i+1].type != Token.Type.IndexBracketClose){
								compileErrors.append(CompileError(tokens.getTokenLine(i+1), "invalid type"));
								break;
							}
						}else{
							compileErrors.append(CompileError(tokens.getTokenLine(i), "unexpected token"));
						}
					}
					varDeclare = ASTNode(ASTNode.Type.VarDeclare,
						cast(string)type~'['~to!string(nestCount)~']', tokens.getTokenLine(index));
				}
				// check if brackEnd == endIndex
				if (tokens.tokens.bracketPos(i) == endIndex){
					// now go through all vars, check if they are vars, and are aeparated by comma
					bool commaExpected = false;
					for (i = i+1; i < endIndex; i ++){
						Token token = tokens.tokens[i];
						if (commaExpected){
							if (token.type != Token.Type.Comma){
								compileErrors.append(CompileError(tokens.getTokenLine(i),
										"variable names in declaration must be separated by a comma"));
							}
							commaExpected = false;
						}else{
							if (token.type != Token.Type.Identifier){
								compileErrors.append(CompileError(tokens.getTokenLine(i),
										"variable name expected in varaible declaration, unexpected token found"));
							}else{
								ASTNode var = ASTNode(ASTNode.Type.Variable, token.token, tokens.getTokenLine(i));
								varDeclare.addSubNode(var);
							}
							commaExpected = true;
						}
					}
				}
				
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
			}
			return varDeclare;
		}
		
		/// generates AST for if/while statements
		ASTNode generateIfWhileAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode ifWhile;
			if (tokens.tokens[index].token == "while"){
				ifWhile = ASTNode(ASTNode.Type.WhileStatement, tokens.getTokenLine(index));
			}else if (tokens.tokens[index].token == "if"){
				ifWhile = ASTNode(ASTNode.Type.IfStatement, tokens.getTokenLine(index));
			}
			// check if is an if/while
			if (index+3 < endIndex && tokens.tokens[index].type == Token.Type.Keyword &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos(index+1);
				ASTNode condition = generateCodeAST(tokens, index+2, brackEnd-1);
				ifWhile.addSubNode(condition);
				// make sure there's a block at the end of the condition
				if (brackEnd+1 < endIndex && tokens.tokens[brackEnd+1].type == Token.Type.BlockStart){
					ASTNode block = generateBlockAST(tokens, brackEnd+1);
					ifWhile.addSubNode(block);
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(brackEnd+1), "if/while statement not followed by a block"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
			}
			return ifWhile;
		}

		/// generates AST for static arrays: like: `[x, y, z]`
		ASTNode generateStaticArrayAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode array;
			// check if is a static array
			if (tokens.tokens[index].type == Token.Type.IndexBracketOpen &&
				tokens.tokens.bracketPos(index) == endIndex){
				// init the node
				array = ASTNode(ASTNode.Type.StaticArray, tokens.getTokenLine(index));
				// add each element using `generateNodeAST`
				bool commaExpected = false;
				for (uinteger i = index+1; i < endIndex; i ++){
					if (commaExpected){
						if (tokens.tokens[i].type != Token.Type.Comma){
							compileErrors.append(CompileError(tokens.getTokenLine(i),
									"elements in static arrays must be separated by a comma"));
						}
						commaExpected = false;
					}else{
						ASTNode element = generateNodeAST(tokens, i);
						i --;
						commaExpected = true;
						array.addSubNode(element);
					}
				}
			}
			return array;
		}
		
		/// returns a node representing either of the following:
		/// 
		/// 1. String literal
		/// 2. Number literal
		/// 3. Function Call (uses `generateFunctionCallAST`)
		/// 4. Variable (uses `generateVariableAST`)
		/// 5. Some code inside parantheses (uses `generateCodeAST`)
		/// 6. A static array (`[x, y, z]`)
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
				
			}else if (token.type == Token.Type.IndexBracketOpen){
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				node = generateStaticArrayAST(tokens, index, brackEnd);
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