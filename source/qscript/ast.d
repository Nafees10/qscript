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
	Node[] children;
	NodeType type;

	JSONValue toJSON(){
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
	@Builder(&readParamList)						ParamList,
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
		toks.read!(NodeType.ParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readTemplateFn(ref Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Template))
		throw new CompileError(ErrorType.Expected, toks.front, ["$fn"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.ParamList),
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
		toks.read!(NodeType.ParamList)
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
		toks.read!(NodeType.ParamList)
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
			toks.read!(NodeType.ParamList)
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
