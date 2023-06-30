module app;

import std.stdio,
			 std.file,
			 std.algorithm.iteration;

import utils.ds;

import qscript.parser,
			 qscript.tokens,
			 qscript.compiler;

version(unittest){}else
void main(){
	// tokenize file
	Flags!TokenType ignore;
	ignore |= TokenType.Whitespace;
	ignore |= TokenType.Comment;
	ignore |= TokenType.CommentMultiline;
	auto range = Tokenizer(cast(string)read("sample"), ignore);

	Node rootNode;
	try{
		rootNode = parseScript(range);
	}catch (CompileError err){
		stderr.writeln("error:\n", err);
	}
	if (rootNode)
		writeln(rootNode.toJSON.toPrettyString);
	else
		stderr.writeln("root is null");
}
