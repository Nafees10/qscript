module qscript.compiler.tokengen;

import utils.misc;
import utils.ds;

import std.regex;

debug{import std.stdio;}

/// A token
package struct Token{
	/// line number and column number
	uint lineno, colno;
	/// token type.
	/// 
	/// `ushort.max` is reserved for `invalid/unknown type`
	ushort type = ushort.max;
	/// token
	string token;
	alias token this;
	/// constructor
	this(uint lineno, uint colno, ushort type, string token){
		this.lineno = lineno;
		this.colno = colno;
		this.type = type;
		this.token = token;
	}
	/// ditto
	this(ushort type, string token){
		this.type = type;
		this.token = token;
	}
}

/// a fancy string exploder using regex
///
/// this should probably be moved to my utils package, but it sits here for now
package class TokenGen{
private:
	/// regex for token types (excluding the ^ at start and $ at end)
	Regex!char[ushort] _typeRegex;
	
	/// currently open source code
	string _source;
	/// the tokens
	Token[] _tokens;
	/// line number and column number of error(s)
	uint[2][] _errors;

	/// Returns: first matching token from a string. type will be `ushort.max` in case of no match
	Token getToken(string str){
		Token r;
		foreach (type, expr; _typeRegex){
			Captures!string m = matchFirst(str, expr);
			if (!m.empty){
				r.type = type;
				r.token = m.hit;
				break;
			}
		}
		return r;
	}
	/// Returns: longest matching token from a string. type will be `ushort.max` in case of no match
	Token getTokenLongest(string str){
		Token r;
		r.type = ushort.max;
		foreach (type, expr; _typeRegex){
			Captures!string m = matchFirst(str, expr);
			if (!m.empty && m.hit.length > r.token.length){
				r.type = type;
				r.token = m.hit;
			}
		}
		return r;
	}
public:
	this(){
	}
	~this(){
	}
	/// the source code
	@property string source(){
		return _source;
	}
	/// ditto
	@property string source(string newVal){
		return _source = newVal;
	}
	/// Returns: line number and column number where unidentified token found
	@property uint[2][] errors(){
		uint[2][] r = _errors;
		_errors.length = 0;
		return r;
	}
	/// Returns: true if there are any errors
	@property bool error(){
		return _errors.length > 0;
	}
	/// adds a token type, with its matching regex.  
	/// Types that are added first, are matched first, so in case of conflicting types, add the higher predcedence one first
	/// 
	/// Returns: true if done, false if type already has a regex
	bool addTokenType(ushort type, string match){
		if (type in _typeRegex)
			return false;
		_typeRegex[type] = regex('^'~match);
		return true;
	}
	/// Returns: tokens
	@property Token[] tokens(){
		return _tokens;
	}
	/// clears tokens
	void clear(){
		_tokens.length = 0;
	}
	/// reads source into tokens. Any existing tokens will be cleared.
	/// 
	/// This will try to match regex expressions, and use the first one that matches.
	/// 
	/// Returns: true if done without errors, false if there was error
	bool readTokens(){
		this.clear();
		uint lineno;
		uint lastNewLineIndex;
		for (uint i = 0; i < _source.length; ){
			Token token = getToken(_source[i .. $]);
			token.lineno = lineno + 1;
			token.colno = i - lastNewLineIndex;
			if (token.type == ushort.max || !token.length){
				_errors ~= [token.lineno, token.colno];
				return false;
			}
			_tokens ~= token;
			foreach (j, c; _source[i .. i + token.length]){
				if (c == '\n'){
					lastNewLineIndex = cast(uint)j + i;
					lineno ++;
				}
			}
			i += token.length;
		}
		return true;
	}
	/// reads source into tokens. Any existing tokens will be cleared.
	/// 
	/// This will match against all regex, and use the longest hit
	/// 
	/// Returns: true if done without errors, false if there was error
	bool readTokensLongest(){
		this.clear();
		uint lineno;
		uint lastNewLineIndex;
		for (uint i = 0; i < _source.length; ){
			Token token = getTokenLongest(_source[i .. $]);
			token.lineno = lineno + 1;
			token.colno = i - lastNewLineIndex;
			if (token.type == ushort.max || !token.length){
				_errors ~= [token.lineno, token.colno];
				return false;
			}
			_tokens ~= token;
			foreach (j, c; _source[i .. i + token.length]){
				if (c == '\n'){
					lastNewLineIndex = cast(uint)j + i;
					lineno ++;
				}
			}
			i += token.length;
		}
		return true;
	}
	/// Removes tokens that match type
	/// 
	/// Returns: number of tokens removed
	uint removeByType(ushort type){
		uint count, i;
		while (i + count < _tokens.length){
			if (_tokens[i+count].type == type)
				count ++;
			else{
				_tokens[i] = _tokens[i+count];
				i ++;
			}
		}
		_tokens.length -= count;
		return count;
	}
	/// ditto
	uint removeByType(ushort[] types){
		uint count, i;
		while (i + count < _tokens.length){
			if (types.hasElement(_tokens[i+count].type))
				count ++;
			else{
				_tokens[i] = _tokens[i+count];
				i ++;
			}
		}
		_tokens.length -= count;
		return count;
	}
}
///
unittest{
	TokenGen tkGen = new TokenGen();
	bool flag = tkGen.addTokenType(0, `#.*`); // comments
	flag &= tkGen.addTokenType(1, `[\s]+`); // whitespace
	flag &= tkGen.addTokenType(2, `\/\*[\s\S]*\*\/`); // multi line comment
	flag &= tkGen.addTokenType(3, `"([^"]|(\\"))*((?<!\\)|(?<=\\\\))"`); // string
	assert(flag);
	tkGen.source = 
" # a single line coment fgdger4543terg h \"fsdfdsf\" \\\\gsdgfdv 
\t\t\"tabs > spaces\"/* multi
line
comment*/   
 \"another string\"";
	assert(tkGen.readTokens());
	Token[] tokens;
	string[] tkStrs;
	ushort[] tkTypes;
	tokens = tkGen.tokens;
	tkTypes.length = tokens.length;
	tkStrs.length = tokens.length;
	foreach (i; 0 .. tkStrs.length){
		tkStrs[i] = tokens[i].token;
		tkTypes[i] = tokens[i].type;
	}
	assert(tkStrs == [" ","# a single line coment fgdger4543terg h \"fsdfdsf\" \\\\gsdgfdv ",
		"\n\t\t","\"tabs > spaces\"","/* multi\nline\ncomment*/","   \n ", "\"another string\""]);
	assert(tkTypes == [1, 0, 1, 3, 2, 1, 3]);
	tkGen.removeByType(1); // no whitespace
	tokens = tkGen.tokens;
	tkTypes.length = tokens.length;
	foreach (i; 0 .. tkTypes.length)
		tkTypes[i] = tokens[i].type;
	assert(tkTypes == [0, 3, 2, 3]);
	tkGen.removeByType([0,2]); // no comments, or multi line comments
	tokens = tkGen.tokens;
	tkTypes.length = tokens.length;
	foreach (i; 0 .. tkTypes.length)
		tkTypes[i] = tokens[i].type;
	assert(tkTypes == [3,3]);
	.destroy(tkGen);
	// now testing readTokensLongest
	tkGen = new TokenGen();
	assert(tkGen.addTokenType(0, `import`));
	assert(tkGen.addTokenType(1, `[\S]+`));
	assert(tkGen.addTokenType(2, `[\s]+`));
	tkGen.source = "import something importsomethingElse";
	assert(tkGen.readTokensLongest());
	tkStrs.length = tkGen.tokens.length;
	tkTypes.length = tkStrs.length;
	foreach (i; 0 .. tkStrs.length){
		tkStrs[i] = tkGen.tokens[i].token;
		tkTypes[i] = tkGen.tokens[i].type;
	}
	assert(tkStrs == ["import", " ", "something", " ", "importsomethingElse"]);
	assert(tkTypes == [0, 2, 1, 2, 1]);
}