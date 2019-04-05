/++
Contains functions to generate AST from tokens
+/
module qscript.compiler.astgen;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

import std.conv : to;

/// contains functions and stuff to convert a QScript from tokens to Syntax Trees
struct ASTGen{
	/// generates an AST representing a script.
	/// 
	/// `tokens` is the TokenList to generate AST from
	/// `errors` is the array in which errors will be put
	/// 
	/// The script must be converted to tokens using `qscript.compiler.tokengen.toTokens`
	/// If any errors occur, they will be contanied in `qscript.compiler.misc.`
	public ScriptNode generateScriptAST(TokenList scriptTokens, ref CompileError[] errors){
		tokens = scriptTokens;
		tokens.tokens = tokens.tokens.dup;
		tokens.tokenPerLine = tokens.tokenPerLine.dup;
		ScriptNode scriptNode;
		LinkedList!FunctionNode functions = new LinkedList!FunctionNode;
		compileErrors = new LinkedList!CompileError;
		// go through the script, compile function nodes, link them to this node
		index = 0;
		for (uinteger lastIndex = tokens.tokens.length - 1; index < tokens.tokens.length; index ++){
			// look for TokenType.Keyword where token.token == "function"
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
				uinteger errorCount = compileErrors.count;
				FunctionNode functionNode = generateFunctionAST();
				index --;
				// check if error free
				if (compileErrors.count == errorCount){
					functions.append(functionNode);
				}
			}
		}
		scriptNode = ScriptNode(functions.toArray);
		.destroy(functions);
		errors = compileErrors.toArray;
		.destroy(compileErrors);
		return scriptNode;
	}
	private{
		/// stores the list of tokens
		TokenList tokens;
		/// stores the current index (of tokens)
		uinteger index;
		/// stores all compilation errors
		LinkedList!CompileError compileErrors;
		/// reads a type from TokensList
		/// 
		/// returns type in DataType struct, changes `index` to token after last token of type
		DataType readType(){
			uinteger startIndex = index;
			// check if it's a ref
			if (tokens.tokens[index].token == "@")
				index ++;
			// the first token has to be the type (int, string, double)
			index ++;
			// then comes the brackets making it an array
			if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
				for (; index < tokens.tokens.length; index ++){
					if (tokens.tokens[index].type != Token.Type.IndexBracketOpen &&
						tokens.tokens[index].type != Token.Type.IndexBracketClose){
						break;
					}
				}
			}
			string sType = tokens.toString(tokens.tokens[startIndex .. index]);
			return DataType(sType);
		}
		/// generates AST for a function definition 
		/// 
		/// changes `index` to the token after function definition
		FunctionNode generateFunctionAST(){
			FunctionNode functionNode;
			functionNode.lineno = tokens.getTokenLine(index);
			// make sure it's a function
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
				// read the type
				index++;
				try{
					functionNode.returnType = readType();
				}catch(Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
				// above functionCall moves index to fName
				// now index is at function name
				functionNode.name = tokens.tokens[index].token;
				index ++;
				// now for the argument types
				if (tokens.tokens[index].type == Token.Type.ParanthesesOpen){
					LinkedList!(FunctionNode.Argument) argList = new LinkedList!(FunctionNode.Argument);
					uinteger brackEnd = tokens.tokens.bracketPos(index);
					bool commaExpected = false;
					for (index ++; index < brackEnd; index ++){
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
							try{
								arg.argType = readType();
							}catch(Exception e){
								compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
								.destroy (e);
							}
							// the type must not be void, script-defined functions must all be static typed
							if (arg.argType.type == DataType.Type.Void){
								compileErrors.append(CompileError(tokens.getTokenLine(index),
										"script-defined functions can not receive arguments of type void"));
							}
							// now the arg_name
							arg.argName = tokens.tokens[index].token;
							commaExpected = true;
							// add it to list
							argList.append (arg);
						}
					}
					// put args in list
					functionNode.arguments = argList.toArray;
					.destroy(argList);
					index = brackEnd+1;
				}
				if (tokens.tokens[index].type == Token.Type.BlockStart){
					// no args, just body
					functionNode.bodyBlock = generateBlockAST();
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "function has no body"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a function definition"));
				index ++;
			}
			return functionNode;
		}
		
		/// generates AST for a {block-of-code}
		/// 
		/// changes `index` to token after block end
		BlockNode generateBlockAST(){
			BlockNode blockNode;
			blockNode.lineno = tokens.getTokenLine(index);
			// make sure it's a block
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				uinteger brackEnd = tokens.tokens.bracketPos!(true)(index);
				LinkedList!StatementNode statements = new LinkedList!StatementNode;
				// read statements
				index++;
				uinteger errorCount = compileErrors.count;
				while (index < brackEnd){
					statements.append(generateStatementAST());
					// check if error added
					if (errorCount != compileErrors.count){
						break;
					}
				}
				// put them all in block
				blockNode.statements = statements.toArray;
				.destroy(statements);
				index = brackEnd+1;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a block"));
				index ++;
			}
			return blockNode;
		}

		/// generates AST for one statement
		StatementNode generateStatementAST(){
			// identify the type, call the appropriate function
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				// block
				return StatementNode(generateBlockAST());
			}else if (tokens.tokens[index].type == Token.Type.Keyword){
				if (tokens.tokens[index].token == "if"){
					// if statement
					return StatementNode(generateIfAST());
				}else if (tokens.tokens[index].token == "while"){
					// while statement
					return StatementNode(generateWhileAST());
				}else if (tokens.tokens[index].token == "for"){
					// for statement
					return StatementNode(generateForAST());
				}else if (tokens.tokens[index].token == "do"){
					// do while
					return StatementNode(generateDoWhileAST());
				}else if (tokens.tokens[index].token == "return"){
					// return statement
					return StatementNode(generateReturnAST());
				}
			}else if (tokens.tokens[index].type == Token.Type.DataType || 
				(tokens.tokens[index].token == "@" && tokens.tokens[index+1].type == Token.Type.DataType)){
				// var declare
				return StatementNode(generateVarDeclareAST());
			}else if (tokens.tokens[index].type == Token.Type.Identifier &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// is a function call
				return StatementNode(generateFunctionCallAST());
			}else if (tokens.tokens[index].type == Token.Type.Identifier || 
				(tokens.tokens[index].token == "@" && tokens.tokens[index+1].type == Token.Type.Identifier)){
				// assignment
				return StatementNode(generateAssignmentAST());
			}
			compileErrors.append (CompileError(tokens.getTokenLine(index), "invalid statement"));
			index ++;
			return StatementNode();
		}

		/// generates AST for function call, changes `index` to token after statementEnd
		FunctionCallNode generateFunctionCallAST(){
			FunctionCallNode functionCallNode;
			functionCallNode.lineno = tokens.getTokenLine(index);
			// check if is function call
			if (tokens.tokens[index].type == Token.Type.Identifier &&
				tokens.tokens[index + 1].type == Token.Type.ParanthesesOpen){
				uinteger brackEnd = tokens.tokens.bracketPos(index + 1);
				functionCallNode.fName = tokens.tokens[index].token;
				// now for the arguments
				index+=2;
				if (tokens.tokens[index].type == Token.Type.ParanthesesClose){
					// has no args
					functionCallNode.arguments = [];
				}else{
					LinkedList!CodeNode args = new LinkedList!CodeNode;
					for (; ; index ++){
						args.append(generateCodeAST());
						if (tokens.tokens[index].type == Token.Type.ParanthesesClose){
							break;
						}
					}
					functionCallNode.arguments = args.toArray;
					.destroy(args);
				}
				// move index to bracketend or semicolon
				index = brackEnd+1;
				if (tokens.tokens[index].type == Token.Type.StatementEnd){
					index ++;
				}
				return functionCallNode;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid function call"));
				index ++;
			}
			return functionCallNode;
		}
		
		/// generates AST for "actual code" like `2 + 2 - 6`.
		/// 
		/// terminates reading when on a Token that is comma, paranthesesEnd, semicolon, index/block bracket close
		CodeNode generateCodeAST(){
			CodeNode lastNode = null;
			bool separatorExpected = false;
			for ( ; ; index ++){
				Token token = tokens.tokens[index];
				// check if has to terminate
				if ([Token.Type.Comma, Token.Type.IndexBracketClose, Token.Type.BlockEnd, Token.Type.ParanthesesClose,
					Token.Type.StatementEnd].hasElement(token.type)){
					break;
				}
				if (!separatorExpected){
					// an identifier, or literal (i.e some data) was expected
					lastNode = generateNodeAST();
					index --;
					separatorExpected = true;
				}else{
					// an operator or something that deals with data was expected.
					// check if there's an [...] to read the array
					if (token.type == Token.Type.IndexBracketOpen){
						// read the index
						uinteger brackEnd = tokens.tokens.bracketPos(index);
						index ++;
						CodeNode indexNode = generateCodeAST();
						// make sure it's a read-element, not a make-array
						if (index != brackEnd){
							compileErrors.append (CompileError(tokens.getTokenLine(index), "unexpected tokens"));
							index++;
							break;
						}
						lastNode = CodeNode(ReadElement(lastNode, indexNode));
						continue;
					}
					separatorExpected = false;
					if (token.type == Token.Type.Operator){
						lastNode = CodeNode(generateOperatorAST(lastNode));
						index --;
						// in case of operators, generateOperatorAST takes the 2nd operand (!separator), itself, so the next
						// token, if any, is to be a separator
						separatorExpected = true;
						continue;
					}else{
						break;
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
		OperatorNode generateOperatorAST(CodeNode firstOperand){
			OperatorNode operator;
			operator.lineno = tokens.getTokenLine(index);
			// make sure it's an operator, and there is a second operand
			if (tokens.tokens[index].type == Token.Type.Operator && OPERATORS.hasElement(tokens.tokens[index].token) &&
				index+1 < tokens.tokens.length){
				// read the next operand
				CodeNode secondOperand;
				string operatorString = tokens.tokens[index].token;
				index ++;
				secondOperand = generateNodeAST();
				// put both operands under one node
				operator = OperatorNode(operatorString, firstOperand, secondOperand);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "no second operand found"));
				index ++;
			}
			return operator;
		}

		/// generates AST for single operand operators
		SOperatorNode generateSOperatorAST(){
			SOperatorNode operator;
			operator.lineno = tokens.getTokenLine(index);
			// make sure its a single operand operator
			if (tokens.tokens[index].type == Token.Type.Operator && SOPERATORS.hasElement(tokens.tokens[index].token)){
				// read the operator
				operator.operator = tokens.tokens[index].token;
				index++;
				// and the operand
				operator.operand = generateNodeAST();
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not an operator"));
			}
			return operator;
		}
		/// generates AST for a variable (or array) and changes value of index to the token after variable ends
		VariableNode generateVariableAST(){
			VariableNode var;
			var.lineno = tokens.getTokenLine(index);
			// make sure first token is identifier
			if (tokens.tokens[index].type == Token.Type.Identifier){
				// set var name
				var.varName = tokens.tokens[index].token;
				index ++;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a variable"));
				index ++;
			}
			return var;
		}
		
		/// generates AST for assignment operator
		AssignmentNode generateAssignmentAST(){
			AssignmentNode assignment;
			assignment.lineno = tokens.getTokenLine(index);
			// get the variable to assign to
			// check if the var is being deref-ed first
			if (tokens.tokens[index] == Token(Token.Type.Operator, "@")){
				assignment.deref = true;
				index++;
			}
			CodeNode varCodeNode = generateCodeAST();
			VariableNode var;
			CodeNode[] indexes;
			if (varCodeNode.type == CodeNode.Type.ReadElement){
				LinkedList!CodeNode indexesList = new LinkedList!CodeNode;
				ReadElement indexRead;
				while (varCodeNode.type == CodeNode.Type.ReadElement){
					indexRead = varCodeNode.node!(CodeNode.Type.ReadElement);
					indexesList.append(indexRead.index);
					varCodeNode = indexRead.readFromNode;
				}
				indexes = indexesList.toArray.reverseArray;
			}
			// make sure it's a var
			if (varCodeNode.type != CodeNode.Type.Variable){
				compileErrors.append (CompileError(tokens.getTokenLine(index),
						"can only assign to variables or deref-ed (@) references"));
			}else{
				var = varCodeNode.node!(CodeNode.Type.Variable);
				// now at index, the token should be a `=` operator
				if (tokens.tokens[index].type == Token.Type.AssignmentOperator){
					// everything's ok till the `=` operator
					index++;
					CodeNode val = generateCodeAST();
					assignment.var = var;
					assignment.indexes = indexes;
					assignment.val = val;
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
					index ++;
				}
			}
			return assignment;
		}
		
		/// generates AST for variable declarations
		VarDeclareNode generateVarDeclareAST(){
			VarDeclareNode varDeclare;
			varDeclare.lineno = tokens.getTokenLine(index);
			// make sure it's a var declaration, and the vars are enclosed in parantheses
			if ((tokens.tokens[index].token == "@" && DATA_TYPES.hasElement(tokens.tokens[index+1].token)) ||
				DATA_TYPES.hasElement(tokens.tokens[index].token)){
				// read the type
				try{
					varDeclare.type = readType();
				}catch(Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
				while (tokens.tokens[index].type != Token.Type.StatementEnd && index < tokens.tokens.length){
					if (tokens.tokens[index].type == Token.Type.Identifier){
						string varName = tokens.tokens[index].token;
						// see if it has a assigned value, case not, skip to next
						if (tokens.tokens[index+1].type == Token.Type.AssignmentOperator){
							index += 2;
							CodeNode value = generateCodeAST();
							varDeclare.addVar(varName, value);
						}else{
							varDeclare.addVar(varName);
							index ++;
						}
						// now there must be a comma
						if (tokens.tokens[index].type == Token.Type.Comma){
							index ++;
						}else if (tokens.tokens[index].type != Token.Type.StatementEnd){
							compileErrors.append (CompileError(tokens.getTokenLine(index), 
							"variable names must be separated by a comma"));
						}
						continue;
					}else{
						compileErrors.append (CompileError(tokens.getTokenLine(index), "variable name expected"));
						// jump to end of statement
						while (tokens.tokens[index].type != Token.Type.StatementEnd && index < tokens.tokens.length){
							index ++;
						}
						break;
					}
				}
				// skip the semicolon
				if (tokens.tokens[index].type == Token.Type.StatementEnd){
					index ++;
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
				index ++;
			}
			return varDeclare;
		}
		
		/// generates AST for if statements
		IfNode generateIfAST(){
			IfNode ifNode;
			ifNode.lineno = tokens.getTokenLine(index);
			// check if is an if
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "if" &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos(index+1);
				index += 2;
				ifNode.condition = generateCodeAST();
				// make sure index & brackEnd are now same
				if (index == brackEnd){
					index = brackEnd+1;
					ifNode.statement = generateStatementAST();
					ifNode.hasElse = false;
					// check if there's any else statement
					if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "else"){
						// add that as well
						index ++;
						ifNode.elseStatement = generateStatementAST();
						ifNode.hasElse = true;
					}
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "syntax error in condition"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
				index ++;
			}
			return ifNode;
		}

		/// generates AST for while statements
		WhileNode generateWhileAST(){
			WhileNode whileNode;
			whileNode.lineno = tokens.getTokenLine(index);
			// check if is an if
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "while" &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos!true(index+1);
				index += 2;
				whileNode.condition = generateCodeAST();
				// skip the brackEnd, if index matches it
				if (index == brackEnd){
					index++;
					whileNode.statement = generateStatementAST();
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "syntax error in condition"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
				index ++;
			}
			return whileNode;
		}

		/// generates AST for for loop statements
		ForNode generateForAST(){
			ForNode forNode;
			forNode.lineno = tokens.getTokenLine(index);
			// check if is a for statement
			if (tokens.tokens[index] == Token(Token.Type.Keyword, "for") && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				/// where the parantheses ends
				uinteger bracketEnd = tokens.tokens.bracketPos(index+1);
				/// get the init statement
				index = index + 2;
				forNode.initStatement = generateStatementAST();
				/// get the condition
				forNode.condition = generateCodeAST();
				/// make sure there's a semicolon
				if (tokens.tokens[index].type != Token.Type.StatementEnd){
					compileErrors.append(CompileError(tokens.getTokenLine(index), "semicolon expected after for loop condition"));
				}
				index ++;
				/// get the increment statement
				forNode.incStatement = generateStatementAST();
				if (index == bracketEnd){
					/// now for the for loop body
					index ++;
					forNode.statement = generateStatementAST();
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "closing parantheses expected after statement"));
				}
			}
			return forNode;
		}

		/// generates AST for do-while loops statements
		DoWhileNode generateDoWhileAST(){
			DoWhileNode doWhile;
			doWhile.lineno = tokens.getTokenLine(index);
			if (tokens.tokens[index] == Token(Token.Type.Keyword, "do")){
				// get the statement
				index ++;
				doWhile.statement = generateStatementAST();
				// now make sure there's a while there
				if (tokens.tokens[index] == Token(Token.Type.Keyword, "while") &&
					tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// read the condition
					uinteger brackEnd = tokens.tokens.bracketPos(index+1);
					index += 2;
					doWhile.condition = generateCodeAST();
					if (index != brackEnd){
						compileErrors.append (CompileError(tokens.getTokenLine(index), "syntax error"));
					}else{
						// skip the bracket end
						index ++;
						// the semicolon after `do ... while(...)` is optional, so if it's there, skip it
						if (tokens.tokens[index].type == Token.Type.StatementEnd){
							index ++;
						}
					}
				}else{
					compileErrors.append (CompileError(tokens.getTokenLine(index),
							"while followed by condition expected after end of loop statement"));
				}
			}
			return doWhile;
		}

		/// returns a node representing a return statement
		ReturnNode generateReturnAST(){
			if (tokens.tokens[index].token != "return"){
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a return statement"));
			}else{
				index ++;
				return ReturnNode(tokens.getTokenLine(index), generateCodeAST());
			}
			return ReturnNode();
		}

		/// returns a node representing either of the following:
		/// 1. String literal
		/// 2. Number literal
		/// 3. Function Call (uses `generateFunctionCallAST`)
		/// 4. Variable (uses `generateVariableAST`)
		/// 5. Some code inside parantheses (uses `generateCodeAST`)
		/// 6. A literal array (`[x, y, z]`)
		/// 
		/// This function is used by `generateCodeAST` to separate nodes, and by `generateOperatorAST` to read operands
		CodeNode generateNodeAST(){
			Token token = tokens.tokens[index];
			// an identifier, or literal (i.e some data) was expected
			if (token.type == Token.Type.Identifier){
				if (index+1 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					CodeNode r = CodeNode(generateFunctionCallAST());
					// check if it skipped the semicolon, because if it did, it shouldnt have, so undo it
					if (tokens.tokens[index-1].type == Token.Type.StatementEnd){
						index --;
					}
					return r;
				}else{
					// just a var
					return CodeNode(generateVariableAST());
				}
			}else if (token.type == Token.Type.Operator && SOPERATORS.hasElement(token.token)){
				return CodeNode(generateSOperatorAST());
			}else if (token.type == Token.Type.ParanthesesOpen){
				// some code
				index ++;
				CodeNode r = generateCodeAST();
				index ++;
				return r;
			}else if (token.type == Token.Type.IndexBracketOpen){
				// literal array
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				// read into ArrayNode
				CodeNode[] elements = [];
				index ++;
				for (; index < brackEnd; index ++){
					elements = elements ~ generateCodeAST();
					if (tokens.tokens[index].type != Token.Type.Comma && index != brackEnd){
						compileErrors.append (CompileError (tokens.getTokenLine(index),
								"Unexpected token, comma must be used to separate array elements"));
						index = brackEnd;
					}
				}
				index = brackEnd+1;
				return CodeNode(ArrayNode(elements));
			}else if (token.type == Token.Type.Double || token.type == Token.Type.Integer || token.type == Token.Type.String){
				// literal
				index ++;
				try{
					return CodeNode(LiteralNode([token]));
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
			}else{
				index ++;
				compileErrors.append(CompileError(tokens.getTokenLine(index), "unexpected token"));
			}
			return CodeNode();
		}

	}
}
