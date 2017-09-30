module qscript.compiler.astgen;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

/// contains functions and stuff to convert a QScript from tokens to Syntax Trees
struct ASTGen{
	/// generates an AST representing a script.
	/// 
	/// The script must be converted to tokens using `qscript.compiler.tokengen.toTokens`
	/// If any errors occur, they will be contanied in `qscript.compiler.misc.`
	static public ScriptNode generateScriptAST(TokenList tokens){
		ScriptNode scriptNode;
		LinkedList!FunctionNode functions = new LinkedList!FunctionNode;
		// go through the script, compile function nodes, link them to this node
		for (uinteger i = 0, lastIndex = tokens.tokens.length - 1; i < tokens.tokens.length; i ++){
			// look for TokenType.Keyword where token.token == "function"
			if (tokens.tokens[i].type == Token.Type.Keyword && tokens.tokens[i].token == "function"){
				uinteger errorCount = compileErrors.count;
				FunctionNode functionNode = generateFunctionAST(tokens, i);
				i --;
				// check if error free
				if (compileErrors.count == errorCount){
					functions.append(functionNode);
				}
			}
		}
		scriptNode = ScriptNode(functions.toArray);
		.destroy(functions);
		return scriptNode;
	}
	static private{
		/// reads a type from TokensList
		/// 
		/// returns type in DataType struct, changes `index` to token after last token of type
		DataType readType(TokenList tokens, ref uinteger index){
			uinteger startIndex = index;
			for (; index < tokens.tokens.length; index ++){
				if (tokens.tokens[index].type != Token.Type.IndexBracketOpen &&
					tokens.tokens[index].type != Token.Type.IndexBracketClose){
					break;
				}
			}
			string sType = tokens.toString(tokens.tokens[startIndex .. index]);
			return DataType(sType);
		}
		/// generates AST for a function definition 
		/// 
		/// changes `index` to the token after function definition
		FunctionNode generateFunctionAST(TokenList tokens, ref uinteger index){
			FunctionNode functionNode;
			BlockNode fBody;
			DataType returnType;
			LinkedList!(FunctionNode.Argument) args = new LinkedList!(FunctionNode.Argument);
			string fName;
			// make sure it's a function
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
				// read the type
				index++;
				returnType = readType(tokens, index);
				// above functionCall moves index to fName
				// now index is at function name
				fName = tokens.tokens[index].token;
				index ++;
				// now for the argument types, and the functionBody
				if (tokens.tokens[index].type == Token.Type.BlockStart){
					// no args, just body
					fBody = generateBlockAST(tokens, index);
				}else{
					/// TODO add code to read arguments + types
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a function definition"));
			}
			return functionNode;
		}
		
		/// generates AST for a {block-of-code}
		/// 
		/// changes `index` to token after block end
		BlockNode generateBlockAST(TokenList tokens, ref uinteger index){
			BlockNode blockNode;
			// make sure it's a block
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				uinteger brackEnd = tokens.tokens.bracketPos!(true)(index);
				blockNode = BlockNode(generateStatementsAST(tokens, index+1, brackEnd-1));
				index = brackEnd+1;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a block"));
			}
			return blockNode;
		}
		
		/// generates ASTs for statements in a block
		StatementNode[] generateStatementsAST(TokenList tokens, uinteger index, uinteger endIndex){
			enum StatementType{
				FunctionCall,
				If,
				While,
				Assignment,
				VarDeclare,
				NoValidType
			}
			StatementType getStatementType(TokenList tokens, uinteger index){
				// check if its a function call, or if/while
				if (tokens.tokens[index].type == Token.Type.Keyword){
					if (tokens.tokens[index].token == "if"){
						return StatementType.If;
					}else if (tokens.tokens[index].token == "while"){
						return StatementType.While;
					}
				}else if (tokens.tokens[index].type == Token.Type.DataType){
					return StatementType.VarDeclare;
				}else if (index+3 <= endIndex && tokens.tokens[index].type == Token.Type.Identifier && 
					tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					return StatementType.FunctionCall;
				}else{
					// check if first token is var
					if (tokens.tokens[index].type == Token.Type.Identifier){
						return StatementType.Assignment;
					}
				}
				return StatementType.NoValidType;
			}

			LinkedList!StatementNode nodeList = new LinkedList!StatementNode;
			// separate statements
			for (uinteger i = index, readFrom = index; i <= endIndex; i ++){
				// get the type
				StatementType currentType = getStatementType(tokens, i);
				// match the type, call the appropriate function
				if (currentType == StatementType.Assignment){
					nodeList.append(
						StatementNode(generateAssignmentAST(tokens, i))
						);
				}else if (currentType == StatementType.FunctionCall){
					nodeList.append(
						StatementNode(generateFunctionCallAST(tokens, i))
						);
				}else if (currentType == StatementType.If){
					nodeList.append(
						StatementNode(generateIfAST(tokens, i))
						);
				}else if (currentType == StatementType.VarDeclare){
					nodeList.append(
						StatementNode(generateVarDeclareAST(tokens, i))
						);
				}else if (currentType == StatementType.While){
					nodeList.append(
						StatementNode(generateWhileAST(tokens, i))
						);
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(i), "invalid statement"));
					break;
				}
				i--;
			}
			StatementNode[] statementNodes = nodeList.toArray;
			.destroy(nodeList);
			return statementNodes;
		}

		/// generates AST for function call, changes `index` to token after statementEnd
		FunctionCallNode generateFunctionCallAST(TokenList tokens, ref uinteger index){
			FunctionCallNode functionCallNode;
			// check if is function call
			if (tokens.tokens[index].type == Token.Type.Identifier &&
				tokens.tokens[index + 1].type == Token.Type.ParanthesesOpen){
				uinteger brackEnd = tokens.tokens.bracketPos(index + 1);
				// now for the arguments
				LinkedList!CodeNode args = new LinkedList!CodeNode;
				for (index = index+2; ; index ++){
					args.append(generateCodeAST(tokens, index));
					if (tokens.tokens[index].type == Token.Type.ParanthesesClose){
						break;
					}
				}
				functionCallNode = FunctionCallNode(tokens.tokens[index].token, args.toArray);
				.destroy(args);
				
				return functionCallNode;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid function call"));
			}
			return functionCallNode;
		}
		
		/// generates AST for "actual code" like `2 + 2 - 6`.
		/// 
		/// terminates reading when on a Token that is comma, paranthesesEnd, semicolon, index/block bracket close
		CodeNode generateCodeAST(TokenList tokens, ref uinteger index){
			CodeNode lastNode;
			bool separatorExpected = false;
			for (uinteger i = index; ; i ++){
				Token token = tokens.tokens[i];
				// check if has to terminate
				if ([Token.Type.Comma, Token.Type.IndexBracketClose, Token.Type.BlockEnd, Token.Type.ParanthesesClose,
					Token.Type.StatementEnd].hasElement(token.type)){
					break;
				}
				if (!separatorExpected){
					// an identifier, or literal (i.e some data) was expected
					lastNode = CodeNode(generateNodeAST(tokens, i));
					i --;
					separatorExpected = true;
				}else{
					// an operator or something that deals with data was expected
					if (token.type == Token.Type.Operator){
						lastNode = CodeNode(generateOperatorAST(tokens, lastNode, i));
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
		OperatorNode generateOperatorAST(TokenList tokens, CodeNode firstOperand, ref uinteger index){
			OperatorNode operator;
			// make sure it's an operator, and there is a second operand
			if (tokens.tokens[index].type == Token.Type.Operator && index+1 < tokens.tokens.length){
				// read the next operand
				CodeNode secondOperand;
				uinteger i = index + 1;
				secondOperand = CodeNode(generateNodeAST(tokens, i));
				index = i;
				// put both operands under one node
				operator = OperatorNode(tokens.tokens[index].token, firstOperand, secondOperand);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "no second operand found"));
			}
			return operator;
		}
		
		/// generates AST for a variable (or array) and changes value of index to the token after variable ends
		VariableNode generateVariableAST(TokenList tokens, ref uinteger index){
			VariableNode var;
			// make sure first token is identifier
			if (tokens.tokens[index].type == Token.Type.Identifier){
				// set var name
				var.varName = tokens.tokens[index].token;
				index ++;
				// check if indexes are specified, case yes, add em
				if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
					LinkedList!CodeNode indexes = new LinkedList!CodeNode;
					for (index = index; index < tokens.tokens.length; index ++){
						if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
							index++;
							indexes.append(generateCodeAST(tokens, index));
						}else{
							break;
						}
					}
					var.indexes = indexes.toArray;
					.destroy(indexes);
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a variable"));
			}
			return var;
		}
		
		/// generates AST for assignment operator
		AssignmentNode generateAssignmentAST(TokenList tokens, ref uinteger index){
			AssignmentNode assignment;
			// get the variable to assign to
			VariableNode var = generateVariableAST(tokens, index);
			// now at index, the token should be a `=` operator
			if (tokens.tokens[index].type == Token.Type.Operator && tokens.tokens[index].token == "="){
				// everything's ok till the `=` operator
				index++;
				CodeNode val = generateCodeAST(tokens, index);
				assignment = AssignmentNode(var, val);
				// make sure it's followed by a semicolon
				if (tokens.tokens[index].type != Token.Type.StatementEnd){
					compileErrors.append(CompileError(tokens.getTokenLine(index),
							"assingment statement not followed by semicolon"));
				}else{
					// skip the semicolon too
					index++;
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not an assignment statement"));
			}
			return assignment;
		}
		
		/// generates AST for variable declarations
		VarDeclareNode generateVarDeclareAST(TokenList tokens, ref uinteger index){
			VarDeclareNode varDeclare;
			// make sure it's a var declaration, and the vars are enclosed in parantheses
			if (DATA_TYPES.hasElement(tokens.tokens[index].token)){
				// read the type
				DataType type = readType(tokens, index);
				// make sure next token = bracket
				if (tokens.tokens[index].type == Token.Type.ParanthesesOpen){
					// now go through all vars, check if they are vars, and are aeparated by comma
					uinteger brackEnd = tokens.tokens.bracketPos!true(index);
					bool commaExpected = false;
					LinkedList!string vars = new LinkedList!string;
					for (index = index+1; index < brackEnd; index ++){
						Token token = tokens.tokens[index];
						if (commaExpected){
							if (token.type != Token.Type.Comma){
								compileErrors.append(CompileError(tokens.getTokenLine(index),
										"variable names in declaration must be separated by a comma"));
							}
							commaExpected = false;
						}else{
							if (token.type != Token.Type.Identifier){
								compileErrors.append(CompileError(tokens.getTokenLine(index),
										"variable name expected in varaible declaration, unexpected token found"));
							}else{
								vars.append(token.token);
							}
							commaExpected = true;
						}
					}
					varDeclare = VarDeclareNode(type, vars.toArray);
					.destroy(vars);
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
			}
			return varDeclare;
		}
		
		/// generates AST for if statements
		IfNode generateIfAST(TokenList tokens, uinteger index, uinteger endIndex){
			IfNode ifNode;
			// check if is an if
			if (index+3 < endIndex && tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "if" &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos(index+1);
				ifNode.condition = generateCodeAST(tokens, index+2, brackEnd-1);
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

		/// generates AST for while statements
		WhileNode generateWhileAST(TokenList tokens, uinteger index){
			WhileNode whileNode;
			// check if is an if
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "while" &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				index += 2;
				whileNode.condition = generateCodeAST(tokens, index);
				// make sure condition's followed by a block

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