module qscript.compiler.tokens.tokengen;

import utils.ds;

import std.algorithm;
import std.traits;

debug import std.stdio;

/// A token
public struct Token(T) if (is (T == enum)){
	/// line number and column number
	uint lineno, colno;
	/// token type(s)
	Flags!T type;
	/// token
	string token;
	alias token this;
	/// [line number, colno]
	@property uint[2] where() const{
		return [lineno, colno];
	}
	/// constructor
	this(uint lineno, uint colno, Flags!T type, string token){
		this.lineno = lineno;
		this.colno = colno;
		this.type = type;
		this.token = token;
	}
	/// ditto
	this(uint lineno, uint colno, T type, string token){
		this.lineno = lineno;
		this.colno = colno;
		this.type.set(type);
		this.token = token;
	}
	/// ditto
	this(Flags!T type, string token){
		this.type = type;
		this.token = token;
	}
	/// ditto
	this(T type, string token){
		this.type.set(type);
		this.token = token;
	}
	/// == operator
	bool opBinary(string op : "==")(const Token rhs) const{
		return type == rhs.type && token == rhs.token;
	}
	/// ditto
	bool opBinary(string op : "==")(const T rhs) const{
		return type.get(rhs);
	}
	/// ditto
	bool opBinary(string op : "==")(const string rhs) const{
		return token == rhs;
	}
	/// != operator
	bool opBinary(string op : "!=")(const Token rhs) const{
		return type != rhs.type || token != rhs.token;
	}
	/// ditto
	bool opBinary(string op : "!=")(const T rhs) const{
		return !type.get(rhs);
	}
	/// ditto
	bool opBinary(string op : "!=")(const string rhs) const{
		return token != rhs;
	}
}

public struct Match{
	private bool exactMatch;
	union{
		string matchStr;
		uint function(string) funcMatch;
	}

	/// attempt to match
	///
	/// Returns: number of characters matching, starting from index 0
	private uint match(string s){
		if (exactMatch){
			if (s.length < matchStr.length)
				return 0;
			return cast(uint)
				(matchStr.length * (s[0 .. matchStr.length] == matchStr));
		}
		return funcMatch(s);
	}

	this (string match){
		this.exactMatch = true;
		this.matchStr = match;
	}

	this(uint function(string) match){
		this.exactMatch = false;
		this.funcMatch = match;
	}
}

/// Tokenizer Exception
public class TokenizerException : Exception{
private:
	uint _lineno, _colno;

public:
	this(uint lineno, uint colno){
		_lineno = lineno;
		_colno = colno;
		super("Unexpected token");
	}

	/// Line number where error occurred
	@property uint line() const {
		return _lineno;
	}

	/// Column number wher error occurred
	@property uint col() const {
		return _colno;
	}
}

/// Fancy string exploder
public class Tokenizer(T) if (is (T == enum)){
private:
	string _source;
	uint _seek;
	uint _lineno;
	uint _lastNewlineIndex;

	/// match a token
	static Token!T _getToken(string str){
		Flags!T matches;
		uint maxLen;
		static foreach (member; EnumMembers!T){{
			uint localMaxLen = 0;
			static foreach (matcher; getUDAs!(member, Match))
				localMaxLen = max(localMaxLen, matcher.match(str));
			if (localMaxLen > maxLen){
				matches = false; // just found a bigger match, previous not valid now
				matches += member;
				maxLen = localMaxLen;
			}else if (maxLen && localMaxLen == maxLen){
				matches += member;
			}
		}}
		if (maxLen && maxLen <= str.length)
			return Token!T(matches, str[0 .. maxLen]);
		return Token!T.init;
	}

public:
	this (string source = null){
		this._source = source;
	}

	/// resets seek
	void resetSeek(){
		_seek = 0;
		_lineno = 0;
		_lastNewlineIndex = 0;
	}

	/// Sets source string
	@property string source(string src){
		resetSeek();
		return _source = src;
	}

	@property bool end() const  {
		return _seek >= _source.length;
	}

	/// Parses next token. This will throw if called after all tokens been read
	///
	/// Returns: Token
	///
	/// Throws: TokenizerException
	Token!T next(){
		Token!T token = _getToken(_source[_seek .. $]);
		token.lineno = _lineno + 1;
		token.colno = _seek - _lastNewlineIndex;
		if (!token)
			throw new TokenizerException(token.lineno, token.colno);
		// increment _lineno if needed
		foreach (i, c; _source[_seek .. _seek + token.length]){
			if (c == '\n'){
				_lastNewlineIndex = cast(uint)i + _seek;
				_lineno ++;
			}
		}
		_seek += token.length;
		return token;
	}
}

///
unittest{
	static uint identifyWhitespace(string str){
		uint ret = 0;
		while (ret < str.length && (str[ret] == ' ' || str[ret] == '\n'))
			ret ++;
		return ret;
	}

	static uint identifyWord(string str){
		foreach (i, c; str){
			if (c < 'a' || c > 'z')
				return cast(uint)i;
			if (i + 1 == str.length)
				return cast(uint)i + 1;
		}
		return 0;
	}

	enum Type{
		@Match(`keyword`)						Keyword,
		@Match(&identifyWhitespace)	Whitespace,
		@Match(&identifyWord)				Word
	}

	auto tokenizer = new Tokenizer!Type(`  keyword word`);
	Token!Type[] tokens;
	while (!tokenizer.end)
		tokens ~= tokenizer.next;

	assert (tokens.length = 4);
	assert(tokens[0].type.get!(Type.Whitespace));

	assert(tokens[1].type.get!(Type.Keyword));
	assert(tokens[1].type.get!(Type.Word));

	assert(tokens[2].type.get!(Type.Whitespace));

	assert(tokens[3].type.get!(Type.Word));
}
