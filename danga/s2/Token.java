package danga.s2;

public abstract class Token {

    public FilePos pos;

    public FilePos getFilePos () {
	return pos;
    }

    public boolean isNecessary() {
	return true;
    }
    public abstract String toString();
    public abstract void asHTML (Output o);

    public void asS2 (Indenter o) {
	o.write("##Token::asS2##");
    }
    public void asPerl (BackendPerl bp, Indenter o) {
	o.write("##Token::asPerl##");
    }

}
