module qscript.compiler.astgen;

import qscript.compiler.tokens.tokens;

import core.vararg;
import std.traits;
import std.json;
import std.string;
import std.array;
import std.stdio;
import std.conv : to;

/// an AST Node
public class ASTNode{
public:
	Token token;
	ASTNode[] children;

	JSONValue toJSON(){
		JSONValue ret;
		ret["token"] = token.token;
		string type;
		foreach (member; EnumMembers!TokenType){
			if (!token.type[member])
				continue;
			type ~= member.to!string ~ ", ";
		}
		if (type.length)
			ret["type"] = type.chomp(", ");
		JSONValue[] sub;
		foreach (child; children)
			sub ~= child.toJSON;
		if (sub.length)
			ret["children"] = sub;
		return ret;
	}
}

struct MatchUnit{
	bool isToken = false;
	union{
		MatchType matchType;
		TokenType tokenType;
	}
}

MatchUnit[] match(string grammar)(){
	enum string[] matchStr = grammar.split(" ");
	MatchUnit[] ret;
	ret.length = matchStr.length;
	static foreach (i, str; matchStr){
		static if (str[0] == '/'){
			ret[i].matchType = __traits(getMember, MatchType, str[1 .. $]);
		}else{
			ret[i].tokenType = __traits(getMember, TokenType, str[0 .. $]);
			ret[i].isToken = true;
		}
	}
	return ret;
}

enum MatchType{
	Expression,
}

struct Matchers{
	@(MatchType.Expression)
	@match!`LiteralInt` @match!`/Expression OperatorAdd /Expression`
	static ASTNode matchExpr(Token[] tokens){
		ASTNode ret = new ASTNode;
		if (tokens.length == 1){
			ret.token = tokens[0];
		}else{
			ret.token = tokens[1];
			ret.children = [matchExpr([tokens[0]]), matchExpr([tokens[2]])];
		}
		return ret;
	}
}

unittest{
	import qscript.compiler.tokens.tokengen : Tokenizer;
	auto tokenizer = new Tokenizer!TokenType(`5 + 3`);
	Token[] tokens;
	while (!tokenizer.end)
		tokens ~= tokenizer.next;
	// remove whitespace
	uint shift, i;
	while (i + shift < tokens.length){
		if (tokens[i + shift].type[TokenType.Whitespace]){
			shift ++;
			continue;
		}
		if (shift)
			tokens[i] = tokens[i + shift];
		i ++;
	}
	tokens.length = i;

	writeln(Matchers.matchExpr(tokens).toJSON.toPrettyString);
}
