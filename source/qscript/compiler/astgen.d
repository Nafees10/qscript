module qscript.compiler.astgen;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

/// contains functions and stuff to convert a QScript from tokens to Syntax Trees
struct ASTGen{
	/// constructor
	/// 
	/// `functionReturnDataTypes` in assoc_array containing data types of pre-defined functions
	this (DataType[string] functionReturnDataTypes){
		functionReturnTypes = functionReturnDataTypes.dup;
	}
	/// generates an AST representing a script.
	/// 
	/// The script must be converted to tokens using `qscript.compiler.tokengen.toTokens`
	/// If any errors occur, they will be contanied in `qscript.compiler.misc.`
	public ScriptNode generateScriptAST(TokenList tokens){
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
	private{
		/// stores functions' return types
		DataType[string] functionReturnTypes;
		/// stores data types for variable in currently-being-converted function
		DataType[string] varDataTypes;
		/// returns return type of a function, if function doesnt exist, throws Exception
		DataType getFunctionReturnType(string functionName, TokenList tokens){
			static bool scannedAllTokens = false;
			// check if already known
			if (functionName in functionReturnTypes){
				// return this one
				return functionReturnTypes[functionName];
			}else if (!scannedAllTokens){
				// scan all the tokens for this function tokens
				for (uinteger i = 0; i < tokens.tokens.length; i ++){
					if (tokens.tokens[i].type == Token.Type.Keyword && tokens.tokens[i].token == "function"){
						// ok, check if it's this one
						// first, read it's type, then see if this is the one we want
						DataType type = readType(tokens, i);
						functionReturnTypes[tokens.tokens[i].token] == type;
					}
					// skip brackets
					if ([Token.Type.BlockStart, Token.Type.IndexBracketOpen, Token.Type.ParanthesesOpen]){
						i = tokens.tokens.bracketPos(i);
					}
				}
				// now all the tokens have been scanned for functions, no more functions
				scannedAllTokens = true;
				return getFunctionReturnType(functionName);
			}else{
				throw new Exception("function "~functionName~" not defined");
			}

		}
		/// reads a type from TokensList
		/// 
		/// returns type in DataType struct, changes `index` to token after last token of type
		static DataType readType(TokenList tokens, ref uinteger index){
			uinteger startIndex = index;
			for (; index < tokens.tokens.length; index ++){
				if (tokens.tokens[index].type != Token.Type.IndexBracketOpen &&
					tokens.tokens[index].type != Token.Type.IndexBracketClose){
					break;
				}
			}
			string sType = tokens.toString(tokens.tokens[startIndex .. index]);
			DataType r;
			try{
				r = DataType(sType);
			}catch(Exception e){
				compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
			}
			return r;
		}
		/// generates AST for a function definition 
		/// 
		/// changes `index` to the token after function definition
		FunctionNode generateFunctionAST(TokenList tokens, ref uinteger index){
			FunctionNode functionNode;
			// make sure it's a function
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
				// read the type
				index++;
				functionNode.returnType = readType(tokens, index);
				// above functionCall moves index to fName
				// now index is at function name
				functionNode.name = tokens.tokens[index].token;
				index ++;
				// now for the argument types
				if (tokens.tokens[index].type == Token.Type.ParanthesesOpen){
					LinkedList!(FunctionNode.Argument) argList = new LinkedList!(FunctionNode.Argument);
					uinteger brackEnd = tokens.tokens.bracketPos(index);
					bool commaExpected = false;
					for (; index < brackEnd; index ++){
						if (commaExpected){
							if (tokens.tokens[index].type == Token.Type.Comma){
								commaExpected = false;
								continue;
							}else{
								compileErrors.append(CompileError(tokens.getTokenLine(index),
										"arguments must be separated using a comma"));
							}
						}else{
							// data type + arg_name expected
							// read the type
							FunctionNode.Argument arg;
							arg.argType = readType(tokens, index);
							// now the arg_name
							arg.argName = tokens.tokens[index].token;
							index++;
							commaExpected = true;
						}
					}
					// put args in list
					functionNode.arguments = argList.toArray;
					.destroy(argList);
				}
				if (tokens.tokens[index].type == Token.Type.BlockStart){
					// no args, just body
					functionNode.bodyBlock = generateBlockAST(tokens, index);
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "function has no body"));
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
				LinkedList!StatementNode statements = new LinkedList!StatementNode;
				// read statements
				while (index < brackEnd){
					statements.append(generateStatementAST(tokens, index));
				}
				// put them all in block
				blockNode.statements = statements.toArray;
				.destroy(statements);
				index = brackEnd+1;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a block"));
			}
			return blockNode;
		}

		/// generates AST for one statement
		StatementNode generateStatementAST(TokenList tokens, ref uinteger index){
			// identify the type, call the appropriate function
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				// block
				return StatementNode(generateBlockAST(tokens, index));
			}else if (tokens.tokens[index].type == Token.Type.Keyword){
				if (tokens.tokens[index].token == "if"){
					// if statement
					return StatementNode(generateIfAST(tokens, index));
				}else if (tokens.tokens[index].token == "while"){
					// while statement
					return StatementNode(generateWhileAST(tokens, index));
				}
			}else if (tokens.tokens[index].type == Token.Type.DataType){
				// var declare
				return StatementNode(generateVarDeclareAST(tokens, index));
			}else if (tokens.tokens[index].type == Token.Type.Identifier &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// is a function call
				return StatementNode(generateFunctionCallAST(tokens, index));
			}else{
				// check if first token is var
				if (tokens.tokens[index].type == Token.Type.Identifier){
					// assignment
					return StatementNode(generateAssignmentAST(tokens, index));
				}
			}
			compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid statement"));
			return StatementNode();
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
					// skip the semicolon
					if (tokens.tokens[brackEnd+1].type == Token.Type.StatementEnd){
						index = brackEnd+2;
					}else{
						compileErrors.append(CompileError(tokens.getTokenLine(brackEnd+1),
									"variable declaration not followed by semicolon"));
					}
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
			}
			return varDeclare;
		}
		
		/// generates AST for if statements
		IfNode generateIfAST(TokenList tokens, ref uinteger index){
			IfNode ifNode;
			// check if is an if
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "if" &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos(index+1);
				index += 2;
				ifNode.condition = generateCodeAST(tokens, index);
				// make sure index & brackEnd are now same
				if (index == brackEnd){
					index = brackEnd+1;
					ifNode.statements = [generateStatementAST(tokens, index)];
					// check if there's any else statement
					if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "else"){
						// add that as well
						index ++;
						ifNode.elseStatements = [generateStatementAST(tokens, index)];
					}
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "syntax error in condition"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
			}
			return ifNode;
		}

		/// generates AST for while statements
		WhileNode generateWhileAST(TokenList tokens, ref uinteger index){
			WhileNode whileNode;
			// check if is an if
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "while" &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos!true(index+1);
				index += 2;
				whileNode.condition = generateCodeAST(tokens, index);
				// skip the brackEnd, if index matches it
				if (index == brackEnd){
					index++;
					whileNode.statements = [generateStatementAST(tokens, index)];
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "syntax error in condition"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
			}
			return whileNode;
		}
		
		/// returns a node representing either of the following:
		/// 
		/// 1. String literal
		/// 2. Number literal
		/// 3. Function Call (uses `generateFunctionCallAST`)
		/// 4. Variable (uses `generateVariableAST`)
		/// 5. Some code inside parantheses (uses `generateCodeAST`)
		/// 6. A literal array (`[x, y, z]`)
		/// 
		/// This function is used by `generateCodeAST` to separate nodes, and by `generateOperatorAST` to read operands
		CodeNode generateNodeAST(TokenList tokens, ref uinteger index){
			Token token = tokens.tokens[index];
			// an identifier, or literal (i.e some data) was expected
			if (token.type == Token.Type.Identifier){
				if (index+1 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					return CodeNode(generateFunctionCallAST(tokens, index));
				}else{
					// just a var
					return CodeNode(generateVariableAST(tokens, index));
				}
			}else if (token.type == Token.Type.ParanthesesOpen){
				// some code
				return CodeNode(generateCodeAST(tokens, index));
			}else if (token.type == Token.Type.IndexBracketOpen){
				// literal array
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				Token[] data = tokens.tokens[index .. brackEnd+1].dup;
				LiteralNode r;
				try{
					r.fromTokens(data);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
				}
				index = brackEnd+1;
				return CodeNode(r);
			}else if (token.type == Token.Type.Double || token.type == Token.Type.Integer || token.type == Token.Type.String){
				// double literal
				LiteralNode r;
				try{
					r.fromTokens([token]);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
				}
				index ++;
				return CodeNode(r);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "unexpected token"));
			}
			return CodeNode();
		}
		
		
	}
}