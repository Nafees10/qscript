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
		static if (__traits(hasMember, qscript.ast, "read" ~ type.to!string)){
			auto fn = &__traits(getMember, qscript.ast, "read" ~ type.to!string);
			static if (is(typeof(fn) == BuilderFunc))
				return fn;
			else
				return null;
		}else{
			return null;
		}
	}
}

/// Checks if token at front is matching type.
///
/// Returns: true if matched
private bool expect(TokenType type)(Tokenizer toks){
	return !toks.empty && !toks.front.type.get!type;
}

/// Checks if token at front is matching type. Pops it if matching
///
/// Returns: true if matched
private bool expectPop(TokenType type)(Tokenizer toks){
	if (!toks.empty && !toks.front.type.get!type){
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
Node read(ref Tokenizer toks){
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

/// UDA for hook in token type
private struct Hook{
	TokenType hook;
	this(TokenType hook){
		this.hook = hook;
	}
}

/// Node types
public enum NodeType{
																		Script,
	@Hook(TokenType.Pub)							Pub,

	@Hook(TokenType.Template)					Template,
	@Hook(TokenType.TemplateFn)				TemplateFn,
	@Hook(TokenType.TemplateEnum)			TemplateEnum,
	@Hook(TokenType.TemplateStruct)		TemplateStruct,
	@Hook(TokenType.TemplateVar)			TemplateVar,
	@Hook(TokenType.TemplateAlias)		TemplateAlias,
	@Hook(TokenType.Fn)								Fn,
	@Hook(TokenType.Var)							Var,
	@Hook(TokenType.Struct)						Struct,
	@Hook(TokenType.Enum)							Enum,
	@Hook(TokenType.Alias)						Alias,

																		DataType,
																		ParamList,
																		NamedValue,

																		Statement,
	@Hook(TokenType.If)								IfStatement,
	@Hook(TokenType.StaticIf)					StaticIfStatement,
	@Hook(TokenType.While)						WhileStatement,
	@Hook(TokenType.Do)								DoWhileStatement,
	@Hook(TokenType.For)							ForStatement,
	@Hook(TokenType.StaticFor)				StaticForStatement,
	@Hook(TokenType.Break)						BreakStatement,
	@Hook(TokenType.Continue)					ContinueStatement,
	@Hook(TokenType.CurlyOpen)				Block,

	@Hook(TokenType.Identifier)				Identifier,
	@Hook(TokenType.LiteralInt)
		@Hook(TokenType.LiteralHexadecimal)
		@Hook(TokenType.LiteralBinary)	IntLiteral,
	@Hook(TokenType.LiteralFloat)			FloatLiteral,
	@Hook(TokenType.LiteralString)		StringLiteral,
	@Hook(TokenType.LiteralChar)			CharLiteral,
	@Hook(TokenType.Null)							NullLiteral,
	@Hook(TokenType.True)							TrueLiteral,
	@Hook(TokenType.False)						FalseLiteral,
																		Expr,

	@Hook(TokenType.Load)							LoadExpr,
	@Hook(TokenType.Arrow)						ArrowExpr,
	@Hook(TokenType.OpDot)						DotOp,
	@Hook(TokenType.OpIndex)					OpIndex,
	@Hook(TokenType.OpFnCall)					OpCall,
	@Hook(TokenType.OpInc)						OpPreInc,
	@Hook(TokenType.OpInc)						OpPostInc,
	@Hook(TokenType.OpDec)						OpPreDec,
	@Hook(TokenType.OpDec)						OpPostDec,
	@Hook(TokenType.OpNot)						OpNot,
	@Hook(TokenType.OpMul)						OpMul,
	@Hook(TokenType.OpDiv)						OpDiv,
	@Hook(TokenType.OpMod)						OpMod,
	@Hook(TokenType.OpAdd)						OpAdd,
	@Hook(TokenType.OpSub)						OpSub,
	@Hook(TokenType.OpLShift)					OpLShift,
	@Hook(TokenType.OpRShift)					OpRShift,
	@Hook(TokenType.OpEquals)					OpEquals,
	@Hook(TokenType.OpNotEquals)			OpNotEquals,
	@Hook(TokenType.OpGreaterEquals)	OpGreaterEquals,
	@Hook(TokenType.OpLesserEquals)		OpLesserEquals,
	@Hook(TokenType.OpGreater)				OpGreater,
	@Hook(TokenType.OpLesser)					OpLesser,
	@Hook(TokenType.OpIs)							OpIs,
	@Hook(TokenType.OpNotIs)					OpNotIs,
	@Hook(TokenType.OpBinAnd)					OpBinAnd,
	@Hook(TokenType.OpBinOr)					OpBinOr,
	@Hook(TokenType.OpBinXor)					OpBinXor,
	@Hook(TokenType.OpBoolAnd)				OpBoolAnd,
	@Hook(TokenType.OpBoolOr)					OpBoolOr,
	@Hook(TokenType.OpAssign)					OpAssign,
	@Hook(TokenType.OpAddAssign)			OpAddAssign,
	@Hook(TokenType.OpSubAssign)			OpSubAssign,
	@Hook(TokenType.OpMulAssign)			OpMulAssign,
	@Hook(TokenType.OpDivAssign)			OpDivAssign,
	@Hook(TokenType.OpModAssign)			OpModAssign,
	@Hook(TokenType.OpSubAssign)			OpBinAndAssign,
	@Hook(TokenType.OpBinOrAssign)		OpBinOrAssign,
	@Hook(TokenType.OpBinXorAssign)		OpBinXorAssign,
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

private Node readPub(Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.Pub))
		throw new CompileError(ErrorType.Expected, toks.front, ["pub"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [toks.read];
	return ret;
}

private Node readTemplate(Tokenizer toks, NodeType context){
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

private Node readTemplateFn(Tokenizer toks, NodeType context){
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

private Node readTemplateEnum(Tokenizer toks, NodeType context){
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

private Node readTemplateStruct(Tokenizer toks, NodeType context){
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
		//static if // TODO continue from here
	}
}

/// reads `foo = bar`
private Node readNamedValue(Tokenizer toks, NodeType context){
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

private Node readIntLiteral(Tokenizer toks, NodeType context){
	if (!toks.expect!(TokenType.LiteralInt) &&
			!toks.expect!(TokenType.LiteralBinary) &&
			!toks.expect!(TokenType.LiteralHexadecimal))
		throw new CompileError(ErrorType.Expected, toks.front, ["int literal"]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}
