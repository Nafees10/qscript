module qscript.compiler.tokens;

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

/// Token generator using regex
package class TokenGen{
private:
	/// regex for token types (excluding the ^ at start and $ at end)
	Regex!char[ushort] _typeRegex;
	
	/// currently open source code
	string _source;
	/// the tokens
	List!Token _tokens;
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
public:
	this(){
		_tokens = new List!Token;
	}
	~this(){
		.destroy(_tokens);
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
		return _tokens.toArray;
	}
	/// clears tokens
	void clear(){
		_tokens.clear();
	}
	/// reads source into tokens. Any existing tokens will be cleared
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
			_tokens.append(token);
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
}