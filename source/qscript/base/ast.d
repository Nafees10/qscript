module qscript.base.ast;

import qscript.base.tokens;

import std.traits;
import std.json;
import std.string;
import std.array;
import std.stdio;
import std.conv : to;

/// an AST Node
// initialise with T = Token Type enum
public class ASTNode(T) if (is(T == enum)){
public:
	Token!T token;
	ASTNode[] childNodes;
	T match;

	JSONValue toJSON(){
		JSONValue ret;
		ret["token"] = token.token;
		ret["match"] = match.to!string;
		string type;
		foreach (member; EnumMembers!T){
			if (!token.type[member])
				continue;
			type ~= member.to!string ~ ", ";
		}
		if (type.length)
			ret["type"] = type.chomp(", ");
		JSONValue[] sub;
		foreach (child; childNodes)
			sub ~= child.toJSON;
		if (sub.length)
			ret["childNodes"] = sub;
		return ret;
	}
}

struct Match{
	string str;
	int priority;
	this(string str, int priority = 0){
		this.str = str;
		this.priority = priority;
	}
}

/// matches patterns from M enum
ASTNode!T match(M, T)(Token!T[] tokens) if (is(T == enum) && is(M == enum)){
	ASTNode!T ret;


	return ret;
}

private struct Unit(T, M){
	bool isTok = false;
	union{
		M mat;
		T tok;
	}
}

private struct MatchTok(T, M){
	int priority;
	Unit[] mat;
	this(Unit[] match, int priority = 0){
		this.match = match;
		this.priority = priority;
		this.isStr = false;
	}
}

private struct MatcherState(T){

}

unittest{
	enum MatchType{
		@Match(`Identifier`) @Match(`\Identifier Dot Identifier`) Identifier
	}
}
