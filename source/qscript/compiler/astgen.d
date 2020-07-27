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
		compileErrors = new LinkedList!CompileError;
		// go through the script, compile function nodes, link them to this node
		index = 0;
		for (uinteger lastIndex = tokens.tokens.length - 1; index < tokens.tokens.length; index ++){
			// look for visibility specifier, or default to private
			Visibility vis = Visibility.Private;
			if (tokens.tokens[index].type == Token.Type.Keyword && VISIBILITY_SPECIFIERS.hasElement(tokens.tokens[index].token)){
				vis = strToVisibility(tokens.tokens[index].token);
				index ++;
			}
			// look for TokenType.Keyword where token.token == "function"
			if (tokens.tokens[index].type == Token.Type.Keyword){
				immutable uinteger errorCount = compileErrors.count;
				if (tokens.tokens[index].token == "import"){
					string[] imports = readImports();
					scriptNode.imports ~= imports;
					index --; // don't wanna skip the semicolon, for (..; index ++) does that
				}else if (tokens.tokens[index].token == "function"){
					FunctionNode functionNode = generateFunctionAST();
					functionNode.visibility = vis;
					index --;
					// check if error free
					if (compileErrors.count == errorCount){
						scriptNode.functions ~= functionNode;
					}
				}else if (tokens.tokens[index].token == "struct"){
					StructNode structNode = generateStructAST();
					structNode.visibility = vis;
					index --;
					if (compileErrors.count == errorCount){
						scriptNode.structs ~= structNode;
					}
				}else if (tokens.tokens[index].token == "enum"){
					EnumNode enumNode = generateEnumAST();
					enumNode.visibility = vis;
					index --;
					if (compileErrors.count == errorCount){
						scriptNode.enums ~= enumNode;
					}
				}else if (tokens.tokens[index].token == "var"){
					VarDeclareNode varDecNode = generateVarDeclareAST();
					varDecNode.visibility = vis;
					index --;
					if (compileErrors.count == errorCount){
						scriptNode.variables ~= varDecNode;
					}
				}
			}
		}
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
		/// Reads a single import statement.
		/// 
		/// Returns: the imported libraries' names
		string[] readImports(){
			string[] r;
			if (tokens.tokens[index] != Token(Token.Type.Keyword, "import")){
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not an import statement"));
				return [];
			}
			index ++; // skip the import
			while (tokens.tokens[index].type != Token.Type.StatementEnd){
				if (tokens.tokens[index].type == Token.Type.Comma)
					continue;
				if (tokens.tokens[index].type == Token.Type.Identifier){
					r ~= tokens.tokens[index].token;
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "identifier expected as library name"));
				}
				index ++;
			}
			index ++; // skip the semicolon

			return r;
		}
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
		/// generates AST for a struct definition
		/// 
		/// changes `index` to next token after struct definition
		StructNode generateStructAST(){
			StructNode structNode;
			if (tokens.tokens[index] == Token(Token.Type.Keyword, "struct")){
				// read the name
				index ++;
				if (tokens.tokens[index].type == Token.Type.Identifier){
					structNode.name = tokens.tokens[index].token;
					// now check the { and read members
					index ++;
					if (tokens.tokens[index].type == Token.Type.BlockStart){
						// now start reading it all as VarDeclareNodes
						index ++;
						while (index + 1 < tokens.tokens.length && tokens.tokens[index].type != Token.Type.BlockEnd){
							VarDeclareNode vars = generateVarDeclareAST();
							// make sure no members were assignned values, thats not allowed
							foreach (memberName; vars.vars){
								if (vars.hasValue(memberName)){
									compileErrors.append(CompileError(tokens.getTokenLine(index),
										"cannot assign value to members in struct definition"));
								}
								// make sure same member name isn't used >1 times
								if (structNode.membersName.hasElement(memberName)){
									compileErrors.append(CompileError(tokens.getTokenLine(index),
										"member '"~memberName~"' is declared multiple times in struct"));
								}else{
									structNode.membersName ~= memberName;
									structNode.membersDataType ~= vars.type;
								}
							}
							structNode.containsRef = structNode.containsRef || vars.type.isRef;
						}
						index ++; // skip the }
						// now check if struct has any members
						if (structNode.membersName.length == 0){
							compileErrors.append(CompileError(tokens.getTokenLine(index), "struct has no members"));
						}
						// if there is a semicolon, skip it
						if (index + 1 < tokens.tokens.length && tokens.tokens[index].type == Token.Type.StatementEnd)
							index ++;
					}else{
						compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid struct definition, '{' expected"));
					}
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "struct name expected"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a struct definition"));
				index ++;
			}
			return structNode;
		}
		/// generates AST for a enum definition
		/// 
		/// changes `index` to next token after enum definition
		EnumNode generateEnumAST(){
			EnumNode enumNode;
			if (tokens.tokens[index] == Token(Token.Type.Keyword, "enum")){
				index ++;
				try{
					enumNode.baseDataType = readType();
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
				// make sure it's a base type
				if (enumNode.baseDataType.isArray() || enumNode.baseDataType.type == DataType.Type.Void ||
				enumNode.baseDataType.type == DataType.Type.Custom){
					compileErrors.append(CompileError(tokens.getTokenLine(index),
						"derived data types and arrays cannot be base type for enums"));
				}
				if (tokens.tokens[index].type == Token.Type.Identifier){
					enumNode.name = tokens.tokens[index].token;
					index ++;
					if (index + 1 < tokens.tokens.length && tokens.tokens[index].type == Token.Type.BlockStart){
						index ++;
						// now start reading members
						while (tokens.tokens[index].type != Token.Type.BlockEnd){
							if (tokens.tokens[index].type == Token.Type.Identifier){
								enumNode.membersName ~= tokens.tokens[index].token;
								// check if value explicitly provided
								index ++;
								if (tokens.tokens[index].type == Token.Type.AssignmentOperator){
									index ++;
									enumNode.membersValue ~= generateLiteralAST();
								}
								// expect a } or a comma
								if (tokens.tokens[index].type != Token.Type.BlockEnd && tokens.tokens[index].type != Token.Type.Comma){
									compileErrors.append(CompileError(tokens.getTokenLine(index),"enum members must be separated using comma"));
								}
							}else{
								compileErrors.append(CompileError(tokens.getTokenLine(index), "enum member name expected"));
							}
						}
						index ++; // skip the }
						// skip the optional semicolon
						if (index + 1 < tokens.tokens.length && tokens.tokens[index].type == Token.Type.StatementEnd)
							index ++;
					}else{
						compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid enum definition, '{' expected"));
					}
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "enum name expected"));
				}
			}
			return enumNode;
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
				// make sure return type is not ref, thats bad, causes segfault
				if (functionNode.returnType.isRef){
					compileErrors.append(CompileError(tokens.getTokenLine(index), "functions cannot return references"));
				}
				// above functionCall moves index to fName
				// now index is at function name
				functionNode.name = tokens.tokens[index].token;
				index ++;
				// now for the argument types
				if (tokens.tokens[index].type == Token.Type.ParanthesesOpen){
					LinkedList!(FunctionNode.Argument) argList = new LinkedList!(FunctionNode.Argument);
					uinteger brackEnd = tokens.tokens.tokenBracketPos(index);
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
					// if there was a semicolon after function definition, skip that too
					if (index +1 < tokens.tokens.length && tokens.tokens[index].type == Token.Type.StatementEnd)
						index ++;
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
				uinteger brackEnd = tokens.tokens.tokenBracketPos!(true)(index);
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
				}else if (tokens.tokens[index].token == "var"){
					// var declare
					return StatementNode(generateVarDeclareAST());
				}
			}else if (tokens.tokens[index].type == Token.Type.Identifier &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// is a function call
				return StatementNode(generateFunctionCallAST());
			}else{
				// now if it's not a assignment statement, idk what it is
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
				uinteger brackEnd = tokens.tokens.tokenBracketPos(index + 1);
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
					Token.Type.StatementEnd, Token.Type.AssignmentOperator].hasElement(token.type)){
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
						uinteger brackStartIndex = index;
						uinteger brackEnd = tokens.tokens.tokenBracketPos(index);
						index ++;
						CodeNode indexNode = generateCodeAST();
						// make sure it's a read-element, not a make-array
						if (index != brackEnd){
							compileErrors.append (CompileError(tokens.getTokenLine(index), "unexpected tokens"));
							index++;
							break;
						}
						lastNode = CodeNode(ReadElement(lastNode, indexNode));
						lastNode.lineno = tokens.getTokenLine(brackStartIndex);
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
						compileErrors.append(CompileError(tokens.getTokenLine(index), "Unexpected token '"~token.token~'\''));
						break;
					}
				}
			}
			return lastNode;
		}

		/// generates AST for `-x` where x is a codenode
		NegativeValueNode generateNegativeNode(){
			if (tokens.tokens[index].type != Token.Type.Operator || tokens.tokens[index].token != "-"){
				compileErrors.append(CompileError(tokens.getTokenLine(index), "Not a negative node"));
				index ++;
				return NegativeValueNode(CodeNode());
			}
			NegativeValueNode r;
			index ++;
			CodeNode val = generateCodeAST();
			r = NegativeValueNode(val);
			return r;
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
			CodeNode lvalue = generateCodeAST();
			// now at index, the token should be a `=` operator
			if (tokens.tokens[index].type == Token.Type.AssignmentOperator){
				// everything's ok till the `=` operator
				index++;
				CodeNode rvalue = generateCodeAST();
				assignment.lvalue = lvalue;
				assignment.rvalue = rvalue;
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
			return assignment;
		}
		
		/// generates AST for variable declarations
		VarDeclareNode generateVarDeclareAST(){
			VarDeclareNode varDeclare;
			varDeclare.lineno = tokens.getTokenLine(index);
			// make sure it's a var declaration, and the vars are enclosed in parantheses
			if (tokens.tokens[index] == Token(Token.Type.Keyword, "var")){
				index ++;
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
				uinteger brackEnd = tokens.tokens.tokenBracketPos(index+1);
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
				uinteger brackEnd = tokens.tokens.tokenBracketPos!true(index+1);
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
				uinteger bracketEnd = tokens.tokens.tokenBracketPos(index+1);
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
					uinteger brackEnd = tokens.tokens.tokenBracketPos(index+1);
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
				ReturnNode r;
				r.lineno = tokens.getTokenLine(index);
				index ++;
				r.value = generateCodeAST();
				if (tokens.tokens[index].type == Token.Type.StatementEnd){
					index ++; //skip semicolon
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index),"semicolon expected"));
				}
				return r;
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
		/// 
		/// set `skipPost` to true in case you do not want it to read into `[...]` or `.` after the Node
		CodeNode generateNodeAST(){
			Token token = tokens.tokens[index];
			CodeNode r = CodeNode();
			// an identifier, or literal (i.e some data) was expected
			if (token.type == Token.Type.Identifier){
				if (index+1 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					r = CodeNode(generateFunctionCallAST());
					// check if it skipped the semicolon, because if it did, it shouldnt have, so undo it
					if (tokens.tokens[index-1].type == Token.Type.StatementEnd){
						index --;
					}
				}else{
					// just a var
					r = CodeNode(generateVariableAST());
				}
			}else if (token.type == Token.Type.Operator && SOPERATORS.hasElement(token.token)){
				r = CodeNode(generateSOperatorAST());
			}else if (token.type == Token.Type.Operator && token.token == "-"){
				r = CodeNode(generateNegativeNode());
			}else if (token.type == Token.Type.ParanthesesOpen){
				// some code
				index ++;
				r = generateCodeAST();
				index ++;
			}else if (token.type == Token.Type.IndexBracketOpen){
				// literal array
				uinteger brackEnd = tokens.tokens.tokenBracketPos(index);
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
				r = CodeNode(ArrayNode(elements));
			}else if (token.type == Token.Type.Double || token.type == Token.Type.Integer || token.type == Token.Type.String ||
			token.type == Token.Type.Char){
				// literal
				index ++;
				try{
					LiteralNode ltNode = LiteralNode([token]);
					ltNode.lineno = tokens.getTokenLine(index);
					r = CodeNode(ltNode);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
			}else{
				index ++;
				compileErrors.append(CompileError(tokens.getTokenLine(index), "unexpected token"));
			}
			// check if theres a [] or MemberSelector ahead of it to read it an element
			while (tokens.tokens[index].type == Token.Type.IndexBracketOpen ||
			tokens.tokens[index].type == Token.Type.MemberSelector){
				if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
					// skip the opening bracket `[`
					index ++;
					r = CodeNode(ReadElement(r, generateCodeAST()));
					if (tokens.tokens[index].type == Token.Type.IndexBracketClose)
						index ++; // skip the ] bracket
				}else if (tokens.tokens[index].type == Token.Type.MemberSelector){
					// read just the member name
					immutable uinteger lineno = tokens.getTokenLine(index);
					index ++;
					if (tokens.tokens[index].type != Token.Type.Identifier){
						compileErrors.append(CompileError(tokens.getTokenLine(index),
								"Expected identifier after member selector operator"));
					}else{
						r = CodeNode(MemberSelectorNode(r, tokens.tokens[index].token, lineno));
						index ++;
					}
				}
			}
			
			return r;
		}
		/// generates LiteralNode
		LiteralNode generateLiteralAST(){
			LiteralNode r;
			if ([Token.Type.Double,Token.Type.Integer,Token.Type.String,Token.Type.Char].hasElement(tokens.tokens[index].type)){
				try{
					r = LiteralNode([tokens.tokens[index]]);
					r.lineno = tokens.getTokenLine(index);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy(e);
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "literal expected"));
			}
			index ++;
			return r;
		}
	}
}
