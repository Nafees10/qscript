module app;

import std.stdio,
			 std.file,
			 std.algorithm.iteration,
			 std.datetime.stopwatch,
			 std.format,
			 std.conv;

import utils.ds;

import qscript.parser,
			 qscript.tokens,
			 qscript.compiler;

version(unittest){}else
int main(string[] args){
	// tokenize file
	Flags!TokenType ignore;
	ignore |= TokenType.Whitespace;
	ignore |= TokenType.Comment;
	ignore |= TokenType.CommentMultiline;
	auto range = Tokenizer(cast(string)read("sample"), ignore);

	/*foreach (tok; range)
		stderr.writeln(tok);*/

	if (args.length > 1 && args[1] == "time" ){
		timeIt(range, args.length > 2 ? args[2].to!uint : 1);
		return 0;
	}

	auto result = parseScript(range);
	if (!result){
		stderr.writeln("error: ", result.error.msg);
		return 1;
	}
	Node rootNode = result.value;
	if (rootNode)
		writeln(rootNode.toJSON.toPrettyString);
	else
		stderr.writeln("root is null");
	return 0;
}

void timeIt(Tokenizer toks, uint times){
	void benchmark(ref StopWatch sw){
		auto branch = toks;
		sw.start;
		parseScript(branch);
		sw.stop;
	}
	bench(&benchmark, times).writeln;
}

struct Times{
	ulong min = ulong.max;
	ulong max = 0;
	ulong total = 0;
	ulong avg = 0;
	string toString() const @safe pure{
		return format!"min\tmax\tavg\ttotal\t/msecs\n%d\t%d\t%d\t%d"(
			min, max, avg, total);
	}
}

Times bench(void delegate(ref StopWatch sw) func, ulong runs = 100_000){
	Times time;
	StopWatch sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. runs){
		func(sw);
		immutable ulong currentTime = sw.peek.total!"msecs" - time.total;
		time.min = currentTime < time.min ? currentTime : time.min;
		time.max = currentTime > time.max ? currentTime : time.max;
		time.total = sw.peek.total!"msecs";
	}
	time.avg = time.total / runs;
	return time;
}
