package danga.s2;

public class FilePos implements Cloneable
{
    public int line;
    public int col;

    public FilePos (int l, int c) {
	line = l;
	col = c;
    }

    public Object clone () {
	return new FilePos(line, col);
    }

    public String locationString () {
	return ("line " + line + ", column " + col);
    }
    public String toString () {
	return locationString();
    }

}
