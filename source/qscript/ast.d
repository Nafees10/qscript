module qscript.ast;

import std.json,
			 std.traits,
			 std.conv,
			 std.string,
			 std.stdio;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// A simple AST Node
public class Node{
public:
	Token token;
	NodeType type;

	abstract JSONValue toJSON(){
		JSONValue ret;
		ret["token"] = token.token;
		ret["type"] = type.to!string;
		string typeStr;
		foreach (member; EnumMembers!TokenType){
			if (!token.type[member])
				continue;
			typeStr ~= member.to!string ~ ", ";
		}
		if (typeStr.length)
			ret["tokentype"] = typeStr.chomp(", ");
		JSONValue[] sub;
		foreach (child; children)
			sub ~= child.toJSON;
		if (sub.length)
			ret["children"] = sub;
		return ret;
	}
}

/*public class ScriptNode : Node{
public:
	DeclNode[] declarations;
}

abstract class DeclNode : Node{}

class TemplateDeclNode{
public:
	DeclNode[] declarations;
}

class TemplateFnNode : Node{
public:
	ParamListNode templateParams;
	FunctionNode fn;
}

class*/ // TODO complete this mess

/// ASTNode builder function type
private alias BuilderFunc = Node function(ref Tokenizer, NodeType);

/// read function for a NodeType
private template ReadFunction(NodeType type){
	enum ReadFunction = getReadFunction();
	BuilderFunc getReadFunction(){
		BuilderFunc ret = null;
		static foreach (sym; EnumMembers!NodeType){
			static if (type == sym && hasUDA!(sym, Builder)){
				ret = getUDAs!(sym, Builder)[0].builder;
			}
		}
		return ret;
	}
}

/// Checks if token at front is matching type.
///
/// Returns: true if matched
private bool expect(TokenType type)(Tokenizer toks){
	return !toks.empty && toks.front.type.get!type;
}

/// Checks if token at front is matching type. Pops it if matching
///
/// Returns: true if matched
private bool expectPop(TokenType type)(Tokenizer toks){
	if (!toks.empty && toks.front.type.get!type){
		toks.popFront;
		return true;
	}
	return false;
}

/// Tries to read a specific type of node from tokens
/// Will increment index to skip tokens consumed
///
/// Returns: Node, or null
Node read(NodeType type)(ref Tokenizer toks){
	static NodeType context = NodeType.Script;
	auto func = ReadFunction!type;
	if (!func)
		return null;
	NodeType prevContext = context;
	context = type;
	auto ret = func(toks, context);
	context = prevContext;
	return ret;
}

/// Tries to read token into node based off of token type hook
/// Will increment index to skip tokens consumed
///
/// Returns: Node or null
public Node read(ref Tokenizer toks){
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	auto type = toks.front.type;
	static foreach (member; EnumMembers!NodeType){
		static foreach (Hook hook; getUDAs!(member, Hook)){
			if (type.get!(hook.hook)){
				auto ret = toks.read!member;
				if (ret !is null){
					ret.type = member;
					return ret;
				}
			}
		}
	}
	return null;
}

/// UDA for Builder function
private struct Builder{
	BuilderFunc builder;
	this (BuilderFunc builder){
		this.builder = builder;
	}
}

/// UDA for hook in token type
private struct Hook{
	TokenType hook;
	this(TokenType hook){
		this.hook = hook;
	}
}

/// Node types
public enum NodeType{
	@Builder(&readScript)								Script,
	@Builder(&readPub)
		@Hook(TokenType.Pub)							Pub,

	@Builder(&readTemplate)
		@Hook(TokenType.Template)					Template,
	@Builder(&readTemplateFn)
		@Hook(TokenType.TemplateFn)				TemplateFn,
	@Builder(&readTemplateEnum)
		@Hook(TokenType.TemplateEnum)			TemplateEnum,
	@Builder(&readTemplateStruct)
		@Hook(TokenType.TemplateStruct)		TemplateStruct,
	@Builder(&readTemplateVar)
		@Hook(TokenType.TemplateVar)			TemplateVar,
	@Builder(&readTemplateAlias)
		@Hook(TokenType.TemplateAlias)		TemplateAlias,
	@Builder(&readFn)
		@Hook(TokenType.Fn)								Fn,
	@Builder(&readVar)
		@Hook(TokenType.Var)							Var,
	@Builder(&readStruct)
		@Hook(TokenType.Struct)						Struct,
	@Builder(&readEnum)
		@Hook(TokenType.Enum)							Enum,
	@Builder(&readAlias)
		@Hook(TokenType.Alias)						Alias,

	@Builder(&readDataType)							DataType,
	@Builder(&readIndexBracketPair)			IndexBracketPair,
	@Builder(&readTemplateParamList)		TemplateParamList,
	@Builder(&readTemplateParam)				TemplateParam,
	@Builder(&readParamList)						ParamList,
	@Builder(&readParam)								Param,
	@Builder(&readNamedValue)						NamedValue,

	@Builder(&readStatement)						Statement,
	@Builder(&readIfStatement)
		@Hook(TokenType.If)								IfStatement,
	@Builder(&readStaticIfStatement)
		@Hook(TokenType.StaticIf)					StaticIfStatement,
	@Builder(&readWhileStatement)
		@Hook(TokenType.While)						WhileStatement,
	@Builder(&readDoWhileStatement)
		@Hook(TokenType.Do)								DoWhileStatement,
	@Builder(&readForStatement)
		@Hook(TokenType.For)							ForStatement,
	@Builder(&readStaticForStatement)
		@Hook(TokenType.StaticFor)				StaticForStatement,
	@Builder(&readBreakStatement)
		@Hook(TokenType.Break)						BreakStatement,
	@Builder(&readContinueStatement)
		@Hook(TokenType.Continue)					ContinueStatement,
	@Builder(&readBlock)
		@Hook(TokenType.CurlyOpen)				Block,

	@Builder(&readIdentifier)
		@Hook(TokenType.Identifier)				Identifier,
	@Builder(&readLiteralInt)
		@Hook(TokenType.LiteralInt)
		@Hook(TokenType.LiteralHexadecimal)
		@Hook(TokenType.LiteralBinary)		IntLiteral,
	@Builder(&readFloatLiteral)
		@Hook(TokenType.LiteralFloat)			FloatLiteral,
	@Builder(&readStringLiteral)
		@Hook(TokenType.LiteralString)		StringLiteral,
	@Builder(&readCharLiteral)
		@Hook(TokenType.LiteralChar)			CharLiteral,
	@Builder(&readNullLiteral)
		@Hook(TokenType.Null)							NullLiteral,
	@Builder(&readTrueLiteral)
		@Hook(TokenType.True)							TrueLiteral,
	@Builder(&readFalseLiteral)
		@Hook(TokenType.False)						FalseLiteral,
	@Builder(&readExpr)									Expr,

	@Builder(&readLoadExpr)
		@Hook(TokenType.Load)							LoadExpr,
	@Builder(&readArrowExpr)
		@Hook(TokenType.Arrow)						ArrowExpr,
	@Builder(&readDotOp)
		@Hook(TokenType.OpDot)						DotOp,
	@Builder(&readOpIndex)
		@Hook(TokenType.OpIndex)					OpIndex,
	@Builder(&readOpCall)
		@Hook(TokenType.OpFnCall)					OpCall,
	@Builder(&readOpPreInc)
		@Hook(TokenType.OpInc)						OpPreInc,
	@Builder(&readOpPostInc)
		@Hook(TokenType.OpInc)						OpPostInc,
	@Builder(&readOpPreDec)
		@Hook(TokenType.OpDec)						OpPreDec,
	@Builder(&readOpPostDec)
		@Hook(TokenType.OpDec)						OpPostDec,
	@Builder(&readOpNot)
		@Hook(TokenType.OpNot)						OpNot,
	@Builder(&readOpMul)
		@Hook(TokenType.OpMul)						OpMul,
	@Builder(&readOpDiv)
		@Hook(TokenType.OpDiv)						OpDiv,
	@Builder(&readOpMod)
		@Hook(TokenType.OpMod)						OpMod,
	@Builder(&readOpAdd)
		@Hook(TokenType.OpAdd)						OpAdd,
	@Builder(&readOpSub)
		@Hook(TokenType.OpSub)						OpSub,
	@Builder(&readOpLShift)
		@Hook(TokenType.OpLShift)					OpLShift,
	@Builder(&readOpRShift)
		@Hook(TokenType.OpRShift)					OpRShift,
	@Builder(&readOpEquals)
		@Hook(TokenType.OpEquals)					OpEquals,
	@Builder(&readOpNotEquals)
		@Hook(TokenType.OpNotEquals)			OpNotEquals,
	@Builder(&readOpGreaterEquals)
		@Hook(TokenType.OpGreaterEquals)	OpGreaterEquals,
	@Builder(&readOpLesserEquals)
		@Hook(TokenType.OpLesserEquals)		OpLesserEquals,
	@Builder(&readOpGreater)
		@Hook(TokenType.OpGreater)				OpGreater,
	@Builder(&readOpLesser)
		@Hook(TokenType.OpLesser)					OpLesser,
	@Builder(&readOpIs)
		@Hook(TokenType.OpIs)							OpIs,
	@Builder(&readOpNotIs)
		@Hook(TokenType.OpNotIs)					OpNotIs,
	@Builder(&readOpBinAnd)
		@Hook(TokenType.OpBinAnd)					OpBinAnd,
	@Builder(&readOpBinOr)
		@Hook(TokenType.OpBinOr)					OpBinOr,
	@Builder(&readOpBinXor)
		@Hook(TokenType.OpBinXor)					OpBinXor,
	@Builder(&readOpBoolAnd)
		@Hook(TokenType.OpBoolAnd)				OpBoolAnd,
	@Builder(&readOpBoolOr)
		@Hook(TokenType.OpBoolOr)					OpBoolOr,
	@Builder(&readOpAssign)
		@Hook(TokenType.OpAssign)					OpAssign,
	@Builder(&readOpAddAssign)
		@Hook(TokenType.OpAddAssign)			OpAddAssign,
	@Builder(&readOpSubAssign)
		@Hook(TokenType.OpSubAssign)			OpSubAssign,
	@Builder(&readOpMulAssign)
		@Hook(TokenType.OpMulAssign)			OpMulAssign,
	@Builder(&readOpDivAssign)
		@Hook(TokenType.OpDivAssign)			OpDivAssign,
	@Builder(&readOpModAssign)
		@Hook(TokenType.OpModAssign)			OpModAssign,
	@Builder(&readOpBinAndAssign)
		@Hook(TokenType.OpSubAssign)			OpBinAndAssign,
	@Builder(&readOpBinOrAssign)
		@Hook(TokenType.OpBinOrAssign)		OpBinOrAssign,
	@Builder(&readOpBinXorAssign)
		@Hook(TokenType.OpBinXorAssign)		OpBinXorAssign,
	@Builder(&readTrait)
		@Hook(TokenType.Trait)						Trait
}

private Node readScript(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	while (!toks.empty){
		Node node = toks.read;
		if (node is null)
			throw new CompileError(ErrorType.Expected, toks.front, ["declaration"]);
		ret.children ~= node;
	}
	return ret;
}

private Node readPub(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Pub))
		throw new CompileError(ErrorType.Expected, toks.front, ["pub"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [toks.read];
	return ret;
}

private Node readTemplate(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Template))
		throw new CompileError(ErrorType.Expected, toks.front, ["template"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.TemplateParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readTemplateFn(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.TemplateFn))
		throw new CompileError(ErrorType.Expected, toks.front, ["$fn"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList),
		toks.read!(NodeType.ParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readTemplateEnum(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.TemplateEnum))
		throw new CompileError(ErrorType.Expected, toks.front, ["$enum"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList)
	];
	// from here on, there can be a block, or a single OpAssign
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	if (toks.expectPop!(TokenType.OpAssign)){
		// single OpAssign
		ret.children ~= toks.read!(NodeType.Expr);
		// expect a semicolon
		if (!toks.expectPop!(TokenType.Semicolon))
			throw new CompileError(ErrorType.Expected, toks.front, ["semicolon"]);
		return ret;
	}
	// multiple values
	if (!toks.expectPop!(TokenType.CurlyOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["{"]);

	while (true){
		ret.children ~= toks.read!(NodeType.NamedValue);
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		if (!toks.expectPop!(TokenType.Comma))
			throw new CompileError(ErrorType.Expected, toks.front, ["comma"]);
	}
	return ret;
}

private Node readTemplateStruct(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.TemplateStruct))
		throw new CompileError(ErrorType.Expected, toks.front, ["$struct"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList)
	];
	if (!toks.expect!(TokenType.CurlyOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["{"]);
	toks.popFront;
	while (true){
		ret.children ~= toks.read; // and hope its a declaration?
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
	}
	return ret;
}

private Node readTemplateVar(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.TemplateVar))
		throw new CompileError(ErrorType.Expected, toks.front, ["$var"]);
	Node ret;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType)
	];

	// now read ident paramlist optional( OpAssign Expr) [Comma or Semicolon]
	while (true){
		Node varNode = toks.read!(NodeType.Identifier);
		varNode.children = [
			toks.read!(NodeType.TemplateParamList)
		];
		if (toks.expectPop!(TokenType.OpAssign))
			varNode.children ~= toks.read!(NodeType.Identifier);

		if (toks.expectPop!(TokenType.Comma))
			continue;
		if (toks.expectPop!(TokenType.Semicolon))
			break;
	}
	return ret;
}

private Node readTemplateAlias(ref Tokenizer toks, NodeType context){
	if (!toks.expectPop!(TokenType.TemplateAlias))
		throw new CompileError(ErrorType.Expected, toks.front, ["$alias"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList),
		null // will replace it with what comes after opEquals
	];
	if (!toks.expectPop!(TokenType.OpAssign))
		throw new CompileError(ErrorType.Expected, toks.front, ["="]);
	ret.children[$ - 1] = toks.read; // read whatever
	// expect a semicolon
	if (!toks.expectPop!(TokenType.Semicolon))
		throw new CompileError(ErrorType.Expected, toks.front, ["semicolon"]);
	return ret;
}

private Node readFn(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Fn))
		throw new CompileError(ErrorType.Expected, toks.front, ["fn"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.ParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readVar(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Var))
		throw new CompileError(ErrorType.Expected, toks.front, ["var"]);
	Node ret;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType)
	];

	// now read ident optional( OpAssign Expr) [Comma or Semicolon]
	while (true){
		Node varNode = toks.read!(NodeType.Identifier);
		if (toks.expectPop!(TokenType.OpAssign))
			varNode.children = [toks.read!(NodeType.Identifier)];

		if (toks.expectPop!(TokenType.Comma))
			continue;
		if (toks.expectPop!(TokenType.Semicolon))
			break;
	}
	return ret;
}

private Node readStruct(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Struct))
		throw new CompileError(ErrorType.Expected, toks.front, ["struct"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
	];
	if (!toks.expect!(TokenType.CurlyOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["{"]);
	toks.popFront;
	while (true){
		ret.children ~= toks.read; // and hope its a declaration?
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
	}
	return ret;
}

private Node readEnum(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Enum))
		throw new CompileError(ErrorType.Expected, toks.front, ["enum"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
	];
	if (toks.expectPop!(TokenType.OpAssign)){
		// single OpAssign
		ret.children ~= toks.read!(NodeType.Expr);
		// expect a semicolon
		if (!toks.expectPop!(TokenType.Semicolon))
			throw new CompileError(ErrorType.Expected, toks.front, ["semicolon"]);
		return ret;
	}
	// multiple values
	if (!toks.expectPop!(TokenType.CurlyOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["{"]);

	while (true){
		ret.children ~= toks.read!(NodeType.NamedValue);
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		if (!toks.expectPop!(TokenType.Comma))
			throw new CompileError(ErrorType.Expected, toks.front, ["comma"]);
	}
	return ret;
}

private Node readAlias(ref Tokenizer toks, NodeType context){
	if (!toks.expectPop!(TokenType.Alias))
		throw new CompileError(ErrorType.Expected, toks.front, ["alias"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
		null // will replace it with what comes after opEquals
	];
	if (!toks.expectPop!(TokenType.OpAssign))
		throw new CompileError(ErrorType.Expected, toks.front, ["="]);
	ret.children[$ - 1] = toks.read; // read whatever
	// expect a semicolon
	if (!toks.expectPop!(TokenType.Semicolon))
		throw new CompileError(ErrorType.Expected, toks.front, ["semicolon"]);
	return ret;
}

private Node readDataType(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	// maybe its a ref?
	if (toks.expect!(TokenType.Ref)){
		// ref not allowed if context is already DataType, ref of ref is very bad
		if (context == NodeType.DataType)
			throw new CompileError(ErrorType.ExpectedAFoundB, toks.front, [
					"Data Type", "ref"
			]);
		ret.token = toks.front;
		toks.popFront;
		ret.children = [
			toks.read!(NodeType.DataType)
		];
		return ret;
	}

	if (toks.expect!(TokenType.Auto)){ // maybe its auto?
		ret.token = toks.front;
		toks.popFront;
		return ret; // auto cannot have [] at end, so just return here
	}else if (toks.expect!(TokenType.Fn)){ // maybe its a fn?
		ret.token = toks.front;
		toks.popFront;
		ret.children = [
			toks.read!(TokenType.DataType), // return type
			toks.read!(TokenType.ParamList)
		];
	}else if (toks.expect!(TokenType.Int) || // or a primitive type
			toks.expect!(TokenType.Float) ||
			toks.expect!(TokenType.Bool) ||
			toks.expect!(TokenType.String) ||
			toks.expect!(TokenType.Char)){
		ret.token = toks.front;
		toks.popFront;
	}else{ // fine! its an expression
		ret.token = toks.front; // just a dummy
		ret.children = [
			read!(NodeType.Expr)
		];
	}

	// now maybe it has bunch of [] making it an array
	while (toks.expect!(TokenType.IndexOpen)){
		ret.children ~= toks.read!(NodeType.IndexBracketPair);
	}
	return ret;
}

private Node readIndexBracketPair(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	if (!toks.expect!(TokenType.IndexOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["[]"]);
	ret.token = toks.front;
	toks.popFront;
	if (!toks.expect!(TokenType.IndexClose))
		throw new CompileError(ErrorType.Expected, toks.front, ["[]"]);
	toks.popFront;
	return ret;
}

private Node readTemplateParamList(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.BracketOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["("]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	while (!toks.expectPop!(TokenType.BracketClose)){
		ret.children ~= read!(NodeType.TemplateParam);
	}
	return ret;
}

private Node readTemplateParam(ref Tokenizer toks, NodeType context){
	// can be:
	// DataType Identifier
	// Identifier
	auto branch = toks;
	try{
		Node ret = branch.read!(NodeType.DataType);
		ret.children = [
			branch.read!(NodeType.Identifier)
		];
		if (!branch.expectPop!(TokenType.Comma) &&
				!branch.expect!(TokenType.BracketClose))
			throw CompileError(ErrorType.Expected, branch.front, ["comma"]);
		toks = branch;
		return ret;
	}catch (CompileError){}

	branch = toks;
	try{
		Node ret = branch.read!(NodeType.Identifier);
		if (!branch.expectPop!(TokenType.Comma) &&
				!branch.expect!(TokenType.BracketClose))
			throw CompileError(ErrorType.Expected, branch.front, ["comma"]);
		toks = branch;
		return ret;
	}catch (CompileError){}
	throw new CompileError(ErrorType.Expected, toks.front, ["Parameter"]);
}

private Node readParamList(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.BracketOpen))
		throw new CompileError(ErrorType.Expected, toks.front, ["("]);
	Node ret = new Node;
	ret.token = toks.front;
	while (!toks.expectPop!(TokenType.BracketClose)){
		ret.children ~= read!(NodeType.Param);
	}
	return ret;
}

private Node readParam(ref Tokenizer toks, NodeType context){
	// can be:
	// DataType Identifier
	// DataType
	auto branch = toks;
	try{
		Node ret = branch.read!(NodeType.DataType);
		ret.children = [
			branch.read!(NodeType.Identifier)
		];
		if (!branch.expectPop!(TokenType.Comma) &&
				!branch.expect!(TokenType.BracketClose))
			throw CompileError(ErrorType.Expected, branch.front, ["comma"]);
		toks = branch;
		return ret;
	}catch (CompileError){}

	branch = toks;
	try{
		Node ret = branch.read!(NodeType.DataType);
		if (!branch.expectPop!(TokenType.Comma) &&
				!branch.expect!(TokenType.BracketClose))
			throw CompileError(ErrorType.Expected, branch.front, ["comma"]);
		toks = branch;
		return ret;
	}catch (CompileError){}
	throw new CompileError(ErrorType.Expected, toks.front, ["Parameter"]);
}

/// reads `foo = bar`
private Node readNamedValue(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	Node name = toks.read!(NodeType.Identifier);
	if (toks.expect!(TokenType.OpAssign))
		throw new CompileError(ErrorType.Expected, toks.front, ["="]);
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		name,
		toks.read!(NodeType.Expr)
	];
	return ret;
}

private Node readIntLiteral(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.LiteralInt) &&
			!toks.expect!(TokenType.LiteralBinary) &&
			!toks.expect!(TokenType.LiteralHexadecimal))
		throw new CompileError(ErrorType.Expected, toks.front, ["int literal"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}
