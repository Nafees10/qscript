module qscript.parser;

import std.json,
			 std.traits,
			 std.conv,
			 std.string,
			 std.stdio,
			 std.functional,
			 std.algorithm,
			 std.meta,
			 std.array;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// A Node
public class Node{
public:
	Token token;
	NodeType type;
	Node[] children;

	this(Token token, Node[] children = null){
		this.token = token;
		this.children = children;
	}

	this(Node[] children = null){
		this.children = children;
	}

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
		foreach (child; children){
			if (child is null)
				sub ~= JSONValue(null);
			else
				sub ~= child.toJSON;
		}
		if (sub.length)
			ret["children"] = sub;
		return ret;
	}
}

/// Returns: Flags constructed from AliasSeq
private template ToFlags(Vals...) if (
		Vals.length > 0 &&
		is(typeof(Vals[0]) == enum)){
	alias T = typeof(Vals[0]);
	enum ToFlags = getFlags;
	Flags!T getFlags(){
		Flags!T ret;
		static foreach (val; Vals){
			static if (!is(typeof(val) == T))
				static assert(false, "Vals not all of same type: " ~
						typeof(val).stringof ~ " != " ~ T.stringof);
			ret |= val;
		}
		return ret;
	}
}

/// stringof's all other template parameters, and joins with a string
private template JoinStringOf(string Jstr, Vals...){
	enum JoinStringOf = getJoinStringOf;
	private string getJoinStringOf(){
		string ret;
		static foreach (i, val; Vals){
			ret ~= val.to!string;
			static if (i + 1 < Vals.length)
				ret ~= Jstr;
		}
		return ret;
	}
}

/// Precedence (if none found, default is 0)
private template PrecedenceOf(alias type){
	enum PrecedenceOf = getPrecedenceOf();
	private uint getPrecedenceOf(){
		static if (hasUDA!(type, Precedence))
			return getUDAs!(type, Precedence)[0].precedence;
		else
			return 0;
	}
}

/// Returns: precedence of a NodeType, or 0
private uint precedenceOf(NodeType type){
	switch (type){
		static foreach(member; EnumMembers!NodeType){
			case member:
				return PrecedenceOf!member;
		}
		default: return 0;
	}
}

/// All precedences
private template Precedences(){
	alias Precedences = AliasSeq!();
	static foreach (member; EnumMembers!NodeType)
		Precedences = AliasSeq!(Precedences, member);
	Precedences = NoDuplicates!Precedences;
}

/// subset that have a precedence equal to or greater
private template HigherPreced(uint P, Ops...){
	alias HigherPreced = AliasSeq!();
	static foreach (node; Ops){
		static if (PrecedenceOf!node >= P)
			HigherPreced = AliasSeq!(HigherPreced, node);
	}
}

/// AliasSeq of TokenType of Hooks for given NodeTypes AliasSeq
private template Hooks(Types...){
	alias Hooks = AliasSeq!();
	static foreach (node; Types){
		static foreach (tokType; getUDAs!(node, TokenType))
			Hooks = AliasSeq!(Hooks, tokType);
	}
}

/// Binary Operators NodeTypes with Precedence >= P
private template BinOps(uint P = 0){
	alias BinOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, BinOp) && PrecedenceOf!type >= P)
			BinOps = AliasSeq!(BinOps, type);
	}
}

/// Prefix Operators with Precedence >= P
private template PreOps(uint P = 0){
	alias PreOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, PreOp) && PrecedenceOf!type >= P)
			PreOps = AliasSeq!(PreOps, type);
	}
}

/// Postfix Operators with Precedence >= P
private template PostOps(uint P = 0){
	alias PostOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if ((hasUDA!(type, PostOp) || hasUDA!(type, BinOp)) &&
				PrecedenceOf!type >= P)
			PostOps = AliasSeq!(PostOps, type);
	}
}

/// Postfix Operators excluding Binary Operators, with Precedence >= P
private template PostNoBinOps(uint P = 0){
	alias PostNoBinOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, PostOp) && !hasUDA!(type, BinOp) &&
				PrecedenceOf!type >= P)
			PostNoBinOps = AliasSeq!(PostNoBinOps, type);
	}
}

/// Checks if token at front is matching type.
///
/// Returns: true if matched
private bool expect(Types...)(ref Tokenizer toks){
	if (toks.empty)
		return false;
	enum Flags!TokenType match = ToFlags!Types;
	return cast(bool)(match & toks.front.type);
}

/// Checks if tokens at front are matching types.
///
/// Returns: true if matched
private bool expectSeqPop(Types...)(ref Tokenizer toks){
	auto branch = toks;
	static foreach (type; Types){{
		if (!branch.expectPop!(type))
			return false;
	}}
	toks = branch;
	return true;
}

/// Checks if token at front is matching type. Pops it if matching
///
/// Returns: true if matched
private bool expectPop(Types...)(ref Tokenizer toks){
	if (toks.expect!Types){
		toks.popFront;
		return true;
	}
	return false;
}

/// current context (NodeType of calling function)
private NodeType currContext, prevContext;

/// Builder function
private template Builder(alias Type){
	static if (exists){
		alias Builder = __traits(getMember, mixin(__MODULE__),
				"read" ~ Type.stringof);
	}else static if (hasUDA!(Type, BinOp)){
		alias Builder = readBinOp;
	}else static if (hasUDA!(Type, PreOp)){
		alias Builder = readPreOp;
	}else static if (hasUDA!(Type, PostOp)){
		alias Builder = readPostOp;
	}

	private bool exists(){
		bool ret = false;
		static foreach (member; __traits(allMembers, mixin(__MODULE__))){
			static if (member.to!string == "read" ~ Type.to!string){
				ret = true;
			}
		}
		return ret;
	}
}

/// Tries to read a specific type(s) by matching hooks
///
/// Returns: Node or null
private template read(Types...){
	static if (Types.length == 0){
		alias read = read!(EnumMembers!NodeType);

	}else static if (Types.length == 1){
		Node read(ref Tokenizer toks, Node preceeding = null){
			// save state
			NodeType displaced = prevContext;
			prevContext = currContext;
			currContext = Types[0];

			alias func = Builder!(Types[0]);
			Node ret = func(toks, preceeding);
			ret.type = Types[0];
			// restore state
			currContext = prevContext;
			prevContext = displaced;
			return ret;
		}

	}else{
		Node read(ref Tokenizer toks, Node preceeding = null){
			const auto type = toks.front.type;
			static foreach (member; Types){
				static foreach (tokType; getUDAs!(member, TokenType)){
					if (type.get!(tokType)){
						auto branch = toks;
						auto ret = branch.read!member(preceeding);
						if (ret !is null){
							toks = branch;
							return ret;
						}
					}
				}
			}
			return null;
		}
	}
}

/// Reads a sequence of Nodes
///
/// Returns: Node[] or empty array in case either one was null
private Node[] readSeq(Types...)(ref Tokenizer toks, Node preceeding = null){
	enum N = Types.length;
	Node[] ret;
	ret.length = N;
	static foreach (i; 0 .. N){{
		auto branch = toks;
		ret[i] = branch.read!(Types[i])(preceeding);
		if (ret[i] is null)
			return null;
		preceeding = ret[i];
		toks = branch;
	}}
	return ret;
}

/// Tries reading Types that are of Precedence >= P
///
/// Returns: Node or null
private Node readWithPrecedence(uint P, Types...)(ref Tokenizer toks, Node a){
	return toks.read!(HigherPreced!(P, Types))(a);
}

/// ditto
private Node readWithPrecedence(Types...)(ref Tokenizer toks, Node a, uint p){
	switch (p){
		static foreach (precedence; Precedences!()){
			case precedence:
				return toks.readWithPrecedence!(precedence, Types)(a);
		}
		default:
			return null;
	}
}

/// UDA for precedence. greater number is first
private struct Precedence{
	uint precedence;
	this(uint precedence){
		this.precedence = precedence;
	}
}

/// UDA for Binary Operator
enum BinOp;
/// UDA for Pre Operator
enum PreOp;
/// UDA for Post Operator
enum PostOp;

/// Node types
public enum NodeType{
																	Script,
	@(TokenType.Pub)								Pub,
	Declaration,
	@(TokenType.Template)						Template,
	@(TokenType.TemplateFn)					TemplateFn,
	@(TokenType.TemplateEnum)				TemplateEnum,
	@(TokenType.TemplateStruct)			TemplateStruct,
	@(TokenType.TemplateVar)				TemplateVar,
	@(TokenType.TemplateAlias)			TemplateAlias,
	@(TokenType.Fn)									Fn,
	@(TokenType.Var)								Var,
	@(TokenType.Struct)							Struct,
	@(TokenType.Enum)								Enum,
	@(TokenType.Alias)							Alias,
																	DataType,
																	IndexBracketPair,
																	TemplateParamList,
																	TemplateParam,
																	ParamList,
																	Param,
																	NamedValue,
																	Statement,
	@(TokenType.If)									IfStatement,
	@(TokenType.StaticIf)						StaticIfStatement,
	@(TokenType.While)							WhileStatement,
	@(TokenType.Do)									DoWhileStatement,
	@(TokenType.For)								ForStatement,
	@(TokenType.StaticFor)					StaticForStatement,
	@(TokenType.Break)							BreakStatement,
	@(TokenType.Continue)						ContinueStatement,
	@(TokenType.CurlyOpen)					Block,
																	ExprUnit,
	@(TokenType.Identifier)					Identifier,
	@(TokenType.LiteralInt)
		@(TokenType.LiteralHexadecimal)
		@(TokenType.LiteralBinary)		IntLiteral,
	@(TokenType.LiteralFloat)				FloatLiteral,
	@(TokenType.LiteralString)			StringLiteral,
	@(TokenType.LiteralChar)				CharLiteral,
	@(TokenType.Null)								NullLiteral,
	@(TokenType.True)
		@(TokenType.False)						BoolLiteral,
																	ArgList,

	@(TokenType.Trait)							Trait,

	@(TokenType.BracketOpen)				Expression,

	@Precedence(110)
		@PreOp
		@(TokenType.Load)							LoadExpr,

	@Precedence(100)
		@PreOp // just a hack, its a binary operator IRL
		@(TokenType.BracketOpen)			ArrowFunc,

	@Precedence(100)
		@BinOp
		@(TokenType.OpDot)						DotOp,
	@Precedence(100)
		@BinOp
		@(TokenType.OpIndex)					OpIndex,
	@Precedence(100)
		@BinOp
		@(TokenType.OpFnCall)					OpCall,

	@Precedence(90)
		@PostOp
		@(TokenType.OpInc)						OpPostInc,
	@Precedence(90)
		@PostOp
		@(TokenType.OpDec)						OpPostDec,

	@Precedence(80)
		@PreOp
		@(TokenType.OpInc)						OpPreInc,
	@Precedence(80)
		@PreOp
		@(TokenType.OpDec)						OpPreDec,
	@Precedence(80)
		@PreOp
		@(TokenType.OpNot)						OpNot,

	@Precedence(70)
		@BinOp
		@(TokenType.OpMul)						OpMul,
	@Precedence(70)
		@BinOp
		@(TokenType.OpDiv)						OpDiv,
	@Precedence(70)
		@BinOp
		@(TokenType.OpMod)						OpMod,

	@Precedence(60)
		@BinOp
		@(TokenType.OpAdd)						OpAdd,
	@Precedence(60)
		@BinOp
		@(TokenType.OpSub)						OpSub,

	@Precedence(50)
		@BinOp
		@(TokenType.OpLShift)					OpLShift,
	@Precedence(50)
		@BinOp
		@(TokenType.OpRShift)					OpRShift,

	@Precedence(40)
		@BinOp
		@(TokenType.OpEquals)					OpEquals,
	@Precedence(40)
		@BinOp
		@(TokenType.OpNotEquals)			OpNotEquals,
	@Precedence(40)
		@BinOp
		@(TokenType.OpGreaterEquals)	OpGreaterEquals,
	@Precedence(40)
		@BinOp
		@(TokenType.OpLesserEquals)		OpLesserEquals,
	@Precedence(40)
		@BinOp
		@(TokenType.OpGreater)				OpGreater,
	@Precedence(40)
		@BinOp
		@(TokenType.OpLesser)					OpLesser,
	@Precedence(40)
		@BinOp
		@(TokenType.OpIs)							OpIs,
	@Precedence(40)
		@BinOp
		@(TokenType.OpNotIs)					OpNotIs,

	@Precedence(30)
		@BinOp
		@(TokenType.OpBinAnd)					OpBinAnd,
	@Precedence(30)
		@BinOp
		@(TokenType.OpBinOr)					OpBinOr,
	@Precedence(30)
		@BinOp
		@(TokenType.OpBinXor)					OpBinXor,

	@Precedence(20)
		@BinOp
		@(TokenType.OpBoolAnd)				OpBoolAnd,
	@Precedence(20)
		@BinOp
		@(TokenType.OpBoolOr)					OpBoolOr,

	@Precedence(10)
		@BinOp
		@(TokenType.OpAssign)					OpAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpAddAssign)			OpAddAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpSubAssign)			OpSubAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpMulAssign)			OpMulAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpDivAssign)			OpDivAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpModAssign)			OpModAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpSubAssign)			OpBinAndAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpBinOrAssign)		OpBinOrAssign,
	@Precedence(10)
		@BinOp
		@(TokenType.OpBinXorAssign)		OpBinXorAssign,
}

public CompileResult!Node parseScript(ref Tokenizer toks){
	auto ret = readScript(toks, null);
	if (ret)
		return CompileResult!Node(ret);
	return CompileResult!Node(CompileError(ErrorType.SyntaxError, toks.front));
}

private Node readScript(ref Tokenizer toks, Node){
	Node ret = new Node;
	while (!toks.empty){
		if (auto val = toks.read!(NodeType.Declaration))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readPub(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Pub))
		return null;
	auto token = toks.front;
	toks.popFront;

	if (auto vals = toks.readSeq!(NodeType.Declaration))
		return new Node(token, vals);
	return null;
}

private Node readDeclaration(ref Tokenizer toks, Node){
	if (auto val = toks.read!(
				NodeType.Pub,
				NodeType.LoadExpr,
				NodeType.Template,
				NodeType.TemplateFn,
				NodeType.TemplateEnum,
				NodeType.TemplateStruct,
				NodeType.TemplateVar,
				NodeType.TemplateAlias,
				NodeType.Fn,
				NodeType.Enum,
				NodeType.Struct,
				NodeType.Var,
				NodeType.Alias)){
		if (val.type == NodeType.LoadExpr){
			if (!toks.expectPop!(TokenType.Semicolon))
				return null;
		}
		return new Node([val]);
	}
	return null;
}

private Node readTemplate(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Template))
		return null;
	auto token = toks.front;
	toks.popFront;

	if (auto vals = toks.readSeq!(
				NodeType.TemplateParamList,
				NodeType.Statement))
		return new Node(token, vals);
	return null;
}

private Node readTemplateFn(ref Tokenizer toks, Node){
	if (toks.expect!(TokenType.TemplateFn))
		return null;
	auto token = toks.front;
	toks.popFront;

	auto branch = toks;
	if (auto vals = branch.readSeq!(
				NodeType.Identifier,
				NodeType.TemplateParamList,
				NodeType.ParamList,
				NodeType.Statement)){
		toks = branch;
		return new Node(token, vals);
	}

	if (auto vals = toks.readSeq!(
				NodeType.DataType,
				NodeType.Identifier,
				NodeType.TemplateParamList,
				NodeType.ParamList,
				NodeType.Statement)){
		return new Node(token, vals);
	}
	return null;
}

private Node readTemplateEnum(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.TemplateEnum))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (auto vals = toks.readSeq!(
				NodeType.DataType,
				NodeType.Identifier,
				NodeType.TemplateParamList))
		ret.children = vals;
	else
		return null;

	// from here on, there can be a block, or a single OpAssign
	if (toks.expectPop!(TokenType.OpAssign)){
		// single OpAssign
		auto val = toks.read!(NodeType.Expression);
		if (val is null)
			return null;
		ret.children ~= val;
		// expect a semicolon
		if (!toks.expectPop!(TokenType.Semicolon))
			return null;
		return ret;
	}

	// multiple values
	if (!toks.expectPop!(TokenType.CurlyOpen))
		return null;

	while (true){
		auto val = toks.read!(NodeType.NamedValue);
		if (val is null)
			return null;
		ret.children ~= val;
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		if (!toks.expectPop!(TokenType.Comma))
			return null;
	}
	return ret;
}

private Node readTemplateStruct(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.TemplateStruct))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (auto vals = toks.readSeq!(
				NodeType.Identifier,
				NodeType.TemplateParamList))
		ret.children = vals;
	else
		return null;

	if (!toks.expectPop!(TokenType.CurlyOpen))
		return null;
	while (true){
		if (auto val = toks.read!(NodeType.Declaration))
			ret.children ~= val;
		else
			return null;
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
	}
	return ret;
}

private Node readTemplateVar(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.TemplateVar))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (auto val = toks.read!(NodeType.DataType))
		ret.children = [val];
	else
		return null;

	// now read ident paramlist optional( OpAssign Expr) [Comma or Semicolon]
	while (true){
		Node varNode = toks.read!(NodeType.Identifier);
		if (varNode is null)
			return null;
		if (auto val = toks.read!(NodeType.TemplateParamList))
			varNode.children = [val];
		else
			return null;

		if (toks.expectPop!(TokenType.OpAssign)){
			if (auto val = toks.read!(NodeType.Identifier))
				varNode.children ~= val;
			else
				return null;
		}

		if (toks.expectPop!(TokenType.Comma))
			continue;
		if (toks.expectPop!(TokenType.Semicolon))
			break;
	}
	return ret;
}

private Node readTemplateAlias(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.TemplateAlias))
		return null;
	auto token = toks.front;
	toks.popFront;

	Node ret;
	if (auto vals = toks.readSeq!(
				NodeType.Identifier,
				NodeType.TemplateParamList))
		ret = new Node(token, vals);
	else
		return null;
	if (!toks.expectPop!(TokenType.OpAssign))
		return null;
	if (auto val = toks.read!())
		ret.children ~= val;
	else
		return null;
	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	return ret;
}

private Node readFn(ref Tokenizer toks, Node){
	if (toks.expect!(TokenType.Fn))
		return null;
	auto token = toks.front;
	toks.popFront;

	auto branch = toks;
	if (auto vals = branch.readSeq!(
				NodeType.Identifier,
				NodeType.ParamList,
				NodeType.Statement)){
		toks = branch;
		return new Node(token, vals);
	}

	if (auto vals = toks.readSeq!(
				NodeType.DataType,
				NodeType.Identifier,
				NodeType.ParamList,
				NodeType.Statement)){
		return new Node(token, vals);
	}
	return null;
}

private Node readVar(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Var))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (auto val = toks.read!(NodeType.DataType))
		ret.children = [val];
	else
		return null;

	// now read ident optional( OpAssign Expr) [Comma or Semicolon]
	while (true){
		Node varNode = toks.read!(NodeType.Identifier);
		if (varNode is null)
			return null;

		if (toks.expectPop!(TokenType.OpAssign)){
			if (auto val = toks.read!(NodeType.Identifier))
				varNode.children ~= val;
			else
				return null;
		}

		if (toks.expectPop!(TokenType.Comma))
			continue;
		if (toks.expectPop!(TokenType.Semicolon))
			break;
	}
	return ret;
}

private Node readStruct(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Struct))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (auto val = toks.read!(NodeType.Identifier))
		ret.children = [val];
	else
		return null;

	if (!toks.expectPop!(TokenType.CurlyOpen))
		return null;
	while (true){
		if (auto val = toks.read!(NodeType.Declaration))
			ret.children ~= val;
		else
			return null;
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
	}
	return ret;
}

private Node readEnum(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Enum))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (auto vals = toks.readSeq!(
				NodeType.DataType,
				NodeType.Identifier))
		ret.children = vals;
	else
		return null;

	// from here on, there can be a block, or a single OpAssign
	if (toks.expectPop!(TokenType.OpAssign)){
		// single OpAssign
		auto val = toks.read!(NodeType.Expression);
		if (val is null)
			return null;
		ret.children ~= val;
		// expect a semicolon
		if (!toks.expectPop!(TokenType.Semicolon))
			return null;
		return ret;
	}

	// multiple values
	if (!toks.expectPop!(TokenType.CurlyOpen))
		return null;

	while (true){
		auto val = toks.read!(NodeType.NamedValue);
		if (val is null)
			return null;
		ret.children ~= val;
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		if (!toks.expectPop!(TokenType.Comma))
			return null;
	}
	return ret;
}

private Node readAlias(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Alias))
		return null;
	auto token = toks.front;
	toks.popFront;

	Node ret;
	if (auto val = toks.read!(NodeType.Identifier))
		ret = new Node(token, [val]);
	else
		return null;
	if (!toks.expectPop!(TokenType.OpAssign))
		return null;
	if (auto val = toks.read!())
		ret.children ~= val;
	else
		return null;
	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	return ret;
}

private Node readDataType(ref Tokenizer toks, Node){
	// maybe its a ref?
	if (toks.expect!(TokenType.Ref)){
		auto token = toks.front;
		toks.popFront;
		if (auto val = toks.read!(NodeType.DataType))
			return new Node(token, [val]);
		return null;
	}
	if (toks.expect!(TokenType.Auto)){ // maybe its auto?
		auto ret = new Node(toks.front);
		toks.popFront;
		return ret; // auto cannot have [] at end, so just return here
	}

	Node ret;
	if (toks.expect!(TokenType.Fn)){ // maybe its a fn?
		auto token = toks.front;
		toks.popFront;
		if (auto vals = toks.readSeq!(
					NodeType.DataType,
					NodeType.ParamList))
			ret = new Node(token, vals);
		else if (auto val = toks.read!(NodeType.ParamList))
			ret = new Node(token, [val]);
		else
			return null;
	}

	if (toks.expect!(
				TokenType.Int,
				TokenType.Float,
				TokenType.Bool,
				TokenType.String,
				TokenType.Char)){
		ret = new Node(toks.front);
		toks.popFront;
	}else{ // fine! its an expression
		if (auto val = toks.read!(NodeType.Expression))
			ret = new Node([val]);
		else
			return null;
	}

	// now maybe it has bunch of [] making it an array
	while (toks.expect!(TokenType.IndexOpen)){
		if (auto val = toks.read!(NodeType.IndexBracketPair))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readIndexBracketPair(ref Tokenizer toks, Node){
	auto token = toks.front;
	if (auto vals = toks.expectSeqPop!(
				TokenType.IndexOpen,
				TokenType.IndexClose))
		return new Node(token);
	return null;
}

private Node readTemplateParamList(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.BracketOpen))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	while (!toks.expectPop!(TokenType.BracketClose)){
		if (auto val = toks.read!(NodeType.TemplateParam))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readTemplateParam(ref Tokenizer toks, Node){
	// can be:
	// DataType Identifier
	// Identifier
	auto branch = toks;
	Node ret;
	if (auto vals = branch.readSeq!(
				NodeType.DataType,
				NodeType.Identifier)){
		ret = new Node(vals);
	}else if (auto val = branch.read!(NodeType.Identifier)){
		ret = new Node([val]);
	}
	toks = branch;
	if (!toks.expect!(TokenType.BracketClose)){
		if (!toks.expectPop!(TokenType.Comma))
			return null;
	}
	return ret;
}

private Node readParamList(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.BracketOpen))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	while (!toks.expectPop!(TokenType.BracketClose)){
		if (auto val = toks.read!(NodeType.Param))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readParam(ref Tokenizer toks, Node){
	// can be:
	// DataType Identifier
	// DataType
	Node ret;
	if (auto val = toks.read!(NodeType.DataType))
		ret = new Node([val]);
	else
		return null;
	auto branch = toks;
	if (auto val = branch.read!(NodeType.Identifier)){
		ret.children ~= val;
		toks = branch;
	}
	if (!toks.expect!(TokenType.BracketClose)){
		if (!toks.expectPop!(TokenType.Comma))
			return null;
	}
	return ret;
}

/// reads `foo = bar`
private Node readNamedValue(ref Tokenizer toks, Node){
	Node ret;
	if (auto val = toks.read!(NodeType.Identifier))
		ret = new Node([val]);
	else
		return null;
	if (!toks.expect!(TokenType.OpAssign))
		return null;

	ret.token = toks.front;
	toks.popFront;
	if (auto val = toks.read!(NodeType.Expression))
		ret.children ~= val;
	else
		return null;
	return ret;
}

private Node readStatement(ref Tokenizer toks, Node){
	auto branch = toks;
	if (auto val = toks.read!(
				NodeType.Declaration,
				NodeType.IfStatement,
				NodeType.StaticIfStatement,
				NodeType.WhileStatement,
				NodeType.DoWhileStatement,
				NodeType.ForStatement,
				NodeType.StaticForStatement,
				NodeType.BreakStatement,
				NodeType.ContinueStatement,
				NodeType.Block)){
		toks = branch;
		return new Node([val]);
	}

	Node ret;
	if (auto val = toks.read!(NodeType.Expression))
		ret = new Node([val]);
	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	return ret;
}

private Node readIfStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.If))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	if (auto vals = toks.readSeq!(
				NodeType.Expression,
				NodeType.Statement))
		ret.children = vals;
	else
		return null;
	if (toks.expectPop!(TokenType.Else)){
		if (auto val = toks.read!(NodeType.Statement))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readStaticIfStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.StaticIf))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	if (auto vals = toks.readSeq!(
				NodeType.Expression,
				NodeType.Statement))
		ret.children = vals;
	else
		return null;
	if (toks.expectPop!(TokenType.Else)){
		if (auto val = toks.read!(NodeType.Statement))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readWhileStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.While))
		return null;
	auto token = toks.front;
	toks.popFront;
	if (auto vals = toks.readSeq!(
				NodeType.Expression,
				NodeType.Statement))
		return new Node(token, vals);
	return null;
}

private Node readDoWhileStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Do))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	if (auto val = toks.read!(NodeType.Statement))
		ret.children = [val, null];
	else
		return null;
	if (!toks.expectPop!(TokenType.While))
		return null;
	if (auto val = toks.read!(NodeType.Expression))
		ret.children[1] = val;
	else
		return null;
	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	return ret;
}

private Node readForStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.For))
		return null;
	auto ret = new Node(toks.front);
	toks.popFront;

	if (!toks.expectPop!(TokenType.BracketOpen))
		return null;
	Node node = toks.read!(NodeType.Identifier);
	if (node is null)
		return null;
	if (toks.expectPop!(TokenType.Comma)){
		ret.children ~= node; // iteration counter
		node = toks.read!(NodeType.Identifier);
		if (node is null)
			return null;
	}
	ret.children ~= node; // iteration element

	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	if (auto val = toks.read!(NodeType.Expression))
		ret.children ~= val;
	else
		return null;

	if (!toks.expectPop!(TokenType.BracketClose))
		return null;
	if (auto val = toks.read!(NodeType.Statement))
		ret.children ~= val;
	else
		return null;
	return ret;
}

private Node readStaticForStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.StaticFor))
		return null;
	auto ret = new Node(toks.front);
	toks.popFront;

	if (!toks.expectPop!(TokenType.BracketOpen))
		return null;
	Node node = toks.read!(NodeType.Identifier);
	if (node is null)
		return null;
	if (toks.expectPop!(TokenType.Comma)){
		ret.children ~= node; // iteration counter
		node = toks.read!(NodeType.Identifier);
		if (node is null)
			return null;
	}
	ret.children ~= node; // iteration element

	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	if (auto val = toks.read!(NodeType.Expression))
		ret.children ~= val;
	else
		return null;

	if (!toks.expectPop!(TokenType.BracketClose))
		return null;
	if (auto val = toks.read!(NodeType.Statement))
		ret.children ~= val;
	else
		return null;
	return ret;
}

private Node readBreakStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Break))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	return ret;
}

private Node readContinueStatement(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Continue))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	if (!toks.expectPop!(TokenType.Semicolon))
		return null;
	return ret;
}

private Node readBlock(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.CurlyOpen))
		return null;
	Node ret = new Node(toks.front);
	ret.token = toks.front;
	toks.popFront;

	while (!toks.expectPop!(TokenType.CurlyClose)){
		if (auto val = toks.read!(NodeType.Statement))
			ret.children ~= val;
		else
			return null;
	}
	return ret;
}

private Node readExprUnit(ref Tokenizer toks, Node){
	if (auto val = toks.read!(
				NodeType.Identifier,
				NodeType.IntLiteral,
				NodeType.FloatLiteral,
				NodeType.StringLiteral,
				NodeType.CharLiteral,
				NodeType.NullLiteral,
				NodeType.BoolLiteral))
		return new Node([val]);
	return null;
}

private Node readIdentifier(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Identifier))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readIntLiteral(ref Tokenizer toks, Node){
	if (!toks.expect!(
				TokenType.LiteralInt,
				TokenType.LiteralBinary,
				TokenType.LiteralHexadecimal))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readFloatLiteral(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.LiteralFloat))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readStringLiteral(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.LiteralString))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readCharLiteral(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.LiteralChar))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readNullLiteral(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Null))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readBoolLiteral(ref Tokenizer toks, Node){
	if (!toks.expect!(
				TokenType.True,
				TokenType.False))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	return ret;
}

private Node readArgList(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.BracketOpen))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;
	if (toks.expectPop!(TokenType.BracketClose))
		return ret;

	while (true){
		if (auto val = toks.read!(NodeType.Expression))
			ret.children ~= val;
		else
			return null;
		if (toks.expectPop!(TokenType.BracketClose))
			break;
		if (!toks.expectPop!(TokenType.Comma))
			return null;
	}
	return ret;
}

private Node readTrait(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Trait))
		return null;
	auto token = toks.front;
	toks.popFront;
	if (auto val = toks.read!(NodeType.ArgList))
		return new Node(token, [val]);
	return null;
}

private Node readExpression(ref Tokenizer toks, Node){
	if (toks.expect!(TokenType.BracketOpen, TokenType.IndexOpen)){
		// so we know which closing bracket to expect
		bool isIndexBracket = toks.front.type.get!(TokenType.IndexOpen);
		toks.popFront;
		Node ret = toks.read!(NodeType.Expression);
		if (ret is null)
			return null;
		bool closed;
		if (isIndexBracket)
			closed = toks.expectPop!(TokenType.IndexClose);
		else
			closed = toks.expectPop!(TokenType.BracketClose);
		if (!closed)
			return null;
		return ret;
	}

	const uint precedence = precedenceOf(prevContext);
	bool createContainer = false;
	auto branch = toks;
	Node expr;
	if (auto val = branch.readWithPrecedence!(PreOps!())(null, precedence)){
		toks = branch;
		expr = val;
		createContainer = true;
	}else if (auto val = toks.read!(NodeType.ExprUnit)){
		expr = val;
	}else{
		return null;
	}

	// now keep feeding it into proceeding operators until precedence violated
	while (true){
		branch = toks;
		/*Flags!TokenType match = ToFlags!(Hooks!(AliasSeq!(
						BinOps!(), PostOps!()
						)));
		if (!(match & toks.front.type))
			break;*/
		if (auto val = branch.readWithPrecedence!(BinOps!(), PostOps!())
				(expr, precedence)){
			toks = branch;
			createContainer = true;
			expr = val;
		}else{
			break;
		}
	}
	if (!createContainer)
		return expr;
	return new Node([expr]);
}

private Node readLoadExpr(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.Load))
		return null;
	Node ret = new Node(toks.front);
	toks.popFront;

	if (!toks.expectPop!(TokenType.BracketOpen))
		return null;
	while (true){
		if (auto val = toks.read!(NodeType.Identifier))
			ret.children ~= val;
		else
			return null;
		if (toks.expectPop!(TokenType.BracketClose))
			break;
		if (!toks.expectPop!(TokenType.BracketClose))
			return null;
	}
	return ret;
}

private Node readArrowFunc(ref Tokenizer toks, Node){
	if (!toks.expect!(TokenType.BracketOpen))
		return null;
	Node ret = new Node;
	if (auto val = toks.read!(NodeType.ParamList))
		ret.children = [val];
	else
		return null;
	// now the arrow
	if (!toks.expect!(TokenType.Arrow))
		return null;
	ret.token = toks.front;
	toks.popFront;

	// (..) -> dataType {..}
	auto branch = toks;
	if (auto vals = toks.readSeq!(
				NodeType.DataType,
				NodeType.Block)){
		toks = branch;
		ret.children ~= vals;
		return ret;
	}

	// (..) -> (<expr> or {..})
	if (auto val = toks.read!(
				NodeType.Expression,
				NodeType.Block)){
		ret.children ~= val;
		return ret;
	}
	return null;
}

private Node readOpCall(ref Tokenizer toks, Node a){
	if (!toks.expect!(TokenType.BracketOpen))
		return null;
	if (auto val = toks.read!(NodeType.ArgList))
		return new Node([a, val]);
	return null;
}

private Node readOpIndex(ref Tokenizer toks, Node a){
	if (!toks.expect!(TokenType.IndexOpen))
		return null;
	if (auto val = toks.read!(NodeType.Expression))
		return new Node([a, val]);
	return null;
}

private Node readBinOp(ref Tokenizer toks, Node a){
	if (!toks.expect!(Hooks!(BinOps!())))
		return null;
	auto token = toks.front;
	if (auto val = toks.read!(NodeType.Expression))
		return new Node(token, [a, val]);
	return null;
}

private Node readPreOp(ref Tokenizer toks, Node){
	if (!toks.expect!(Hooks!(PreOps!())))
		return null;
	auto token = toks.front;
	if (auto val = toks.read!(NodeType.Expression))
		return new Node(token, [val]);
	return null;
}

private Node readPostOp(ref Tokenizer toks, Node a){
	if (!toks.expect!(Hooks!(PostNoBinOps!())))
		return null;
	auto token = toks.front;
	toks.popFront;
	return new Node(token, [a]);
}
