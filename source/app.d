module app;

import std.stdio,
			 std.file,
			 std.algorithm.iteration;

import qscript.ast,
			 qscript.tokens,
			 qscript.compiler;

version(unittest){}else
void main(){
	Token[] tokens;
	write("tokens: ");
	foreach (token; Tokenizer(cast(string)read("sample")).
			filter(a => !a.type.get!(TokenType.Whitespace))){
	}
	while (!tokMaker.end){
		try{
			tokens ~= tokMaker.next;
		}catch (Exception e){
			writeln(tokens);
			writefln!"\n%s"(e.msg);
			return;
		}
	}
	whitespaceRemove(tokens);
	writeln(tokens);

	Node rootNode;
	uint i;
	rootNode = read(tokens, i);
	writeln(rootNode.toJSON.toPrettyString);
}
