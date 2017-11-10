module qscript.compiler.astgen;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

import std.conv : to;

/// contains functions and stuff to convert a QScript from tokens to Syntax Trees
struct ASTGen{
	/// constructor
	/// 
	/// `onGetReturnTypeFunction` is a pointer to a function that will return the data type a function returns,
	/// or throws Exception if that function doesnt exist. The function will receive name of function &
	/// DataTypes of arguments it's being called with.
	/// 
	/// `onArgsTypeOkFunction` is a pointer to a function that will return true if the argument types for a pre-defined function
	/// are ok, else, false. It receives the functionName, and the argument types
	this (DataType delegate (string, DataType[]) onGetReturnTypeFunction,
		bool delegate(string, DataType[]) onArgsTypeOkFunction){
		onArgsTypeOk = onArgsTypeOkFunction;
		onGetFunctionReturnType = onGetReturnTypeFunction;
		compileErrors = new LinkedList!CompileError;
	}
	/// destructor
	~this (){
		.destroy(compileErrors);
	}
	/// generates an AST representing a script.
	/// 
	/// `tokens` is the TokenList to generate AST from
	/// `errors` is the array in which errors will be put
	/// 
	/// The script must be converted to tokens using `qscript.compiler.tokengen.toTokens`
	/// If any errors occur, they will be contanied in `qscript.compiler.misc.`
	public ScriptNode generateScriptAST(TokenList scriptTokens, ref CompileError[] errors){
		compileErrors.clear;
		tokens = scriptTokens;
		ScriptNode scriptNode;
		LinkedList!FunctionNode functions = new LinkedList!FunctionNode;
		// scan for return types & arg types of script-defined functions
		scanTokensForFunctionReturnArgTypes();
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
		/// stores functions' return types
		DataType[string] functionReturnTypes;
		/// called to get predefined function's return type
		DataType delegate(string, DataType[]) onGetFunctionReturnType;
		/// stores functions' argument types
		DataType[][string] functionArgTypes;
		/// called to check pre-defined functions' argument types
		bool delegate(string, DataType[]) onArgsTypeOk;
		struct{
			/// stores data types for variable in currently-being-converted function
			private DataType[string] varDataTypes;
			/// stores the scope depth count for each var
			private uinteger[string] varScopeDepth;
			/// stores current scope
			private uinteger scopeCount = 0;
			/// adds a var, throws Exception if var with same name already exists
			void addVarType(string name, DataType type){
				if (name in varDataTypes){
					throw new Exception("variable '"~name~"' declared twice");
				}
				varDataTypes[name] = type;
				varScopeDepth[name] = scopeCount;
			}
			/// returns data type of a var, throws Exception if var doesnt exist
			DataType getVarType(string name){
				if (name in varDataTypes){
					return varDataTypes[name];
				}else{
					throw new Exception("variable '"~name~"' not declared");
				}
			}
			/// removes vars of last scope, and decreases scopeCount
			void removeLastScope(){
				foreach (key; varScopeDepth.keys){
					if (varScopeDepth[key] == scopeCount){
						varScopeDepth.remove(key);
						// remove from varDataTypes too!
						varDataTypes.remove(key);
					}
				}
				if (scopeCount > 0){
					scopeCount --;
				}
			}
			/// increases scope count
			void increaseScopeCount(){
				scopeCount ++;
			}
		}
		/// scans tokens for script-defined functions' return types and argument types
		/// 
		/// keep in mind that it messes up the value of `index`! so only call it before anything else, and reset `index` then.
		void scanTokensForFunctionReturnArgTypes(){
			LinkedList!DataType argTypes = new LinkedList!DataType;
			for (index = 0; index < tokens.tokens.length; index ++){
				if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
					index ++;
					DataType returnType;
					try{
						returnType = readType();
					}catch(Exception e){
						compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
						.destroy (e);
					}
					string fName = tokens.tokens[index].token;
					functionReturnTypes[fName] = returnType;
					// now for the args
					index ++; // skip the name
					if (tokens.tokens[index].type == Token.Type.ParanthesesOpen){
						// it's got args
						uinteger brackEnd = tokens.tokens.bracketPos(index);
						for (index += 1; index < brackEnd; index ++){
							DataType argType;
							try{
								argType = readType();
							}catch (Exception e){
								compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
								.destroy (e);
							}
							argTypes.append(argType);
							// now should be the arg_name, ignore that
							assert (tokens.tokens[index].type == Token.Type.Identifier,
								"argument type should be followed by argument name");
							index ++;
							// now skip the comma, or could be a parenthesesEnd
							assert (tokens.tokens[index].type == Token.Type.ParanthesesClose ||
								tokens.tokens[index].type == Token.Type.Comma,
								"arguments must be separated using a comma");
							// index ++ in for statement does the job this time
						}
						functionArgTypes[fName] = argTypes.toArray;
						argTypes.clear;
					}else{
						// no args
						functionArgTypes[fName] = [];
					}
				}
				// skip brackets
				if ([Token.Type.BlockStart, Token.Type.IndexBracketOpen, Token.Type.ParanthesesOpen].
					hasElement(tokens.tokens[index].type)){
					index = tokens.tokens.bracketPos(index);
				}
			}
			.destroy (argTypes);
		}
		/// returns return type of a function, if function doesnt exist, throws Exception
		DataType getFunctionReturnType(string functionName, DataType[] argTypes){
			/// stores whether the all the tokens have been scanned for function return types
			static bool scannedAllTokens = false;
			if (functionName in functionReturnTypes){
				return functionReturnTypes[functionName];
			}else{
				if (onGetFunctionReturnType !is null){
					return onGetFunctionReturnType(functionName, argTypes.dup);
				}else{
					throw new Exception("function '"~functionName~"' not defined");
				}
			}
		}
		/// matches arguments' types to see if they can be used for a function
		/// 
		/// in case they dont match, appends error to compileErrors
		bool matchFunctionArgTypes(string functionName, DataType[] argTypes){
			bool r = true;
			// check if is predefined
			if (functionName in functionArgTypes){
				DataType[] acceptableTypes = functionArgTypes[functionName];
				if (argTypes.length != acceptableTypes.length){
					compileErrors.append(
						CompileError(tokens.getTokenLine(index), "function '"~functionName~"' called with invalid number of arguments"));
					r = false;
				}else{
					if (!matchArguments(acceptableTypes.dup, argTypes.dup)){
						compileErrors.append(CompileError(tokens.getTokenLine(index), "function '"~functionName~"' called with invalid arguments"));
						return false;
					}else{
						return true;
					}
				}
			}else{
				// use onArgsTypeOk
				if (onArgsTypeOk !is null){
					if (!onArgsTypeOk(functionName, argTypes)){
						compileErrors.append(CompileError(tokens.getTokenLine(index), "function '"~functionName~"' called with invalid arguments"));
						return false;
					}
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "function '"~functionName~"' not defined"));
				}
			}
			return r;
		}
		/// reads a type from TokensList
		/// 
		/// returns type in DataType struct, changes `index` to token after last token of type
		DataType readType(){
			uinteger startIndex = index;
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
							index++;
							commaExpected = true;
							// add it to list
							argList.append (arg);
							addVarType(arg.argName, arg.argType);
						}
					}
					// put args in list
					functionNode.arguments = argList.toArray;
					.destroy(argList);
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
			// make sure it's a block
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				increaseScopeCount();
				uinteger brackEnd = tokens.tokens.bracketPos!(true)(index);
				LinkedList!StatementNode statements = new LinkedList!StatementNode;
				// read statements
				index++;
				while (index < brackEnd){
					statements.append(generateStatementAST());
				}
				// put them all in block
				blockNode.statements = statements.toArray;
				.destroy(statements);
				index = brackEnd+1;

				removeLastScope();
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
				}
			}else if (tokens.tokens[index].type == Token.Type.DataType){
				// var declare
				return StatementNode(generateVarDeclareAST());
			}else if (tokens.tokens[index].type == Token.Type.Identifier &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// is a function call
				return StatementNode(generateFunctionCallAST());
			}else if (tokens.tokens[index].type == Token.Type.Identifier){
				// assignment
				return StatementNode(generateAssignmentAST());
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid statement"));
				index ++;
			}
			return StatementNode();
		}

		/// generates AST for function call, changes `index` to token after statementEnd
		FunctionCallNode generateFunctionCallAST(){
			FunctionCallNode functionCallNode = FunctionCallNode();
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
				// match argument types
				DataType[] argTypes;
				argTypes.length = functionCallNode.arguments.length;
				foreach(i, arg; functionCallNode.arguments){
					argTypes[i] = arg.returnType;
				}
				matchFunctionArgTypes(functionCallNode.fName, argTypes);
				// then the return type
				try{
					functionCallNode.returnType = getFunctionReturnType(functionCallNode.fName, argTypes);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy(e);
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
			CodeNode lastNode = CodeNode();
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
					// an operator or something that deals with data was expected
					if (token.type == Token.Type.Operator){
						lastNode = CodeNode(generateOperatorAST(lastNode));
						index --;
					}else{
						compileErrors.append(CompileError(tokens.getTokenLine(index), "unexpected token"));
						index ++;
						break;
					}
					separatorExpected = false;
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
			// make sure it's an operator, and there is a second operand
			if (tokens.tokens[index].type == Token.Type.Operator && index+1 < tokens.tokens.length){
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
		
		/// generates AST for a variable (or array) and changes value of index to the token after variable ends
		VariableNode generateVariableAST(){
			VariableNode var;
			// make sure first token is identifier
			if (tokens.tokens[index].type == Token.Type.Identifier){
				// set var name
				var.varName = tokens.tokens[index].token;
				try{
					var.varType = getVarType(var.varName);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy(e);
				}
				index ++;
				// check if indexes are specified, case yes, add em
				if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
					LinkedList!CodeNode indexes = new LinkedList!CodeNode;
					for (index = index; index < tokens.tokens.length; index ++){
						if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
							index++;
							indexes.append(generateCodeAST());
						}else{
							break;
						}
					}
					var.indexes = indexes.toArray;
					.destroy(indexes);
				}
				// make sure the indexes are possible
				if (var.indexes.length > var.varType.arrayNestCount){
					compileErrors.append(CompileError(tokens.getTokenLine(index),
							"cannot read variable as a "~to!string(var.indexes.length)~" dimensional array"));
				}else{
					// fix the var.type.arrayNestCount, according to the indexes read
					var.varType.arrayNestCount -= var.indexes.length;
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a variable"));
				index ++;
			}
			return var;
		}
		
		/// generates AST for assignment operator
		AssignmentNode generateAssignmentAST(){
			AssignmentNode assignment;
			// get the variable to assign to
			VariableNode var = generateVariableAST();
			// now at index, the token should be a `=` operator
			if (tokens.tokens[index].type == Token.Type.Operator && tokens.tokens[index].token == "="){
				// everything's ok till the `=` operator
				index++;
				CodeNode val = generateCodeAST();
				assignment = AssignmentNode(var, val);
				// make sure it's followed by a semicolon
				if (tokens.tokens[index].type != Token.Type.StatementEnd){
					compileErrors.append(CompileError(tokens.getTokenLine(index),
							"assingment statement not followed by semicolon"));
				}else{
					// skip the semicolon too
					index++;
				}
				// make sure the variable data type matches the val's data type
				DataType varType;
				try{
					varType = getVarType(var.varName);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index-1), e.msg));
				}
				// also need to check if the var was declared a array or not, and if it's being set a correct type or not
				if (varType.arrayNestCount < var.indexes.length){
					compileErrors.append(CompileError(tokens.getTokenLine(index-1),
							"variable dimensions in assignment differs from declaration"));
				}else{
					// continue with checking
					DataType expectedType = DataType(varType.type, varType.arrayNestCount - var.indexes.length);
					// make sure it matches
					if (expectedType != val.returnType){
						compileErrors.append(CompileError(tokens.getTokenLine(index-1),
								"cannot assign value with different data type to variable"));
					}
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
			// make sure it's a var declaration, and the vars are enclosed in parantheses
			if (DATA_TYPES.hasElement(tokens.tokens[index].token)){
				// read the type
				DataType type;
				try{
					type = readType();
				}catch(Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
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
								try{
									addVarType(token.token, type);
								}catch (Exception e){
									compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
									.destroy (e);
								}
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
				index ++;
			}
			return varDeclare;
		}
		
		/// generates AST for if statements
		IfNode generateIfAST(){
			IfNode ifNode;
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
					ifNode.statements = [generateStatementAST()];
					// check if there's any else statement
					if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "else"){
						// add that as well
						index ++;
						ifNode.elseStatements = [generateStatementAST()];
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
					whileNode.statements = [generateStatementAST()];
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "syntax error in condition"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
				index ++;
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
			}else if (token.type == Token.Type.ParanthesesOpen){
				// some code
				return generateCodeAST();
			}else if (token.type == Token.Type.IndexBracketOpen){
				// literal array
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				Token[] data = tokens.tokens[index .. brackEnd+1].dup;
				LiteralNode r;
				try{
					r.fromTokens(data);
				}catch (Exception e){
					compileErrors.append(CompileError(tokens.getTokenLine(index), e.msg));
					.destroy (e);
				}
				index = brackEnd+1;
				return CodeNode(r);
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