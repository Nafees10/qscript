function void main{
	# count from 1-100000, test loops
	int (i);
	i = 0;
	while (i < 100000){
		i = i + 1;
		writeln(intToStr(i)); #writeln is not available in QScript by default
	}
}